import 'package:flutter/material.dart';

/// 旋转加载动画（旧项目是 RotatingImageLoader，用一张 loading_icon 图片）。
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size = 48, this.message});

  final double size;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
