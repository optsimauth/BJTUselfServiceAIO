import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/exam/exam_model.dart';
import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';
import 'package:bjtuselfserviceaio/features/home/home_calendar.dart';

Homework _homework({String openDate = '', String endTime = ''}) => Homework(
  upId: 1,
  courseName: '高等数学',
  title: '第一次作业',
  openDate: openDate,
  endTime: endTime,
);

void main() {
  test('日历按开放日和截止日生成两个作业标记', () {
    final events = buildHomeCalendarEvents(
      homework: const [
        Homework(
          upId: 1,
          courseName: '高等数学',
          title: '第一次作业',
          openDate: '2026-03-01 08:00',
          endTime: '2026-03-05 23:59',
        ),
      ],
      exams: const [],
    );

    expect(
      eventsOn(events, DateTime(2026, 3, 1)).single.type,
      HomeCalendarEventType.homeworkStart,
    );
    expect(
      eventsOn(events, DateTime(2026, 3, 5)).single.type,
      HomeCalendarEventType.homeworkEnd,
    );
  });

  test('截止时间为午夜时沿用 Android 归属前一天的规则', () {
    final events = buildHomeCalendarEvents(
      homework: const [
        Homework(
          upId: 2,
          courseName: '英语',
          title: '报告',
          endTime: '2026-03-05 00:00',
        ),
      ],
      exams: const [],
    );

    expect(
      eventsOn(events, DateTime(2026, 3, 4)).single.type,
      HomeCalendarEventType.homeworkEnd,
    );
    expect(eventsOn(events, DateTime(2026, 3, 5)), isEmpty);
  });

  test('考试从时间地点文本提取日期并生成考试标记', () {
    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [
        ExamSchedule(
          examType: '期末',
          courseName: '大学物理',
          examTimeAndPlace: '2026年3月8日 08:00-10:00 教四403',
        ),
      ],
    );

    final event = eventsOn(events, DateTime(2026, 3, 8)).single;
    expect(event.type, HomeCalendarEventType.exam);
    expect(event.title, '大学物理');
  });

  test('当前日期所在周保持当前教学周', () {
    expect(
      weekNumberForDate(
        date: DateTime(2026, 3, 4),
        now: DateTime(2026, 3, 4),
        currentWeek: 8,
      ),
      8,
    );
  });

  test('下一周日期教学周数加一', () {
    expect(
      weekNumberForDate(
        date: DateTime(2026, 3, 11),
        now: DateTime(2026, 3, 4),
        currentWeek: 8,
      ),
      9,
    );
  });

  test('上一周日期教学周数减一', () {
    expect(
      weekNumberForDate(
        date: DateTime(2026, 2, 25),
        now: DateTime(2026, 3, 4),
        currentWeek: 8,
      ),
      7,
    );
  });

  test('无法解析的日期不生成标记', () {
    final events = buildHomeCalendarEvents(
      homework: [_homework(openDate: '待定', endTime: '待定')],
      exams: const [
        ExamSchedule(examType: '期末', courseName: '数学', examTimeAndPlace: '待定'),
      ],
    );

    expect(events, isEmpty);
  });
}
