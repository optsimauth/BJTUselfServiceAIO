import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/model/async_state.dart';
import '../../core/state/sync_result.dart';
import '../../data/models/account/account_model.dart';
import '../../data/models/calendar/calendar_week.dart';
import '../../data/models/course/course_model.dart';
import '../../data/models/exam/exam_model.dart';
import '../../data/models/homework/homework_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/exam_repository.dart';
import '../../data/repositories/homework_repository.dart';
import '../../data/repositories/sync_coordinator.dart';

/// 首页要展示的一屏数据。
class HomeSummary {
  const HomeSummary({
    this.profile = StudentProfile.empty,
    this.currentWeek = 0,
    this.calendar,
    this.todayCourses = const [],
    this.pendingHomework = const [],
    this.upcomingExams = const [],
    this.allCourses = const [],
    this.allHomework = const [],
    this.allExams = const [],
  });

  final StudentProfile profile;
  final int currentWeek;

  /// 校历时间轴。null = 没拿到校历（退回 7 天除法，假期期间周次会偏）。
  final TeachingCalendar? calendar;
  final List<Course> todayCourses;
  final List<Homework> pendingHomework;
  final List<ExamSchedule> upcomingExams;
  final List<Course> allCourses;
  final List<Homework> allHomework;
  final List<ExamSchedule> allExams;
}

/// 首页的状态。旧项目 MainViewModel + 各 Screen 里各自算的「今日课程/待交作业」。
class HomeController extends ChangeNotifier {
  HomeController({
    required AccountRepository accountRepository,
    required CourseRepository courseRepository,
    required HomeworkRepository homeworkRepository,
    required ExamRepository examRepository,
    required SyncCoordinator syncCoordinator,
  }) : _accountRepository = accountRepository,
       _courseRepository = courseRepository,
       _homeworkRepository = homeworkRepository,
       _examRepository = examRepository,
       _syncCoordinator = syncCoordinator {
    _bind();
  }

  final AccountRepository _accountRepository;
  final CourseRepository _courseRepository;
  final HomeworkRepository _homeworkRepository;
  final ExamRepository _examRepository;
  final SyncCoordinator _syncCoordinator;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  AsyncState<HomeSummary> _state = AsyncState<HomeSummary>.idle();
  bool _disposed = false;

  AsyncState<HomeSummary> get state => _state;

  bool get isSyncing => _syncCoordinator.isSyncing.value;

  /// 已有内容时不闪 loading，本地缓存先留在屏幕上。
  Future<void> refresh() async {
    if (_state.valueOrNull == null) {
      _setState(AsyncState<HomeSummary>.loading());
    }
    try {
      final summary = await _loadSummary();
      _setState(AsyncState<HomeSummary>.data(summary));
    } catch (error) {
      _setState(AsyncState<HomeSummary>.error(error));
    }
  }

  /// 本次登录检测到、还没进页面确认的变化。
  ValueListenable<Map<SyncModule, SyncResult>> get pendingChanges =>
      _syncCoordinator.pendingChanges;

  /// 登录后 / 下拉刷新：后台同步并刷新首页摘要。
  Future<void> syncAll() async {
    await _syncCoordinator.previewAll();
    await refresh();
  }

  /// 用户进过对应页面（已落库）后清掉那一行提示。
  void clearChange(SyncModule module) => _syncCoordinator.clearPending(module);

  /// 今日课程：先按学期过滤，再取当天的格子。
  List<Course> todayCourses(
    List<Course> courses,
    DateTime now, {
    bool isCurrentSemester = true,
  }) {
    final targetDay = now.weekday;
    return courses
        .where((course) => course.isCurrentSemester == isCurrentSemester)
        .where((course) => course.weekDay == targetDay)
        .toList()
      ..sort((a, b) => a.section.compareTo(b.section));
  }

  /// 一屏首页数据。个人信息 / 教学周都是附加信息，拿不到就退回空值，
  /// 不要因为一个附加请求把整屏打成错误态。
  Future<HomeSummary> _loadSummary() async {
    final courses = await _courseRepository.watchAll().first;
    final homework = await _homeworkRepository.watchAll().first;
    final exams = await _examRepository.watchAll().first;

    final calendar = _courseRepository.loadTeachingCalendar();
    return HomeSummary(
      profile: await _tryProfile(),
      currentWeek: calendar?.weekOf(DateTime.now()) ?? await _currentWeek(),
      calendar: calendar,
      todayCourses: todayCourses(courses, DateTime.now()),
      pendingHomework: homework
          .where((item) => !item.isSubmitted)
          .take(5)
          .toList(),
      upcomingExams: exams.take(5).toList(),
      allCourses: courses,
      allHomework: homework,
      allExams: exams,
    );
  }

  Future<StudentProfile> _tryProfile() async {
    try {
      return await _accountRepository.fetchStudentProfile();
    } catch (_) {
      return StudentProfile.empty;
    }
  }

  Future<int> _currentWeek() async {
    try {
      return await _courseRepository.refreshCurrentWeek();
    } catch (_) {
      return 0;
    }
  }

  void _bind() {
    _subscriptions.addAll([
      _courseRepository.watchAll().listen((_) => _refreshQuietly()),
      _homeworkRepository.watchAll().listen((_) => _refreshQuietly()),
      _examRepository.watchAll().listen((_) => _refreshQuietly()),
    ]);
    _syncCoordinator.isSyncing.addListener(_notify);
  }

  /// 后台数据变了但页面已有内容时不闪 loading。
  void _refreshQuietly() {
    if (_disposed || _state.isLoading) {
      return;
    }
    if (_state.valueOrNull == null) {
      unawaited(refresh());
      return;
    }
    unawaited(_reloadQuietly());
  }

  Future<void> _reloadQuietly() async {
    try {
      final summary = await _loadSummary();
      _setState(AsyncState<HomeSummary>.data(summary));
    } catch (_) {
      // 静默刷新失败就保持原样，别把已有内容换成错误态。
    }
  }

  void _setState(AsyncState<HomeSummary> next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _syncCoordinator.isSyncing.removeListener(_notify);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
