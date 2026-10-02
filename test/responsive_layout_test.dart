// 响应式守卫：360x800（手机）与 1280x900（桌面）下都不能出现 overflow。
//
// 覆盖 home / homework / email 三屏里最容易撑破的三块公共外壳：
// - [PageWidth]：所有页面的外壳（app.dart 里包住整个 Navigator）；
// - [AppCard]：首页待办、作业条目、成绩条目共用的卡片外壳；
// - [ScheduleCalendar]：首页「今日课」和课表页共用的最密网格。
//
// 整页 pumpWidget(HomePage()) 跑不了：ServiceLocator 是私有构造的依赖图
// （数据库 / 网络 / 平台通道），没有测试缝，而这次不允许动 lib/app、lib/data。
// 组件级 + 双断点是当前能自动化的最强断言，页面级留给人工过一遍
// docs/DESIGN_AUDIT.md 末尾的响应式清单。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/models/course/schedule_position.dart';
import 'package:bjtuselfserviceaio/features/course/schedule_board.dart';
import 'package:bjtuselfserviceaio/shared/components/calendar/schedule_calendar.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:bjtuselfserviceaio/shared/widgets/cards/app_card.dart';
import 'package:bjtuselfserviceaio/shared/widgets/page_width.dart';

const phone = Size(360, 800);
const desktop = Size(1280, 900);

Widget _app(Widget child, Size size) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: Scaffold(body: child),
  ),
);

CourseBoard _busyBoard() => ScheduleBoardBuilder.build([
  for (var weekday = 1; weekday <= SchedulePosition.weekdayCount; weekday++)
    for (var section = 1; section <= 4; section++)
      Course(
        courseId: 'C$weekday-$section',
        name: '高等数学（第 $section 章）',
        teacher: '张老师',
        place: '教三楼 101 大教室',
        time: '第1-16周',
        locationIndex: SchedulePosition.locationIndex(
          section: section,
          weekday: weekday,
        ),
      ),
]);

/// 长得最离谱的一条：长中文标题 + 长数字 + 尾部徽标。
Widget _longCard(BuildContext context) => AppCard(
  leading: const Icon(Icons.assignment_outlined),
  trailing: const Text('98 分 · 排名 1/1200'),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '高等数学（下）习题册参考答案与评分标准 2025-2026 学年第二学期',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 4),
      Text(
        '截止 2026-10-08 23:59 · 已提交 42 人 · 作业编号 2026100112345678',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  ),
);

void main() {
  for (final (label, size) in [
    ('手机 360x800', phone),
    ('桌面 1280x900', desktop),
  ]) {
    group(label, () {
      setUp(() {
        // 两个断点都用物理像素直接设定，避免字体/像素比差异影响断言。
      });

      testWidgets('PageWidth 里的长卡片列表不溢出', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            PageWidth(
              child: Builder(
                builder: (context) => ListView(
                  children: [for (var i = 0; i < 8; i++) _longCard(context)],
                ),
              ),
            ),
            size,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('课表网格（最密的一屏）不溢出', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            ScheduleCalendar(
              board: _busyBoard(),
              currentWeek: 6,
              selectedWeek: 6,
              now: DateTime(2026, 10, 5, 9, 30),
            ),
            size,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        // 课表内部有 30s 自走定时器，测试结束前必须销毁，否则判定为 pending timer。
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  }

  testWidgets('PageWidth 默认铺满窗口，传了上限才限宽', (tester) async {
    Widget probe(Size size, {double? maxWidth}) => _app(
      PageWidth(
        maxWidth: maxWidth,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              Text('宽度 ${constraints.maxWidth.toStringAsFixed(0)}'),
        ),
      ),
      size,
    );

    tester.view.physicalSize = desktop;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 默认：桌面多宽就铺多宽。
    await tester.pumpWidget(probe(desktop));
    expect(find.text('宽度 ${desktop.width.toStringAsFixed(0)}'), findsOneWidget);

    // 传上限：回到定宽居中。
    await tester.pumpWidget(probe(desktop, maxWidth: 1160));
    expect(find.text('宽度 1160'), findsOneWidget);

    // 手机两种写法一样：屏宽小于上限。
    tester.view.physicalSize = phone;
    await tester.pumpWidget(probe(phone));
    expect(find.text('宽度 360'), findsOneWidget);
  });
}
