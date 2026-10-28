// 教学楼缩写徽章：旧项目 v1.8.1（commit 13efd16）用缩写区分 11 栋常用楼，
// 但请求和路由仍然用全名。这里把映射和列表渲染一起钉住。
import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/features/detection/detection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('缩写映射（与旧项目 buildingAbbreviation 一致）', () {
    String abbr(String name) => ClassroomBuilding(id: 'x', name: name).abbreviation;

    test('常用 11 栋给固定缩写', () {
      expect(abbr('第十七号教学楼'), '17');
      expect(abbr('第九教学楼'), '九');
      expect(abbr('第八教学楼'), '八');
      expect(abbr('第五教学楼'), '五');
      expect(abbr('思源楼'), 'SY');
      expect(abbr('思源西楼'), 'SX');
      expect(abbr('思源东楼'), 'SD');
      expect(abbr('逸夫教学楼'), 'YF');
      expect(abbr('机械楼'), 'JX');
      expect(abbr('东区一教'), 'D1');
      expect(abbr('东区二教'), 'D2');
    });

    test('其余楼取前两个字，两个字的楼原样给', () {
      expect(abbr('学生活动服务中心'), '学生');
      expect(abbr('科技大厦'), '科技');
      expect(abbr('天佑会堂'), '天佑');
      expect(abbr('科技楼'), '科技');
    });

    test('缩写不改全名：请求仍拿全名', () {
      const building = ClassroomBuilding(id: '1', name: '思源楼');
      expect(building.abbreviation, 'SY');
      expect(building.name, '思源楼');
    });
  });

  group('教学楼列表', () {
    Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const DetectionPage(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('缩写和全名同时出现', (tester) async {
      await pump(tester);
      expect(find.text('SY'), findsOneWidget);
      expect(find.text('思源楼'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('第十七号教学楼'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2 倍字号下徽章不撑破列表行', (tester) async {
      await pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('SY'), findsOneWidget);
    });
  });
}
