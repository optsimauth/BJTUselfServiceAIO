import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/app/app_navigation.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:bjtuselfserviceaio/shared/widgets/buttons/app_buttons.dart';

void main() {
  for (final width in [360.0, 599.0, 600.0, 839.0, 840.0, 1199.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('窗口 $width / 字号 $scale：规范断点与导航交互', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: StatefulBuilder(
                builder: (context, setState) => AppNavigation(
                  index: selected,
                  onSelected: (value) => setState(() => selected = value),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        if (width < 600) {
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.byType(NavigationRail), findsNothing);
        } else {
          final rail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );
          expect(rail.extended, width >= 1200);
          expect(find.byType(NavigationBar), findsNothing);
        }
        final service = find.text('服务');
        final tapTarget = find
            .ancestor(
              of: service,
              matching: find.byWidgetPredicate(
                (widget) => widget is InkResponse,
              ),
            )
            .first;
        final rect = tester.getRect(tapTarget);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.tap(service);
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final loading in [false, true]) {
    testWidgets('主按钮大字号与${loading ? "加载" : "可点击"}状态', (tester) async {
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  child: PrimaryButton(
                    label: '重新连接校园服务',
                    expanded: false,
                    loading: loading,
                    onPressed: () => count++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final button = find.byType(FilledButton);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      if (loading) {
        expect(find.text('正在处理…'), findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
      } else {
        await tester.tap(button);
        expect(count, 1);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
