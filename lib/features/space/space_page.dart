import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../shared/theme/spacing.dart';

/// 服务目录按使用目的分组；文字自然换行。
class SpacePage extends StatelessWidget {
  const SpacePage({super.key});
  static const _study = [
    _SpaceEntry(
      '课程表',
      '查看一周安排',
      Icons.calendar_view_week_outlined,
      AppRoutes.course,
    ),
    _SpaceEntry('成绩', '学期成绩与均分', Icons.school_outlined, AppRoutes.grade),
    _SpaceEntry('考试', '时间、地点与安排', Icons.assignment_outlined, AppRoutes.exam),
    _SpaceEntry(
      '作业',
      '提交状态与截止时间',
      Icons.edit_note_outlined,
      AppRoutes.homework,
    ),
    _SpaceEntry('课件', '课程资料与下载', Icons.folder_outlined, AppRoutes.courseware),
  ];
  static const _campus = [
    _SpaceEntry(
      '教室占用',
      '找一间自习教室',
      Icons.meeting_room_outlined,
      AppRoutes.detection,
    ),
    _SpaceEntry('邮箱', '校内邮件与通知', Icons.mail_outline, AppRoutes.email),
    _SpaceEntry('其他', '校历与校园工具', Icons.widgets_outlined, AppRoutes.other),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('校园服务')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= AppLayout.railMinWidth &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21;
              return ListView(
                padding: EdgeInsets.all(
                  constraints.maxWidth >= AppLayout.railMinWidth
                      ? AppSpacing.xl
                      : AppSpacing.lg,
                ),
                children: [
                  Text(
                    '查课表、交作业，或找一间自习教室。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (columns)
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ServiceGroup(title: '学业', entries: _study),
                        ),
                        SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: _ServiceGroup(title: '校园', entries: _campus),
                        ),
                      ],
                    )
                  else ...[
                    const _ServiceGroup(title: '学业', entries: _study),
                    const SizedBox(height: AppSpacing.xl),
                    const _ServiceGroup(title: '校园', entries: _campus),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ServiceGroup extends StatelessWidget {
  const _ServiceGroup({required this.title, required this.entries});
  final String title;
  final List<_SpaceEntry> entries;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Column(
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) const Divider(indent: 72),
              _ServiceTile(entry: entries[index]),
            ],
          ],
        ),
      ),
    ],
  );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.entry});
  final _SpaceEntry entry;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadius.control,
        ),
        child: Icon(entry.icon, color: scheme.primary),
      ),
      title: Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        entry.description,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: () => context.push(entry.route),
    );
  }
}

class _SpaceEntry {
  const _SpaceEntry(this.title, this.description, this.icon, this.route);
  final String title;
  final String description;
  final IconData icon;
  final String route;
}
