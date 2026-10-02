import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';

/// 「彩色淡底 + 一行字」的徽章：作业紧迫度、考试阶段、变更类型都用它。
///
/// 以前这些地方各写一遍 `Container(color: accent.withValues(alpha: 0.12))`
/// 加一句 `Text(style: copyWith(color: 另一个 token))` —— 底色和字色来自
/// 两个不相关的地方，对比度纯属巧合，深浅主题下都会翻车。
/// 现在配色只由 [AppColors.badge] 一处算，配对关系不可能再错。
class TintedBadge extends StatelessWidget {
  const TintedBadge({
    super.key,
    required this.label,
    required this.accent,
    this.icon,
    this.borderRadius,
    this.padding,
  });

  /// 徽章上的字。
  final String label;

  /// 身份色：决定这一块是「红/黄/蓝」的哪一个，不直接拿来当字色。
  final Color accent;

  final IconData? icon;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.badge(Theme.of(context).colorScheme, accent);
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: borderRadius ?? AppRadius.sheet,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
