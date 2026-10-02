import 'package:flutter/foundation.dart';

import '../../data/models/homework/homework_model.dart';
import 'homework_timing.dart';

export 'homework_timing.dart' show HomeworkTiming, HomeworkUrgency;

/// 一条作业 + 拆好的时间信息。界面上直接用这个，不再碰自由文本。
@immutable
class HomeworkEntry {
  HomeworkEntry({required this.homework})
    : timing = HomeworkTiming.parse(
        endTime: homework.endTime,
        openDate: homework.openDate,
      );

  final Homework homework;
  final HomeworkTiming timing;

  String get courseName => homework.courseName;

  String get title => homework.title;

  /// 学生要动手的那一批：没交、也没批改。
  bool get needsAction => homework.needsAction;

  HomeworkStage get stage => needsAction
      ? HomeworkStage.todo
      : homework.isGraded
      ? HomeworkStage.graded
      : HomeworkStage.submitted;

  /// 排序键：知道截止时间的排前面，同组里早截止的在前。
  DateTime? get deadline => timing.deadline;
}

/// 作业所处的阶段。分组和图标都由它决定。
enum HomeworkStage {
  /// 还没交（不论有没有过期）。
  todo,

  /// 交了，等老师批。
  submitted,

  /// 已经批改，能看分了。
  graded;

  String get label => switch (this) {
    HomeworkStage.todo => '待提交',
    HomeworkStage.submitted => '已提交',
    HomeworkStage.graded => '已批改',
  };
}

/// 作业列表的组织方式：按阶段分组 + 按截止时间排序。
///
/// 学生打开这页只想知道「我还有什么没交」，所以未交的永远排在最前面；
/// 组内按截止时间从早到晚，没给截止时间的沉底。
abstract final class HomeworkTimeline {
  static const Map<HomeworkStage, String> groupTitles = {
    HomeworkStage.todo: '待提交',
    HomeworkStage.submitted: '已提交',
    HomeworkStage.graded: '已批改',
  };

  static const List<HomeworkStage> groupOrder = [
    HomeworkStage.todo,
    HomeworkStage.submitted,
    HomeworkStage.graded,
  ];

  static List<HomeworkEntry> entriesOf(Iterable<Homework> homework) {
    final entries = [
      for (final item in homework) HomeworkEntry(homework: item),
    ];
    entries.sort(compareEntries);
    return entries;
  }

  /// 三级排序：阶段 -> 截止时间 -> 课程名。
  /// 课程名兜底，保证每次刷新顺序一致。
  static int compareEntries(HomeworkEntry a, HomeworkEntry b) {
    final byStage = groupOrder
        .indexOf(a.stage)
        .compareTo(groupOrder.indexOf(b.stage));
    if (byStage != 0) return byStage;

    final byDeadline = _compareNullable(a.deadline, b.deadline);
    if (byDeadline != 0) return byDeadline;

    final byCourse = a.courseName.compareTo(b.courseName);
    if (byCourse != 0) return byCourse;
    return a.title.compareTo(b.title);
  }

  /// null 排最后。
  static int _compareNullable<T extends Object>(T? a, T? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return (a as Comparable<Object>).compareTo(b);
  }

  static List<HomeworkGroup> groupsOf(
    List<HomeworkEntry> entries, {
    required DateTime now,
    HomeworkFilter filter = const HomeworkFilter(),
  }) {
    final buckets = {for (final stage in groupOrder) stage: <HomeworkEntry>[]};
    for (final entry in entries) {
      if (!filter.matches(entry)) continue;
      buckets[entry.stage]!.add(entry);
    }
    return [
      for (final stage in groupOrder)
        if (buckets[stage]!.isNotEmpty)
          HomeworkGroup(stage: stage, entries: buckets[stage]!),
    ];
  }

  /// 下一件要做的事：还没交的那批里截止最早的一个。
  ///
  /// [entries] 已经按截止时间排好序了，所以取第一个待交的就是答案 ——
  /// 逾期的自然排在最前，不需要在这里再判一遍紧迫度。
  static HomeworkEntry? nextTodo(List<HomeworkEntry> entries) {
    for (final entry in entries) {
      if (entry.needsAction) return entry;
    }
    return null;
  }

  /// 还没交的总数 —— 顶部的「待办 N 项」用它。
  static int pendingCount(List<HomeworkEntry> entries) =>
      entries.where((entry) => entry.needsAction).length;

  /// 还没交、且 48 小时内截止的件数。顶部卡片那句「其中 N 项快截止」用它。
  ///
  /// 已截止的不算 —— 那已经是另一件事（该补交或者放弃），不该再算作「快到了」。
  static int urgentCount(
    List<HomeworkEntry> entries, {
    required DateTime now,
  }) => entries
      .where(
        (entry) =>
            entry.needsAction &&
            entry.timing.urgencyAt(now) == HomeworkUrgency.soon,
      )
      .length;
}

/// 一个阶段下的作业。空分组不入列。
@immutable
class HomeworkGroup {
  const HomeworkGroup({required this.stage, required this.entries});

  final HomeworkStage stage;
  final List<HomeworkEntry> entries;

  String get title => HomeworkTimeline.groupTitles[stage] ?? '其它';

  int get count => entries.length;
}

/// 作业筛选。三个维度可叠加，跟考试那边一样用一个不可变值对象。
@immutable
class HomeworkFilter {
  const HomeworkFilter({this.type, this.courseName, this.onlyPending = false});

  /// null 表示不限类型（作业 / 课程设计 / 实验报告）。
  final HomeworkType? type;

  /// null 表示不限课程。
  final String? courseName;

  /// 只看待交。
  final bool onlyPending;

  bool get isDefault => type == null && courseName == null && !onlyPending;

  bool get hasCourse => courseName != null;

  String get label => courseName ?? '全部课程';

  bool matches(HomeworkEntry entry) {
    if (type != null && entry.homework.homeworkType != type) return false;
    if (courseName != null && entry.courseName != courseName) return false;
    if (onlyPending && !entry.needsAction) return false;
    return true;
  }

  HomeworkFilter copyWith({
    HomeworkType? type,
    bool clearType = false,
    String? courseName,
    bool clearCourse = false,
    bool? onlyPending,
  }) => HomeworkFilter(
    type: clearType ? null : type ?? this.type,
    courseName: clearCourse ? null : courseName ?? this.courseName,
    onlyPending: onlyPending ?? this.onlyPending,
  );

  /// 换类型是二选一：再点一次同一个就取消。
  HomeworkFilter toggleType(HomeworkType value) =>
      type == value ? copyWith(clearType: true) : copyWith(type: value);

  /// 课程同理。
  HomeworkFilter toggleCourse(String value) => courseName == value
      ? copyWith(clearCourse: true)
      : copyWith(courseName: value);

  @override
  bool operator ==(Object other) =>
      other is HomeworkFilter &&
      other.type == type &&
      other.courseName == courseName &&
      other.onlyPending == onlyPending;

  @override
  int get hashCode => Object.hash(type, courseName, onlyPending);

  @override
  String toString() =>
      'HomeworkFilter(type: $type, course: $courseName, onlyPending: $onlyPending)';
}
