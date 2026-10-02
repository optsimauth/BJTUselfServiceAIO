import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/model/async_state.dart';
import '../../core/state/sync_result.dart';
import '../../data/models/grade/grade_model.dart';
import '../../data/repositories/grade_repository.dart';
import 'grade_filter.dart';
import 'grade_math.dart';
import 'grade_sort.dart';
import 'grade_view.dart';

/// 成绩页的状态。
///
/// 职责边界：数据（下载 + 入库）交给 Repository，这里管「现在在看什么」——
/// 学期筛选、排序、自选课程勾选，以及跟着这三样走的加权平均分。
///
/// 勾选记录按「课程名|教师|学年|学期」这个复合键存（旧代码按数据库主键，
/// 但合并后的成绩主键每次同步都可能变，键换了勾选就丢了；课程的这四样
/// 在成绩表里是稳定的）。没有学号（页面没解析到）时勾选只在内存里生效。
class GradeController extends ChangeNotifier {
  GradeController({required GradeRepository repository, String studentId = ''})
    : _repository = repository,
      _studentId = studentId.trim() {
    _subscription = _repository.watchAll().listen(_onGradesChanged);
  }

  final GradeRepository _repository;
  final String _studentId;
  StreamSubscription<List<Grade>>? _subscription;
  bool _disposed = false;

  AsyncState<List<Grade>> _state = AsyncState<List<Grade>>.idle();

  /// 最近一次同步的变化提示；页面弹过之后置空。
  final ValueNotifier<String?> syncMessage = ValueNotifier<String?>(null);
  final ScrollController scrollController = ScrollController();
  List<Grade> _grades = const [];
  GradeSemesterFilter _filter = const GradeSemesterFilter();
  GradeSortOrder _sort = GradeSortOrder.original;
  Set<String> _selectedKeys = <String>{};
  bool _saving = false;

  AsyncState<List<Grade>> get state => _state;

  /// ServiceLocator 启动时恢复一次本地数据；页面进入不再重复读库。
  Future<void> hydrate() async {
    if (_disposed) return;
    _onGradesChanged(await _repository.watchAll().first);
  }

  List<Grade> get grades => _grades;

  GradeSemesterFilter get filter => _filter;

  GradeSortOrder get sort => _sort;

  int get selectedCount => _selectedKeys.length;

  /// 勾选记录正在写盘（测试里用来等持久化落定）。
  bool get isSaving => _saving;

  bool get hasStudent => _studentId.isNotEmpty;

  /// 界面上出现过的学期，展示顺序 = 成绩顺序（第一个出现的在前）。
  List<String> get semesterOptions {
    final seen = <String>[];
    final set = <String>{};
    for (final grade in _grades) {
      if (set.add(grade.tag)) {
        seen.add(grade.tag);
      }
    }
    return seen;
  }

  /// 一条成绩的勾选键。courseName / teacher / year / tag 任一个含 `|` 也
  /// 能安全拼回去 —— 键只在 [baseKeyParts] 之间拆，不直接劈字符串。
  String selectionKeyOf(Grade grade) => baseKey(
    grade.courseName,
    grade.courseTeacher,
    grade.courseYear,
    grade.tag,
  );

  static String baseKey(
    String name,
    String teacher,
    String year,
    String semester,
  ) => '$name\u0000$teacher\u0000$year\u0000$semester';

  Future<void> refresh() async {
    if (_state.valueOrNull == null) {
      _state = AsyncState<List<Grade>>.loading();
      notifyListeners();
    }
    _reloadSelections();
    try {
      _reportChanges(await _repository.sync());
    } catch (error) {
      if (_disposed) {
        return;
      }
      _state = AsyncState<List<Grade>>.error(error);
      notifyListeners();
      return;
    }
    if (_disposed) {
      return;
    }
    if (hasStudent) {
      unawaited(_pruneStaleSelections());
    }
    _state = AsyncState<List<Grade>>.data(_grades);
    notifyListeners();
  }

  /// 筛选 + 排序 + 勾选标记，页面直接拿来画列表。
  List<GradeView> visibleViews() {
    final filtered = _filter.isAll
        ? _grades
        : _grades.where(_filter.matches).toList(growable: false);
    final sorted = _sort.apply(filtered);
    return [
      for (final grade in sorted)
        GradeView(
          grade: grade,
          selected: _selectedKeys.contains(selectionKeyOf(grade)),
        ),
    ];
  }

