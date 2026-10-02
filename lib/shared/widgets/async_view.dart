import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_router.dart';
import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../data/repositories/account_repository.dart';
import 'buttons/app_buttons.dart';
import 'error_text.dart';
import 'loading/app_loading.dart';

/// AsyncState -> 界面。每个页面不用再手写 loading / error / empty 三分支。
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.loadingMessage,
    this.isEmpty,
    this.emptyBuilder,
  });

  final AsyncState<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final bool Function(T value)? isEmpty;
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AsyncIdle<T>() => const SizedBox.shrink(),
      AsyncLoading<T>() => AppLoading(message: loadingMessage),
      AsyncError<T>(:final error) => _ErrorView(error: error, onRetry: onRetry),
      AsyncData<T>(:final value) =>
        isEmpty?.call(value) ?? false
            ? (emptyBuilder?.call(context) ?? const _EmptyView())
            : builder(context, value),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(errorText(error), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}

/// 兜底空页：图标 + 标题 + 说明 + 一个动作。
///
/// 只有「暂无数据」三个字的话，用户既不知道是没数据、还是筛选太严、
/// 还是登录掉了，也不知道下一步该点什么。各页面能用 [AsyncView.emptyBuilder]
/// 换成自己的话更好，这里只保证「不出现光秃秃一句话的页面」。
///
/// 没登录且本地确实没数据时改成登录入口：本地有的数据由页面直接显示，
/// 不该被登录态挡住（挡住等于白存那一库）。
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ServiceScope.of(context).accountRepository.sessionState;
    if (session.value != SessionState.loggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40),
            const SizedBox(height: 12),
            Text('登录后查看', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '本地还没有这部分数据',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '去登录',
              icon: Icons.login,
              onPressed: () => context.push(AppRoutes.login),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('这里还没有内容', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '换个筛选条件，或者下拉刷新再看看',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
