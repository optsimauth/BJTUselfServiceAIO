import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../shared/theme/spacing.dart';

/// 应用宫格页（旧 SpaceScreen）。只做导航，没有数据依赖。
class SpacePage extends StatelessWidget {
  const SpacePage({super.key});

  static const List<_SpaceEntry> _entries = [
    _SpaceEntry('课程表', Icons.calendar_view_week, AppRoutes.course),
    _SpaceEntry('成绩', Icons.grade_outlined, AppRoutes.grade),
    _SpaceEntry('考试', Icons.assignment_outlined, AppRoutes.exam),
    _SpaceEntry('作业', Icons.edit_note, AppRoutes.homework),
    _SpaceEntry('课件', Icons.folder_outlined, AppRoutes.courseware),
    _SpaceEntry('教室占用', Icons.meeting_room_outlined, AppRoutes.detection),
    _SpaceEntry('邮箱', Icons.mail_outline, AppRoutes.email),
    _SpaceEntry('其他', Icons.apps, AppRoutes.other),
    // 暂时停用：Windows 上 WebView2 纹理合成仍会白屏 / 吞点击，定位完再放开。
    // _SpaceEntry('网页', Icons.language, AppRoutes.web),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          // 格子宽度永远不超过这个值。取 120 时：手机 360/390/412 都是
          // 3 列（格宽 101/111/119，正好放下图标+三字），平板 6 列、
          // 桌面 10 列，且格子始终接近正方，不会出现「块很大字很小」。
          maxCrossAxisExtent: 120,
          mainAxisExtent: 76,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: _entries.length,
        // 里面的 [Builder] 不能省。
        //
        // 直接在 itemBuilder 里读主题，切浅色/深色时格子**不会**跟着换色：
        // sliver 的子项在新的 Theme 数据落地之前就重建完了，之后不再被通知，
        // 结果是深色底 + 浅色主题的深色字（"看不清字"）。
        // Builder 自己是被 Theme 标记的依赖，会被正常通知到。
        itemBuilder: (context, index) => Builder(
          builder: (context) {
            final entry = _entries[index];
            final scheme = Theme.of(context).colorScheme;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(entry.route),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.icon, size: 25, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpaceEntry {
  const _SpaceEntry(this.title, this.icon, this.route);

  final String title;
  final IconData icon;
  final String route;
}
