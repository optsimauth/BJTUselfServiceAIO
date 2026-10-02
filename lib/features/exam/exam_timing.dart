import 'package:flutter/foundation.dart';

/// 「考试时间地点」这一格是教务给的自由文本，真实见过的写法有：
/// - `2026-01-08(第18周) 08:00-10:00 教四403`
/// - `2026年1月8日 08:00~10:00 逸夫303`
/// - `2026/01/08  13:30-15:30  线上`
/// - `待定`
///
/// 这里把它拆成日期 / 时段 / 地点 / 括号注释四段。
/// **拆不出来就留空，不猜**：猜错的倒计时比没有倒计时更糟 ——
/// 学生会以为还有时间。
@immutable
class ExamTiming {
  const ExamTiming({
    this.date,
    this.dateText = '',
    this.timeText = '',
    this.place = '',
    this.note = '',
  });

  /// 解析不出时的空实例。界面照常展示原文，只是没有倒计时。
  static const ExamTiming unknown = ExamTiming();

  /// 考试当天的零点。没解析出日期时为 null。
  final DateTime? date;

  /// 原样保留的日期文本（`2026-01-08`、`2026年1月8日`…），便于展示。
  final String dateText;

  /// 时段文本（`08:00-10:00`），解析不出时为空。
  final String timeText;

  /// 地点文本；线上考试也是地点，所以这里不排除空。
  final String place;

  /// 括号里的补充说明（第18周 / 西校区 / 单双周…）。教务习惯用括号放注释，
  /// 混进地点里会让「地点」变得没法用，所以单独拆出来。
  final String note;

  /// 有没有解析出日期。
  bool get hasDate => date != null;

  /// 上课时刻的分钟数（0..1439）。取不到返回 -1。
  int get startMinute => _minuteOf(timeText, 0);

  /// 下课时刻的分钟数（0..1439）。取不到返回 -1。
  int get endMinute => _minuteOf(timeText, 1);

  bool get hasPeriod => startMinute >= 0 && endMinute > startMinute;

  /// 排序用：同一天里，知道确切时段的排在前面。
  int? get sortMinute => hasPeriod ? startMinute : null;

  /// 距离 [now] 还有几天；已经过去返回负数，没有日期返回 null。
  ///
  /// 用日历天算，不按 24 小时算：考试是按天算的，
  /// 「今天下午 2 点的考试」在早上 9 点就该显示「今天」，不是「还有 5 小时」。
  int? daysUntil(DateTime now) {
    final target = date;
    if (target == null) return null;
    return _midnight(target).difference(_midnight(now)).inDays;
  }

  /// 相对于 [now] 的阶段。界面上用它决定徽章颜色和分组。
  ExamPhase phaseAt(DateTime now) {
    final days = daysUntil(now);
    if (days == null) return ExamPhase.unknown;
    if (days < 0) return ExamPhase.finished;
    if (days > 0) return ExamPhase.upcoming;
    // 今天：知道下课时间且已经过了，就算结束。
    if (hasPeriod && _minuteOfDay(now) >= endMinute) return ExamPhase.finished;
    return ExamPhase.today;
  }

  /// 一句人话的倒计时文案。
  String countdownLabel(DateTime now) {
    final days = daysUntil(now);
    if (days == null) return '时间待定';
    if (days < 0) return '已结束';
    if (days == 0) return hasPeriod ? '今天' : '今天（时段待定）';
    if (days == 1) return '明天';
    if (days < 7) return '$days 天后';
    if (days % 7 == 0) return '${days ~/ 7} 周后';
    return '$days 天后';
  }

  /// 拆完剩下的原文，界面上用它兜底。
  String get raw =>
      [dateText, timeText, place].where((part) => part.isNotEmpty).join(' ');

  /// 从「考试时间地点」自由文本里拆四段。任何一段拆不出来都留空。
  static ExamTiming parse(String source) {
    final text = source.trim();
    if (text.isEmpty) return unknown;

    final dateMatch = _datePattern.firstMatch(text);
    final periodMatch = _periodPattern.firstMatch(text);
    final annotations = _annotationPattern.allMatches(text).toList();

    final spans = <RegExpMatch>[?dateMatch, ?periodMatch, ...annotations];

    return ExamTiming(
      date: dateMatch == null ? null : _dateOf(dateMatch),
      dateText: dateMatch?.group(0)?.trim() ?? '',
      timeText: periodMatch?.group(0)?.trim() ?? '',
      place: _remainingPlace(text, consumed: spans),
      note: _noteOf(annotations),
    );
  }

  /// `2026-01-08` / `2026/1/8` / `2026年1月8日` 都认。
  static final RegExp _datePattern = RegExp(
    r'(\d{4})\s*[-/年.]\s*(\d{1,2})\s*[-/月.]\s*(\d{1,2})\s*日?',
  );

  /// `08:00-10:00` / `08:00~10:00` / `8:00至10:00` 都认。
  static final RegExp _periodPattern = RegExp(
    r'(\d{1,2})\s*[:：]\s*(\d{2})\s*(?:[-~—－]|至|到)\s*(\d{1,2})\s*[:：]\s*(\d{2})',
  );

  /// 括号注释：`(第18周)` / `（西校区）`。
  static final RegExp _annotationPattern = RegExp(r'[(（]([^)）]*)[)）]');

  /// 把日期、时段、括号注释从原文里剔掉，剩下的就是地点。
  static String _remainingPlace(
    String text, {
    required List<RegExpMatch> consumed,
  }) {
    if (consumed.isEmpty) return _clean(text);
    final ranges =
        consumed.map((match) => (start: match.start, end: match.end)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final kept = <String>[];
    var cursor = 0;
    for (final range in ranges) {
      // 重叠的片段只吃一次，避免把文字吃掉两遍。
      if (range.end <= cursor) continue;
      if (range.start > cursor) kept.add(text.substring(cursor, range.start));
      cursor = range.end;
    }
    if (cursor < text.length) kept.add(text.substring(cursor));
    return _clean(kept.join(' '));
  }

  static String _noteOf(List<RegExpMatch> annotations) => annotations
      .map((match) => match.group(1)?.trim() ?? '')
      .where((text) => text.isNotEmpty)
      .join(' / ');

  /// 压成单行。分隔用的括号在 [_remainingPlace] 里已经被整段剔掉了。
  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static DateTime _dateOf(RegExpMatch match) => DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );

  /// 时段文本里的第 [index] 个 `HH:mm` 转成分钟数；取不到返回 -1。
  static int _minuteOf(String timeText, int index) {
    final matches = RegExp(r'(\d{1,2})\s*[:：]\s*(\d{2})')
        .allMatches(timeText)
        .toList();
    if (index >= matches.length) return -1;
    return int.parse(matches[index].group(1)!) * 60 +
        int.parse(matches[index].group(2)!);
  }

  static int _minuteOfDay(DateTime now) => now.hour * 60 + now.minute;

  static DateTime _midnight(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  @override
  bool operator ==(Object other) =>
      other is ExamTiming &&
      other.date == date &&
      other.dateText == dateText &&
      other.timeText == timeText &&
      other.place == place &&
      other.note == note;

  @override
  int get hashCode => Object.hash(date, dateText, timeText, place, note);

  @override
  String toString() => 'ExamTiming($dateText, $timeText, $place, $note)';
}

/// 考试相对当下的阶段。
enum ExamPhase {
  /// 还没到。
  upcoming,

  /// 就是今天，而且还没下课。
  today,

  /// 已经考过了（当天过了下课时间也算）。
  finished,

  /// 教务没给日期，算不出来。
  unknown,
}
