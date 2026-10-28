import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../data/models/classroom/classroom_model.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/page_width.dart';

/// 教学楼选择页（旧 BuildingScreen）。点进去看该楼的教室占用课表。
///
/// 名单用 [ClassroomBuildings.all]：教务教室使用查询的 `jxlh` 要的是这串数字
/// ID，不是中文楼名，所以列表项必须是 [ClassroomBuilding] 而不是裸字符串。
class DetectionPage extends StatelessWidget {
  const DetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('教室占用'),
      ),
      body: PageWidth(
        maxWidth: AppLayout.contentMaxWidth,
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: ClassroomBuildings.all.length,
          // 包 Builder：直接读主题的懒子项在切浅色/深色时不换色
          // （详见 space_page.dart 里同一处的说明）。
          itemBuilder: (context, index) => Builder(
            builder: (context) {
              final building = ClassroomBuildings.all[index];
              final hasPeople = ClassroomBuildings.peopleSourceNames.contains(
                building.name,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Card(
                  child: ListTile(
                    leading: _BuildingBadge(text: building.abbreviation),
                    title: Text(building.name),
                    subtitle: Text(
                      hasPeople ? '课表 · 此刻人数 · 可规划路线' : '只有课表，人数未开放',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(AppRoutes.classroomDetail(building)),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 教学楼缩写徽章（旧项目 `DetectionScreen` 的 42dp 方块）。
///
/// 缩写只做识别位，标题仍然是全名 —— 请求和路由用的是全名，缩写只在这里出现。
class _BuildingBadge extends StatelessWidget {
  const _BuildingBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.control,
      ),
      // 2 倍字号下缩写会比方块大，缩到装得下为止（缩写是图形化的识别位，不是正文）。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
