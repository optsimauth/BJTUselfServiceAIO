import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../core/network/network_exception.dart';
import 'email_controller.dart';
import 'email_models.dart';
import 'email_widgets.dart';
import '../../shared/theme/spacing.dart';

class EmailPage extends StatefulWidget {
  const EmailPage({super.key});

  @override
  State<EmailPage> createState() => _EmailPageState();
}

enum _EmailMode { list, detail, compose }

class _EmailPageState extends State<EmailPage> {
  late final EmailController _controller;
  _EmailMode _mode = _EmailMode.list;
  MailSummary? _selected;
  bool _opening = false;
  bool _startingCompose = false;

  @override
  void initState() {
    super.initState();
    _controller = ServiceScope.of(context).emailController;
    if (_controller.state is AsyncIdle<EmailViewState>) {
      unawaited(_controller.refresh());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Text(_title),
        actions: _actions,
      ),
      body: switch (_mode) {
        _EmailMode.list => _MailboxList(
          controller: _controller,
          onOpen: _openMessage,
          onCompose: _startCompose,
        ),
        _EmailMode.detail => _MailboxDetail(
          message: _controller.message,
          loading: _opening,
          onReply: _startReply,
        ),
        _EmailMode.compose => _MailboxCompose(
          draft: _controller.draft,
          loading: _startingCompose,
          onCancel: _cancelCompose,
          onSend: _sendDraft,
          onChanged: _controller.updateDraft,
        ),
      },
    ),
  );

  void _goBack() {
    if (_mode == _EmailMode.list) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _mode = _mode == _EmailMode.compose && _selected != null
          ? _EmailMode.detail
          : _EmailMode.list;
    });
  }

  String get _title => switch (_mode) {
    _EmailMode.list => '邮箱',
    _EmailMode.detail => '邮件详情',
    _EmailMode.compose => _controller.draft?.isReply == true ? '回复邮件' : '写信',
  };

  List<Widget> get _actions => switch (_mode) {
    _EmailMode.list => [
      IconButton(
        tooltip: '写信',
        icon: const Icon(Icons.edit_outlined),
        onPressed: _startCompose,
      ),
      IconButton(
        tooltip: '刷新',
        icon: const Icon(Icons.refresh),
        onPressed: _controller.refresh,
      ),
    ],
    _EmailMode.detail => [
      IconButton(
        tooltip: '回复',
        icon: const Icon(Icons.reply_outlined),
        onPressed: _startReply,
      ),
    ],
    _EmailMode.compose => const [],
  };

  Future<void> _openMessage(MailSummary summary) async {
    setState(() {
      _selected = summary;
      _mode = _EmailMode.detail;
      _opening = true;
    });
    final message = await _controller.openMessage(summary);
    if (!mounted) return;
    if (message == null) {
      setState(() {
        _mode = _EmailMode.list;
        _opening = false;
      });
      _showMessage('邮件详情暂时无法打开，请检查网络后重试');
      return;
    }
    setState(() => _opening = false);
  }

  Future<void> _startCompose() async {
    setState(() {
      _mode = _EmailMode.compose;
      _startingCompose = true;
    });
    final draft = await _controller.startCompose();
    if (!mounted) return;
    if (draft == null) {
      setState(() {
        _mode = _EmailMode.list;
        _startingCompose = false;
      });
      _showMessage('写信页面暂时无法打开，请检查网络后重试');
      return;
    }
    setState(() => _startingCompose = false);
  }

  Future<void> _startReply() async {
    final message = _controller.message;
    if (message == null) return;
    setState(() {
      _mode = _EmailMode.compose;
      _startingCompose = true;
    });
    final draft = await _controller.startCompose(replyToMessageId: message.id);
    if (!mounted) return;
    if (draft == null) {
      setState(() {
        _mode = _EmailMode.detail;
        _startingCompose = false;
      });
      _showMessage('回复页面暂时无法打开，请检查网络后重试');
      return;
    }
    setState(() => _startingCompose = false);
  }

  Future<void> _cancelCompose() async {
    await _controller.cancelDraft();
    if (mounted) {
      setState(
        () => _mode = _selected == null ? _EmailMode.list : _EmailMode.detail,
      );
    }
  }

  Future<void> _sendDraft() async {
    final draft = _controller.draft;
    if (draft == null) return;
    final recipients = _recipients(draft.to);
    if (recipients.isEmpty) return _showMessage('请至少填写一个收件人');
    if (draft.subject.trim().isEmpty && draft.bodyText.trim().isEmpty) {
      return _showMessage('请填写主题或正文');
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认发送'),
        content: Text(
          '将发送给 ${recipients.join('、')}\n主题：${draft.subject.trim().isEmpty ? '无主题' : draft.subject}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final sent = await _controller.sendDraft();
    if (!mounted) return;
    if (sent) {
      _showMessage('邮件已发送');
      setState(() => _mode = _EmailMode.list);
    } else {
      _showMessage('邮件发送失败，请检查网络后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static List<String> _recipients(String value) => value
      .split(RegExp(r'[,;，；\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// 邮箱外壳。
///
/// 结构是 AppShell 那种两栏：左边的文件夹栏 + 右边的列表区**常驻**，
/// 切换文件夹只换右边的内容，绝不整页替换 —— 整页替换就是「点一下闪一下」。
/// 这里只处理**整页级**的失败（连文件夹列表都拿不到时）。
class _MailboxList extends StatelessWidget {
  const _MailboxList({
    required this.controller,
    required this.onOpen,
    required this.onCompose,
  });

  final EmailController controller;
  final ValueChanged<MailSummary> onOpen;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final error = switch (controller.state) {
      AsyncError<EmailViewState>(:final error) => error,
      _ => null,
    };
    if (error != null) {
      return _MailboxError(error: error, onRetry: controller.refresh);
    }
    return _MailboxBody(
      controller: controller,
      onOpen: onOpen,
      onCompose: onCompose,
    );
  }
}

/// 宽屏左侧出文件夹栏；窄屏只留顶部文件夹切换。
class _MailboxBody extends StatelessWidget {
  const _MailboxBody({
    required this.controller,
    required this.onOpen,
    required this.onCompose,
  });

  final EmailController controller;
  final ValueChanged<MailSummary> onOpen;
  final VoidCallback onCompose;

  static const double railBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    return Row(
      children: [
        if (wide) MailFolderRail(controller: controller, onCompose: onCompose),
        Expanded(
          child: Column(
            children: [
              _MailToolbar(controller: controller, showPicker: !wide),
              // 正在拉数据时在列表区顶边挂一条 2px 进度条。
              // 不用遮罩：盖一层半透明色就是那一下灰闪，内容也看不见了。
              _ListProgress(showing: controller.loading),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: _MailList(controller: controller, onOpen: onOpen),
                ),
              ),
              if (controller.selecting)
                MailSelectionBar(
                  controller: controller,
                  onAction: (action) async {
                    final ok = await controller.runActionOnSelection(action);
                    if (!context.mounted) return;
                    _toast(
                      context,
                      ok ? '已更新 ${controller.selection.length} 封' : '操作失败，已恢复',
                    );
                  },
                  onMove: (fid) async {
                    final ok = await controller.moveSelection(fid);
                    if (!context.mounted) return;
                    _toast(context, ok ? '已移动' : '移动失败');
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 列表区顶部的 2px 进度条。[showing] 为 false 时**不占任何高度**，
/// 所以它出现/消失不会把下面的列表挤一下（那也是一次抖动）。
class _ListProgress extends StatelessWidget {
  const _ListProgress({required this.showing});

  final bool showing;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 120),
    curve: Curves.easeOut,
    alignment: Alignment.topCenter,
    child: SizedBox(
      height: showing ? 2 : 0,
      width: double.infinity,
      child: showing
          ? LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Theme.of(context).colorScheme.surface,
            )
          : null,
    ),
  );
}
class _MailToolbar extends StatelessWidget {
  const _MailToolbar({required this.controller, required this.showPicker});

  final EmailController controller;
  final bool showPicker;

  @override
  Widget build(BuildContext context) {
    final folder = controller.folders.firstWhere(
      (f) => f.id == controller.folderId,
      orElse: () => controller.folders.first,
    );
    return Column(
      children: [
        MailListToolbar(controller: controller, folderName: folder.name),
        if (showPicker) _FolderPicker(controller: controller),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
          child: TextField(
            style: Theme.of(context).textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索邮件（发件人 / 主题 / 正文）',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.sm,
              ),
            ),
            onChanged: (value) => controller.updateFilter(
              controller.filter.copyWith(query: value),
            ),
          ),
        ),
      ],
    );
  }
}

class _FolderPicker extends StatelessWidget {
  const _FolderPicker({required this.controller});

  final EmailController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
    child: PopupMenuButton<int>(
      tooltip: '切换文件夹',
      onSelected: controller.selectFolder,
      itemBuilder: (context) => [
        for (final folder in controller.visibleFolders)
          if (!folder.isGroup)
            PopupMenuItem<int>(
              value: folder.id,
              child: Row(
                children: [
                  Icon(mailFolderIcon(folder.icon), size: 18),
                  const SizedBox(width: 8),
                  Text(folder.name),
                  if (folder.id == controller.folderId) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
      ],
      child: Chip(
        avatar: Icon(mailFolderIcon(folderIconOf(controller)), size: 18),
        label: Text(controller.currentFolderName),
      ),
    ),
  );

  static String folderIconOf(EmailController controller) => controller.folders
      .firstWhere(
        (f) => f.id == controller.folderId,
        orElse: () => controller.folders.first,
      )
      .icon;
}

/// 列表区的居中占位：首屏转圈、空文件夹提示都走它。
class _ListPlaceholder extends StatelessWidget {
  const _ListPlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    // 居中靠 ListView 而不是 Center：RefreshIndicator 需要能滚动的子树。
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
      Center(child: child),
    ],
  );
}

class _MailList extends StatelessWidget {
  const _MailList({required this.controller, required this.onOpen});

  final EmailController controller;
  final ValueChanged<MailSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    // 首屏：还没拿到过任何数据，列表区是空的 —— 居中转圈，不会有内容闪。
    if (controller.loading && !controller.hasData) {
      return const _ListPlaceholder(child: CircularProgressIndicator());
    }
    final messages = controller.visibleMessages;
    if (messages.isEmpty) {
      final filtering = !controller.filter.isEmpty;
      return _ListPlaceholder(
        child: Text(
          filtering ? '没有符合筛选条件的邮件' : '这个文件夹里没有邮件',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          if (!controller.hasMore) return const SizedBox(height: 12);
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: controller.loadingMore ? null : controller.loadMore,
              icon: controller.loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(controller.loadingMore ? '正在加载' : '加载更多邮件'),
            ),
          );
        }
        final message = messages[index];
        return _MailRow(
          message: message,
          selected: controller.selection.contains(message.id),
          selecting: controller.selecting,
          onTap: () => onOpen(message),
          onToggleSelect: () => controller.toggleSelect(message.id),
          onAction: (action) async {
            // 标待办先问是哪一天 —— 待办队列按这天分页；关掉日期框等于放弃。
            DateTime? todoAt;
            if (action == MailAction.todo) {
              todoAt = await _pickTodoDay(context);
              if (todoAt == null) return;
            }
            if (!context.mounted) return;
            final ok = await controller.runAction(
              message,
              action,
              todoAt: todoAt,
            );
            if (!context.mounted) return;
            _toast(context, ok ? '已${action.label}' : '操作失败，已恢复');
          },
          onMove: (fid) async {
            final ok = await controller.moveMessage(message.id, fid);
            if (!context.mounted) return;
            _toast(context, ok ? '已移动' : '移动失败');
          },
        );
      },
    );
  }
}

/// 选待办日期。默认明天，今天到三年后。
Future<DateTime?> _pickTodoDay(BuildContext context) {
  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));
  return showDatePicker(
    context: context,
    initialDate: tomorrow,
    firstDate: today,
    lastDate: DateTime(today.year + 3, today.month, today.day),
    helpText: '待办到哪一天',
  );
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _MailRow extends StatelessWidget {
  const _MailRow({
    required this.message,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onToggleSelect,
    required this.onAction,
    required this.onMove,
  });

  final MailSummary message;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;
  final ValueChanged<MailAction> onAction;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onToggleSelect,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting)
                Checkbox(value: selected, onChanged: (_) => onToggleSelect())
              else
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.md),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: message.isRead
                        ? scheme.surfaceContainerHighest
                        : scheme.primaryContainer,
                    child: Text(
                      _initial(message.sender),
                      // 背景在「已读 / 未读」之间切换，文字色必须跟着配对。
                      style: TextStyle(
                        color: message.isRead
                            ? scheme.onSurfaceVariant
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!message.isRead) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (message.isFlagged)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(
                              Icons.flag,
                              size: 14,
                              color: scheme.error,
                            ),
                          ),
                        if (message.isTop)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: scheme.primary,
                            ),
                          ),
                        if (message.isTodo)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(
                              Icons.schedule,
                              size: 14,
                              color: scheme.tertiary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            message.sender.isEmpty ? '未知往来对象' : message.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: message.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                          ),
                        ),
                        Text(
                          message.dateText,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.subject.isEmpty ? '无主题' : message.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (message.hasAttachments)
                          const Icon(Icons.attach_file, size: 16),
                        MailActionMenu(
                          message: message,
                          onAction: onAction,
                          onMove: onMove,
                        ),
                      ],
                    ),
                    if (message.preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String value) =>
      value.trim().isEmpty ? '信' : value.trim().characters.first;
}

