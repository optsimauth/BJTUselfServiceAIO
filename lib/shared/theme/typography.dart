import 'package:flutter/material.dart';

/// 字体风格。原来的 MaterialColor.kt / Type.kt 里定义了多套字重，
/// Flutter 直接用 Theme 的 textTheme 派生即可。
abstract final class AppTypography {
  /// 全局字号倍率。整体调大/调小只改这一个值。
  ///
  /// 作用在两处：
  /// 1. `AppTheme._build` 里 `TextTheme.apply(fontSizeFactor:)` —— 覆盖所有走主题的样式；
  /// 2. 下面三个具名样式 —— 必须是 getter 才乘得动，原来是 `static const`，
  ///    fontSize 在编译期就定死了，没法缩放。
  ///
  /// 页面里直接写死 `fontSize:` 的少数地方不受它管，要用 [size] 自己换算。
  static const double scale = 1.18;

  /// 把写死的基准字号换算成缩放后的值。
  static double size(double base) => base * scale;

  /// 固定字号，**不**乘 [scale]。
  ///
  /// 只给两类地方用：窄屏必须塞下的标签（星期缩写、格子里的小注），
  /// 以及要跟别的元素严格对齐的数字。其余一律走 [size]。
  static double sizeFixed(double base) => base;

  /// 把整份 textTheme 的字号乘 [scale]。
  ///
  /// 不用 `TextTheme.apply(fontSizeFactor:)`：那条路内部走
  /// `TextStyle.copyWith`，而 copyWith 里有这条断言
  /// `fontSize != null || (fontSizeFactor == 1.0 && fontSizeDelta == 0.0)`。
  /// 只要主题里有一个 fontSize 为空的样式（M3 某些派生样式、
  /// 组件自带的默认 TextStyle 就会这样），debug 下必然崩。
  /// 这里逐条判空后显式相乘，行为完全一致且不会触发断言。
  static TextTheme scaleFontSizes(TextTheme base) => base.copyWith(
    displayLarge: _scaled(base.displayLarge),
    displayMedium: _scaled(base.displayMedium),
    displaySmall: _scaled(base.displaySmall),
    headlineLarge: _scaled(base.headlineLarge),
    headlineMedium: _scaled(base.headlineMedium),
    headlineSmall: _scaled(base.headlineSmall),
    titleLarge: _scaled(base.titleLarge),
    titleMedium: _scaled(base.titleMedium),
    titleSmall: _scaled(base.titleSmall),
    bodyLarge: _scaled(base.bodyLarge),
    bodyMedium: _scaled(base.bodyMedium),
    bodySmall: _scaled(base.bodySmall),
    labelLarge: _scaled(base.labelLarge),
    labelMedium: _scaled(base.labelMedium),
    labelSmall: _scaled(base.labelSmall),
  );

  static TextStyle? _scaled(TextStyle? style) {
    final fontSize = style?.fontSize;
    if (style == null || fontSize == null) {
      return style;
    }
    return style.copyWith(fontSize: fontSize * scale);
  }

  /// 行高节奏：全 app 一套，同类文字的呼吸感一致。
  ///
  /// M3 每档字号的默认行高不一样（1.1~1.43 都有），中文在 1.1 上下显得挤，
  /// 同一个页面里标题松、正文紧，整屏看着东一块西一块。这里按用途定档：
  /// 展示字 1.15、标题 1.25、正文 1.45、标签 1.2。
  static TextTheme rhythm(TextTheme base) => base.copyWith(
    displayLarge: _rhythm(base.displayLarge, 1.15),
    displayMedium: _rhythm(base.displayMedium, 1.15),
    displaySmall: _rhythm(base.displaySmall, 1.15),
    headlineLarge: _rhythm(base.headlineLarge, 1.15),
    headlineMedium: _rhythm(base.headlineMedium, 1.15),
    headlineSmall: _rhythm(base.headlineSmall, 1.2),
    titleLarge: _rhythm(base.titleLarge, 1.25),
    titleMedium: _rhythm(base.titleMedium, 1.25),
    titleSmall: _rhythm(base.titleSmall, 1.25),
    bodyLarge: _rhythm(base.bodyLarge, 1.45),
    bodyMedium: _rhythm(base.bodyMedium, 1.45),
    bodySmall: _rhythm(base.bodySmall, 1.45),
    labelLarge: _rhythm(base.labelLarge, 1.2),
    labelMedium: _rhythm(base.labelMedium, 1.2),
    labelSmall: _rhythm(base.labelSmall, 1.2),
  );

  static TextStyle? _rhythm(TextStyle? style, double height) =>
      style?.copyWith(height: height);

  static TextTheme apply(TextTheme base) => base.copyWith(
    titleLarge: _titled(base.titleLarge),
    titleMedium: _titled(base.titleMedium),
    labelLarge: _titled(base.labelLarge),
    bodySmall: base.bodySmall?.copyWith(height: 1.4),
    // 等宽数字：成绩单、排名、倒计时这些数字每次刷新宽度都不一样，
    // 表格会左右跳、倒计时会抖。数字等宽就锁住了。
    bodyMedium: base.bodyMedium?.copyWith(fontFeatures: _tabular),
    labelMedium: base.labelMedium?.copyWith(fontFeatures: _tabular),
  );

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle? _titled(TextStyle? style) =>
      style?.copyWith(fontWeight: FontWeight.w600, fontFeatures: _tabular);

  // 三个具名样式都不写 color：颜色交给主题派生（见 AppTheme._build 里
  // 对 bodyColor / displayColor 的显式绑定），避免深色模式下底字同色。
  static TextStyle get cardTitle =>
      TextStyle(fontSize: size(16), fontWeight: FontWeight.w600);

  static TextStyle get cardSubtitle => TextStyle(fontSize: size(13));

  static TextStyle get captionMuted => TextStyle(fontSize: size(12));
}
