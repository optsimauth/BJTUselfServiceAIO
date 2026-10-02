// 「一进去浅色、切到深色（或相反），应用宫格的字就看不清」——
// 根因：在 ListView/GridView 的 itemBuilder 里直接读主题时，懒子项在新的
// Theme 数据落地前就重建完了，之后不再被通知，于是深色底配浅色主题的深色字。
// 修法是给 itemBuilder 的返回值包一层 Builder。
// 这里钉住「切主题后懒子项的字色必须跟着换，而且两种主题下都要看得清」。
import 'package:bjtuselfserviceaio/features/detection/detection_page.dart';
import 'package:bjtuselfserviceaio/features/space/space_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final light = AppTheme.light();
final dark = AppTheme.dark();

/// 浅色 -> 深色来回切，多打几帧：旧 bug 要好几帧才暴露出来。
Future<void> _switch(
  WidgetTester tester,
  Widget Function(ThemeData) app,
) async {
  await tester.pumpWidget(app(light));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pumpWidget(app(dark));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
}

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (la > lb ? la / lb : lb / la);
}

void main() {
  testWidgets('应用宫格：切到深色后标签跟着换成浅色', (tester) async {
    await _switch(
      tester,
      (theme) => MaterialApp(theme: theme, home: const SpacePage()),
    );

    final style = tester.widget<Text>(find.text('课程表')).style;
    expect(
      style?.color,
      dark.colorScheme.onSurface,
      reason: '还在用浅色主题的字色 —— 深底深字',
    );
    final card = Theme.of(tester.element(find.byType(Card).first));
    expect(
      _contrast(style!.color!, dark.cardTheme.color!),
      greaterThanOrEqualTo(4.5),
    );
    expect(card.colorScheme.brightness, Brightness.dark);
  });

  testWidgets('应用宫格：切回浅色后标签跟着换回深色', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: dark, home: const SpacePage()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(theme: light, home: const SpacePage()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('课程表')).style?.color,
      light.colorScheme.onSurface,
    );
  });

  testWidgets('教室占用列表：切主题后副标题跟着换色', (tester) async {
    await _switch(
      tester,
      (theme) => MaterialApp(theme: theme, home: const DetectionPage()),
    );
    final text = tester.widget<Text>(find.text('只有课表，人数未开放'));
    expect(text.style?.color, dark.textTheme.bodySmall?.color);
  });
}
