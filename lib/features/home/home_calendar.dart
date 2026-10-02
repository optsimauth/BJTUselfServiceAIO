import 'package:flutter/foundation.dart';

import '../../data/models/calendar/calendar_week.dart';
import '../../data/models/exam/exam_model.dart';
import '../../data/models/homework/homework_model.dart';
import '../exam/exam_timing.dart';
import '../homework/homework_timing.dart';

/// 首页日历中的一类事项。
enum HomeCalendarEventType { homeworkStart, homeworkEnd, exam }

@immutable
class HomeCalendarEvent {
  const HomeCalendarEvent({
    required this.type,
    required this.date,
    this.homework,
    this.exam,
  });

  final HomeCalendarEventType type;
  final DateTime date;
  final Homework? homework;
  final ExamSchedule? exam;

  String get title => homework?.title ?? exam?.courseName ?? '';

  String get typeLabel => switch (type) {
    HomeCalendarEventType.homeworkStart => '作业开始',
    HomeCalendarEventType.homeworkEnd => '作业截止',
    HomeCalendarEventType.exam => '考试',
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

/// 将首页已有的作业和考试数据转换成日历事件。
Map<DateTime, List<HomeCalendarEvent>> buildHomeCalendarEvents({
  required List<Homework> homework,
  required List<ExamSchedule> exams,
}) {
  final events = <DateTime, List<HomeCalendarEvent>>{};
  for (final item in homework) {
    _addHomeworkEvents(events, item);
  }
  for (final item in exams) {
    _addExamEvent(events, item);
  }
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
