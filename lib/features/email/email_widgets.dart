import 'package:flutter/material.dart';

import 'email_controller.dart';
import 'email_models.dart';
import '../../shared/theme/spacing.dart';

/// 邮箱侧栏：写信 + 文件夹列表 + 搜索文件夹。
///
/// 侧栏只在宽屏出现；窄屏由页面顶部的文件夹切换按钮承担。
class MailFolderRail extends StatelessWidget {
  const MailFolderRail({
    super.key,
    required this.controller,
    required this.onCompose,
  });

  final EmailController controller;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folders = controller.visibleFolders;
    return Container(
      width: 216,
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: FilledButton.tonalIcon(
              onPressed: onCompose,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('写信'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索文件夹',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.sm,
                ),
              ),
              onChanged: controller.searchFolders,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (final folder in folders)
                  if (folder.isGroup)
                    _FolderGroupTile(name: folder.name)
                  else
                    _FolderTile(
                      folder: folder,
                      selected: folder.id == controller.folderId,
                      onTap: () => controller.selectFolder(folder.id),
                    ),
                if (folders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      '没有匹配的文件夹',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 「其他文件夹」这类分组标题：不可点，只做视觉分隔。
class _FolderGroupTile extends StatelessWidget {
  const _FolderGroupTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.selected,
    required this.onTap,
  });

  final MailFolder folder;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedColor: scheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        leading: Icon(
          mailFolderIcon(folder.icon),
          size: 18,
          color: selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 列表工具条：文件夹名 + 搜索 + 过滤 + 排序。
class MailListToolbar extends StatelessWidget {
  const MailListToolbar({
    super.key,
    required this.controller,
    required this.folderName,
  });

  final EmailController controller;
  final String folderName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              folderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          MailFilterMenu(controller: controller),
          const SizedBox(width: 4),
          MailSortMenu(controller: controller),
        ],
      ),
    );
  }
}

/// 过滤菜单（对应截图里的过滤面板）。
class MailFilterMenu extends StatelessWidget {
  const MailFilterMenu({super.key, required this.controller});

  final EmailController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.filter.activeCount;
    return PopupMenuButton<Object>(
      tooltip: '筛选',
      icon: Badge(
        isLabelVisible: active > 0,
        label: Text('$active'),
        child: const Icon(Icons.filter_list),
      ),
      onSelected: (choice) {
        if (choice is _FilterChoice) _apply(controller, choice);
      },
      itemBuilder: (context) => <PopupMenuEntry<Object>>[
        const PopupMenuItem<Object>(
          value: _Clear(),
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.clear_all, size: 18),
            title: Text('清除全部条件'),
          ),
        ),
        const PopupMenuDivider(),
        _filterHeader(context, '全部邮件'),
        ..._radio<MailReadFilter>(
          MailReadFilter.values,
          controller.filter.read,
          (v) => _Read(v),
        ),
        _filterHeader(context, '标记'),
        ..._radio<MailFlagFilter>(
          MailFlagFilter.values,
          controller.filter.flag,
          (v) => _Flag(v),
        ),
        _filterHeader(context, '优先级'),
        ..._radio<MailPriorityFilter>(
          MailPriorityFilter.values,
          controller.filter.priority,
          (v) => _Priority(v),
        ),
        _filterHeader(context, '附件'),
        ..._radio<MailAttachmentFilter>(
          MailAttachmentFilter.values,
          controller.filter.attachment,
          (v) => _Attachment(v),
        ),
        _filterHeader(context, '往来'),
        ..._radio<MailDealFilter>(
          MailDealFilter.values,
          controller.filter.deal,
          (v) => _Deal(v),
        ),
      ],
    );
  }

  List<PopupMenuEntry<Object>> _radio<T>(
    List<T> values,
    T current,
    _FilterChoice Function(T) wrap,
  ) => [
    for (final value in values)
      PopupMenuItem<Object>(
        value: wrap(value),
        child: _CheckLine(label: _labelOf(value), checked: value == current),
      ),
  ];

  String _labelOf<T>(T value) => switch (value) {
    MailReadFilter v => v.label,
    MailFlagFilter v => v.label,
    MailPriorityFilter v => v.label,
    MailAttachmentFilter v => v.label,
    MailDealFilter v => v.label,
    _ => '$value',
  };
}

void _apply(EmailController controller, _FilterChoice choice) {
  final current = controller.filter;
  controller.updateFilter(switch (choice) {
    _Clear() => const MailFilter(),
    _Read(:final value) => current.copyWith(read: value),
    _Flag(:final value) => current.copyWith(flag: value),
    _Priority(:final value) => current.copyWith(priority: value),
    _Attachment(:final value) => current.copyWith(attachment: value),
    _Deal(:final value) => current.copyWith(deal: value),
  });
}

/// 排序菜单（对应截图里的排序面板）。
class MailSortMenu extends StatelessWidget {
  const MailSortMenu({super.key, required this.controller});

  final EmailController controller;

  @override
  Widget build(BuildContext context) => PopupMenuButton<Object>(
    tooltip: '排序：${controller.sort.label}',
    icon: const Icon(Icons.swap_vert),
    onSelected: (choice) {
      if (choice is MailSortField) {
        controller.updateSort(
          MailSort(field: choice, descending: controller.sort.descending),
        );
      } else if (choice == _sortFlip) {
        controller.flipSortDirection();
      }
    },
    itemBuilder: (context) => [
      for (final field in MailSortField.values)
        PopupMenuItem<Object>(
          value: field,
          child: _CheckLine(
            label: field.label,
            checked: controller.sort.field == field,
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<Object>(
        value: _sortFlip,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.swap_vert, size: 18),
          title: Text('升降序切换'),
        ),
      ),
    ],
  );
}

