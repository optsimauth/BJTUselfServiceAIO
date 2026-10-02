import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/storage/preferences.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/download_progress_bar.dart';
import '../shared/widgets/page_width.dart';
import 'app_router.dart';
import 'service_locator.dart';

/// APP 根组件。登录门闸在 [createAppRouter] 的守卫里，这里只负责起自动登录。
class BjtuSelfServiceApp extends StatefulWidget {
  const BjtuSelfServiceApp({super.key, required this.locator});

  final ServiceLocator locator;

  @override
  State<BjtuSelfServiceApp> createState() => _BjtuSelfServiceAppState();
}

class _BjtuSelfServiceAppState extends State<BjtuSelfServiceApp> {
  late final _router = createAppRouter(widget.locator);

  /// 主题模式只存在 preferences 里，谁改了监听一下重建 MaterialApp 即可。
  ThemeMode _themeMode = ThemeMode.system;
  StreamSubscription<String>? _preferencesSubscription;

  @override
  void initState() {
    super.initState();
    final preferences = widget.locator.preferences;
    _readThemeMode(preferences);
    _preferencesSubscription = preferences.changes.listen((key) {
      if (key == StorageKeys.themeMode) {
        setState(() => _readThemeMode(preferences));
      }
    });
    // 界面不等它：守卫停在启动页，本地数据照常先渲染。
    unawaited(widget.locator.accountRepository.restoreSession());
  }

  void _readThemeMode(AppPreferences preferences) {
    _themeMode = AppThemeMode.fromStorage(preferences.themeMode).themeMode;
  }

  @override
  void dispose() {
    _preferencesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ServiceScope(
      locator: widget.locator,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: _router,
        scrollBehavior: const AppScrollBehavior(),
        // builder 包住整个 Navigator，所以三个 tab 页、push 出来的子页、
        // 弹层全部一次套上，不用挨个页面去改。手机上不生效。
        builder: (context, child) => PageWidth(
          // 系统字号放大到 2x 时，日历格、成绩表头、筛选 chip 会直接溢出。
          // 保留 1.3x：大字体用户看得见，只是放不下密集表格。
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: 1.3,
            // 下载进度浮在最底下。放在 builder 里 = 整个 Navigator 都被包住，
            // 课件、成绩单、教学日历、导出的 .ics，谁在下载都从这里冒出来。
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DownloadProgressBar(
                    tasks: widget.locator.downloadService.tasks,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
