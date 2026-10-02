import 'package:flutter/foundation.dart';

import '../../data/models/course/schedule_position.dart';

/// 一个节次：序号 + 名称 + 作息时间。
///
/// 作息表来自旧项目 `course_schedule_page.dart` 的 `_lessonTimes`，
/// 属于学校层面的事实，不随学期变化，所以放在常量里而不是接口。
@immutable
class LessonPeriod {
  const LessonPeriod({
    required this.section,
    required this.name,
    required this.start,
    required this.end,
  });

  /// 1..8。
  final int section;

  /// 例如「第一节」。
  final String name;

  /// 上课时间 `HH:mm`。
  final String start;

  /// 下课时间 `HH:mm`。
  final String end;

  /// 紧凑展示：`08:00-09:50`。
  String get timeRange => '$start-$end';

  /// 适合窄格子里的两行展示。
  String get timeStacked => '$start\n$end';


  /// 窄格子用：`8:00~9:50`（去掉小时的前导零，窄一截好塞下）。
  String get timeRangeShort => '${_dropLeadingZero(start)}~${_dropLeadingZero(end)}';

  int get startMinutes => _toMinutes(start);

  int get endMinutes => _toMinutes(end);

  /// 只去掉**小时**的前导零：`08:00` -> `8:00`，`20:50` -> `20:50`。
  /// （早先用 replaceFirst('0','')，会把 `20:50` 砍成 `2:50`。）
  static String _dropLeadingZero(String hhmm) =>
      hhmm.startsWith('0') ? hhmm.substring(1) : hhmm;

  /// 这一节是否覆盖给定的「一天第几分钟」。
  bool coversMinute(int minuteOfDay) =>
      minuteOfDay >= startMinutes && minuteOfDay < endMinutes;

  /// 距离这节课开始还有几分钟；已经开始则返回 0。
  int minutesUntilStart(int minuteOfDay) =>
      (startMinutes - minuteOfDay).clamp(0, 1 << 30);

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}

/// 一天的 8 节课 + 星期几的显示名。
abstract final class SchedulePeriods {
  /// 第几节 -> 作息。索引 0 对应第一节。
  static const List<LessonPeriod> catalog = [
    LessonPeriod(section: 1, name: '第一节', start: '08:00', end: '09:50'),
    LessonPeriod(section: 2, name: '第二节', start: '10:10', end: '12:00'),
    LessonPeriod(section: 3, name: '第三节', start: '12:10', end: '14:00'),
    LessonPeriod(section: 4, name: '第四节', start: '14:10', end: '16:00'),
    LessonPeriod(section: 5, name: '第五节', start: '16:20', end: '18:10'),
    LessonPeriod(section: 6, name: '第六节', start: '19:00', end: '20:50'),
    LessonPeriod(section: 7, name: '第七节', start: '21:00', end: '21:50'),
    // 第八节学校没有固定作息，界面上只显示序号。
    LessonPeriod(section: 8, name: '第八节', start: '', end: ''),
  ];

  /// 星期几全称，索引 0 = 周一。
  static const List<String> weekdayNames = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  /// 星期几单字，窄屏用。
  static const List<String> weekdayShortNames = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  /// 界面上省略掉「星期」前缀后的一行标题：周一、周二 …
  static List<String> get weekdayTitles => weekdayNames
      .map((name) => name.replaceFirst('星期', '周'))
      .toList(growable: false);

  /// 1..8 -> 作息；越界返回 null。
  static LessonPeriod? bySection(int section) {
    if (section < 1 || section > catalog.length) return null;
    return catalog[section - 1];
  }

  /// 界面上给某一行画的标签：没有作息时只画序号。
  static String labelOf(int section) => bySection(section)?.name ?? '$section';

  /// 界面上给某一行画的副标题：没有作息时留空。
  static String timeOf(int section) {
    final period = bySection(section);
    if (period == null || period.start.isEmpty) return '';
    return period.timeStacked;
  }

  /// 此刻正在上的课（节次 1..8），不在课表时间内返回 null。
  static int? currentSectionAt(DateTime now) {
    final minute = SchedulePosition.minuteOfDay(now);
    for (final period in catalog) {
      if (period.start.isEmpty) continue;
      if (period.coversMinute(minute)) return period.section;
    }
    return null;
  }
}
