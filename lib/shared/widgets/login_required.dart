import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/service_locator.dart';
import '../../data/repositories/account_repository.dart';
import '../widgets/buttons/app_buttons.dart';
import 'app_status_view.dart';

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
    return AppStatusView(
      icon: Icons.lock_outline,
      title: '登录后查看',
      message: '使用校园账号连接此项服务',
      action: PrimaryButton(
        label: '去登录',
        icon: Icons.login,
        onPressed: () => context.push(AppRoutes.login),
      ),
    );
  }
}
