import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

/// 通用卡片。旧项目里 HomeworkItemCard / ExamItemCard 的公共外壳。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.card,
    this.leading,
    this.trailing,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    return Card(
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
