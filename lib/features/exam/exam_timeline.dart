import 'package:flutter/foundation.dart';

import '../../data/models/exam/exam_model.dart';
import 'exam_timing.dart';

export 'exam_timing.dart' show ExamPhase, ExamTiming;

/// 一条考试 + 拆好的时间信息。界面上直接用这个，不再碰自由文本。
@immutable
class ExamEntry {
  const ExamEntry({required this.exam, required this.timing});

  final ExamSchedule exam;
  final ExamTiming timing;

  String get courseName => exam.courseName;

  /// 阶段跟着 [now] 变，界面上不用自己判断。
  ExamPhase phaseAt(DateTime now) => timing.phaseAt(now);

  /// 排序键：有日期的按日期，没有日期的排到最后（而不是排最前）。
  DateTime? get date => timing.date;

  /// 同一天内的排序键：知道确切时段的排在前面。
  int? get startMinute => timing.sortMinute;
}

/// 考试列表的组织方式：按阶段分组 + 按日期排序。
///
/// 学生真正关心的是「接下来还有什么」，所以：
/// - 有日期的按时间从早到晚排；
/// - 没日期的（`待定`）永远排在最后，不会挤掉有确定时间的考试。
abstract final class ExamTimeline {
  /// 组标题。
  static const Map<ExamPhase, String> groupTitles = {
    ExamPhase.today: '今天',
    ExamPhase.upcoming: '之后',
    ExamPhase.unknown: '时间待定',
    ExamPhase.finished: '已结束',
  };

  /// 页面上的展示顺序。已结束排最后但默认折叠关注。
  static const List<ExamPhase> groupOrder = [
    ExamPhase.today,
    ExamPhase.upcoming,
    ExamPhase.unknown,
    ExamPhase.finished,
  ];

  /// 把原始列表拆成 [ExamEntry]，排好序。
  static List<ExamEntry> entriesOf(Iterable<ExamSchedule> exams) {
    final entries = [
      for (final exam in exams)
        ExamEntry(exam: exam, timing: ExamTiming.parse(exam.examTimeAndPlace)),
    ];
    entries.sort(compareEntries);
    return entries;
  }

  /// 三级排序：日期 -> 时段 -> 课程名。
  /// 缺的靠后放（没日期沉底、同一天里没时段的靠后），
  /// 最后用课程名兜底，保证每次刷新顺序一致。
  static int compareEntries(ExamEntry a, ExamEntry b) {
    final byDate = _compareNullable<DateTime>(a.date, b.date);
    if (byDate != 0) return byDate;
    final byTime = _compareNullable<int>(a.startMinute, b.startMinute);
    if (byTime != 0) return byTime;
    return a.courseName.compareTo(b.courseName);
  }

  /// null 排最后。
  static int _compareNullable<T extends Object>(T? a, T? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return (a as Comparable<Object>).compareTo(b);
  }

  /// 按阶段分组；[filter] 先过滤再分组。
  ///
  /// 返回的分组按 [groupOrder] 排好，空的分组不返回。
  static List<ExamGroup> groupsOf(
    List<ExamEntry> entries, {
    required DateTime now,
    ExamFilter filter = const ExamFilter.all(),
  }) {
    final buckets = {for (final phase in groupOrder) phase: <ExamEntry>[]};
    for (final entry in entries) {
      if (!filter.matches(entry)) continue;
      buckets[entry.phaseAt(now)]!.add(entry);
    }
    return [
      for (final phase in groupOrder)
        if (buckets[phase]!.isNotEmpty)
          ExamGroup(phase: phase, entries: buckets[phase]!),
    ];
  }

  /// 下一场「还没考完」的考试，用于页面顶部的倒计时卡片。
  static ExamEntry? nextUpcoming(
    List<ExamEntry> entries, {
    required DateTime now,
  }) {
    for (final entry in entries) {
      final phase = entry.phaseAt(now);
      if (phase == ExamPhase.today || phase == ExamPhase.upcoming) return entry;
    }
    return null;
  }
}

/// 一个阶段下的考试。空分组不入列。
@immutable
class ExamGroup {
  const ExamGroup({required this.phase, required this.entries});

  final ExamPhase phase;
  final List<ExamEntry> entries;

  String get title => ExamTimeline.groupTitles[phase] ?? '其它';

  int get count => entries.length;
}

/// 考试类型筛选。
///
/// 考试类型是教务给的开放集合（期中 / 期末 / 补考 / 实验考核…），
/// 所以筛选项在运行时生成，这里用类而不是枚举。
/// 阶段筛选不用做成分类器：分组标题本身就是「今天 / 之后 / 已结束」导航。
@immutable
class ExamFilter {
  const ExamFilter.all() : examType = null;

  const ExamFilter.byType(this.examType);

  /// null 表示不过滤。
  final String? examType;

  /// 栏上显示的字。
  String get label => examType ?? '全部';

  bool get isAll => examType == null;

  bool matches(ExamEntry entry) =>
      examType == null || entry.exam.examType == examType;

  /// `全部` + 表里出现过的每种考试类型，去重后保持首次出现的顺序。
  static List<ExamFilter> withTypes(Iterable<String> examTypes) {
    final seen = <String>{};
    return [
      const ExamFilter.all(),
      for (final type in examTypes)
        if (type.trim().isNotEmpty && seen.add(type)) ExamFilter.byType(type),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is ExamFilter && other.examType == examType;

  @override
  int get hashCode => examType.hashCode;

  @override
  String toString() => 'ExamFilter($label)';
}
