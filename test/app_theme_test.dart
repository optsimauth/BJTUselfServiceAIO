import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:bjtuselfserviceaio/shared/theme/typography.dart';

/// 按固定顺序取出 textTheme 的 15 个槽位。
List<TextStyle?> _slotsOf(TextTheme theme) => <TextStyle?>[
  theme.displayLarge,
  theme.displayMedium,
  theme.displaySmall,
  theme.headlineLarge,
  theme.headlineMedium,
  theme.headlineSmall,
  theme.titleLarge,
  theme.titleMedium,
  theme.titleSmall,
  theme.bodyLarge,
  theme.bodyMedium,
  theme.bodySmall,
  theme.labelLarge,
  theme.labelMedium,
  theme.labelSmall,
];

void main() {
  test('字号为空的样式走显式缩放不会触发 TextStyle 断言', () {
    // 这正是 debug 崩溃的那条断言：TextStyle.apply 收到 fontSizeFactor != 1.0
    // 且 fontSize == null 时直接 assert 失败。显式缩放必须原样放过空字号。
    final scaled = AppTypography.scaleFontSizes(
      const TextTheme(
        bodyMedium: TextStyle(),
        titleMedium: TextStyle(fontSize: 20),
      ),
    );

    expect(scaled.bodyMedium?.fontSize, isNull);
    expect(scaled.titleMedium?.fontSize, 20 * AppTypography.scale);
  });

  test('显式缩放：有字号的乘 1.18，空字号原样保留', () {
    final plain = ThemeData(useMaterial3: true).textTheme;
    final before = _slotsOf(plain);
    final after = _slotsOf(AppTypography.scaleFontSizes(plain));

    expect(before.where((style) => style != null), isNotEmpty);
    for (var i = 0; i < before.length; i++) {
      final original = before[i];
      if (original == null) continue;
      final expected = original.fontSize == null
          ? null
          : original.fontSize! * 1.18;
      expect(after[i]?.fontSize, expected, reason: '第 $i 个字号缩放不对：$original');
    }
  });

  test('浅色与深色主题都能构建，正文颜色跟随 ColorScheme', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(theme.textTheme.bodyMedium?.color, scheme.onSurface);
      expect(_slotsOf(theme.textTheme).where((s) => s != null), isNotEmpty);
    }
  });

  test('textTheme.apply 不再传 fontSizeFactor，空字号主题也能安全套用', () {
    // 回归锁点：只要重新传回 fontSizeFactor，空字号样式就会让 debug 崩掉。
    final base = ThemeData(useMaterial3: true).textTheme;
    expect(
      () => AppTypography.scaleFontSizes(base).apply(bodyColor: Colors.black),
      returnsNormally,
    );
  });

  test('行高按用途分档，全 app 一套节奏', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.bodyMedium?.height, 1.45, reason: '正文行高');
      expect(theme.textTheme.bodySmall?.height, 1.45);
      expect(theme.textTheme.titleLarge?.height, 1.25, reason: '标题行高');
      expect(theme.textTheme.labelSmall?.height, 1.2, reason: '标签行高');
      expect(theme.textTheme.headlineMedium?.height, 1.15);
    }
  });
}
