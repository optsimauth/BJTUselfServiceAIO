import 'package:flutter/foundation.dart';

import '../../data/models/calendar/calendar_week.dart';
import '../../data/models/course/course_model.dart';
import '../../data/models/exam/exam_model.dart';
import '../../data/models/homework/homework_model.dart';
import '../course/schedule_weeks.dart';
import '../exam/exam_timing.dart';
import '../homework/homework_timing.dart';

/// 首页日历中的一类事项。
enum HomeCalendarEventType { course, homeworkStart, homeworkEnd, exam }

@immutable
class HomeCalendarEvent {
  const HomeCalendarEvent({
    required this.type,
    required this.date,
    this.course,
    this.homework,
    this.exam,
  });

  final HomeCalendarEventType type;
  final DateTime date;
  final Course? course;
  final Homework? homework;
  final ExamSchedule? exam;

  String get title => course?.name ?? homework?.title ?? exam?.courseName ?? '';

  String get typeLabel => switch (type) {
    HomeCalendarEventType.course => '课程',
    HomeCalendarEventType.homeworkStart => '作业开始',
    HomeCalendarEventType.homeworkEnd => '作业截止',
    HomeCalendarEventType.exam => '考试',
  };

  /// 排序用：课程按节次排在最前，然后是作业、考试。
  ///
  /// 单独一个 int 而不是比较器 —— 界面只按这个升序排，节次天然是 1..8，
  /// 和后面三个常量不重叠。
  int get sortKey => switch (type) {
    HomeCalendarEventType.course => course?.section ?? 0,
    HomeCalendarEventType.homeworkStart => 100,
    HomeCalendarEventType.homeworkEnd => 200,
    HomeCalendarEventType.exam => 300,
  };
}

/// [date] 是第几教学周。
///
/// 有校历时以校历为准：**假期周返回 null** —— 国庆那一周不是「第 4 周」，
/// 它就是假期周（周数不推进），显示成「第 4 周」会把课表整体带偏两周。
/// 没有校历时退回 7 天除法，这时假期期间算出来的周次是偏的（降级）。
int? weekNumberForDate({
  required DateTime date,
  required DateTime now,
  required int currentWeek,
  TeachingCalendar? calendar,
}) {
  if (calendar != null && !calendar.isEmpty) {
    return calendar.weekOf(date);
  }
  final todayMonday = _mondayOf(now);
  final targetMonday = _mondayOf(date);
  return currentWeek + targetMonday.difference(todayMonday).inDays ~/ 7;
}

/// 周次标题：假期周写「假期周」，其余「第 N 教学周」。
String weekTitleOf(int? week) => week == null ? '假期周' : '第 $week 教学周';

DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// 将首页已有的课程、作业和考试数据转换成日历事件。
///
/// [courses] 是每周重复的课，要按 [calendar] / [currentWeek] 展开成具体日期，
/// 详见 [_addCourseEvents]。
Map<DateTime, List<HomeCalendarEvent>> buildHomeCalendarEvents({
  required List<Homework> homework,
  required List<ExamSchedule> exams,
  List<Course> courses = const [],
  TeachingCalendar? calendar,
  int currentWeek = 0,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final events = <DateTime, List<HomeCalendarEvent>>{};
  for (final item in homework) {
    _addHomeworkEvents(events, item);
  }
  for (final item in exams) {
    _addExamEvent(events, item);
  }
  _addCourseEvents(
    events,
    courses: courses,
    calendar: calendar,
    currentWeek: currentWeek,
    now: today,
  );
  return {
    for (final entry in events.entries)
      entry.key: List<HomeCalendarEvent>.unmodifiable(entry.value),
  };
}

void _addHomeworkEvents(
  Map<DateTime, List<HomeCalendarEvent>> events,
  Homework homework,
) {
  final openDate = _dateOf(homework.openDate);
  if (openDate != null) {
    _addEvent(
      events,
      HomeCalendarEvent(
        type: HomeCalendarEventType.homeworkStart,
        date: openDate,
        homework: homework,
      ),
    );
  }
  final deadline = _deadlineDayOf(homework.endTime);
  if (deadline != null) {
    _addEvent(
      events,
      HomeCalendarEvent(
        type: HomeCalendarEventType.homeworkEnd,
        date: deadline,
        homework: homework,
      ),
    );
  }
}

void _addExamEvent(
  Map<DateTime, List<HomeCalendarEvent>> events,
  ExamSchedule exam,
) {
  final date = ExamTiming.parse(exam.examTimeAndPlace).date;
  if (date == null) return;
  _addEvent(
    events,
    HomeCalendarEvent(type: HomeCalendarEventType.exam, date: date, exam: exam),
  );
}

/// 把每周重复的课铺到具体日期上。
///
/// 这一步不能省：课程没有日期，只有「周几 + 第几周 + 第几节」。
/// 按教学周逐周展开，再问 [ScheduleWeeks] 这门课这周上不上
/// —— `1-8周(单)` 的课只在奇数周落到日历上。
///
/// **只展开 [now] 所在的教学周往后**：日历能翻到 2035 年，全量铺
/// 会一次生成几万个事件。
void _addCourseEvents(
  Map<DateTime, List<HomeCalendarEvent>> events, {
  required List<Course> courses,
  required TeachingCalendar? calendar,
  required int currentWeek,
  required DateTime now,
}) {
  final placed =
      courses
          .where((course) => course.isCurrentSemester && course.isPlaced)
          .toList()
        ..sort((a, b) => a.section.compareTo(b.section));
  if (placed.isEmpty) return;

  for (final (monday, week) in _courseWeeks(calendar, currentWeek, now)) {
    for (final course in placed) {
      if (!ScheduleWeeks.includesWeek(course.time, week)) continue;
      _addEvent(
        events,
        HomeCalendarEvent(
          type: HomeCalendarEventType.course,
          date: monday.add(Duration(days: course.weekDay - 1)),
          course: course,
        ),
      );
    }
  }
}

/// [now] 所在教学周及其后所有教学周的 (周一, 周次)。
///
/// 有校历时以校历为准：假期周（`teachingWeek == null`）不上课，跳过；
/// 学期之前的周也不再生成 —— 已经过去的课留在日历上没意义。
/// 没校历时退回从今天这周起按 7 天推 [ScheduleWeeks.maxWeek] 周，
/// 这时假期期间的周次是偏的（已知降级，和 `weekNumberForDate` 一致）。
List<(DateTime, int)> _courseWeeks(
  TeachingCalendar? calendar,
  int currentWeek,
  DateTime now,
) {
  final thisMonday = _mondayOf(now);
  if (calendar == null || calendar.isEmpty) {
    return [
      for (var offset = 0; offset < ScheduleWeeks.maxWeek; offset++)
        (thisMonday.add(Duration(days: offset * 7)), currentWeek + offset),
    ];
  }
  return [
    for (final slot in calendar.slots)
      if (slot.teachingWeek != null && !slot.monday.isBefore(thisMonday))
        (slot.monday, slot.teachingWeek!),
  ];
}

void _addEvent(
  Map<DateTime, List<HomeCalendarEvent>> events,
  HomeCalendarEvent event,
) {
  final day = _dayOf(event.date);
  events.putIfAbsent(day, () => []).add(event);
}

DateTime? _dateOf(String raw) {
  final timing = HomeworkTiming.parse(endTime: raw);
  final date = timing.deadline;
  return date == null ? null : _dayOf(date);
}

DateTime? _deadlineDayOf(String raw) {
  final timing = HomeworkTiming.parse(endTime: raw);
  final date = timing.deadline;
  return date == null
      ? null
      : _dayOf(date.subtract(const Duration(minutes: 1)));
}

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

List<HomeCalendarEvent> eventsOn(
  Map<DateTime, List<HomeCalendarEvent>> events,
  DateTime day,
) => events[_dayOf(day)] ?? const [];
