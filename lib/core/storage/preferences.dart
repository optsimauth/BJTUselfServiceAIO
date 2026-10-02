import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// 需要自动同步的模块。业务侧只认枚举，不认字符串 key。
enum AutoSyncTarget { grades, homework, schedule, exams, courseware }

/// 轻量键值存储，替代 Android 的 DataStoreRepository。
/// 明文/非敏感配置放这里，账号密码走 SecureStorage。
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppPreferences> open() async =>
      AppPreferences(await SharedPreferences.getInstance());

  String readString(String key, {String fallback = ''}) =>
      _prefs.getString(key) ?? fallback;

  bool readBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  int readInt(String key, {int fallback = 0}) => _prefs.getInt(key) ?? fallback;

  Future<void> writeString(String key, String value) async {
    await _prefs.setString(key, value);
    _notify(key);
  }

  Future<void> writeBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    _notify(key);
  }

  Future<void> writeInt(String key, int value) async {
    await _prefs.setInt(key, value);
    _notify(key);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
    _notify(key);
  }

  /// 替代 DataStore 的 Flow：设置页监听它做实时刷新。
  Stream<String> get changes => _changes.stream;

  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  void _notify(String key) {
    if (!_changes.isClosed) {
      _changes.add(key);
    }
  }

  // ---- 业务向封装 ----
  bool autoSyncEnabled(AutoSyncTarget target) =>
      readBool(_autoSyncKey(target), fallback: true);

  Future<void> setAutoSyncEnabled(AutoSyncTarget target, bool enabled) =>
      writeBool(_autoSyncKey(target), enabled);

  int get currentWeek => readInt(StorageKeys.currentWeek);

  Future<void> setCurrentWeek(int week) =>
      writeInt(StorageKeys.currentWeek, week);

  // ---- 课表页的本地选择 ----

  /// 上次看的学期视图（`current` / `history`），没存过时是本学期。
  String get scheduleTerm =>
      readString(StorageKeys.scheduleTerm, fallback: 'current');

  Future<void> setScheduleTerm(String term) =>
      writeString(StorageKeys.scheduleTerm, term);

  String get themeMode => readString(StorageKeys.themeMode, fallback: 'system');

  Future<void> setThemeMode(String mode) =>
      writeString(StorageKeys.themeMode, mode);

  bool get dynamicColorEnabled =>
      readBool(StorageKeys.dynamicColor, fallback: true);

  Future<void> setDynamicColorEnabled(bool enabled) =>
      writeBool(StorageKeys.dynamicColor, enabled);

  bool get checkUpdateEnabled =>
      readBool(StorageKeys.checkUpdate, fallback: true);

  Future<void> setCheckUpdateEnabled(bool enabled) =>
      writeBool(StorageKeys.checkUpdate, enabled);

  String get backgroundImageUri => readString(StorageKeys.backgroundImageUri);

  Future<void> setBackgroundImageUri(String uri) =>
      writeString(StorageKeys.backgroundImageUri, uri);

  String get coursewareJson => readString(StorageKeys.coursewareJson);

  Future<void> setCoursewareJson(String json) =>
      writeString(StorageKeys.coursewareJson, json);
  // ---- 校历 ----

  /// 校历时间轴缓存 JSON。没缓存过是空串 —— 调用方退回 7 天除法兜底。
  String get academicWeeksJson => readString(StorageKeys.academicWeeks);

  Future<void> setAcademicWeeksJson(String value) =>
      writeString(StorageKeys.academicWeeks, value);

  // ---- 下载位置 ----

  /// 设置页里选的下载根目录。空串表示「还没选过」，下载走系统默认目录。
  String get downloadDirectory => readString(StorageKeys.downloadDirectory);

  Future<void> setDownloadDirectory(String path) =>
      writeString(StorageKeys.downloadDirectory, path);

  // ---- 日志位置 ----

  /// 设置页里选的日志目录。空串 = 应用私有目录下的 `logs/`。
  String get logDirectory => readString(StorageKeys.logDirectory);

  Future<void> setLogDirectory(String path) =>
      writeString(StorageKeys.logDirectory, path);
  Future<void> clearAllBusinessData() async {
    for (final key in [
      StorageKeys.coursewareJson,
      StorageKeys.gradeSelections,
      StorageKeys.currentWeek,
    ]) {
      await remove(key);
    }
  }

  static String _autoSyncKey(AutoSyncTarget target) => switch (target) {
    AutoSyncTarget.grades => StorageKeys.autoSyncGrades,
    AutoSyncTarget.homework => StorageKeys.autoSyncHomework,
    AutoSyncTarget.schedule => StorageKeys.autoSyncSchedule,
    AutoSyncTarget.exams => StorageKeys.autoSyncExams,
    AutoSyncTarget.courseware => StorageKeys.autoSyncCourseware,
  };

  void dispose() => _changes.close();
}
