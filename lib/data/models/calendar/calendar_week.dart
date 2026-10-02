/// 教学周 ↔ 自然日期的换算（校历驱动）。
///
/// 为什么不能简单「开学日 + 7 天 × 周次」：国庆这种假期校历会**空掉**
/// 一到两个自然周 —— 第 3 周从 9/21 开始，第 4 周却从 10/12 开始。
/// 假期那一周不是「第 4 周」，它是假期周，没有课（但作业/考试仍可能在那周起止）。
/// 所以这里的时间轴以校历为准，中间缺的周补成 [teachingWeek] == null。
library;

/// 校历上的一个教学周：第 [teachingWeek] 教学周，周一是 [startDate]。
class CalendarWeek {
  const CalendarWeek({required this.teachingWeek, required this.startDate});

  final int teachingWeek;
  final DateTime startDate;
}

/// 校历时间轴上的一个自然周。
///
/// [teachingWeek] 为 null 表示这是校历明确留出的**非教学周**（假期），
/// 而不是「这周没课」—— 作业/考试仍可能在非教学周开始或截止。
class AcademicWeekSlot {
  const AcademicWeekSlot({required this.teachingWeek, required this.startDate});

  final int? teachingWeek;
  final DateTime startDate;

  bool get isNonTeachingWeek => teachingWeek == null;

  DateTime get endDate => startDate.add(const Duration(days: 6));

  DateTime get monday {
    final day = DateTime(startDate.year, startDate.month, startDate.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(startDate) && !day.isAfter(endDate);
  }
}

/// 一个学期的校历时间轴。空校历时 [isEmpty]，调用方退回 7 天除法兜底。
class TeachingCalendar {
  TeachingCalendar._(this.slots, this.label);

  /// 校历时间轴：按自然周排序，假期周 teachingWeek 为 null。
  final List<AcademicWeekSlot> slots;

  /// 学期 label，如 `2025-2026-2`。
  final String label;

  bool get isEmpty => slots.isEmpty;

  /// 含有 [date] 的那一周；不在校历范围内返回 null。
  AcademicWeekSlot? slotOf(DateTime date) {
    for (final slot in slots) {
      if (slot.contains(date)) return slot;
    }
    return null;
  }

  /// [date] 所在的教学周号；假期周 / 超出范围返回 null。
  int? weekOf(DateTime date) => slotOf(date)?.teachingWeek;

  /// [teachingWeek] 那一周的周一；没有返回 null。
  DateTime? mondayOfWeek(int teachingWeek) {
    for (final slot in slots) {
      if (slot.teachingWeek == teachingWeek) return slot.monday;
    }
    return null;
  }

  /// 把校历里的教学周展开成按自然周排序的时间轴，并补出相邻教学周之间的空周。
  ///
  /// 例如第 3 周从 9/21 开始、第 4 周从 10/12 开始，结果里会出现 9/28 与 10/5
  /// 两个 [AcademicWeekSlot]（teachingWeek 为 null），国庆就是它们。
  static TeachingCalendar? fromWeeks(
    List<CalendarWeek> weeks, {
    String label = '',
    int maxTeachingWeek = 30,
  }) {
    final dated = <(int, DateTime)>[];
    for (final week in weeks) {
      if (week.teachingWeek <= 0 || week.teachingWeek > maxTeachingWeek) {
        continue;
      }
      if (week.startDate.year < 2000) continue;
      final day = DateTime(
        week.startDate.year,
        week.startDate.month,
        week.startDate.day,
      );
      dated.add((
        week.teachingWeek,
        day.subtract(Duration(days: day.weekday - DateTime.monday)),
      ));
    }
    if (dated.isEmpty) return null;

    // 校历按时间顺序给出。同一周被两条记录命中时保留先出现的那条。
    dated.sort((a, b) => a.$2.compareTo(b.$2));
    final byMonday = <DateTime, int>{};
    for (final entry in dated) {
      byMonday.putIfAbsent(entry.$2, () => entry.$1);
    }
    final first = byMonday.keys.first;
    final last = byMonday.keys.last;

    final slots = <AcademicWeekSlot>[];
    for (
      var monday = first;
      !monday.isAfter(last);
      monday = monday.add(const Duration(days: 7))
    ) {
      slots.add(
        AcademicWeekSlot(teachingWeek: byMonday[monday], startDate: monday),
      );
    }
    return TeachingCalendar._(slots, label);
  }

  /// 没校历时用的兜底：按「第 1 周的周一」纯 7 天推。
  ///
  /// 假期周会让它和真实周次对不上，所以只作为**降级**，界面应说明没有校历数据。
  static int fallbackWeekOf({
    required DateTime firstWeekMonday,
    required DateTime now,
  }) {
    final monday = _mondayOf(now);
    return monday.difference(firstWeekMonday).inDays ~/ 7 + 1;
  }

  /// 任意日期所在那一周的周一。
  static DateTime mondayOf(DateTime date) => _mondayOf(date);

  static DateTime _mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Map<String, Object?> toJson() => {
    'label': label,
    'weeks': [
      for (final slot in slots)
        if (slot.teachingWeek != null)
          {'week': slot.teachingWeek, 'date': _isoDate(slot.monday)},
    ],
  };

  static TeachingCalendar? fromJson(Map<String, Object?> json) {
    final rawWeeks = json['weeks'];
    if (rawWeeks is! List) return null;
    final weeks = <CalendarWeek>[];
    for (final item in rawWeeks) {
      if (item is! Map) continue;
      final week = item['week'];
      final date = DateTime.tryParse('${item['date']}');
      if (week is int && date != null) {
        weeks.add(CalendarWeek(teachingWeek: week, startDate: date));
      }
    }
    return fromWeeks(weeks, label: '${json['label'] ?? ''}');
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
