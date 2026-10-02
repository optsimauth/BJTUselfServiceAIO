import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/model/async_state.dart';
import '../../core/state/sync_result.dart';
import '../../core/storage/preferences.dart';
import '../../data/models/calendar/calendar_week.dart';
import '../../data/models/course/course_model.dart';
import '../../data/repositories/course_repository.dart';
import 'lesson_period.dart';
import 'schedule_board.dart';
import 'schedule_term.dart';
import 'schedule_weeks.dart';

/// 课表页的一屏：网格 + 没能落格的课程。
typedef CourseScheduleView = ({CourseBoard board, List<Course> unplaced});

const _emptyView = (board: <List<List<Course>>>[], unplaced: <Course>[]);

/// 课表页的状态。
///
/// 职责边界：
/// - 数据从 [CourseRepository] 来，本地库变化通过流推过来；
/// - 「看哪个学期 / 看第几周」是纯 UI 状态，存 SharedPreferences；
/// - 网格排布交给 [ScheduleBoardBuilder]，这里只负责筛。
class CourseController extends ChangeNotifier {
  CourseController({
    required CourseRepository repository,
    required AppPreferences preferences,
  }) : _repository = repository,
       _preferences = preferences,
       _term = ScheduleTerm.fromStorage(preferences.scheduleTerm) {
    _calendar = repository.loadTeachingCalendar();
    _restoreCurrentWeek();
    _rebuildView();
    _subscription = _repository.watchAll().listen(_onCoursesChanged);
  }

  final CourseRepository _repository;
  final AppPreferences _preferences;
  StreamSubscription<List<Course>>? _subscription;
  bool _disposed = false;

  AsyncState<List<Course>> _state = AsyncState<List<Course>>.idle();

  /// 最近一次同步的变化提示；页面弹过之后置空。
  final ValueNotifier<String?> syncMessage = ValueNotifier<String?>(null);
  List<Course> _courses = const [];
  CourseScheduleView _view = _emptyView;
  ScheduleTerm _term = ScheduleTerm.current;
  int _currentWeek = 0;
  TeachingCalendar? _calendar;
  int _selectedWeek = ScheduleWeeks.allWeeks;

  AsyncState<List<Course>> get state => _state;

  /// ServiceLocator 启动时恢复一次本地数据；页面进入不再重复读库。
  Future<void> hydrate() async {
    if (_disposed) return;
    _onCoursesChanged(await _repository.watchAll().first);
  }

  ScheduleTerm get term => _term;

  /// 当前是第几教学周（接口权威值）。
  int get currentWeek => _currentWeek;

  /// 正在看的教学周；[ScheduleWeeks.allWeeks] 表示不过滤。
  int get selectedWeek => _selectedWeek;

  /// 界面上显示的周次文案。
  String get selectedWeekLabel => ScheduleWeeks.labelOf(_selectedWeek);

  /// 当前视图的网格：已按学期 + 周次过滤并落格，下标 [节次-1][星期-1]。
  CourseBoard get board => _view.board;

  /// 当前视图里网格上的课一共有多少节（同一门课多个格子重复计，和界面上的色块数一致）。
  int get courseCount => ScheduleBoardQuery.courseCount(_view.board);

  /// 网格上是否一节课都没有 —— 用来区分「加载中」和「这一周真的没课」。
  bool get isBoardEmpty => ScheduleBoardQuery.isEmpty(_view.board);

  /// 拿不到格子位置的课程（只从课程平台 JSON 来的行），界面上给个提示。
  List<Course> get unplacedCourses => _view.unplaced;

  /// 正在看「全部周」。
  bool get isViewingAllWeeks => _selectedWeek <= ScheduleWeeks.allWeeks;

  /// 导出日历用的课程：当前学期视图里位置已知的课（不受周次过滤影响）。
  List<Course> get exportableCourses => _courses
      .where(
        (course) =>
            course.isPlaced &&
            _term.accepts(isCurrentSemester: course.isCurrentSemester),
      )
      .toList(growable: false);

  /// 校历时间轴；null = 没拿到（这时周次换算退回 7 天除法）。
  TeachingCalendar? get calendar => _calendar;

  /// 第 1 教学周的周一。
  ///
  /// 有校历时直接取校历里第 1 周的周一 —— 假期周不在校历里，所以**不会**
  /// 因为国庆多算两周。没校历时才从「当前第几周」反推（那期间周次是偏的）。
  DateTime firstWeekMonday([DateTime? now]) {
    final today = now ?? DateTime.now();
    final monday = TeachingCalendar.mondayOf(today);
    final week = _currentWeek > 0 ? _currentWeek : 1;
    return _calendar?.mondayOfWeek(1) ??
        monday.subtract(Duration(days: 7 * (week - 1)));
  }


