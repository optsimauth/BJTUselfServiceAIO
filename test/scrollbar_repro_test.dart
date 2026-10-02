import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 桌面端每帧抛的 "The Scrollbar's ScrollController has no ScrollPosition
/// attached" 就是从 [AppScrollBehavior] 的滚动条注入来的：桌面上
/// `ScrollView.primary` 解析成 false，注入的 Scrollbar 摸到的永远是空的
/// PrimaryScrollController。这里钉住「桌面端不注入」。
void main() {
  testWidgets('桌面端不往没有 ScrollPosition 的视图上挂 Scrollbar', (tester) async {
    // 必须在用例体内首尾置位：test 框架不允许用例结束时还留着这个 debug 变量。
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: List.generate(40, (i) => Text('row$i'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final error = tester.takeException();

    debugDefaultTargetPlatformOverride = null;
    expect(error, isNull, reason: 'Scrollbar 挂在没有 ScrollPosition 的视图上');
  });
}
