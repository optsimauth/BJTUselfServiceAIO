import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/network_exception.dart';
import '../../core/state/sync_module.dart';
import '../../core/utils/logger.dart';
import '../../core/state/sync_result.dart';
import '../../core/storage/preferences.dart';
import 'course_repository.dart';
import 'courseware_repository.dart';
import 'exam_repository.dart';
import 'grade_repository.dart';
import 'homework_repository.dart';

export '../../core/state/sync_module.dart';

/// 全局数据同步编排。
///
/// 登录后后台同步并写入数据库；页面只订阅共享 Controller 和 Drift stream，
/// 所以本地旧数据先显示，网络结果落库后页面自动换成新的。
class SyncCoordinator {
  SyncCoordinator({
    required CourseRepository course,
    required GradeRepository grade,
    required ExamRepository exam,
    required HomeworkRepository homework,
    required CoursewareRepository courseware,
    required AppPreferences preferences,
    required this.awaitSession,
    this.sessionWait = const Duration(seconds: 30),
    this.retryDelay = const Duration(milliseconds: 800),
  }) : _course = course,
       _grade = grade,
       _exam = exam,
       _homework = homework,
       _courseware = courseware,
       _preferences = preferences;

  final CourseRepository _course;
  final GradeRepository _grade;
  final ExamRepository _exam;
  final HomeworkRepository _homework;
  final CoursewareRepository _courseware;
  final AppPreferences _preferences;

  /// 等冷启动那次自动登录跑完（成功或失败都会返回），
  /// 别把第一轮同步打在半截会话上。
  final Future<void> Function() awaitSession;

  /// 等 [awaitSession] 的上限。超时后不再等，直接试同步。
  final Duration sessionWait;

  /// 网络失败后的重试间隔。测试里调小，别让单测真的睡 800ms。
  final Duration retryDelay;

  static const Logger _log = Logger('Sync');

  /// 顶部进度条绑这个。
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  /// 本次同步检测到的、还没进对应页面确认的模块变化。
  final ValueNotifier<Map<SyncModule, SyncResult>> pendingChanges =
      ValueNotifier<Map<SyncModule, SyncResult>>(const {});

  int _running = 0;

  /// 进主页就调用：等自动登录结束，然后后台同步并落库，
  /// 页面通过 Drift stream 静默更新。
  Future<void> syncAll() async {
    // 等冷启动那次自动登录跑完，好把第一轮同步打在完整会话上。
    //
    // 但**不能无限等**：自动登录一旦 hang 住，首页就会永远停在空数据上，
    // 而且没有任何提示。超时后照样往下走 —— 真没登录成功，后面的
    // `ensureLoggedIn` 会自己抛，比卡在这里强。
    try {
      await awaitSession().timeout(sessionWait);
    } on TimeoutException {
      _log.w('等待自动登录超时，仍继续尝试同步');
    }
    await Future.wait([
      for (final module in _enabledModules()) _syncSafely(module),
    ]);
  }

  /// 兼容旧调用名；现在登录预览会直接提交到本地数据库。
  Future<void> previewAll() => syncAll();

  /// 手动检测单个模块；保留给首页或设置页使用。
  Future<void> previewModule(SyncModule module) async {
    await _syncSafely(module);
  }

  Future<void> _syncSafely(SyncModule module) async {
    try {
      await syncModule(module);
    } catch (error, stack) {
      // 单个模块失败不阻塞其他模块；本地旧数据继续可用。
      //
      // 但**必须留下痕迹**。原来这里是 `catch (_) {}`，同步真跑了、
      // 某个模块失败时，界面上和「压根没同步」完全一样，用户无从判断。
      // LogRecorder 会把这条写进日志文件，设置页的「查看日志」能看到。
      _log.e('${module.label}同步失败', error, stack);
    }
  }

  /// 手动刷新某个模块并落库，忽略自动同步开关。
  ///
  /// 同一个模块并发调用**共用同一个 Future**：首页 initState 会自动同步一次，
  /// 用户又可能立刻手动刷新，不去重就是同一份数据打两遍接口，
  /// `pendingChanges` 还会被后写的那次覆盖掉。
  Future<SyncResult> syncModule(SyncModule module) {
    return _inFlight[module] ??= _runModule(module).whenComplete(() {
      _inFlight.remove(module);
    });
  }

  final Map<SyncModule, Future<SyncResult>> _inFlight = {};

  Future<SyncResult> _runModule(SyncModule module) async {
    _begin();
    try {
      final result = await _fetchWithRetry(module);
      _record(module, result);
      return result;
    } finally {
      _end();
    }
  }

  /// 瞬时故障（弱网、网关抖一下）重试一次。
  ///
  /// 只对 [NetworkException] 重试：解析失败重试多少次都是同样的空结果，
  /// 纯属浪费请求配额。固定 [retryDelay]，不引入指数退避状态机 ——
  /// 一次重试不值得。
  Future<SyncResult> _fetchWithRetry(SyncModule module) async {
    try {
      return await _fetch(module);
    } on NetworkException catch (error) {
      _log.w('${module.label}请求失败，重试一次', error);
      await Future<void>.delayed(retryDelay);
      return _fetch(module);
    }
  }

  Future<SyncResult> _fetch(SyncModule module) => switch (module) {
    SyncModule.course => _course.sync(),
    SyncModule.grade => _grade.sync(),
    SyncModule.exam => _exam.sync(),
    SyncModule.homework => _homework.sync(),
    SyncModule.courseware => _courseware.sync(),
  };

  /// 用户查看对应模块后，把首页上那一行提示清掉。
  void clearPending(SyncModule module) {
    if (!pendingChanges.value.containsKey(module)) return;
    final next = Map<SyncModule, SyncResult>.of(pendingChanges.value)
      ..remove(module);
    pendingChanges.value = next;
  }

  /// 设置页的开关 -> 同步模块。开关和「哪些模块参与自动同步」必须共用这一张
  /// 映射表：两处各写一遍，早晚会对不上。
  static SyncModule? moduleOf(AutoSyncTarget target) => switch (target) {
    AutoSyncTarget.schedule => SyncModule.course,
    AutoSyncTarget.grades => SyncModule.grade,
    AutoSyncTarget.exams => SyncModule.exam,
    AutoSyncTarget.homework => SyncModule.homework,
    AutoSyncTarget.courseware => SyncModule.courseware,
  };

  List<SyncModule> _enabledModules() => [
    for (final target in AutoSyncTarget.values)
      if (_preferences.autoSyncEnabled(target)) ?moduleOf(target),
  ];

  void _record(SyncModule module, SyncResult result) {
    final next = Map<SyncModule, SyncResult>.of(pendingChanges.value);
    if (result.hasChanges) {
      next[module] = result;
    } else {
      next.remove(module);
    }
    pendingChanges.value = next;
  }

  // ponytail: 没有做 in-flight 去重，同一模块并发调用会重复打接口；
  // 真出现重复请求再按 SyncModule 加一张 in-flight 表。
  void _begin() {
    _running++;
    isSyncing.value = true;
  }

  void _end() {
    _running--;
    if (_running <= 0) {
      isSyncing.value = false;
    }
  }

  void dispose() {
    isSyncing.dispose();
    pendingChanges.dispose();
  }
}