const _sortFlip = 'flip';

/// 单封邮件的操作菜单（对应截图里的操作面板）。
class MailActionMenu extends StatelessWidget {
  const MailActionMenu({
    super.key,
    required this.message,
    required this.onAction,
    this.onMove,
  });

  final MailSummary message;
  final ValueChanged<MailAction> onAction;
  final ValueChanged<int>? onMove;

  @override
  Widget build(BuildContext context) => PopupMenuButton<Object>(
    tooltip: '更多操作',
    icon: const Icon(Icons.more_vert, size: 20),
    onSelected: (choice) {
      if (choice is MailAction) {
        onAction(choice);
      } else if (choice is MailFolder && onMove != null) {
        onMove!(choice.id);
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem<Object>(
        value: message.isRead ? MailAction.markUnread : MailAction.markRead,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            message.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
            size: 18,
          ),
          title: Text(message.isRead ? '未读' : '已读'),
        ),
      ),
      PopupMenuItem<Object>(
        value: message.isFlagged ? MailAction.unflag : MailAction.flag,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            message.isFlagged ? Icons.flag : Icons.outlined_flag,
            size: 18,
          ),
          title: Text(message.isFlagged ? '取消标记' : '红旗'),
        ),
      ),
      PopupMenuItem<Object>(
        value: message.isTop ? MailAction.untop : MailAction.top,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.push_pin_outlined, size: 18),
          title: Text(message.isTop ? '取消置顶' : '置顶邮件'),
        ),
      ),
      PopupMenuItem<Object>(
        value: message.isTodo ? MailAction.untodo : MailAction.todo,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule, size: 18),
          title: Text(message.isTodo ? '取消待办' : '待办邮件'),
        ),
      ),
      if (onMove != null) ...[
        const PopupMenuDivider(),
        _filterHeader(context, '移动到'),
        for (final folder in moveTargetFolders)
          if (folder.id != message.folderId)
            PopupMenuItem<Object>(
              value: folder,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(mailFolderIcon(folder.icon), size: 18),
                title: Text(folder.name),
              ),
            ),
      ],
    ],
  );
}

/// 多选时浮在底部的批量操作条。
class MailSelectionBar extends StatelessWidget {
  const MailSelectionBar({
    super.key,
    required this.controller,
    required this.onAction,
    required this.onMove,
  });

  final EmailController controller;
  final Future<void> Function(MailAction) onAction;
  final Future<void> Function(int) onMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                tooltip: '取消多选',
                onPressed: controller.clearSelection,
                icon: const Icon(Icons.close),
              ),
              Text(
                '已选 ${controller.selection.length} 封',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onAction(MailAction.flag),
                icon: const Icon(Icons.outlined_flag, size: 18),
                label: const Text('标记'),
              ),
              TextButton.icon(
                onPressed: () => onAction(MailAction.markUnread),
                icon: const Icon(Icons.mark_email_unread, size: 18),
                label: const Text('未读'),
              ),
              PopupMenuButton<Object>(
                tooltip: '移动到',
                icon: const Icon(Icons.drive_file_move_outline),
                onSelected: (choice) {
                  if (choice is MailFolder) onMove(choice.id);
                },
                itemBuilder: (context) => [
                  for (final folder in moveTargetFolders)
                    PopupMenuItem<Object>(
                      value: folder,
                      child: Text(folder.name),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        checked ? Icons.check : Icons.check_box_outline_blank,
        size: 18,
        color: checked ? Theme.of(context).colorScheme.primary : null,
      ),
      const SizedBox(width: 8),
      Text(label),
    ],
  );
}

/// 过滤菜单里的分组标题。不可选，只是视觉分隔。
PopupMenuEntry<Object> _filterHeader(BuildContext context, String title) =>
    PopupMenuItem<Object>(
      enabled: false,
      height: 32,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );

/// 过滤菜单的选中项。用普通 sealed 子类而不是工厂构造，
/// 这样 `const PopupMenuItem(value: _FilterChoice.clear)` 才能编译。
sealed class _FilterChoice {
  const _FilterChoice();
}

class _Clear extends _FilterChoice {
  const _Clear();
}

class _Read extends _FilterChoice {
  const _Read(this.value);
  final MailReadFilter value;
}

class _Flag extends _FilterChoice {
  const _Flag(this.value);
  final MailFlagFilter value;
}

class _Priority extends _FilterChoice {
  const _Priority(this.value);
  final MailPriorityFilter value;
}

class _Attachment extends _FilterChoice {
  const _Attachment(this.value);
  final MailAttachmentFilter value;
}

class _Deal extends _FilterChoice {
  const _Deal(this.value);
  final MailDealFilter value;
}

/// 图标映射。侧栏和移动菜单共用。
IconData mailFolderIcon(String icon) => switch (icon) {
  'inbox' => Icons.inbox_outlined,
  'flag' => Icons.flag_outlined,
  'drafts' => Icons.drafts_outlined,
  'send' => Icons.send_outlined,
  'delete' => Icons.delete_outline,
  'spam' => Icons.report_outlined,
  'virus' => Icons.dangerous_outlined,
  'other' => Icons.create_new_folder_outlined,
  _ => Icons.folder_outlined,
};
