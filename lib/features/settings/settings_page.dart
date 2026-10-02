import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app_router.dart';

import 'package:go_router/go_router.dart';

import '../../app/service_locator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/preferences.dart';
import '../../core/utils/log_recorder.dart';
import '../../data/repositories/sync_coordinator.dart';
import '../../services/update/update_service.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/dialog/app_dialog.dart';

/// 设置页。旧项目 SettingScreen.kt（868 行）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _preferences = ServiceScope.of(context).preferences;
  late final _updateService = ServiceScope.of(context).updateService;
  late final _accountRepository = ServiceScope.of(context).accountRepository;
  late final _filePicker = ServiceScope.of(context).filePickerService;

  AppRelease? _latestRelease;
  bool _checkingUpdate = false;

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final release = await _updateService.checkForUpdate();
      if (!mounted) return;
      setState(() => _latestRelease = release);
      if (release == null) {
        _toast('已经是最新版本');
      } else {
        await _offerUpdate(release);
      }
    } catch (error) {
      if (!mounted) return;
      await AppDialog.error(context, error);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _offerUpdate(AppRelease release) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '发现新版本 ${release.version}',
      message: release.body.isEmpty ? '要现在下载吗？' : release.body,
      confirmText: '下载',
    );
    if (!confirmed) {
      return;
    }
    await _updateService.downloadRelease(release);
    _toast('安装包已保存');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 选一个新的下载根目录。取消了就不改设置。
  Future<void> _chooseDownloadDirectory() async {
    final picked = await _filePicker.pickDirectory(
      initialDirectory: _preferences.downloadDirectory,
    );
    if (picked == null || !mounted) return;
    await _preferences.setDownloadDirectory(picked);
    if (!mounted) return;
    _toast('所有下载将保存到 $picked/${AppConstants.downloadAppFolder}/');
  }

  /// 下载真正落盘的目录：设置里选的（或者系统下载目录）+ app 那一层文件夹。
  ///
  /// 设置页要显示它，用户才找得到自己下的东西；课件、成绩单、校历、
  /// 教学日历、课表 .ics 全部在这里面。
  String get _downloadLocation {
    final root = _preferences.downloadDirectory.trim();
    final base = root.isEmpty ? '系统下载目录' : root;
    return '$base/${AppConstants.downloadAppFolder}/';
  }

  /// 选一个新的日志目录。取消了就不改设置。
  Future<void> _chooseLogDirectory() async {
    final picked = await _filePicker.pickDirectory(
      initialDirectory: _preferences.logDirectory,
    );
    if (picked == null) return;
    await _setLogDirectory(picked);
  }

  /// 改完立刻切目录，prefs 的 changes 流带着设置页一起刷新。
  Future<void> _setLogDirectory(String path) async {
    await _preferences.setLogDirectory(path);
    await LogRecorder.instance.setOverrideDirectory(path);
    if (!mounted) return;
    _toast(path.isEmpty ? '日志将保存到应用默认目录' : '日志将保存到 $path');
  }

  /// App 自身介绍：是什么、能干什么、数据从哪来。
  /// 版本号读安装包里的，发版不用改代码。
  Future<void> _showAbout() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppConstants.appName} ${info.version}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppConstants.appSlogan, style: theme.textTheme.bodyMedium),
              _AboutSection(
                theme: theme,
                heading: '能干什么',
                lines: const [
                  '· 课表、成绩、作业、考试安排同步一次，离线也能看',
                  '· 课件、校历、成绩单下到你自己选的目录',
                  '· 课表能导出 .ics，导入 iOS / Google 日历就会提前提醒',
                  '· 空闲教室、教室容量、成绩排名、倒计时在首页',
                ],
              ),
              _AboutSection(
                theme: theme,
                heading: '数据从哪来',
                lines: const [
                  '所有内容都来自学校教务与智慧教学平台的公开接口，用你自己的',
                  '账号登录后抓取。App 不保存也不上传你的密码。',
                ],
              ),
              _AboutSection(
                theme: theme,
                heading: '开源项目',
                lines: const ['代码开源在 GitHub：${AppConstants.githubRepository}'],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '退出登录',
      message: '会清除本地缓存的课程、成绩和作业数据。',
      confirmText: '退出',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await _accountRepository.logout();
      if (!mounted) return;
      _toast('已退出登录');
    } catch (error) {
      if (!mounted) return;
      await AppDialog.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: StreamBuilder<String>(
        stream: _preferences.changes,
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader(title: '外观'),
            _ThemeModeTile(preferences: _preferences),
            const _SectionHeader(title: '下载'),
            ListTile(
              title: const Text('下载位置'),
              subtitle: Text(
                _downloadLocation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.folder_open, size: 20),
              onTap: _chooseDownloadDirectory,
            ),
            ListTile(
              title: const Text('恢复默认位置'),
              enabled: _preferences.downloadDirectory.isNotEmpty,
              onTap: () => _preferences.setDownloadDirectory(''),
            ),
            const _SectionHeader(title: '日志'),
            ListTile(
              title: const Text('日志保存位置'),
              subtitle: Text(
                _preferences.logDirectory.isEmpty
                    ? '应用默认目录'
                    : _preferences.logDirectory,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.folder_open, size: 20),
              onTap: _chooseLogDirectory,
            ),
            ListTile(
              title: const Text('恢复默认位置'),
              enabled: _preferences.logDirectory.isNotEmpty,
              onTap: () => _setLogDirectory(''),
            ),
            ListTile(
              title: const Text('查看日志'),
              onTap: () => context.push(AppRoutes.logs),
            ),
            const _SectionHeader(title: '自动同步'),
            for (final target in AutoSyncTarget.values)
              SwitchListTile(
                title: Text(_label(target)),
                value: _preferences.autoSyncEnabled(target),
                onChanged: (value) => _setAutoSync(target, value),
              ),
            const _SectionHeader(title: '其他'),
            SwitchListTile(
              title: const Text('启动时检查更新'),
              value: _preferences.checkUpdateEnabled,
              onChanged: _preferences.setCheckUpdateEnabled,
            ),
            ListTile(
              title: const Text('检查更新'),
              subtitle: _latestRelease == null
                  ? null
                  : Text('最新版本 ${_latestRelease!.version}'),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _checkingUpdate ? null : _checkForUpdate,
            ),
            ListTile(
              leading: const Icon(Icons.star_outline, size: 22),
              title: const Text('项目 Star'),
              subtitle: const Text('看看仓库最近涨了多少'),
              onTap: () => context.push(AppRoutes.stars),
            ),
            ListTile(title: const Text('关于'), onTap: _showAbout),
            ListTile(
              title: const Text('退出登录'),
              textColor: Theme.of(context).colorScheme.error,
              onTap: _confirmLogout,
            ),
          ],
        ),
      ),
    );
  }

  /// 打开开关立刻补一次同步。不补的话新开的模块要等下次冷启动才生效，
  /// 看起来就像开关没用。关掉不用动作：下次自动同步自然就不带它了。
  Future<void> _setAutoSync(AutoSyncTarget target, bool enabled) async {
    await _preferences.setAutoSyncEnabled(target, enabled);
    if (!enabled) return;
    final module = SyncCoordinator.moduleOf(target);
    if (module == null || !mounted) return;
    _toast('正在同步${_label(target)}…');
    final result = await ServiceScope.of(
      context,
    ).syncCoordinator.syncModule(module);
    if (!mounted) return;
    _toast(
      result.hasChanges
          ? '${_label(target)}有新变化'
          : '${_label(target)}已是最新',
    );
  }

  String _label(AutoSyncTarget target) => switch (target) {
    AutoSyncTarget.grades => '成绩',
    AutoSyncTarget.homework => '作业',
    AutoSyncTarget.schedule => '课表',
    AutoSyncTarget.exams => '考试',
    AutoSyncTarget.courseware => '课件',
  };
}

/// 主题模式。之前这个偏好只能写不能读，设置页里没有入口。
class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.preferences});

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('主题'),
      trailing: DropdownButton<String>(
        value: preferences.themeMode,
        onChanged: (value) {
          if (value != null) preferences.setThemeMode(value);
        },
        items: const [
          DropdownMenuItem(value: 'system', child: Text('跟随系统')),
          DropdownMenuItem(value: 'light', child: Text('浅色')),
          DropdownMenuItem(value: 'dark', child: Text('深色')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// 关于弹窗里的一组小标题 + 若干行说明。
class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.theme,
    required this.heading,
    required this.lines,
  });

  final ThemeData theme;
  final String heading;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines) Text(line, style: muted),
        ],
      ),
    );
  }
}
