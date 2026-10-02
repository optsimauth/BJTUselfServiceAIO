import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../data/models/classroom/classroom_model.dart';
import '../../shared/widgets/buttons/app_buttons.dart';

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
      body: ListView.builder(
        itemCount: ClassroomBuildings.all.length,
        // 包 Builder：直接读主题的懒子项在切浅色/深色时不换色
        // （详见 space_page.dart 里同一处的说明）。
        itemBuilder: (context, index) => Builder(
          builder: (context) {
            final building = ClassroomBuildings.all[index];
            final hasPeople = ClassroomBuildings.peopleSourceNames.contains(
              building.name,
            );
            return ListTile(
              leading: const Icon(Icons.apartment),
              title: Text(building.name),
              subtitle: Text(
                hasPeople ? '课表 + 此刻人数' : '只有课表，人数未开放',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.classroomDetail(building)),
            );
          },
        ),
      ),
    );
  }
}
