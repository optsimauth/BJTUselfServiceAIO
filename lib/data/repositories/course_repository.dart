import '../../core/state/data_sync_manager.dart';
import '../../core/state/pending_sync.dart';
import '../../core/state/sync_module.dart';
import '../../core/state/sync_result.dart';
import 'dart:convert';

import '../../core/storage/preferences.dart';
import '../models/calendar/calendar_week.dart';
import '../../services/download/download_service.dart';
import '../local/local_stores.dart';
import '../mock/mock_lists.dart';
import '../models/course/course_model.dart';
import '../remote/api/calendar_api.dart';
import '../remote/api/course_api.dart';
import '../remote/parsers/calendar_parser.dart';
import '../remote/parsers/course_parser.dart';

/// 课表的唯一数据出口。页面只知道 watchAll / sync，不知道网络和数据库。
class CourseRepository {
  CourseRepository({
    required CourseApi courseApi,
    required CalendarApi calendarApi,
    required CourseLocalStore localStore,
    required DownloadService downloadService,
    required AppPreferences preferences,
  }) : _courseApi = courseApi,
       _calendarApi = calendarApi,
       _localStore = localStore,
       _downloadService = downloadService,
       _preferences = preferences,
       _syncManager = DataSyncManager<Course>(
         store: localStore,
         identity: (course) => course.identity,
         changed: (current, previous) =>
             current.name != previous.name ||
             current.teacher != previous.teacher ||
             current.time != previous.time ||
             current.place != previous.place,
         mergeIds: (current, previous) => current.copyWith(id: previous.id),
       );

  final CourseApi _courseApi;
  final CalendarApi _calendarApi;
  final CourseLocalStore _localStore;
  final DownloadService _downloadService;
  final AppPreferences _preferences;
  final DataSyncManager<Course> _syncManager;

  /// 全部课程（两个学期混在一起）。学期/周次过滤交给上层。
  Stream<List<Course>> watchAll() => _localStore.watchAll();

  Future<SyncResult> sync() async => (await prepareSync()).commit();

  /// 只请求并比较，不写数据库；首页用它展示待确认的变化。
  Future<PendingSync> prepareSync() async {
    final local = await _localStore.getAll();
    final changes = <DataChange<Course>>[];
    var succeeded = false;
    for (final isCurrentSemester in [true, false]) {
      try {
        final remote = await _fetchSemester(
          isCurrentSemester: isCurrentSemester,
        );
        final localSemester = local
            .where((course) => course.isCurrentSemester == isCurrentSemester)
            .toList();
        changes.addAll(
          _syncManager.detectChanges(remote: remote, local: localSemester),
        );
        succeeded = true;
      } catch (_) {
        // 失败学期不参与比较，避免把本地缓存误判成删除。
      }
    }
    if (!succeeded) throw StateError('课表刷新失败');
    return _pendingSync(changes);
  }

  PendingSync _pendingSync(List<DataChange<Course>> changes) {
    final result = SyncResult.fromChanges(SyncModule.course, changes);
    return PendingSync(
      result: result,
      commit: () async {
        await _syncManager.apply(changes);
        return result;
      },
    );
  }

  // ---- 校历时间轴（周次 ↔ 日期）----

