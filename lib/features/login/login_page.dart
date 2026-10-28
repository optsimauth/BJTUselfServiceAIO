import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/service_locator.dart';
import '../../core/model/common_models.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/buttons/app_buttons.dart';

/// 入口装配依赖，表单独立渲染与测试。
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final locator = ServiceScope.of(context);
    return LoginView(
      initialUsername: locator.secureStorage.cachedCredentials?.username ?? '',
      onLogin: locator.accountRepository.login,
    );
  }
}

class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    this.initialUsername = '',
    required this.onLogin,
  });
  final String initialUsername;
  final Future<void> Function(Credentials) onLogin;
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final _username = TextEditingController(text: widget.initialUsername);
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _canSubmit =>
      !_busy && _username.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(
        Credentials(username: _username.text.trim(), password: _password.text),
      );
      TextInput.finishAutofillContext();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LoginHeading(),
                  const SizedBox(height: AppSpacing.xxl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: _buildFields(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '使用学校统一身份认证账号\n密码仅保存在此设备的安全存储中',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildFields(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('登录校园账号', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      Text('课表、成绩与待办，从这里开始。', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xl),
      TextField(
        controller: _username,
        enabled: !_busy,
        autofillHints: const [AutofillHints.username],
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: '学号 / 工号',
          prefixIcon: Icon(Icons.person_outline),
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _password,
        enabled: !_busy,
        autofillHints: const [AutofillHints.password],
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '统一认证密码',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _obscure ? '显示密码' : '隐藏密码',
            onPressed: _busy
                ? null
                : () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _submit(),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      PrimaryButton(
        label: '登录',
        icon: Icons.arrow_forward,
        loading: _busy,
        onPressed: _canSubmit ? _submit : null,
      ),
    ],
  );
}

class _LoginHeading extends StatelessWidget {
  const _LoginHeading();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: AppRadius.sheet,
          ),
          child: Icon(
            Icons.train_outlined,
            size: 32,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '交大自由行',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '让校园生活，从容一点。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
