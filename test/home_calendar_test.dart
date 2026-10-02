import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/calendar/calendar_week.dart';
import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
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

/// 周一 = 2026-03-02，第 8 教学周；课表在第 8~9 周连续两周，中间没有假期。
TeachingCalendar _calendar() => TeachingCalendar.fromWeeks([
  CalendarWeek(teachingWeek: 8, startDate: DateTime(2026, 3, 2)),
  CalendarWeek(teachingWeek: 9, startDate: DateTime(2026, 3, 9)),
])!;

/// [locationIndex] 用 SchedulePosition 的扁平下标：1..56。
/// 周一第 1 节 = 1，周三第 3 节 = 15。
Course _course({
  String time = '第1-16周',
  int locationIndex = 1,
  bool isCurrentSemester = true,
}) => Course(
  courseId: 'C1',
  name: '高等数学',
  teacher: '王老师',
  place: '教三201',
  time: time,
  locationIndex: locationIndex,
  isCurrentSemester: isCurrentSemester,
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

  test('课程按教学周展开到每个上课日', () {
    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [],
      courses: [_course()],
      calendar: _calendar(),
      currentWeek: 8,
      now: DateTime(2026, 3, 2),
    );

    // 周一第 1 节：第 8 周的 3/2 和第 9 周的 3/9 都有课。
    expect(
      eventsOn(events, DateTime(2026, 3, 2)).single.type,
      HomeCalendarEventType.course,
    );
    expect(
      eventsOn(events, DateTime(2026, 3, 9)).single.type,
      HomeCalendarEventType.course,
    );
    expect(eventsOn(events, DateTime(2026, 3, 3)), isEmpty);
  });

  test('单双周课程只落在自己那一侧', () {
    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [],
      courses: [_course(time: '第8-9周(单)')],
      calendar: _calendar(),
      currentWeek: 8,
      now: DateTime(2026, 3, 2),
    );

    // 8-9 周里的奇数周 = 第 9 周，所以只有 3/9 有课。
    expect(eventsOn(events, DateTime(2026, 3, 2)), isEmpty);
    expect(eventsOn(events, DateTime(2026, 3, 9)), hasLength(1));
  });

  test('假期周不生成课程', () {
    // 3/2 是第 8 周，3/9 是假期周，3/16 是第 9 周。
    final calendar = TeachingCalendar.fromWeeks([
      CalendarWeek(teachingWeek: 8, startDate: DateTime(2026, 3, 2)),
      CalendarWeek(teachingWeek: 9, startDate: DateTime(2026, 3, 16)),
    ])!;

    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [],
      courses: [_course()],
      calendar: calendar,
      currentWeek: 8,
      now: DateTime(2026, 3, 2),
    );

    expect(eventsOn(events, DateTime(2026, 3, 9)), isEmpty);
    expect(eventsOn(events, DateTime(2026, 3, 16)), hasLength(1));
  });

  test('学期开始之前的周不再展开课程', () {
    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [],
      courses: [_course()],
      calendar: _calendar(),
      currentWeek: 8,
      // 「现在」落在第 9 周：第 8 周已经在过去。
      now: DateTime(2026, 3, 10),
    );

    expect(eventsOn(events, DateTime(2026, 3, 2)), isEmpty);
    expect(eventsOn(events, DateTime(2026, 3, 9)), hasLength(1));
  });

  test('非本学期和位置未知的课程不进日历', () {
    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [],
      courses: [_course(isCurrentSemester: false), _course(locationIndex: 0)],
      calendar: _calendar(),
      currentWeek: 8,
      now: DateTime(2026, 3, 2),
    );

    expect(eventsOn(events, DateTime(2026, 3, 2)), isEmpty);
  });

  test('没有校历时从今天这周起按 7 天推', () {
    final events = buildHomeCalendarEvents(
      homework: const [],
      exams: const [],
      courses: [_course()],
      currentWeek: 8,
      now: DateTime(2026, 3, 4),
    );

    expect(eventsOn(events, DateTime(2026, 3, 2)), hasLength(1));
    expect(eventsOn(events, DateTime(2026, 3, 9)), hasLength(1));
    // 26 周之后不再生成，别把日历翻到 2035 的那几万个事件都铺出来。
    expect(eventsOn(events, DateTime(2026, 9, 7)), isEmpty);
  });

  test('课程按节次排在作业和考试前面', () {
    final events = buildHomeCalendarEvents(
      homework: [
        _homework(openDate: '2026-03-02 08:00', endTime: '2026-03-02 23:59'),
      ],
      exams: const [
        ExamSchedule(
          examType: '期末',
          courseName: '物理',
          examTimeAndPlace: '2026-03-02 08:00-10:00 教四403',
        ),
      ],
      courses: [_course()],
      calendar: _calendar(),
      currentWeek: 8,
      now: DateTime(2026, 3, 2),
    );

    // 顺序是界面按 sortKey 排出来的：课程（按节次）→ 作业 → 考试。
    final day = [...eventsOn(events, DateTime(2026, 3, 2))]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    expect(day.map((e) => e.type), [
      HomeCalendarEventType.course,
      HomeCalendarEventType.homeworkStart,
      HomeCalendarEventType.homeworkEnd,
      HomeCalendarEventType.exam,
    ]);
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
