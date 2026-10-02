import 'package:flutter/material.dart';

/// 全局页面宽度控制。
///
/// 默认**铺满**窗口：[maxWidth] 留空就是不限宽。
///
/// 想回退到「宽屏定宽居中」时传一个上限即可（例如 `PageWidth(maxWidth: 1160)`）：
/// 桌面端窗口一拉宽，课表和列表会横铺到几千像素，眼睛从一行文字的开头扫到
/// 结尾要转头，课表格子宽到看不出是哪一节。
///
/// 手机上（屏宽小于上限）行为完全一致，一个像素都不会多留。
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// 内容宽度上限；`null` = 铺满窗口。
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final limit = maxWidth ?? double.infinity;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, limit);
        // 限宽模式下两侧留白得画上底色，否则窗口背景会从边上透出来。
        return ColoredBox(
          color: scheme.surface,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, height: constraints.maxHeight, child: child),
          ),
        );
      },
    );
  }
}