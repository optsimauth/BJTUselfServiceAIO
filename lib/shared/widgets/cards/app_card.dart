import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

/// 设置、账号与工具目录共用的分组面板。
class AppSection extends StatelessWidget {
  const AppSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}

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
