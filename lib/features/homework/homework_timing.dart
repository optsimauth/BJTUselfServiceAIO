import 'package:flutter/foundation.dart';

/// 作业的开放 / 截止时间，以及由此得出的紧迫度。
///
/// 平台的 `end_time` 是 `yyyy-MM-dd HH:mm` 的自由文本，也见过
/// `2026-01-20 23:59`、`2026/01/20 23:59`、`2026-01-20` 三种写法。
/// **解析不出来就是不知道**：界面上写「截止时间待定」，绝不假装还有多久。
@immutable
class HomeworkTiming {
  const HomeworkTiming({
    this.deadline,
    this.deadlineText = '',
    this.openText = '',
  });

  static const HomeworkTiming unknown = HomeworkTiming();

  /// 截止时刻；解析不出来是 null。
  final DateTime? deadline;

  /// 原样保留的截止时间文本。
  final String deadlineText;

  /// 开放时间文本（平台原样给，展示用）。
  final String openText;

  bool get hasDeadline => deadline != null;

  /// 距离 [now] 还有几小时。已过是负数，没有截止时间是 null。
  int? hoursUntil(DateTime now) => deadline?.difference(now).inHours;

  /// 距离 [now] 还有几天（按日历天算，和考试那一套保持一致）。
  int? daysUntil(DateTime now) {
    final target = deadline;
    if (target == null) return null;
    return DateTime(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// 相对于 [now] 的紧迫度。
  HomeworkUrgency urgencyAt(DateTime now) {
    final deadline = this.deadline;
    if (deadline == null) return HomeworkUrgency.unknown;
    if (!deadline.isAfter(now)) return HomeworkUrgency.overdue;
    if (deadline.difference(now) <= const Duration(hours: 48)) {
      return HomeworkUrgency.soon;
    }
    return HomeworkUrgency.normal;
  }

  /// 一句人话的截止文案。已提交的作业不再强调紧迫度，交给调用方决定要不要显示。
  String countdownLabel(DateTime now) {
    final deadline = this.deadline;
    if (deadline == null) return '截止待定';

    // 先判「过没过」再算天数：`inHours` 是向零截断的，
    // 「今天 09:00 的截止」在 09:30 去看差值是 0 小时，
    // 只按天数算会落到「今天」分支里，被说成「马上截止」。
    if (!deadline.isAfter(now)) return '已截止';

    final days = daysUntil(now);
    if (days == null || days <= 0) {
      final hours = deadline.difference(now).inHours;
      if (hours <= 0) return '不到 1 小时';
      return '今天还剩 $hours 小时';
    }
    if (days == 1) return '明天截止';
    return '还有 $days 天';
  }

  /// 从平台字段解析。`endTime` / `openDate` 都是自由文本。
  static HomeworkTiming parse({required String endTime, String openDate = ''}) {
    final deadline = _parseDateTime(endTime);
    return HomeworkTiming(
      deadline: deadline,
      deadlineText: endTime.trim(),
      openText: openDate.trim(),
    );
  }

  /// 认得 `2026-01-20 23:59`、`2026/01/20 23:59`、`2026-01-20T23:59`、
  /// 只有日期的 `2026-01-20`（按 23:59 收尾，和平台默认一致）。
  static DateTime? _parseDateTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final match = _pattern.firstMatch(text);
    if (match == null) return null;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;

    // 捕获组：1 年 / 2 月 / 3 日 / 4 时 / 5 分。时、分是可选的，
    // 缺省按 23:59 收尾（平台只给日期时的惯例）。
    final hour = int.tryParse(match.group(4) ?? '') ?? 23;
    final minute = int.tryParse(match.group(5) ?? '') ?? 59;

    final parsed = DateTime(year, month, day, hour, minute);
    // 2 月 30 日这种会溢出到下个月，判掉。
    if (parsed.month != month || parsed.day != day) return null;
    return parsed;
  }

  /// 年 / 月 / 日 + 可选的 时:分。
  ///
  /// 分隔用的 `\s` 必须待在这个可选组**里面**：写成 `\s*日?(?:[T\s]+…)` 的话，
  /// 前面的 `\s*` 会先把空格吃掉，正则引擎又不会回头让它重试，
  /// 结果就是最常见的 `2026-01-20 23:59` 只能解析出日期，时间被丢掉。
  static final RegExp _pattern = RegExp(
    r'(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?'
    r'(?:\s*[T]?\s*(\d{1,2})\s*[:：]\s*(\d{1,2}))?',
  );
}

/// 截止紧迫度。界面按这个上色：越靠前越显眼。
enum HomeworkUrgency {
  /// 48 小时内截止。
  soon,

  /// 已经过了截止时间。
  overdue,

  /// 时间还早。
  normal,

  /// 平台没给截止时间。
  unknown;

  /// 徽章上写什么。
  String get label => switch (this) {
    HomeworkUrgency.soon => '快截止',
    HomeworkUrgency.overdue => '已截止',
    HomeworkUrgency.normal => '进行中',
    HomeworkUrgency.unknown => '时间待定',
  };
}
