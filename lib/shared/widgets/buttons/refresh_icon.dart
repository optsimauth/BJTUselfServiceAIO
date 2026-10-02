import 'package:flutter/material.dart';

/// 刷新按钮：转的时候自己转，不转就是一颗安静的图标。
///
/// 同步要好几秒，只有图标不动的这几秒用户会以为按钮坏了；
/// 转起来就一眼知道「已经在跑了，别再点」。
class RefreshIcon extends StatefulWidget {
  const RefreshIcon({
    super.key,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;

  /// 转的时候置空 —— [IconButton] 拿到 null 就是禁用态，重复点击不会重发请求。
  final VoidCallback? onPressed;

  @override
  State<RefreshIcon> createState() => _RefreshIconState();
}

class _RefreshIconState extends State<RefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isBusy) _spin.repeat();
  }

  @override
  void didUpdateWidget(RefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy == oldWidget.isBusy) return;
    // 停的时候先把角度归零，不然下次开始会从上次停下的地方接着转，看着像卡住。
    if (widget.isBusy) {
      _spin.repeat();
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '刷新',
    onPressed: widget.isBusy ? null : widget.onPressed,
    // 一直画同一颗图标，只在 [isBusy] 时转起来 —— 换成进度圈的话，
    // 同步一结束整个图标就换了个形状，位置也跟着跳。
    icon: RotationTransition(turns: _spin, child: const Icon(Icons.refresh)),
  );
}