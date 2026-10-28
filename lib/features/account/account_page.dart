import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../data/models/account/account_model.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/cards/app_card.dart';
import '../../shared/widgets/page_width.dart';
import '../../shared/widgets/app_status_view.dart';
import '../../shared/widgets/error_text.dart';
import '../../shared/widgets/loading/app_loading.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final _account = ServiceScope.of(context).accountRepository;

  StudentProfile? _profile;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 路由守卫保证只有登录后才会进这一页，直接发请求即可。
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _account.fetchStudentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: PageWidth(
        maxWidth: AppLayout.contentMaxWidth,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final profile = _profile;
    if (_error != null && profile == null) {
      return _ErrorRetry(error: _error!, onRetry: _load);
    }
    if (profile == null) {
      return const AppLoading(message: '正在读取账号资料…');
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppSection(
          title: '校园账号',
          children: [
            ListTile(title: const Text('姓名'), subtitle: Text(profile.name)),
            ListTile(
              title: const Text('学号'),
              subtitle: Text(profile.studentId),
            ),
            ListTile(title: const Text('学院'), subtitle: Text(profile.college)),
            ListTile(title: const Text('专业'), subtitle: Text(profile.major)),
            ListTile(
              title: const Text('班级'),
              subtitle: Text(profile.className),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppStatusView(
      icon: Icons.person_outline,
      title: '账号资料暂时无法读取',
      message: errorText(error),
      action: FilledButton(onPressed: onRetry, child: const Text('重试')),
    );
  }
}
