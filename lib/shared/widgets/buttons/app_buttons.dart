import 'package:flutter/material.dart';
import '../../../shared/theme/spacing.dart';

/// 子页面左上角的返回按钮。桌面 / 网页端没有系统返回键，进到子页面后全靠它回去。
///
/// 底层走 [BackButton]（`Navigator.maybePop`）：能退就退，已经是最底层
/// （比如直接深链进子页面）就什么都不做，不会把 app 整个弹掉。
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});

  @override
  Widget build(BuildContext context) =>
      const Tooltip(message: '返回', child: BackButton());
}

/// 主按钮：统一高度和圆角，登录页/提交按钮都用它。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