  /// 加权平均分。[selectionMode] 为真时只算勾选过的课，否则算当前筛选范围。
  GradeGpa gpa({required bool selectionMode}) {
    if (selectionMode) {
      return gpaOf(
        _grades.where((grade) => _selectedKeys.contains(selectionKeyOf(grade))),
      );
    }
    return gpaOf(_grades.where(_filter.matches));
  }

  void selectFilter(GradeSemesterFilter filter) {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    notifyListeners();
  }

  /// 回到全部学期。筛选空态里给的快捷入口。
  void clearFilter() => selectFilter(const GradeSemesterFilter());

  void cycleSort() {
    _sort = switch (_sort) {
      GradeSortOrder.original => GradeSortOrder.ascending,
      GradeSortOrder.ascending => GradeSortOrder.descending,
      GradeSortOrder.descending => GradeSortOrder.original,
    };
    notifyListeners();
  }

  void toggleSelected(Grade grade) {
    final key = selectionKeyOf(grade);
    if (!_selectedKeys.add(key)) {
      _selectedKeys.remove(key);
    }
    notifyListeners();
    unawaited(_persistSelections());
  }

  /// 全选 = 勾住当前筛选下看到的那批（旧「全选」同款口径）。
  void selectAllVisible() {
    _selectedKeys.addAll(
      visibleViews().map((view) => selectionKeyOf(view.grade)),
    );
    notifyListeners();
    unawaited(_persistSelections());
  }

  /// 清空当前筛选出的这些学期的勾选（旧「清空本学期」）。
  void deselectFilteredSemesters() {
    final target = _filter.semesters;
    if (target.isEmpty) {
      return;
    }
    _selectedKeys.removeWhere((key) {
      final parts = key.split('\u0000');
      return parts.length >= 4 && target.contains(parts[3]);
    });
    notifyListeners();
    unawaited(_persistSelections());
  }

  /// 全部清空（勾选 + 存储）。
  Future<void> clearSelections() async {
    _selectedKeys = <String>{};
    notifyListeners();
    await _persistSelections();
  }

  /// 成绩单下载，返回「保存到哪里」；失败直接抛，由页面弹错误框。
  Future<String> downloadReport({required bool english}) =>
      _repository.downloadReport(english: english);

  Future<void> _reloadSelections() async {
    if (!hasStudent) {
      _selectedKeys = <String>{};
      return;
    }
    _selectedKeys = _repository
        .loadSelections(_studentId)
        .map(_selectionKeyOfRecord)
        .whereType<String>()
        .toSet();
  }

  /// 同步回来之后，勾选记录里已经不在成绩表里的（补考改名 / 退课等）清掉，
  /// 免得「全部清空」之外还留着没人看得见的脏数据。
  Future<void> _pruneStaleSelections() async {
    final valid = _grades.map(selectionKeyOf).toSet();
    final pruned = _selectedKeys.where(valid.contains).toSet();
    if (setEquals(pruned, _selectedKeys)) {
      return;
    }
    _selectedKeys = pruned;
    notifyListeners();
    await _persistSelections();
  }

  Future<void> _persistSelections() async {
    if (!hasStudent) {
      return;
    }
    _saving = true;
    notifyListeners();
    final kept = _selectedKeys;
    final records = [
      for (final grade in _grades)
        if (kept.contains(selectionKeyOf(grade)))
          GradeSelectionRecord(
            courseName: grade.courseName,
            courseTeacher: grade.courseTeacher,
            courseYear: grade.courseYear,
            semester: grade.tag,
            lastKnownScore: grade.courseScore,
            lastKnownCredits: grade.courseCredits,
          ),
    ];
    await _repository.saveSelections(_studentId, records);
    if (_disposed) {
      return;
    }
    _saving = false;
    notifyListeners();
  }

  static String? _selectionKeyOfRecord(GradeSelectionRecord record) {
    final key = baseKey(
      record.courseName,
      record.courseTeacher,
      record.courseYear,
      record.semester,
    );
    return key.isEmpty ? null : key;
  }

  void _onGradesChanged(List<Grade> grades) {
    _grades = grades;
    if (_state.isLoading) {
      return;
    }
    _state = AsyncState<List<Grade>>.data(_grades);
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
