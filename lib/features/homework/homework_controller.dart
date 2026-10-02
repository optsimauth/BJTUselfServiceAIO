import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/model/async_state.dart';
import '../../core/state/sync_result.dart';
import '../../data/models/homework/homework_model.dart';
import '../../data/repositories/homework_repository.dart';
import 'homework_timeline.dart';

/// 作业页的状态。
///
/// 职责边界：拉数据交给 Repository，这里只管「现在在看什么」——
/// 筛了哪些类型 / 哪门课、按什么分组、下一件要交的是哪个。
class HomeworkController extends ChangeNotifier {
  HomeworkController({required HomeworkRepository repository})
    : _repository = repository {
    _subscription = _repository.watchAll().listen(_onChanged);
  }

  final HomeworkRepository _repository;
  StreamSubscription<List<Homework>>? _subscription;
  bool _disposed = false;

  AsyncState<List<Homework>> _state = AsyncState<List<Homework>>.idle();

  /// 最近一次同步的变化提示；页面弹过之后置空。
  final ValueNotifier<String?> syncMessage = ValueNotifier<String?>(null);
  final ScrollController _scrollController = ScrollController();

  ScrollController get listScrollController => _scrollController;

  /// 最近一次从本地读到的数据。
  ///
  /// 单独存一份而不是从 [state] 里取，是因为 [refresh] 会先把 state 置成
  /// loading，那时 `state.valueOrNull` 已经是 null 了 —— 直接从 state 取会把
  /// 刚同步回来的数据清空，界面上闪一下空列表。
  List<Homework> _homework = const [];

  HomeworkFilter _filter = const HomeworkFilter();

  AsyncState<List<Homework>> get state => _state;

  HomeworkFilter get filter => _filter;

  /// ServiceLocator 启动时恢复一次本地数据；页面进入不再重复读库。
  Future<void> hydrate() async {
    if (_disposed) return;
    _onChanged(await _repository.watchAll().first);
  }

  /// 作业类型是平台定的三个固定值（0/1/2），所以这里是枚举而不是开放集合。
  List<HomeworkType> get availableTypes => HomeworkType.values;

  /// 课程名来自数据，去重后按作业数从多到少排 —— 选课筛选用得最多的排前面。
  List<String> get availableCourses {
    final counts = <String, int>{};
    for (final item in _homework) {
      if (item.courseName.isEmpty) continue;
      counts[item.courseName] = (counts[item.courseName] ?? 0) + 1;
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return names;
  }

  /// 排好序的条目。
  List<HomeworkEntry> entries() => HomeworkTimeline.entriesOf(_homework);

  /// 按阶段分好组的展示数据。
  List<HomeworkGroup> groups({DateTime? now}) => HomeworkTimeline.groupsOf(
    entries(),
    now: now ?? DateTime.now(),
    filter: _filter,
  );

  /// 下一件要交的作业；全交了返回 null（界面退化成统计卡片）。
  HomeworkEntry? nextTodo() => HomeworkTimeline.nextTodo(entries());

  /// 当前筛选下还剩几件没交 —— 顶部那张卡片的主数字。
  int pendingCount({DateTime? now}) => HomeworkTimeline.pendingCount(
    entries().where(_filter.matches).toList(growable: false),
  );

  /// 当前筛选下还剩几件「48 小时内截止」—— 卡片上那句提醒。
  int urgentCount({DateTime? now}) => HomeworkTimeline.urgentCount(
    entries().where(_filter.matches).toList(growable: false),
    now: now ?? DateTime.now(),
  );

  /// 一共同步回来多少条（不看筛选）。空态判断用它。
  int totalCount() => _homework.length;

  /// 当前筛选下能看到几条。
  ///
  /// 顶部卡片的「共 N 项」必须用这个：筛选到「大学物理」却报总数 8，
  /// 会和下面那份只列了一门的列表自相矛盾。
  int visibleCount() => entries().where(_filter.matches).length;

  Future<void> refresh() async {
    if (_state.valueOrNull == null) {
      _state = AsyncState<List<Homework>>.loading();
      notifyListeners();
    }
    try {
      _reportChanges(await _repository.sync());
    } catch (error) {
      if (_disposed) return;
      _state = AsyncState<List<Homework>>.error(error);
      notifyListeners();
      return;
    }
    if (_disposed) return;
    _state = AsyncState<List<Homework>>.data(_homework);
    notifyListeners();
  }

  void toggleType(HomeworkType type) {
    _filter = _filter.toggleType(type);
    notifyListeners();
  }

  /// 只放开类型这一个维度，课程和「仅待交」保持不变 ——
  /// 筛选条上那颗「全部类型」就干这个。
  void clearType() {
    if (_filter.type == null) return;
    _filter = _filter.copyWith(clearType: true);
    notifyListeners();
  }

  void toggleCourse(String courseName) {
    _filter = _filter.toggleCourse(courseName);
    notifyListeners();
  }

  void toggleOnlyPending() {
    _filter = _filter.copyWith(onlyPending: !_filter.onlyPending);
    notifyListeners();
  }

  void clearFilter() {
    if (_filter.isDefault) return;
    _filter = const HomeworkFilter();
    notifyListeners();
  }

  /// 交作业。成功后再同步一次，让列表里的「已提交」立刻变过来。
  Future<String> upload(Homework homework, {String content = ''}) async {
    final receipt = await _repository.upload(homework, content: content);
    if (!_disposed) {
      await refresh();
    }
    return receipt;
  }

  Future<HomeworkDetail> detailOf(Homework homework) =>
      _repository.fetchDetail(homework);

  Future<String> downloadAttachment(Homework note, HomeworkAttachment file) =>
      _repository.downloadAttachment(note, file);

  void _onChanged(List<Homework> homework) {
    _homework = homework;
    // 正在刷新时保持 loading，否则会闪一下「空页面」。
    if (_state.isLoading) return;
    _state = AsyncState<List<Homework>>.data(_homework);
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
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
