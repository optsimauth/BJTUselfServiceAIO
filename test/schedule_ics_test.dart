import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/features/course/schedule_ics.dart';

/// 2026-09-07 是周一。
final _firstWeekMonday = DateTime(2026, 9, 7);

Course _course({
  String courseId = 'MATH101',
  String name = '高等数学',
  String teacher = '张老师',
  String place = '教三楼 101',
  String time = '第1-2周',
  int section = 1,
  int weekday = 1,
}) => Course(
  courseId: courseId,
  name: name,
  teacher: teacher,
  place: place,
  time: time,
  locationIndex: (section - 1) * 8 + weekday,
);

void main() {
  test('导出的日历是合法的 VCALENDAR 头尾配对', () {
    final ics = ScheduleIcs.build(
      courses: [_course()],
      firstWeekMonday: _firstWeekMonday,
      now: DateTime.utc(2026, 8, 20, 12),
    );
    final lines = ics.text.split('\r\n');
    expect(lines.first, 'BEGIN:VCALENDAR');
    expect(lines.where((line) => line.isNotEmpty).last, 'END:VCALENDAR');
    expect(ics.text, contains('VERSION:2.0'));
    expect(ics.text, contains('PRODID:'));
    // CRLF 结尾，最后一个 CRLF 之后没有内容
    expect(ics.text.endsWith('END:VCALENDAR\r\n'), isTrue);
  });

  test('第 1 周周一第一节课写成正确的本地时间', () {
    final ics = ScheduleIcs.build(
      courses: [_course()],
      firstWeekMonday: _firstWeekMonday,
      now: DateTime.utc(2026, 8, 20, 12),
    );
    expect(ics.events, 2);
    expect(ics.text, contains('DTSTART:20260907T080000'));
    expect(ics.text, contains('DTEND:20260907T095000'));
    // 第二周同一星期几，日期 +7
    expect(ics.text, contains('DTSTART:20260914T080000'));
    expect(ics.text, contains('SUMMARY:高等数学'));
    expect(ics.text, contains('LOCATION:教三楼 101'));
    expect(ics.text, contains('TRIGGER:-PT30M'));
    expect(ics.text, contains('DTSTAMP:20260820T120000Z'));
  });

  test('单双周只导指定的周次', () {
    final ics = ScheduleIcs.build(
      courses: [_course(time: '第1-8周(单)'), _course(weekday: 3)],
      firstWeekMonday: _firstWeekMonday,
      now: DateTime.utc(2026, 8, 20, 12),
    );
    // 第一门 1..8 周里的 4 个单周，第二门 1..2 周 2 次
    expect(ics.events, 6);
    expect(ics.text, isNot(contains('DTSTART:20260908T080000')));
  });

  test('时间字段解析不出来时按整个学期导', () {
    final ics = ScheduleIcs.build(
      courses: [_course(time: '未知')],
      firstWeekMonday: _firstWeekMonday,
      now: DateTime.utc(2026, 8, 20, 12),
    );
    expect(ics.events, 26);
  });

  test('第八节没有作息时间，跳过并计数', () {
    final ics = ScheduleIcs.build(
      courses: [_course(section: 8)],
      firstWeekMonday: _firstWeekMonday,
      now: DateTime.utc(2026, 8, 20, 12),
    );
    expect(ics.events, 0);
    expect(ics.skipped, 1);
    expect(ics.text, isNot(contains('BEGIN:VEVENT')));
  });

  test('逗号分号按 TEXT 规则转义，长行按 75 字节折叠', () {
    final ics = ScheduleIcs.build(
      courses: [_course(name: '信号与系统,实验;一', place: '综合教学楼 12 层 304 室')],
      firstWeekMonday: _firstWeekMonday,
      now: DateTime.utc(2026, 8, 20, 12),
    );
    expect(ics.text, contains(r'SUMMARY:信号与系统\,实验\;一'));
    for (final line in ics.text.split('\r\n')) {
      expect(
        line.startsWith(' ') || utf8.encode(line).length <= 75,
        isTrue,
        reason: '超长行没有折叠：$line',
      );
    }
  });
}
