import 'package:flutter/material.dart';

import '../error_text.dart';

/// 统一弹窗。旧项目里登录失败弹窗 / 退出确认弹窗各自手写，这里收敛成两个函数。
abstract final class AppDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = '确定',
    String cancelText = '取消',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> error(
    BuildContext context,
    Object error, {
    String title = '出错了',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(errorText(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
