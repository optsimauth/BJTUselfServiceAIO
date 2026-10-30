import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../data/models/homework/homework_model.dart';
import '../../data/repositories/homework_repository.dart';
import '../../services/file_picker/file_picker_service.dart';
import '../../shared/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/dialog/app_dialog.dart';
import '../../shared/widgets/error_text.dart';
import '../../shared/widgets/tinted_badge.dart';
import 'homework_controller.dart';
import 'homework_html_view.dart';
import 'homework_submit_dialog.dart';
import 'homework_timeline.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/page_width.dart';

/// 作业页。
///
/// 交互分层（每层只回答一个问题）：
/// - 顶部卡片回答「我现在最该交什么」，一件不剩时退化成统计；
/// - 筛选条管「看哪一类」（类型 / 课程 / 只看待交）；
/// - 阶段分组列表本身就是导航：待提交 → 已提交 → 已批改。
///
/// 旧项目 HomeworkScreen.kt 1308 行，把筛选、排序、上传、详情全塞在一个
/// StatefulWidget 里；这里拆成 [HomeworkController]（状态）+ 下面几个叶子组件。
class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key, this.now, this.repository, this.controller});

  /// 「现在」的时间，测试可注入；正常运行时自己走。
  final DateTime? now;

  /// 数据来源。不传就从 [ServiceScope] 拿，测试里注入内存实现。
  final HomeworkRepository? repository;

  final HomeworkController? controller;

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  late final HomeworkController _controller;
  bool _ownsController = false;
  Timer? _clock;
  late DateTime _now;

  /// 选文件。真实的平台层只在有 ServiceScope 时才有，测试里注入别的入口。
  Future<List<PickedFileInfo>> Function()? _pickFiles;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _controller =
        widget.controller ??
        (widget.repository == null
            ? ServiceScope.of(context).homeworkController
            : HomeworkController(repository: widget.repository!));
    _ownsController = widget.controller == null && widget.repository != null;
    _controller.syncMessage.addListener(_showSyncMessage);
    if (_ownsController) _controller.refresh();
    if (widget.controller == null && widget.repository == null) {
      _pickFiles = () => ServiceScope.of(context).filePickerService.pickFiles();
    }
    if (widget.now == null) {
      // 倒计时自己走：跨过截止点时「快截止」要立刻变成「已截止」。
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  /// 同步完有变化才提示一次；读走就置空，避免重建又弹。
  void _showSyncMessage() {
    final message = _controller.syncMessage.value;
    if (message == null || !mounted) return;
    _controller.syncMessage.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.syncMessage.removeListener(_showSyncMessage);
    _clock?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('作业'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: '刷新',
              onPressed: _controller.state is AsyncLoading
                  ? null
                  : _controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: PageWidth(
        maxWidth: AppLayout.contentMaxWidth,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            children: [
              _HomeworkFilterBar(
                controller: _controller,
                onPickCourse: _showCourseSheet,
              ),
              Expanded(
                child: AsyncView<List<Homework>>(
                  state: _controller.state,
                  onRetry: _controller.refresh,
                  loadingMessage: '正在同步作业…',
                  isEmpty: (_) => _controller.totalCount() == 0,
                  emptyBuilder: (_) => const EmptyHomeworkView(),
                  builder: (context, _) => _HomeworkBody(
                    controller: _controller,
                    now: _now,
                    onRefresh: _controller.refresh,
                    scrollController: _controller.listScrollController,
                    pickFiles: _pickFiles,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 课程是多选里退化成单选的那种筛选：一次只看一门课，选项太多不适合挤在条上。
  Future<void> _showCourseSheet() async {
    final courses = _controller.availableCourses;
    if (courses.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CourseSheet(
        courses: courses,
        selected: _controller.filter.courseName,
        onSelect: (name) {
          _controller.toggleCourse(name);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// 列表主体：顶部卡片 + 阶段分组。
class _HomeworkBody extends StatelessWidget {
  const _HomeworkBody({
    required this.controller,
    required this.now,
    required this.onRefresh,
    required this.scrollController,
    this.pickFiles,
  });

  final HomeworkController controller;
  final DateTime now;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;
  final Future<List<PickedFileInfo>> Function()? pickFiles;

  @override
  Widget build(BuildContext context) {
    final groups = controller.groups(now: now);
    if (groups.isEmpty) {
      // 筛选太窄了：一份作业都不剩，不该让用户以为「真的一门都没有」。
      return EmptyHomeworkView(
        message: '没有符合条件的作业',
        onClearFilter: controller.clearFilter,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          _HomeworkSummaryCard(controller: controller, now: now),
          for (final group in groups) ...[
            _GroupHeader(
              key: ValueKey('homework-group-${group.stage.name}'),
              group: group,
            ),
            for (final entry in group.entries)
              _HomeworkCard(
                key: ValueKey('homework-${entry.homework.identity}'),
                entry: entry,
                now: now,
                onTap: () => openHomeworkDetail(
                  context,
                  controller,
                  entry.homework,
                  now,
                  pickFiles: pickFiles,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 筛选条：课程 / 只看待交在前，类型在后面。
///
/// 顺序是有讲究的：学生最常用的两个筛选是「哪门课」和「还没交的」，
/// 所以它们必须在首屏；类型是平台定的三个固定值，用得少，放进可滚动区。
/// （反过来排的话，课程筛选会被四个类型 chip 顶到屏幕外。）
class _HomeworkFilterBar extends StatelessWidget {
  const _HomeworkFilterBar({
    required this.controller,
    required this.onPickCourse,
  });

  final HomeworkController controller;
  final VoidCallback onPickCourse;

  @override
  Widget build(BuildContext context) {
    final filter = controller.filter;
    return ConstrainedBox(
      // 52 只是「手机上一行 chip 的视觉高度」，不是硬性盒子：
      // 系统字号放大后 chip 会长高，写死高度会把文字裁掉。
      constraints: const BoxConstraints(minHeight: 52),
      child: SingleChildScrollView(
        key: const ValueKey('homework-filter-bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          // 横向滚动区里宽度是无界的，最小化才不会被判成「撑满无限宽」。
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TypeChip(
              label: filter.hasCourse ? filter.courseName! : '全部课程',
              selected: filter.hasCourse,
              icon: Icons.menu_book_outlined,
              onSelected: onPickCourse,
            ),
            _TypeChip(
              label: '仅待交',
              selected: filter.onlyPending,
              icon: Icons.pending_actions_outlined,
              onSelected: controller.toggleOnlyPending,
            ),
            const _ChipDivider(),
            _TypeChip(
              label: '全部类型',
              selected: filter.type == null,
              onSelected: controller.clearType,
            ),
            for (final type in controller.availableTypes)
              _TypeChip(
                label: type.label,
                selected: filter.type == type,
                onSelected: () => controller.toggleType(type),
              ),
          ],
        ),
      ),
    );
  }
}

/// 普通筛选片。`all` 段是「不限」，所以只有被选中时才需要点一下复位。
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: Center(
      child: Container(
        width: 1,
        height: 20,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

/// 课程选择弹层。课程名从数据来，所以选项有多少完全由同步结果决定。
class _CourseSheet extends StatelessWidget {
  const _CourseSheet({
    required this.courses,
    required this.selected,
    required this.onSelect,
  });

  final List<String> courses;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(
                '按课程筛选',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (selected != null)
              ListTile(
                dense: true,
                title: const Text('全部课程'),
                trailing: Icon(Icons.check, color: scheme.primary),
                onTap: () {
                  onSelect(selected!); // toggleCourse 会把同名的取消掉
                },
              ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return ListTile(
                    dense: true,
                    title: Text(course, overflow: TextOverflow.ellipsis),
                    trailing: course == selected
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () => onSelect(course),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部卡片：有待交的就说「下一件是什么」，否则说「一共多少件」。
class _HomeworkSummaryCard extends StatelessWidget {
  const _HomeworkSummaryCard({required this.controller, required this.now});

  final HomeworkController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = controller.pendingCount(now: now);
    final urgent = controller.urgentCount(now: now);
    final next = controller.nextTodo();

    return Container(
      key: const ValueKey('homework-summary'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: pending == 0
          ? _summaryDone(context, controller.visibleCount())
          : _summaryTodo(context, pending: pending, urgent: urgent, next: next),
    );
  }

  /// 统计态：全部交了。
  Widget _summaryDone(BuildContext context, int total) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '作业',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          '共 $total 项，全部已提交',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '老师批改后会出现在「已批改」分组里',
          style: AppTypography.captionMuted.copyWith(color: scheme.onSurface),
        ),
      ],
    );
  }

  /// 待交态：主数字 + 下一件是什么。
  Widget _summaryTodo(
    BuildContext context, {
    required int pending,
    required int urgent,
    required HomeworkEntry? next,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          urgent > 0 ? '待办 $pending 项 · $urgent 项快截止' : '待办 $pending 项',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (next != null) ...[
          Text(
            next.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            next.title.isEmpty ? '未命名作业' : next.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionMuted.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '下一件 · ${next.timing.countdownLabel(now)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// 分组标题：竖条 + 名字 + 件数。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.group});

  final HomeworkGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _stageAccent(group.stage, scheme),
              borderRadius: AppRadius.bar,
            ),
          ),
          const SizedBox(width: 8),
          Text(group.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${group.count}',
            style: AppTypography.captionMuted.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一条作业。已批改的那批整张卡降透明度，别跟「还要动手的」抢注意力。
class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    super.key,
    required this.entry,
    required this.now,
    required this.onTap,
  });

  final HomeworkEntry entry;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final homework = entry.homework;
    final muted = entry.stage == HomeworkStage.graded;
    final textColor = muted ? scheme.onSurfaceVariant : scheme.onSurface;

    // 时间项照旧项目 InfoItem 的排法：开放时间主行、截止时间次行。
    // 平台只给一个时就只显示那一行，不摆空占位。
    final openText = entry.timing.openText;
    final deadlineText = entry.timing.hasDeadline
        ? '截止 ${_deadlineText(entry)}'
        : null;

    return Opacity(
      opacity: muted ? 0.7 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        homework.title.isEmpty ? '未命名作业' : homework.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UrgencyBadge(
                      urgency: entry.timing.urgencyAt(now),
                      label: entry.timing.countdownLabel(now),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // 课程名和提交状态同一行 —— 旧项目卡片就是这么排的：
                // 左边课程，右边状态标签（`getHomeworkStatusInfo`）。
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        homework.courseName.isEmpty
                            ? '未知课程'
                            : homework.courseName,
                        style: AppTypography.captionMuted.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _SubmitStateBadge(homework: homework),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (openText.isNotEmpty || deadlineText != null)
                  _InfoLine(
                    icon: Icons.event_outlined,
                    text: openText.isEmpty ? deadlineText! : '开放 $openText',
                    secondary: openText.isEmpty ? null : deadlineText,
                  ),
                if (homework.allCount > 0)
                  _InfoLine(
                    icon: Icons.people_outline,
                    text: '已交 ${homework.submitCount}/${homework.allCount}',
                  ),
                // 批改状态：旧项目卡片上的一行，和分数同一来源。
                _InfoLine(
                  icon: Icons.fact_check_outlined,
                  text: homework.isGraded ? '已批改' : '未批改',
                ),
                if (homework.isGraded)
                  _InfoLine(
                    icon: Icons.star_outline,
                    text: '分数 ${homework.score}',
                  ),
                if (homework.needsAction) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: onTap,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('去提交'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 有时间戳就精确到分；平台只给了原始文本就原样显示，不自己编。
  String _deadlineText(HomeworkEntry entry) {
    final deadline = entry.timing.deadline;
    if (deadline == null) return entry.timing.deadlineText;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${deadline.year}-${two(deadline.month)}-${two(deadline.day)} '
        '${two(deadline.hour)}:${two(deadline.minute)}';
  }
}

/// 紧迫度徽章。颜色越暖越该先看。
class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency, required this.label});

  final HomeworkUrgency urgency;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = _urgencyAccent(urgency, Theme.of(context).colorScheme);
    return TintedBadge(label: label, accent: accent);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.secondary});

  final IconData icon;
  final String text;

  /// 次行。旧项目 InfoItem 就是「主 + 次」两行：时间项用它挂截止时间。
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: style),
                if (secondary != null) Text(secondary!, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 打开作业详情弹窗。抽成顶层函数，卡片和按钮共用一条路径。
///
/// 用 dialog 而不是底部弹层，是照旧项目 `HomeworkDetailDialog` 的样子：
/// 正文是 HTML，得给 WebView 一块**高度确定**的区域，弹层那种
/// 「内容多高我多高」的布局会让 WebView 拿不到约束。
Future<void> openHomeworkDetail(
  BuildContext context,
  HomeworkController controller,
  Homework homework,
  DateTime now, {
  Future<List<PickedFileInfo>> Function()? pickFiles,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _HomeworkDetailDialog(
      controller: controller,
      homework: homework,
      now: now,
      pickFiles: pickFiles,
    ),
  );
}

/// 作业详情弹窗：正文（HTML）+ 附件 + 提交。
///
/// 正文**第一帧就有**：列表同步时已经把 `content` 落库了，这里先用它渲染，
/// 详情接口退到后台补附件。以前是「整块转圈等网络」，看起来就像每次都在
/// 重新加载。
class _HomeworkDetailDialog extends StatefulWidget {
  const _HomeworkDetailDialog({
    required this.controller,
    required this.homework,
    required this.now,
    this.pickFiles,
  });

  final HomeworkController controller;
  final Homework homework;
  final DateTime now;
  final Future<List<PickedFileInfo>> Function()? pickFiles;

  @override
  State<_HomeworkDetailDialog> createState() => _HomeworkDetailDialogState();
}

class _HomeworkDetailDialogState extends State<_HomeworkDetailDialog> {
  /// 桌面端窗口可以很宽，正文一行几百字读不下去。手机上这个上限不起作用。
  static const double _maxWidth = 640;

  /// 占屏高的比例。旧项目是 0.76，这里留一点给系统的安全区；
  /// 字号翻倍时再往上顶一点 —— 头部和按钮都变高，弹窗不长高正文就没地方了。
  static const double _heightRatio = 0.78;
  static const double _heightRatioLargeText = 0.94;

  /// 正文。初值直接取本地那份，弹窗一出现就能读到字。
  late String _content = widget.homework.content;

  List<HomeworkAttachment> _attachments = const [];

  /// 附件清单还没拿到（本地没缓存、网络也还在路上）。
  bool _attachmentsLoading = true;

  /// 详情接口失败的原因。正文照旧显示，只在附件栏说明。
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  /// 先用本地缓存铺满，再回源。
  ///
  /// 两步分开是为了让界面立刻有东西：`cachedDetailOf` 只读内存/数据库，
  /// 网络失败也不影响已经显示出来的正文。
  Future<void> _loadDetail() async {
    final cached = await widget.controller.cachedDetailOf(widget.homework);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        if (cached.content.trim().isNotEmpty) _content = cached.content;
        _attachments = cached.attachments;
        _attachmentsLoading = false;
        _detailError = null;
      });
    }

    try {
      final detail = await widget.controller.detailOf(widget.homework);
      if (!mounted) return;
      if (detail.isFailed) {
        setState(() {
          _attachmentsLoading = false;
          _detailError = detail.error;
        });
        return;
      }
      setState(() {
        if (detail.content.trim().isNotEmpty) _content = detail.content;
        _attachments = detail.attachments;
        _attachmentsLoading = false;
        _detailError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _attachmentsLoading = false;
        _detailError = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final homework = widget.homework;
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dialog 已经把 insetPadding 扣掉了，这里只需再压一个上限。
          final width = constraints.maxWidth.clamp(0.0, _maxWidth);
          final height = constraints.maxHeight.clamp(
            0.0,
            media.height * _heightRatioOf(context),
          );
          return SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                _DetailHeader(
                  homework: homework,
                  now: widget.now,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _DetailContent(
                    content: _content,
                    attachments: _attachments,
                    attachmentsLoading: _attachmentsLoading,
                    error: _detailError,
                    homework: homework,
                    controller: widget.controller,
                  ),
                ),
                _SubmitBar(
                  homework: homework,
                  onSubmit: _openSubmit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 系统字号越大，弹窗越高：头部标题、徽章和提交按钮都跟着长，
  /// 弹窗不长高的话正文会被挤成一条缝。
  double _heightRatioOf(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final extra = (scale - 1).clamp(0.0, 1.0);
    return _heightRatio + (_heightRatioLargeText - _heightRatio) * extra;
  }

  /// 打开提交弹窗（选文件 → 备注 → 提交），成功后退回列表。
  Future<void> _openSubmit() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final submitted = await showHomeworkSubmitDialog(
      context,
      homework: widget.homework,
      controller: widget.controller,
      pickFiles: widget.pickFiles,
    );
    if (!mounted || !submitted) return;
    // 交完就退回列表：这份 homework 还是提交前的快照（徽章写着「未提交」），
    // 留在弹窗里只会自相矛盾；列表那边已经重新同步过了。
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('作业已提交')));
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.homework,
    required this.now,
    required this.onClose,
  });

  final Homework homework;
  final DateTime now;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timing = HomeworkTiming.parse(
      endTime: homework.endTime,
      openDate: homework.openDate,
    );
    return Padding(
      // 右边只留 xs：TextButton 自带内边距，再多一段看着像偏左。
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homework.title.isEmpty ? '未命名作业' : homework.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  homework.courseName.isEmpty ? '未知课程' : homework.courseName,
                  style: AppTypography.captionMuted.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // 提交状态放最前面：这是「要不要动手」的那一个信号。
                // 旧项目卡片的 `getHomeworkStatusInfo` 也是这个意思 ——
                // 「已提交」用对勾 + 主色，其它一律感叹 + 错误色。
                // 平台不返回 subStatus 时按 isSubmitted 推断，不能没有这一行。
                if (_isLargeText(context))
                  // _metaOf 的第一段就是提交状态，别再拼一遍。
                  Text(
                    _metaOf(timing).join(' · '),
                    style: AppTypography.captionMuted.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _SubmitStateBadge(homework: homework),
                      _MiniBadge(
                        icon: Icons.category_outlined,
                        label: homework.homeworkType.label,
                      ),
                      if (timing.hasDeadline)
                        _MiniBadge(
                          icon: Icons.event_outlined,
                          label: timing.countdownLabel(now),
                        ),
                      if (homework.isGraded)
                        _MiniBadge(
                          icon: Icons.star_outline,
                          label: '分数 ${homework.score}',
                        ),
                    ],
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onClose, child: const Text('关闭')),
        ],
      ),
    );
  }

  /// 系统字号超过 1.4 倍就把徽章收成一行文字。
  bool _isLargeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.4;

  /// 徽章上的那几段字，按顺序：提交状态 / 类型 / 截止 / 分数。
  List<String> _metaOf(HomeworkTiming timing) => [
    _submitStateLabel(homework),
    homework.homeworkType.label,
    if (timing.hasDeadline) timing.countdownLabel(now),
    if (homework.isGraded) '分数 ${homework.score}',
  ];
}

/// 已提交 / 未提交。卡片和详情头部共用，避免两处写出两种颜色。
class _SubmitStateBadge extends StatelessWidget {
  const _SubmitStateBadge({required this.homework});

  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final submitted = homework.isSubmitted;
    return TintedBadge(
      label: _submitStateLabel(homework),
      icon: submitted
          ? Icons.check_circle_outline
          : Icons.do_not_disturb_on_outlined,
      accent: submitted ? scheme.primary : scheme.error,
    );
  }
}

/// 状态文案。平台给了 subStatus 就用原文（可能是「已逾期」），
/// 没给就按已交 / 没交二值 —— 这一行不能空着。
String _submitStateLabel(Homework homework) {
  final status = homework.subStatus.trim();
  if (status.isNotEmpty) return status;
  return homework.isSubmitted ? '已提交' : '未提交';
}

/// 详情正文。三种状态各自成一个小组件，父级只做 FutureBuilder。
class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.content,
    required this.attachments,
    required this.attachmentsLoading,
    required this.error,
    required this.homework,
    required this.controller,
  });

  /// 附件区最多这么高：再多就自己滚，别把正文挤没。
  ///
  /// 144 不是随手写的：一封附件行 72 高，这个高度正好两整行 —— 停在半行上
  /// 会把文件名切掉一截，看着像渲染坏了。
  static const double _maxAttachmentsHeight = 144;

  /// 正文无论如何要留的高度。矮弹窗 + 2 倍字号时，就靠这条兜底。
  static const double _minHtmlHeight = 120;

  /// 附件行低于这个高度就别画了。
  static const double _minAttachmentRowHeight = 56;

  /// 平台正文（HTML）。
  final String content;

  final List<HomeworkAttachment> attachments;

  /// 附件清单还在路上。正文不受影响，这一栏先说明「正在加载」。
  final bool attachmentsLoading;

  /// 非空 = 附件没拿到，显示在「附件」栏里，正文照常渲染。
  final String? error;

  final Homework homework;
  final HomeworkController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final attachmentsHeight = attachments.isEmpty
            ? 0.0
            : _attachmentsHeight(constraints.maxHeight);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('作业内容', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              // 正文是平台给的 HTML，交给 WebView 渲染 —— 旧项目
              // HomeworkDetailDialog 也是这么显示的。它自带滚动，所以这里必须是
              // Expanded：给它一块高度确定的区域，否则平台视图拿不到约束。
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.md,
                  child: HomeworkHtmlView(html: content),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('附件', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              if (error != null)
                Text(
                  '附件加载失败：$error',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                )
              else if (attachmentsLoading)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '正在加载附件…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else if (attachments.isEmpty)
                Text(
                  '暂无附件',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else if (attachmentsHeight > 0)
                SizedBox(
                  height: attachmentsHeight,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final file in attachments)
                        _AttachmentTile(
                          file: file,
                          onDownload: () => _download(context, file),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 附件区高度：最多三成，且正文至少留 [_minHtmlHeight]。
  ///
  /// 原来写死 132 —— 360×800 的窗口配 2 倍字号时，正文区只剩 185 高，
  /// 固定 132 的附件区直接把 Column 顶出 41px（见 ui_redesign 的 2.0x 用例）。
  /// 改成按可用高度算，矮窗口下附件区自己让位，不会溢出。
  static double _attachmentsHeight(double available) {
    if (available <= _minHtmlHeight) return 0;
    final limit = (available - _minHtmlHeight).clamp(
      0.0,
      _maxAttachmentsHeight,
    );
    final height = (available * 0.36).clamp(0.0, limit);
    // 连一行都放不下就别放了：露半行被裁断的字比没有更糟。
    return height < _minAttachmentRowHeight ? 0 : height;
  }

  Future<void> _download(BuildContext context, HomeworkAttachment file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await controller.downloadAttachment(homework, file);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已保存到 $savedPath')));
    } catch (error) {
      if (!context.mounted) return;
      await AppDialog.error(context, error);
    }
  }
}

/// 附件行。文件名里的 `+` 在解析时已经换回空格了。
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.file, required this.onDownload});

  final HomeworkAttachment file;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = _formatSize(file.sizeBytes);
    // 2 倍字号下这一行要塞的东西都翻倍：再带着「大小文字 + 48dp 下载按钮」，
    // 固定尺寸的部件就把名字挤成一两个字。大字号时只保名字（大小是次要
    // 信息），下载图标退成纯装饰 —— 整行本身就是下载入口，触控区反而更大。
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Semantics(
      button: true,
      label: '下载 ${file.fileName}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: InkWell(
          onTap: onDownload,
          borderRadius: AppRadius.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    file.fileName,
                    maxLines: large ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (size.isNotEmpty && !large) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    size,
                    style: AppTypography.captionMuted.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.download_outlined, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.homework, required this.onSubmit});

  final Homework homework;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // 已批改的就不再给提交入口了 —— 那时候改的是已经录入的成绩。
    if (homework.isGraded) return const SizedBox.shrink();
    final label = homework.needsAction ? '提交作业' : '重新提交';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.upload_file),
          label: Text(label),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.captionMuted.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阶段配色：还要动手的最显眼，已批改的退成中性。
Color _stageAccent(HomeworkStage stage, ColorScheme scheme) => switch (stage) {
  HomeworkStage.todo => scheme.error,
  HomeworkStage.submitted => scheme.primary,
  HomeworkStage.graded => scheme.tertiary,
};

/// 紧迫度配色。
Color _urgencyAccent(HomeworkUrgency urgency, ColorScheme scheme) =>
    switch (urgency) {
      HomeworkUrgency.overdue => scheme.error,
      HomeworkUrgency.soon => scheme.tertiary,
      HomeworkUrgency.normal => scheme.primary,
      HomeworkUrgency.unknown => scheme.onSurfaceVariant,
    };

/// 附件体积。平台不给大小就显示空串，而不是「0 B」。
String _formatSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 空态：区分「真的一份都没有」和「当前筛选下没有」。
class EmptyHomeworkView extends StatelessWidget {
  const EmptyHomeworkView({super.key, this.message, this.onClearFilter});

  final String? message;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              message ?? '老师还没有布置作业',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              onClearFilter == null ? '布置后点右上角刷新' : '换个筛选条件看看',
              style: AppTypography.captionMuted,
              textAlign: TextAlign.center,
            ),
            if (onClearFilter != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('看全部'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
