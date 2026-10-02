import 'package:flutter/foundation.dart';

import '../../core/model/async_state.dart';
import '../../data/models/classroom/classroom_model.dart';
import '../../data/repositories/classroom_repository.dart';
import '../course/lesson_period.dart';
import 'classroom_filter.dart';
import 'classroom_room_view.dart';

/// 教室占用课表页的状态。
///
/// 职责边界：拉数据交给 Repository，这里只管「现在在看什么」——
/// 哪一周、聚焦星期几、搜哪个教室、按什么口径筛、按什么排。
///
/// 两个数据源各有一份状态，因为它们的失败后果不一样：
/// 主源（教务整周占用）挂了整页没内容，副源（此刻人数）挂了只是少一条信息，
/// 所以后者失败绝不能把页面打成错误态。
class ClassroomController extends ChangeNotifier {
  /// [clock] 在这里只读一次 —— 「今天」和默认聚焦那天必须是同一个时刻，
  /// 分两次读正好跨过午夜的话，进来就落在一个自相矛盾的星期上。
  ClassroomController({
    required ClassroomRepository repository,
    required ClassroomBuilding building,
    DateTime Function()? clock,
  }) : this._(
         repository: repository,
         building: building,
         clock: clock ?? DateTime.now,
         now: (clock ?? DateTime.now)(),
       );

  ClassroomController._({
    required ClassroomRepository repository,
    required ClassroomBuilding building,
    required DateTime Function() clock,
    required DateTime now,
  }) : _repository = repository,
       building = building,
       _clock = clock,
       todayWeekday = ClassroomWeekStatus.weekdayIndexOf(now) + 1,
       _weekday = ClassroomWeekStatus.weekdayIndexOf(now) + 1;

  final ClassroomRepository _repository;
  final ClassroomBuilding building;
  final DateTime Function() _clock;

  /// 「今天」是几号星期。它不跟着筛选走 —— 用户切到周三不代表今天变成了周三。
  final int todayWeekday;

  bool _disposed = false;

  AsyncState<ClassroomWeekStatus> _statusState =
      AsyncState<ClassroomWeekStatus>.idle();
  AsyncState<BuildingInfo> _peopleState = AsyncState<BuildingInfo>.idle();
  Uri? _entryUri;
  int _currentWeek = 1;
  int _week = 1;
  int _weekday;
  ClassroomFilter _filter = ClassroomFilter.initial;

  /// 筛完排完的结果。每次状态变化重算一次并留在这里：
  /// 界面每帧都要读它，重算一次是 O(房间数)，缓存住是 O(1)。
  List<ClassroomRoomView>? _roomsCache;

  AsyncState<ClassroomWeekStatus> get statusState => _statusState;

  /// 此刻人数（副源）。这栋楼不在服务覆盖范围内时一直是 idle。
  AsyncState<BuildingInfo> get peopleState => _peopleState;

  ClassroomFilter get filter => _filter;

  ClassroomWeekStatus? get status => _statusState.valueOrNull;

  DateTime get now => _clock();

  /// 学校当前的教学周（入口页 `zc`）。
  int get currentWeek => _currentWeek;

  /// 正在看的教学周。
  int get week => _week;

  /// 正被聚焦的星期（1 = 周一）。
  int get weekday => _weekday;

  /// 看的就是本周 —— 只有这时「今天」才有意义，高亮和 `此刻空闲` 才成立。
  bool get isCurrentWeek => _week == _currentWeek;

  /// 此刻是第几节（1..8）。不在作息时间内是 null。
  int? get currentSection => SchedulePeriods.currentSectionAt(_clock());

  /// 楼里一共几间教室（不过滤）。
  int get totalRooms => status?.rooms.length ?? 0;

  /// 第三方服务覆盖这栋楼吗。不覆盖就不发那次必然失败的请求。
  bool get supportsPeopleCount =>
      ClassroomBuildings.peopleSourceNames.contains(building.name);

  /// 有效期那句话（两个日期都拿到才有）。
  String? get effectivePeriod =>
      _peopleState.valueOrNull?.effectivePeriodText;

  bool get hasFilters => _filter.hasFilters;

  /// 正在看的那一天，这栋楼有几间一节没排。
  int get freeRoomCountOnWeekday => status?.freeCountAt(_weekday) ?? 0;

  /// 筛完排完的列表。界面直接渲染这个。
  List<ClassroomRoomView> rooms() => _roomsCache ??= _filter.apply(
    _merged(),
    weekday: _weekday,
    section: currentSection,
  );

  /// 筛选后剩几间。
  int get visibleCount => rooms().length;

