import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/service_locator.dart';
import '../../data/repositories/account_repository.dart';
import '../widgets/buttons/app_buttons.dart';

/// 数据页的外壳：登录态掉了就先给一个登录入口，别让请求打水漂。
///
/// 正常情况下路由守卫不会让人在未登录时进到这些页，这里只是兜底
/// （比如登录态在页面停留期间失效）。
class LoginRequired extends StatelessWidget {
  const LoginRequired({super.key, required this.builder});

  /// 已登录时才搭起来的内容。
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final account = ServiceScope.of(context).accountRepository;
    return ValueListenableBuilder<SessionState>(
      valueListenable: account.sessionState,
      builder: (context, session, _) => session == SessionState.loggedIn
          ? builder(context)
          : const _LoginPrompt(),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 12),
          Text('登录后查看', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          PrimaryButton(
            label: '去登录',
            icon: Icons.login,
            onPressed: () => context.push(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
