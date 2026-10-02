import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/model/async_state.dart';
import '../../core/state/sync_result.dart';
import '../../data/models/exam/exam_model.dart';
import '../../data/repositories/exam_repository.dart';
import 'exam_timeline.dart';

/// 考试安排页的状态。
///
/// 拉数据交给 Repository，这里管「现在在看什么」：选了哪个考试类型、
/// 按 [now] 分组、下一场是谁。倒计时随时间自己走，所以 [now] 由页面注入。
class ExamController extends ChangeNotifier {
  ExamController({required ExamRepository repository})
    : _repository = repository {
    _subscription = _repository.watchAll().listen(_onChanged);
  }

  final ExamRepository _repository;
  StreamSubscription<List<ExamSchedule>>? _subscription;

  AsyncState<List<ExamSchedule>> _state = AsyncState<List<ExamSchedule>>.idle();

  /// 最近一次同步的变化提示；页面弹过之后置空。
  final ValueNotifier<String?> syncMessage = ValueNotifier<String?>(null);
  final ScrollController scrollController = ScrollController();
  bool _disposed = false;

  AsyncState<List<ExamSchedule>> get state => _state;

  /// ServiceLocator 启动时恢复一次本地数据；页面进入不再重复读库。
  Future<void> hydrate() async {
    if (_disposed) return;
    _onChanged(await _repository.watchAll().first);
  }

  /// 最近一次从本地读到的数据。
  ///
  /// 单独存一份而不是从 [state] 里取，是因为 [refresh] 会先把 state 置成
  /// loading，那时 `state.valueOrNull` 已经是 null 了 —— 直接从 state 取会把
  /// 刚同步回来的数据清空，界面上闪一下空列表。
  List<ExamSchedule> _exams = const [];

  ExamFilter _filter = const ExamFilter.all();

  ExamFilter get filter => _filter;

  /// 当前筛选下的可用筛选项（全部 + 表里出现过的类型）。
  List<ExamFilter> get availableFilters =>
      ExamFilter.withTypes(_exams.map((exam) => exam.examType));

  /// 排好序的条目。原始列表按数据库顺序返回，直接用会看着很乱。
  List<ExamEntry> entries() => ExamTimeline.entriesOf(_exams);

  /// 按阶段分好组的展示数据。
  List<ExamGroup> groups({DateTime? now}) => ExamTimeline.groupsOf(
    entries(),
    now: now ?? DateTime.now(),
    filter: _filter,
  );

  /// 下一场还没考的考试；没有了返回 null（例如考完了或全都没给日期）。
  ///
  /// 跟着当前筛选走：筛了「期末」就别把「期中」塞到顶上，
  /// 否则卡片和下面的列表会互相打架。
  ExamEntry? nextExam({DateTime? now}) => ExamTimeline.nextUpcoming(
    entries().where(_filter.matches).toList(growable: false),
    now: now ?? DateTime.now(),
  );

  /// 重新从平台拉一次。失败会写进 [state]。
  Future<void> refresh() async {
    if (_state.valueOrNull == null) {
      _state = AsyncState<List<ExamSchedule>>.loading();
      notifyListeners();
    }
    try {
      _reportChanges(await _repository.sync());
    } catch (error) {
      if (_disposed) return;
      _state = AsyncState<List<ExamSchedule>>.error(error);
      notifyListeners();
      return;
    }
    if (_disposed) return;
    _state = AsyncState<List<ExamSchedule>>.data(_exams);
    notifyListeners();
  }

  void selectFilter(ExamFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// 回到「全部」。空态里给的快捷入口。
  void selectFilterAll() => selectFilter(const ExamFilter.all());

  /// 本地库有变动。数据先落到 [_exams]，state 只在没在刷新时才重建。
  void _onChanged(List<ExamSchedule> exams) {
    _exams = exams;
    // 正在刷新时保持 loading，否则会闪一下「空页面」。
    if (_state.isLoading) {
      return;
    }
    _state = AsyncState<List<ExamSchedule>>.data(_exams);
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
    scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
