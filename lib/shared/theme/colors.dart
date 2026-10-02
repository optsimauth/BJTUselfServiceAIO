import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 品牌色 + 状态色。可动态取色的部分交给 Material 3 的 ColorScheme.fromSeed。
/// 徽章 / 标签的一套配色：淡底 + 字 + 描边，三者由一个 accent 一次算出。
typedef BadgeColors = ({
  Color background,
  Color foreground,
  Color border,
});

abstract final class AppColors {
  static const Color brand = Color(0xFF1B5E9C);
  static const Color brandDark = Color(0xFF0E3A61);
  static const Color accent = Color(0xFF2E9E6B);

  /// 铺在 [background]（课程色 / primary）上的文字色。
  ///
  /// 课程色是按哈希取的中等饱和色：黄色、浅绿上写死白字看不见，
  /// 深色卡片上写死黑字又看不见。黑/白里挑对比度高的那个（0.179 是
  /// WCAG 里黑白对比度相等的亮度分界），不靠猜。
  static Color onCourse(Color background) =>
      background.computeLuminance() > 0.179
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  /// WCAG 相对对比度。
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 徽章 / 标签这类「彩色淡底 + 文字」的标准配色。
  ///
  /// 以前每个页面各写各的：底色是 accent 的淡洗，字色却从另一个 token
  ///（`onErrorContainer` 之类）拿。那个字色只保证和**满色**容器对比，
  /// 和 12% 淡洗没有任何关系 —— 深浅两套主题下都可能糊成一片，
  /// 而且每处都得自己记得调一遍。
  ///
  /// 这里一次算完：底 = accent 淡洗叠在 [scheme] 的 surface 上，
  /// 字 = 从 accent 出发往可读方向推，保证 ≥ 4.5:1（WCAG AA）。
  static BadgeColors badge(
    ColorScheme scheme,
    Color accent, {
    double alpha = 0.12,
    double borderAlpha = 0.4,
  }) {
    final background = Color.alphaBlend(
      accent.withValues(alpha: alpha),
      scheme.surface,
    );
    return (
      background: background,
      foreground: readableOn(background, accent),
      border: accent.withValues(alpha: borderAlpha),
    );
  }

  /// 把 [from] 往纯黑 / 纯白推，直到它在 [background] 上达到 [minContrast]。
  ///
  /// 保留色相（还是红/黄/蓝那套），只调亮度；推到底还是不够就交出纯黑/白 ——
  /// 那是对比度最高的选项，不可能再更差。
  static Color readableOn(
    Color background,
    Color from, {
    double minContrast = 4.5,
  }) {
    final target = background.computeLuminance() > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    var candidate = from;
    for (var i = 0; i < 12 && contrast(candidate, background) < minContrast; i++) {
      candidate = Color.lerp(candidate, target, 0.25)!;
    }
    return contrast(candidate, background) >= minContrast
        ? candidate
        : target;
  }

  /// 「什么都没有」的透明色。CalendarStyle 这类 const 容器里也要有名字。
  static const Color transparent = Color(0x00000000);

  static const Color success = Color(0xFF2E9E6B);
  static const Color warning = Color(0xFFE8A33D);
  static const Color danger = Color(0xFFD9534F);

  static const Color surfaceLight = Color(0xFFF6F7F9);
  static const Color surfaceDark = Color(0xFF14161A);

  /// 日历 / 课表里的「考试」色。
  ///
  /// 不再写死 [Colors.orange]：同一个色值在浅色底上要压暗才够对比度，
  /// 在深色底上要提亮才看得见，一份常量没法两边都对。
  static Color exam(ColorScheme scheme) => switch (scheme.brightness) {
    Brightness.dark => const Color(0xFFF5A524),
    Brightness.light => const Color(0xFFB25A00),
  };

  /// 课程表格子按课程哈希取色，保证同一门课颜色稳定。
  static const List<Color> coursePalette = [
    Color(0xFF4C8BF5),
    Color(0xFF2E9E6B),
    Color(0xFFE8A33D),
    Color(0xFF9B59B6),
    Color(0xFFE0674F),
    Color(0xFF16A4A4),
    Color(0xFF6C7A89),
    Color(0xFFD4658E),
  ];

  static Color forCourse(String courseId) =>
      coursePalette[courseId.hashCode.abs() % coursePalette.length];
}
