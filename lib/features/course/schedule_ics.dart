import 'dart:convert';

import '../../data/models/course/course_model.dart';
import 'lesson_period.dart';
import 'schedule_weeks.dart';

/// 课表 -> RFC 5545 的 iCalendar（.ics）。
///
/// 一次课导成一个 VEVENT，而不是一条 RRULE 重复规则：教务的时间字段有
/// 「第1-8周(单),9-16周(双)」这种规则，用重复规则表达就得配一堆 EXDATE，
/// 而 iOS / Google 日历对 RRULE+EXDATE 的处理并不一致；展开成单次事件
/// 各家都认，代价只是文件大一点。
abstract final class ScheduleIcs {
  /// 上课前多久提醒。空串 = 不提醒。
  static const String reminder = '-PT30M';

  /// 行折叠上限：RFC 5545 要求每行不超过 75 字节，超出用 CRLF + 空格续行。
  static const int _lineLimit = 75;

  /// 生成 .ics 文本。[firstWeekMonday] 是第 1 教学周的周一。
  ///
  /// 返回 [events] 条事件；没有作息时间（第八节）的那几格进不了日历，
  /// 计入 [skipped] 让界面能提示一句。
  static ({String text, int events, int skipped}) build({
    required List<Course> courses,
    required DateTime firstWeekMonday,
    String calendarName = 'BJTU 课程表',
    DateTime? now,
  }) {
    final stamp = _utcStamp(now ?? DateTime.now());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BJTUselfService//Course Schedule//ZH',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${_escape(calendarName)}',
    ];
    var events = 0;
    var skipped = 0;
    for (final course in courses) {
      if (!_hasPeriod(course)) {
        skipped++;
        continue;
      }
      for (final week in _weeksOf(course)) {
        lines.addAll(
          _vevent(
            course: course,
            date: firstWeekMonday.add(
              Duration(days: course.weekDay - 1 + 7 * (week - 1)),
            ),
            week: week,
            stamp: stamp,
          ),
        );
        events++;
      }
    }
    lines.add('END:VCALENDAR');
    return (
      text: '${lines.map(_fold).join('\r\n')}\r\n',
      events: events,
      skipped: skipped,
    );
  }

  /// 一门课这一节有没有作息时间：第八节学校没定，进不了日历。
  static bool _hasPeriod(Course course) {
    final period = SchedulePeriods.bySection(course.section);
    return period != null && period.start.isNotEmpty && period.end.isNotEmpty;
  }

  /// 单次课的 VEVENT（含 VALARM）。
  static List<String> _vevent({
    required Course course,
    required DateTime date,
    required int week,
    required String stamp,
  }) {
    final period = SchedulePeriods.bySection(course.section)!;
    final slug = _slug(course.courseId);
    final lines = <String>[
      'BEGIN:VEVENT',
      'UID:$slug-${course.weekDay}${course.section}-$week@bjtuselfservice',
      'DTSTAMP:$stamp',
      'DTSTART:${_localStamp(date, period.start)}',
      'DTEND:${_localStamp(date, period.end)}',
      'SUMMARY:${_escape(course.name)}',
    ];
    if (course.place.isNotEmpty) {
      lines.add('LOCATION:${_escape(course.place)}');
    }
    lines.add('DESCRIPTION:${_escape(_description(course, week))}');
    if (reminder.isNotEmpty) {
      lines
        ..add('BEGIN:VALARM')
        ..add('ACTION:DISPLAY')
        ..add('TRIGGER:$reminder')
        ..add('DESCRIPTION:${_escape(course.name)}')
        ..add('END:VALARM');
    }
    lines.add('END:VEVENT');
    return lines;
  }

  static String _description(Course course, int week) => [
    if (course.teacher.isNotEmpty) '教师：${course.teacher}',
    '时间：${SchedulePeriods.bySection(course.section)!.timeRange}',
    '教学周：第 $week 周（${course.time.isEmpty ? '全部周' : course.time}）',
  ].join('\n');

  /// 课程时间字段 -> 周次集合；解析不出来时按整个学期算。
  static Set<int> _weeksOf(Course course) {
    final weeks = ScheduleWeeks.weeksOf(course.time);
    if (weeks.isNotEmpty) return weeks;
    return {for (var week = 1; week <= ScheduleWeeks.maxWeek; week++) week};
  }

  /// TEXT 值转义：RFC 5545 里反斜杠、分号、逗号、换行都要转义。
  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  /// 超长行按 75 字节折叠，续行前加一个空格（空格算进 75 字节里）。
  static String _fold(String line) {
    if (utf8.encode(line).length <= _lineLimit) return line;
    final buffer = StringBuffer();
    var used = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (used + size > _lineLimit) {
        buffer.write('\r\n ');
        used = 1;
      }
      buffer.write(char);
      used += size;
    }
    return buffer.toString();
  }

  /// DTSTAMP：UTC，格式 20260901T081500Z。
  static String _utcStamp(DateTime time) {
    final utc = time.toUtc();
    return '${_digits(utc.year, 4)}${_digits(utc.month)}${_digits(utc.day)}'
        'T${_digits(utc.hour)}${_digits(utc.minute)}${_digits(utc.second)}Z';
  }

  /// DTSTART/DTEND：本地浮动时间（不绑时区，日历按设备时区解释）。
  static String _localStamp(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return '${_digits(date.year, 4)}${_digits(date.month)}${_digits(date.day)}'
        'T${_digits(hour)}${_digits(minute)}00';
  }

  static String _digits(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');

  /// UID 只允许安全的 ASCII 字符。
  static String _slug(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '');
    return cleaned.isEmpty ? 'course' : cleaned;
  }
}
