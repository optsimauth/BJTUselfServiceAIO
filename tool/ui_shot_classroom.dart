// 教室页的手机截图（浅色 / 深色），给「改完自己看一眼」用。
//
// 跑法：`flutter test tool/ui_shot_classroom.dart`，输出到 `build/ui-review/classroom-phone-*.png`。
//
// 为什么不在 `test/` 里：它没有断言，只是生成图片；放进常规回归会拖慢每一次 `flutter test`，
// 而且连续 `toImage` 会让 flutter_tester 偶发退出（详见 docs/VERIFICATION.md）。
// 依赖用假数据，不联网、不读本地库。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/data/remote/api/classroom_api.dart';
import 'package:bjtuselfserviceaio/data/repositories/classroom_repository.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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
      '${_row('SY102 (60)', '#ffffff')}${_row('SY201 (45)', '#7fb2e5')}'
      '${_row('SY202 (45)', '#f0e68c')}</tbody></table></body></html>';

  @override
  Future<String> fetchBuildingOccupancyRaw({
    required String buildingName,
  }) async =>
      '{"time":["2026-03-02","2026-07-20"],"data":[["思源楼101",1,30,120]]}';
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    final loader = FontLoader('NotoSansSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC-VF.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final dark in [false, true]) {
    testWidgets('classroom ${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: RepaintBoundary(
            key: key,
            child: ClassroomPage(
              building: const ClassroomBuilding(id: '1', name: '思源楼'),
              repository: ClassroomRepository(api: _FakeApi()),
              clock: () => DateTime(2026, 10, 7, 9, 30),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _shot(tester, key, 'classroom-phone-${dark ? 'dark' : 'light'}');
    });
  }

  // 规划面板：选两节 → 生成路线，看看结果排版是否读得下去。
  testWidgets('classroom planner light', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    // 弹层在 Navigator 的 Overlay 里，边界要包住整个 MaterialApp，否则只截到底页。
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ClassroomPage(
            building: const ClassroomBuilding(id: '1', name: '思源楼'),
            repository: ClassroomRepository(api: _FakeApi()),
            clock: () => DateTime(2026, 10, 7, 9, 30),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('规划空教室'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '1'));
    await tester.tap(find.widgetWithText(FilterChip, '2'));
    await tester.pump();
    await tester.tap(find.text('生成路线'));
    await tester.pumpAndSettle();
    await _shot(tester, key, 'classroom-planner-light');
  });
}
