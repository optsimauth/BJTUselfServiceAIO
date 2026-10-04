import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/classroom_repository.dart';
import 'package:bjtuselfserviceaio/data/remote/api/classroom_api.dart';
import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_controller.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_page.dart';
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

Future<void> _pump(WidgetTester tester, DateTime now) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ClassroomPage(
        building: const ClassroomBuilding(id: '1', name: '思源楼'),
        repository: ClassroomRepository(api: _FakeApi()),
        clock: () => now,
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
}
