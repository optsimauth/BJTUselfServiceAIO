/// 全局常量与本地存储 key。对应 Android 的 DataStore keys + BuildConfig。
abstract final class AppConstants {
  static const String appName = '交大自由行';
  static const String appSlogan = '让校园生活更便捷';
  static const String githubRepository = 'HFDLYS/BJTUselfService';

  /// 所有下载统一落在这个子目录下：课件、成绩单、校历、教学日历、课表 .ics。
  /// 目的只有一个 —— 用户找得到、删得掉，也不会和自己下的文件混在一起。
  static const String downloadAppFolder = 'bjtuselfserviceaio';

  /// 与旧 Room 库同名，便于后续做数据迁移对拍。
  static const String databaseName = 'bjtuselfservice_database';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration downloadTimeout = Duration(minutes: 5);

  /// 下载并发上限（对应 DownloadUtil.maxConcurrentDownloads）。
  static const int maxConcurrentDownloads = 8;
}

/// SharedPreferences / SecureStorage 的 key，集中管理避免拼写漂移。
abstract final class StorageKeys {
  static const String username = 'username';
  static const String password = 'password';
  static const String autoSyncGrades = 'auto_sync_grades';
  static const String autoSyncHomework = 'auto_sync_homework';
  static const String autoSyncSchedule = 'auto_sync_schedule';
  static const String autoSyncExams = 'auto_sync_exams';
  static const String autoSyncCourseware = 'auto_sync_courseware';
  static const String currentWeek = 'current_week';
  static const String scheduleTerm = 'schedule_term';
  static const String semesterStart = 'semester_start';
  static const String checkUpdate = 'check_update';
  static const String dynamicColor = 'dynamic_color';
  static const String themeMode = 'theme';
  static const String backgroundImageUri = 'background_image_uri';
  static const String coursewareJson = 'courseware_json';
  static const String gradeSelections = 'grade_selections_by_student';
  static const String cookies = 'persisted_cookies';

  /// 用户在设置里选的下载根目录（绝对路径）。空串 = 用系统默认下载目录。
  static const String downloadDirectory = 'download_directory';

  /// 校历时间轴缓存（JSON：每学期的教学周 -> 周一日期）。
  ///
  /// 缓存它是因为周次换算要在首页日历 / 课表 / 导出里到处用，
  /// 而 bksy 是公开页但也上不了线（每页几百 KB 的隐藏字段）。
  static const String academicWeeks = 'academic_weeks';

  /// 用户在设置里选的日志目录（绝对路径）。空串 = 应用私有目录下的 logs/。
  static const String logDirectory = 'log_directory';
}