  /// 此刻正在上的节次（1..8），不在课表时间内返回 null。
  int? sectionAt(DateTime now) => SchedulePeriods.currentSectionAt(now);

  /// 冷启动：先读本地的当前教学周把界面点亮，再等网络刷新。
  ///
  /// 看第几周**不持久化**：周次是「我现在想知道这周上什么」的问题，
  /// 存下来只会让用户下次打开还停在一周前。进来一律当前周，往前翻随用随翻。
  void _restoreCurrentWeek() {
    final cached = _preferences.currentWeek;
    if (cached <= 0) {
      return;
    }
    _currentWeek = cached;
    _selectedWeek = cached;
  }

  Future<void> refresh() async {
    if (_state.valueOrNull == null) {
      _state = AsyncState<List<Course>>.loading();
      notifyListeners();
    }
    try {
      _reportChanges(await _repository.sync());
    } catch (error) {
      if (_disposed) return;
      _state = AsyncState<List<Course>>.error(error);
      _rebuildView();
      notifyListeners();
      return;
    }
    final week = await _refreshCurrentWeek();
    if (_disposed) return;
    _currentWeek = week;
    _state = AsyncState<List<Course>>.data(_courses);
    unawaited(_refreshCalendar());
    _rebuildView();
    notifyListeners();
  }

  /// 后台刷校历。校历决定「第几周对应哪几天」，假期周就靠它 —— 拿不到就沿用缓存。
  Future<void> _refreshCalendar() async {
    try {
      final calendar = await _repository.refreshTeachingCalendar();
      if (_disposed || calendar == null) return;
      _calendar = calendar;
      // 校历比接口的 weekCode 权威：接口给的是「第几周」，校历给的是「第几周 = 哪几天」。
      final week = calendar.weekOf(DateTime.now());
      if (week != null && week != _currentWeek) {
        _currentWeek = week;
        _rebuildView();
        notifyListeners();
      }
    } catch (_) {
      // 校历只是显示精度，拿不到不影响看课表。
    }
  }

  /// 当前教学周拿不到就沿用上次那个，不要因为一个附加请求把整屏打成错误态。
  Future<int> _refreshCurrentWeek() async {
    try {
      return await _repository.refreshCurrentWeek();
    } catch (_) {
      return _currentWeek;
    }
  }

  void selectTerm(ScheduleTerm value) {
    if (_term == value) return;
    _term = value;
    _rebuildView();
    notifyListeners();
    _preferences.setScheduleTerm(value.storageValue);
  }

  /// 切换周次。0 表示「全部周」。
  Future<void> selectWeek(int week) async {
    final clamped = week < ScheduleWeeks.allWeeks
        ? ScheduleWeeks.allWeeks
        : week;
    if (_selectedWeek == clamped) return;
    _selectedWeek = clamped;
    _rebuildView();
    notifyListeners();
  }

  /// 周次步进。从「全部周」出发时先跳到当前周（没有则第 1 周）。
  Future<void> stepWeek(int delta) {
    final from = _selectedWeek <= ScheduleWeeks.allWeeks
        ? (_currentWeek > 0 ? _currentWeek : 1)
        : _selectedWeek;
    final next = (from + delta).clamp(1, ScheduleWeeks.maxWeek);
    return selectWeek(next);
  }

  /// 进入页面时对齐当前周：周次不持久化，进来看到的永远是这周。
  void showCurrentWeek() {
    if (_currentWeek <= 0 || _selectedWeek == _currentWeek) return;
    selectWeek(_currentWeek);
  }

  /// 回到当前教学周；已经在当前周就切到「全部周」，符合「再点一次取消筛选」的直觉。
  Future<void> resetWeek() {
    if (_currentWeek > 0 && _selectedWeek != _currentWeek) {
      return selectWeek(_currentWeek);
    }
    return selectWeek(ScheduleWeeks.allWeeks);
  }

  Future<String> downloadTeachingCalendar(Course course) =>
      _repository.downloadTeachingCalendar(course: course);

  void _rebuildView() {
    final unplaced = <Course>[];
    final board = ScheduleBoardBuilder.buildFiltered(
      courses: _courses,
      isCurrentSemester: (course) =>
          _term.matches(isCurrentSemester: course.isCurrentSemester),
      week: _selectedWeek,
      unplaced: unplaced,
    );
    _view = (board: board, unplaced: unplaced);
  }

  void _onCoursesChanged(List<Course> courses) {
    _courses = courses;
    if (_state.isLoading) {
      return;
    }
    _state = AsyncState<List<Course>>.data(courses);
    _rebuildView();
    notifyListeners();
  }

  /// 有变化才提示；没变化保持安静。
  void _reportChanges(SyncResult result) {
    if (!result.hasChanges) {
      return;
    }
    syncMessage.value = result.message;
  }

  @override
  void dispose() {
    _disposed = true;
    syncMessage.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
