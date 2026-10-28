import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/classroom_repository.dart';
import 'package:bjtuselfserviceaio/data/remote/api/classroom_api.dart';
import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_controller.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/spacing.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _row(String header, String color) =>
    '<tr>'
    '<td>$header</td>'
    '${List<String>.filled(49, '<td style="background-color:$color"></td>').join()}'
    '</tr>';

class _FakeApi extends ClassroomApi {
  _FakeApi() : super(RequestManager(dio: Dio(), ensureLoggedIn: () {}));

  @override
  Future<FetchedText> fetchStatusEntry() async =>
      FetchedText(body: '', finalUri: Uri.parse('https://example.com/a?zc=5'));

  @override
  Future<String> fetchStatusPage({
    required Uri entryUri,
    required int week,
    required String buildingId,
  }) async =>
      '<html><body><table><tbody>${_row('SY101 (90)', '#e46868')}'
      '${_row('SY102 (60)', '#ffffff')}</tbody></table></body></html>';

  @override
  Future<String> fetchBuildingOccupancyRaw({
    required String buildingName,
  }) async =>
      '{"time":["2026-03-02","2026-07-20"],"data":[["思源楼101",1,30,120]]}';
}

Future<void> _pump(
  WidgetTester tester,
  DateTime now, {
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: ClassroomPage(
          building: const ClassroomBuilding(id: '1', name: '思源楼'),
          repository: ClassroomRepository(api: _FakeApi()),
          clock: () => now,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  // 回归：weekdayIndexOf 已经是 1..7（周一=1），外面再 +1 就成了 2..8。
  // 七天里六天静默看错一天，周日越界 -> 页面 build 时 RangeError。
  // 旧测试只传过 1..7 的合法值，整类错位测不出来，所以这里逐天遍历。
  test('一周七天里，「今天」和默认聚焦日都等于当天的星期号', () {
    for (var day = 4; day <= 10; day++) {
      final now = DateTime(2026, 10, day, 9, 30);
      final controller = ClassroomController(
        repository: ClassroomRepository(api: _FakeApi()),
        building: const ClassroomBuilding(id: '1', name: '思源楼'),
        clock: () => now,
      );
      expect(controller.todayWeekday, now.weekday, reason: '$now');
      expect(controller.weekday, now.weekday, reason: '$now');
      expect(controller.weekday, inInclusiveRange(1, 7), reason: '$now');
      controller.dispose();
    }
  });

  test('切到 0 和 8 会被夹在 1..7 内，不会把越界值漏给界面', () {
    final controller = ClassroomController(
      repository: ClassroomRepository(api: _FakeApi()),
      building: const ClassroomBuilding(id: '1', name: '思源楼'),
      clock: () => DateTime(2026, 10, 4, 9, 30),
    );
    controller.setWeekday(0);
    expect(controller.weekday, 1);
    controller.setWeekday(8);
    expect(controller.weekday, 7);
    controller.dispose();
  });

  testWidgets('周日进教室页不再抛异常', (tester) async {
    await _pump(tester, DateTime(2026, 10, 4, 9, 30));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('周日'), findsWidgets);
  });

  testWidgets('周三进教室页也不抛异常', (tester) async {
    await _pump(tester, DateTime(2026, 10, 7, 9, 30));
    expect(tester.takeException(), isNull);
  });

  // 一排 7 个胶囊要塞进 360 宽，顺手就会写成 32x32 的纯视觉尺寸：
  // 看着能点，手指点不中。视觉可以小，命中区域必须到 AppTouch.minimum。
  testWidgets('星期胶囊的命中区域不小于 48（视觉圆片仍是 32）', (tester) async {
    await _pump(tester, DateTime(2026, 10, 7, 9, 30));
    final target = find
        .ancestor(of: find.text('三'), matching: find.byType(InkWell))
        .first;
    final size = tester.getSize(target);
    expect(size.width, greaterThanOrEqualTo(AppTouch.minimum));
    expect(size.height, greaterThanOrEqualTo(AppTouch.minimum));
  });

  // 七天各 48 命中区，加起来 336：窄屏得把说明文字让出去，
  // 否则周日被挤出屏幕，要横着划才找得到。
  testWidgets('手机窄屏七天整行都看得见，不用横向滑', (tester) async {
    await _pump(tester, DateTime(2026, 10, 7, 9, 30));
    final pageWidth = tester.getSize(find.byType(ClassroomPage)).width;
    for (final label in ['一', '二', '三', '四', '五', '六', '日']) {
      final rect = tester.getRect(find.text(label).first);
      expect(rect.left, greaterThanOrEqualTo(0), reason: label);
      expect(rect.right, lessThanOrEqualTo(pageWidth), reason: label);
    }
  });

  // 360 宽时一格不到 48，两行字里的「8:00~9:50」会被压到 7px 上下 ——
  // 看得见但看不清。窄屏只写节次号，宽屏才把时间段写进格子。
  testWidgets('窄屏格子只写节次号，宽屏才写时间段', (tester) async {
    const cellKey = ValueKey('classroom-cell-SY101-1');
    await _pump(tester, DateTime(2026, 10, 7, 9, 30));
    expect(
      find.descendant(
        of: find.byKey(cellKey),
        matching: find.textContaining(':'),
      ),
      findsNothing,
    );

    await _pump(
      tester,
      DateTime(2026, 10, 7, 9, 30),
      size: const Size(1280, 900),
    );
    expect(
      find.descendant(
        of: find.byKey(cellKey),
        matching: find.textContaining(':'),
      ),
      findsOneWidget,
    );
  });

  // 原项目（DetectionScreen）的「按楼层差最小生成路径」，Flutter 版接在教室页的
  // 唯一主操作上：选节次 → 生成路线。这里走一遍真实交互。
  testWidgets('规划空教室：选一节就能拿到一条路线', (tester) async {
    await _pump(tester, DateTime(2026, 10, 7, 9, 30));

    await tester.tap(find.text('规划空教室'));
    await tester.pumpAndSettle();
    expect(find.text('空教室规划'), findsOneWidget);

    // 假数据里 SY101 整周有课（红），SY102 整周空着（白）。
    await tester.tap(find.widgetWithText(FilterChip, '1'));
    await tester.pump();
    await tester.tap(find.text('生成路线'));
    await tester.pumpAndSettle();

    expect(find.text('全程在同一层，不用上下楼'), findsOneWidget);
    expect(find.text('SY102'), findsOneWidget);
  });

  // 时间段格子原来写死 44 高：系统字号放到 2 倍时两行字比 44 高，
  // 直接报 RenderFlex overflow。高度要跟内容走，44 只是下限。
  testWidgets('2 倍字号下教室页不溢出', (tester) async {
    await _pump(tester, DateTime(2026, 10, 7, 9, 30), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(ClassroomPage), findsOneWidget);
  });
}
