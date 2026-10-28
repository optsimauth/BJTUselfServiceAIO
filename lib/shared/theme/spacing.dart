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

  /// 列表项、菜单、SnackBar。
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));

  /// 按钮与输入：沿用 Shadcn 的克制圆角，触控尺寸单独保证。
  static const BorderRadius control = BorderRadius.all(Radius.circular(8));

  /// 卡片。
  static const BorderRadius lg = BorderRadius.all(Radius.circular(12));

  /// 对话框、底部弹层、摘要卡。
  static const BorderRadius sheet = BorderRadius.all(Radius.circular(16));
}

/// 项目的跨平台触控下限，采用 Material 的 48dp（HIG 的下限为 44pt）。
/// 视觉上小一点没关系，命中区域不能小。
abstract final class AppTouch {
  static const double minimum = 48;
}

/// 窗口断点来自 Flutter / Material，自适应依据是可用空间而不是设备名称。
abstract final class AppLayout {
  static const double railMinWidth = 600;
  static const double extendedRailMinWidth = 1200;
  static const double contentMaxWidth = 840;
  static const double formMaxWidth = 440;
  static const double boardMaxWidth = 1200;
}
