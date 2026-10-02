import 'package:flutter/material.dart';

/// 间距刻度：4 的倍数，只有这几档。新增间距时先在 [AppSpacing] 里找一档，
/// 找不到再谈新值 —— 页面上出现 7、10、18 这种数字就是节奏乱了。
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 页面左右留白。
  static const double gutter = 16;

  /// 列表/卡片之间的竖向间距。
  static const double stack = 12;

  /// 卡片内边距。
  static const EdgeInsets card = EdgeInsets.all(16);

  /// 页面级左右留白。
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 16);
}

/// 圆角刻度。名字说的是**用途**不是数值，换档时不会漏改语义。
///
/// 值本身就是 [BorderRadius]：Flutter 里所有 `borderRadius:` 位置都收它，
/// 页面里就不该再出现 `BorderRadius.circular(16)`。
abstract final class AppRadius {
  /// 课程色条、进度条：细长条，两端几乎不圆。
  static const BorderRadius bar = BorderRadius.all(Radius.circular(2));

  /// 列表行内高亮块。
  static const BorderRadius xs = BorderRadius.all(Radius.circular(4));

  /// 徽章、小圆点标签。
  static const BorderRadius chip = BorderRadius.all(Radius.circular(6));

  /// 输入框、小色块（课表格子、空闲教室时间段）。
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));

  /// 课表格子上的次级徽章。
  static const BorderRadius badge = BorderRadius.all(Radius.circular(10));

  /// 列表项、输入框、对话框按钮。
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));

  /// 按钮：FilledButton / OutlinedButton 的统一形状。
  static const BorderRadius control = BorderRadius.all(Radius.circular(14));

  /// 卡片。
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));

  /// 对话框、底部弹层、摘要卡。
  static const BorderRadius sheet = BorderRadius.all(Radius.circular(20));
}

/// 触控目标下限。Apple HIG / Material 都要求可点区域不小于这个尺寸，
/// 视觉上小一点没关系，命中区域不能小。
abstract final class AppTouch {
  static const double minimum = 44;
}