  /// 进页面 / 下拉刷新。两个源一起发，谁先回来谁先上屏。
  Future<void> load() async {
    if (_statusState.isLoading) return;
    _statusState = AsyncState<ClassroomWeekStatus>.loading();
    if (supportsPeopleCount) {
      _peopleState = AsyncState<BuildingInfo>.loading();
    } else {
      _peopleState = AsyncState<BuildingInfo>.idle();
    }
    _changed();

    // 人数源跟周次无关，单独发，主源查询期间它可以自己回来。
    final peopleFuture = supportsPeopleCount
        ? _repository.fetchBuilding(buildingName: building.name)
        : null;

    // 入口页只为拿当前周号 + 一条可复用的地址。切周之后只发 room_view，不再走它。
    ClassroomWeekStatus? status;
    Object? statusError;
    try {
      final entry = await _repository.openEntry();
      if (_disposed) return;
      _entryUri = entry.entryUri;
      _currentWeek = entry.week;
      _week = entry.week;
      status = await _repository.fetchWeekStatus(
        entryUri: entry.entryUri,
        week: entry.week,
        buildingId: building.id,
      );
    } catch (error) {
      statusError = error;
    }
    if (_disposed) return;
    _statusState = status != null
        ? AsyncState<ClassroomWeekStatus>.data(status)
        : AsyncState<ClassroomWeekStatus>.error(
            statusError ?? StateError('教室占用查询失败'),
          );
    _changed();

    if (peopleFuture == null) return;
    try {
      final people = await peopleFuture;
      if (_disposed) return;
      _peopleState = AsyncState<BuildingInfo>.data(people);
    } catch (error) {
      if (_disposed) return;
      // 人数读不到不影响课表，只是每间教室少一条信息。
      _peopleState = AsyncState<BuildingInfo>.error(error);
    }
    _changed();
  }

  /// 切周。只重查主源 —— 此刻人数跟周次没关系，没必要为一次翻页重发它。
  Future<void> selectWeek(int week) async {
    final target = ClassroomWeeks.clamp(week);
    if (target == _week || _statusState.isLoading) return;
    final entryUri = _entryUri;
    if (entryUri == null) {
      await load();
      return;
    }
    _week = target;
    _statusState = AsyncState<ClassroomWeekStatus>.loading();
    _changed();
    try {
      final status = await _repository.fetchWeekStatus(
        entryUri: entryUri,
        week: target,
        buildingId: building.id,
      );
      if (_disposed) return;
      _statusState = AsyncState<ClassroomWeekStatus>.data(status);
    } catch (error) {
      if (_disposed) return;
      // 切周失败保留旧列表：这一周看不成，上一周的表总比空白强。
      _statusState = AsyncState<ClassroomWeekStatus>.error(error);
    }
    _changed();
  }

  Future<void> nudgeWeek(int offset) => selectWeek(_week + offset);

  /// 回到本周。
  Future<void> goCurrentWeek() => selectWeek(_currentWeek);

  void setWeekday(int weekday) {
    final target = weekday < 1
        ? 1
        : (weekday > ClassroomStatus.weekdayCount
              ? ClassroomStatus.weekdayCount
              : weekday);
    if (target == _weekday) return;
    _weekday = target;
    _changed();
  }

  void setFreeFilter(ClassroomFreeFilter value) {
    if (_filter.freeFilter == value) return;
    _filter = _filter.withFreeFilter(value);
    _changed();
  }

  void setMaxUsed(int? value) {
    if (_filter.maxUsed == value) return;
    _filter = _filter.withMaxUsed(value);
    _changed();
  }

  void setSortKey(ClassroomSortKey key) {
    if (_filter.sortKey == key) return;
    _filter = _filter.withSortKey(key);
    _changed();
  }

  void toggleSortOrder() {
    _filter = _filter.toggleDescending();
    _changed();
  }

  void search(String keyword) {
    if (_filter.query == keyword) return;
    _filter = _filter.withQuery(keyword);
    _changed();
  }

  /// 清掉关键词、空闲口径和人数上限。排序偏好留着 —— 排序是口味，不是筛选。
  void clearFilter() {
    if (!_filter.hasFilters) return;
    _filter = _filter.withoutFilters();
    _changed();
  }

  /// 两个数据源合成的完整列表（还没筛）。
  List<ClassroomRoomView> _merged() => ClassroomRooms.merge(
    status: status,
    capacities: _peopleState.valueOrNull?.classrooms ?? const [],
  );

  /// 作废缓存再通知。列表顺序是筛选结果的一部分，必须跟着状态一起重算。
  void _changed() {
    _roomsCache = null;
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
