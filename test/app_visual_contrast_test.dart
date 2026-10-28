import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/features/space/space_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:bjtuselfserviceaio/shared/theme/colors.dart';

/// WCAG 对比度必须包含相对亮度的 0.05 偏移，不能直接相除。
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

void main() {
  test('WCAG 黑白为 21:1，相同颜色为 1:1', () {
    expect(_contrast(Colors.black, Colors.white), 21);
    expect(_contrast(Colors.grey, Colors.grey), 1);
  });
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    final scheme = theme.colorScheme;

    test('$label：主题文字配色至少 4.5:1，输入框和焦点边框至少 3:1', () {
      for (final (foreground, background) in [
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, scheme.surfaceContainerLow),
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onErrorContainer, scheme.errorContainer),
      ]) {
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
      final input = theme.inputDecorationTheme;
      final enabled = input.enabledBorder! as OutlineInputBorder;
      final focused = input.focusedBorder! as OutlineInputBorder;
      expect(
        _contrast(enabled.borderSide.color, input.fillColor!),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(focused.borderSide.color, input.fillColor!),
        greaterThanOrEqualTo(3),
      );
    });

    test('$label：卡片有 1px 描边，不再是一块看不出边界的底色', () {
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      final side = shape.side;
      expect(side.width, greaterThan(0), reason: '卡片没有描边，和背景糊在一起');
      expect(_contrast(side.color, scheme.surface), greaterThan(1.5));
    });

    test('$label：卡片底色和页面底色分得开', () {
      expect(
        _contrast(theme.cardTheme.color!, scheme.surface),
        greaterThan(1.02),
        reason: '卡片和页面底色差不到 1% ，肉眼等于没有卡片',
      );
    });

    test('$label：考试色和背景对比度够（写死 orange 在深色底下会糊）', () {
      expect(_contrast(AppColors.exam(scheme), scheme.surface), greaterThan(3));
    });

    test('$label：正文和背景对比度够（4.5 是 WCAG AA 的底线）', () {
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
    });

    test('$label：课程色上的文字对比度够（写死白字在黄/浅绿上看不见）', () {
      for (final courseColor in AppColors.coursePalette) {
        expect(
          _contrast(AppColors.onCourse(courseColor), courseColor),
          greaterThan(4.5),
          reason: '课程色 $courseColor 上的字看不清',
        );
      }
    });

    test('$label：选中高亮跟着主色走，不是 Material 默认紫', () {
      final selection = theme.textSelectionTheme.selectionColor!;
      expect(selection, scheme.primary.withValues(alpha: 0.24));
    });
  }

  // 徽章的底色是 accent 的淡洗、字色是另一个 token —— 这套配对以前在四个
  // 页面各写各的，深浅两套主题下都翻过车。这里把每个用到的 accent 都过一遍。
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    final scheme = theme.colorScheme;
    final accents = <String, Color>{
      'error': scheme.error,
      'tertiary': scheme.tertiary,
      'primary': scheme.primary,
      'outline': scheme.outline,
      'onSurfaceVariant': scheme.onSurfaceVariant,
      'brand': AppColors.brand,
      'coursePalette0': AppColors.coursePalette.first,
      'coursePaletteLast': AppColors.coursePalette.last,
    };

    test('$label：徽章的字在淡底上够清楚（≥4.5）', () {
      for (final entry in accents.entries) {
        final badge = AppColors.badge(scheme, entry.value);
        expect(
          AppColors.contrast(badge.foreground, badge.background),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} 的徽章字看不清',
        );
      }
    });

    test('$label：徽章底色确实叠在卡片底上，不是透明', () {
      for (final entry in accents.entries) {
        expect(AppColors.badge(scheme, entry.value).background.a, 1.0);
      }
    });
  }

  test('readableOn 推到底也能保证对比度（输入极差颜色）', () {
    for (final scheme in [
      const ColorScheme.light(),
      const ColorScheme.dark(),
    ]) {
      for (final accent in [
        const Color(0xFF808080),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
        const Color(0xFFFFF200),
      ]) {
        final badge = AppColors.badge(scheme, accent);
        expect(
          AppColors.contrast(badge.foreground, badge.background),
          greaterThanOrEqualTo(4.5),
          reason: '$accent 的徽章字看不清',
        );
      }
    }
  });

  test('考试色两边都给得出来同一份代码', () {
    expect(
      AppColors.exam(const ColorScheme.light()),
      isNot(AppColors.exam(const ColorScheme.dark())),
      reason: '深浅底用同一个值，必然有一边看不清',
    );
  });

  // 「应用中各个功能的字体看不见」——直接量宫格里那段文字实际渲染出来的颜色：
  // 主题给什么颜色、卡片上就画什么，不靠推断。
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('$label：应用宫格的标签在卡片上够清楚（≥4.5）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const SpacePage()),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      final text = tester.widget<Text>(find.text('课程表'));
      final background = card.color ?? theme.cardTheme.color!;
      expect(
        _contrast(text.style?.color ?? theme.colorScheme.onSurface, background),
        greaterThanOrEqualTo(4.5),
        reason: '宫格标签和卡片底色分不开',
      );
    });
  }
}