class _MailboxDetail extends StatelessWidget {
  const _MailboxDetail({
    required this.message,
    required this.loading,
    required this.onReply,
  });

  final MailMessage? message;
  final bool loading;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    if (loading || message == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final mail = message!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      children: [
        Text(
          mail.subject.isEmpty ? '无主题' : mail.subject,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _AddressLine(label: '发件人', values: mail.from),
        _AddressLine(label: '收件人', values: mail.to),
        if (mail.cc.isNotEmpty) _AddressLine(label: '抄送', values: mail.cc),
        Text(mail.dateText, style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 28),
        for (final block in mail.blocks) _ContentBlockView(block: block),
        if (mail.blocks.isEmpty) const Text('这封邮件没有可显示的正文'),
        if (mail.attachments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('附件', style: Theme.of(context).textTheme.titleMedium),
          for (final file in mail.attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(file.name),
              subtitle: Text(_fileMeta(file)),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onReply,
          icon: const Icon(Icons.reply),
          label: const Text('回复'),
        ),
      ],
    );
  }

  static String _fileMeta(MailAttachment file) {
    final size = file.sizeBytes;
    if (size == null || size <= 0) return file.contentType ?? '附件';
    final label = size < 1024 * 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${file.contentType ?? '附件'} · $label';
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text('$label：${values.isEmpty ? '未知' : values.join('、')}'),
  );
}

class _ContentBlockView extends StatelessWidget {
  const _ContentBlockView({required this.block});