  /// 上次缓存的校历。没有就是 null，调用方退回 7 天除法（假期周会算不准）。
  TeachingCalendar? loadTeachingCalendar({DateTime? today}) {
    final raw = _preferences.academicWeeksJson;
    if (raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! List) return null;
      final all = <String, TeachingCalendar>{};
      for (final item in json) {
        if (item is! Map) continue;
        final calendar = TeachingCalendar.fromJson(item.cast<String, Object?>());
        if (calendar != null) all[calendar.label] = calendar;
      }
      return _pickSemester(all, today ?? DateTime.now());
    } catch (_) {
      return null;
    }
  }

  /// 拉一次校历并覆盖缓存。失败时保留旧缓存（宁可旧周次，也不要没有周次）。
  Future<TeachingCalendar?> refreshTeachingCalendar({DateTime? today}) async {
    final now = today ?? DateTime.now();
    try {
      final html = await _calendarApi.fetchAcademicWeeksPage();
      final parsed = CalendarParser.parseAcademicWeeks(html);
      if (parsed.isEmpty) return loadTeachingCalendar(today: now);
      await _preferences.setAcademicWeeksJson(
        jsonEncode([
          for (final calendar in parsed.values) calendar.toJson(),
        ]),
      );
      return _pickSemester(parsed, now);
    } catch (_) {
      return loadTeachingCalendar(today: now);
    }
  }

  /// 挑今天所在的那个学期：先按「今天落在它的周区间里」找，
  /// 再退「已经开始的学期里最晚的那个」。
  TeachingCalendar? _pickSemester(
    Map<String, TeachingCalendar> all,
    DateTime today,
  ) {
    if (all.isEmpty) return null;
    for (final calendar in all.values) {
      if (calendar.slotOf(today) != null) return calendar;
    }
    final started =
        all.values
            .where(
              (c) =>
                  c.slots.isNotEmpty && !c.slots.first.startDate.isAfter(today),
            )
            .toList()
          ..sort(
            (a, b) => a.slots.first.startDate.compareTo(b.slots.first.startDate),
          );
    return started.isNotEmpty ? started.last : all.values.first;
  }


  /// 当前教学周。课程平台是权威值；它挂了再退回教室状态页的 `zc` 参数，
  /// 最后退回本地记录。
  Future<int> refreshCurrentWeek() async {
    final week = await _fetchPlatformWeek() ?? await _fetchClassroomWeek() ?? 0;
    if (week > 0) {
      await _preferences.setCurrentWeek(week);
    }
    return _preferences.currentWeek;
  }

  Future<List<Semester>> _fetchSemesters() async {
    final raw = await _courseApi.fetchSemesterTypes();
    return CourseParser.parseSemesterList(raw);
  }

  /// 校历 PDF。返回落盘后的文件名。
  Future<String> downloadSchoolCalendar() async {
    final page = await _calendarApi.fetchSchoolCalendarPage();
    final url = CalendarParser.parseSchoolCalendarPdfUrl(page);
    return _downloadService.download(
      url: url,
      fileName: '校历.pdf',
      name: 'calendar.school',
    );
  }

  /// 某门课的教学日历 PDF。
  Future<String> downloadTeachingCalendar({required Course course}) async {
    final page = await _calendarApi.fetchTeachingCalendarPage(
      courseId: course.courseId,
    );
    final iframeSrc = CalendarParser.parseTeachingCalendarPdfUrl(
      page.isEmpty ? '' : page,
    );
    return _downloadService.download(
      url: iframeSrc,
      fileName: '${course.name}-教学日历.pdf',
      name: 'calendar.teaching.${course.courseId}',
    );
  }

  /// 单个学期的课表。主来源是教务 HTML 页，失败/解析为空时退回课程平台 JSON。
  Future<List<Course>> _fetchSemester({required bool isCurrentSemester}) async {
    final fetched = await _fetchSemesterOrNull(
      isCurrentSemester: isCurrentSemester,
    );
    if (!MockList.course) return fetched;
    return [
      ...fetched,
      ...MockList.courses.where(
        (course) => course.isCurrentSemester == isCurrentSemester,
      ),
    ];
  }

  Future<List<Course>> _fetchSemesterOrNull({
    required bool isCurrentSemester,
  }) async {
    final fromHtml = await _tryFetchSchedulePage(
      isCurrentSemester: isCurrentSemester,
    );
    if (fromHtml != null) {
      return fromHtml;
    }
    return _fetchSemesterFromPlatform(isCurrentSemester: isCurrentSemester);
  }

  /// 教务 HTML 课表页。拿不到有效课程时返回 null，让调用方决定要不要兜底。
  Future<List<Course>?> _tryFetchSchedulePage({
    required bool isCurrentSemester,
  }) async {
    try {
      final html = await _courseApi.fetchSchedulePage(
        isCurrentSemester: isCurrentSemester,
      );
      final courses = CourseParser.parseScheduleHtml(
        html,
        isCurrentSemester: isCurrentSemester,
      );
      return courses.isEmpty ? null : courses;
    } catch (_) {
      return null;
    }
  }

  /// 课程平台 JSON 兜底。注意它没有格子位置。
  Future<List<Course>> _fetchSemesterFromPlatform({
    required bool isCurrentSemester,
  }) async {
    final semesters = await _fetchSemesters();
    final matched = semesters.where(
      (semester) => semester.isCurrent == isCurrentSemester,
    );
    if (matched.isEmpty) {
      return const [];
    }
    final raw = await _courseApi.fetchCourseListRaw(
      semesterCode: matched.first.code,
    );
    return CourseParser.parseCourseListJson(
      raw,
      isCurrentSemester: isCurrentSemester,
    );
  }

  /// 课程平台 `getTimeList` 的 weekCode。拿不到返回 null（区别于「确实是第 0 周」）。
  Future<int?> _fetchPlatformWeek() async {
    try {
      final raw = await _courseApi.fetchCurrentWeekRaw();
      final week = CourseParser.parseCurrentWeek(raw);
      return week > 0 ? week : null;
    } catch (_) {
      return null;
    }
  }

  /// 教室状态页的当前周次：访问入口会 302 到 `?zc=<周次>`。
  Future<int?> _fetchClassroomWeek() async {
    try {
      final entry = await _courseApi.fetchClassroomStatusEntry();
      final week = CourseParser.parseWeekFromQuery(entry.queryParameter('zc'));
      return week > 0 ? week : null;
    } catch (_) {
      return null;
    }
  }
}
