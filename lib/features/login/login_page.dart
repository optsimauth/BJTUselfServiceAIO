import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/model/common_models.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/theme/spacing.dart';

/// 登录页。只在**没有**本地凭据（第一次用）或自动登录失败时出现。
///
/// 不显示验证码：验证码在 AccountRepository 里自动识别后直接提交。
/// 登录成功后不自己导航，路由守卫看到登录态变成 true 会把人送回主页。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // 初值在 initState 里同步取好，之后**任何**代码都不再往这两个 controller 里写内容。
    // 异步回填会在用户已经改过输入框之后才落笔，从而出现「旧密码粘回来」的现象。
    final credentials = ServiceScope.of(context)
        .secureStorage
        .cachedCredentials;
    _usernameController = TextEditingController(
      text: credentials?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: credentials?.password ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ServiceScope.of(context).accountRepository.login(
        Credentials(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.appSlogan,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      _ErrorBanner(message: '$_error'),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _usernameController,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '学号',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      // 输入变了才能重新判断登录按钮该不该亮。
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.password],
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: '登 录',
                      icon: Icons.login,
                      loading: _busy,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}