  final MailContentBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    MailParagraph(:final text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SelectableText(text, style: Theme.of(context).textTheme.bodyLarge),
    ),
    MailTable(:final rows) => _MailTable(rows: rows),
  };
}

class _MailTable extends StatelessWidget {
  const _MailTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: Text(cell)),
            ],
          ),
      ],
    ),
  );
}

class _MailboxCompose extends StatefulWidget {
  const _MailboxCompose({
    required this.draft,
    required this.loading,
    required this.onCancel,
    required this.onSend,
    required this.onChanged,
  });

  final MailComposeDraft? draft;
  final bool loading;
  final Future<void> Function() onCancel;
  final Future<void> Function() onSend;
  final ValueChanged<MailComposeDraft> onChanged;

  @override
  State<_MailboxCompose> createState() => _MailboxComposeState();
}

class _MailboxComposeState extends State<_MailboxCompose> {
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _bcc = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      _loadDraft(draft);
    }
  }

  @override
  void didUpdateWidget(covariant _MailboxCompose oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft != null && oldWidget.draft?.id != widget.draft?.id) {
      _loadDraft(widget.draft!);
    }
  }

  @override
  void dispose() {
    for (final item in [_to, _cc, _bcc, _subject, _body]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    if (widget.loading || draft == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      children: [
        _ComposeField(
          controller: _to,
          label: '收件人',
          hint: '多个地址用逗号分隔',
          onChanged: () => _emit(draft),
        ),
        const SizedBox(height: 10),
        _ComposeField(
          controller: _cc,
          label: '抄送',
          hint: '可选',
          onChanged: () => _emit(draft),
        ),
        const SizedBox(height: 10),
        _ComposeField(
          controller: _bcc,
          label: '密送',
          hint: '可选',
          onChanged: () => _emit(draft),
        ),
        const SizedBox(height: 10),
        _ComposeField(
          controller: _subject,
          label: '主题',
          hint: '无主题',
          onChanged: () => _emit(draft),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _body,
          minLines: 12,
          maxLines: 20,
          decoration: const InputDecoration(
            labelText: '正文',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(draft),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sending ? null : widget.onCancel,
                icon: const Icon(Icons.close),
                label: const Text('取消'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_sending ? '发送中' : '发送'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '邮件会先在服务器创建草稿，点击发送后才会发出。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _loadDraft(MailComposeDraft draft) {
    _to.text = draft.to;
    _cc.text = draft.cc;
    _bcc.text = draft.bcc;
    _subject.text = draft.subject;
    _body.text = draft.bodyText;
  }

  void _emit(MailComposeDraft draft) => widget.onChanged(
    draft.copyWith(
      to: _to.text,
      cc: _cc.text,
      bcc: _bcc.text,
      subject: _subject.text,
      bodyText: _body.text,
    ),
  );

  Future<void> _send() async {
    final draft = widget.draft!;
    _emit(draft);
    setState(() => _sending = true);
    await widget.onSend();
    if (mounted) setState(() => _sending = false);
  }
}

class _ComposeField extends StatelessWidget {
  const _ComposeField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    maxLines: null,
    onChanged: (_) => onChanged(),
  );
}

class _MailboxError extends StatelessWidget {
  const _MailboxError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mail_outline,
            size: 44,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(_mailboxErrorText(error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}

/// 把底层异常翻成一句**能区分是哪一环断了**的话。
///
/// 原来所有失败都显示同一句「请检查登录状态和网络」，既没说清是会话、
/// 网络还是解析，也没法据此定位 —— 这里按已知的几种失败分支给不同文案。
String _mailboxErrorText(Object error) => switch (error) {
  NetworkException(:final kind) => switch (kind) {
    NetworkErrorKind.unauthorized => '登录已失效，请重新登录后再打开邮箱',
    NetworkErrorKind.timeout => '连接邮箱超时，请检查网络后重试',
    NetworkErrorKind.noConnection => '当前没有网络连接',
    _ => '连接邮箱失败，请稍后重试',
  },
  FormatException(:final message) => switch (message) {
    '邮箱登录会话已失效' => '学校会话已失效，请退出后重新登录',
    '邮箱会话缺少 sid' => '邮箱会话建立失败，请重新登录后重试',
    '邮箱服务返回失败' => '邮箱服务返回异常（通常是会话过期），请点重试',
    _ => '邮箱返回了无法识别的内容，请点重试',
  },
  _ => '邮箱暂时无法打开，请稍后重试',
};
