// 课表格子画什么、不画什么，由这两条测试钉死：
// 1. 格子只出现课程名和地点（课号/节次/教师都在详情弹层里）；
// 2. 桌面平台下滚动条挂在这个自定义网格上不报错 —— 桌面上 ScrollView.primary
//    默认是 false，Scrollbar 摸 PrimaryScrollController 只会拿到空。
import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/models/course/schedule_position.dart';
import 'package:bjtuselfserviceaio/features/course/schedule_board.dart';
import 'package:bjtuselfserviceaio/shared/components/calendar/schedule_calendar.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Course _course() => Course(
  courseId: 'P401048B',
  name: '嵌入式系统',
  place: '海淀西校区,第九教学楼,南415',
  locationIndex: SchedulePosition.locationIndex(section: 1, weekday: 1),
);

Widget _app(CourseBoard board) => MaterialApp(
  theme: AppTheme.light(),
  scrollBehavior: const AppScrollBehavior(),
  home: Scaffold(body: ScheduleCalendar(board: board)),
);

void main() {
  testWidgets('格子里只有课程名和地点，课号不直接显示', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(ScheduleBoardBuilder.build([_course()])));
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(CourseChip),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList();
    expect(texts, ['嵌入式系统', '海淀西校区,第九教学楼,南415'], reason: '格子只该有课程名和地点两行');
  });

  testWidgets('桌面平台下课表网格不抛 Scrollbar 异常', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(ScheduleBoardBuilder.build([_course()])));
    await tester.pumpAndSettle();
    final error = tester.takeException();

    debugDefaultTargetPlatformOverride = null;
    expect(error, isNull, reason: 'Scrollbar 找不到可滚的 ScrollPosition');
  });
}
