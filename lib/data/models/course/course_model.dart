import 'package:flutter/foundation.dart';

import 'schedule_position.dart';

/// 学期（对应智慧教学平台的 xqCode）。
@immutable
class Semester {
  const Semester({
    required this.code,
    required this.name,
    this.isCurrent = false,
  });

  final String code;
  final String name;
  final bool isCurrent;
}

/// 一节课（同一个课号可能占多个格子）。
@immutable
class Course {
  const Course({
    this.id = 0,
    required this.courseId,
    required this.name,
    this.teacher = '',
    this.locationIndex = 0,
    this.time = '',
    this.place = '',
    this.isCurrentSemester = true,
  });

  final int id;
  final String courseId;
  final String name;
  final String teacher;

  /// 教务课表格子的扁平下标，1..56；[SchedulePosition.unknown] 表示位置未知。
  /// 换算规则见 [SchedulePosition]。
  final int locationIndex;
  final String time;
  final String place;
  final bool isCurrentSemester;

  /// 是否能画到课表网格上（位置已知且不是空位）。
  bool get isPlaced => SchedulePosition.isPlaced(locationIndex);

  /// 星期几，1=周一 .. 7=周日；位置未知时为 0。
  int get weekDay => isPlaced ? SchedulePosition.weekdayOf(locationIndex) : 0;

  /// 第几节，1=第一节 .. 8=第八节；位置未知时为 0。
  int get section => isPlaced ? SchedulePosition.sectionOf(locationIndex) : 0;

  /// 在网格里的列下标，0..6；位置未知时为 -1。
  int get dayIndex => isPlaced ? SchedulePosition.columnOfWeekday(weekDay) : -1;

  /// 在网格里的行下标，0..7；位置未知时为 -1。
  int get sectionIndex => isPlaced ? section - 1 : -1;

  Course copyWith({
    int? id,
    String? courseId,
    String? name,
    String? teacher,
    int? locationIndex,
    String? time,
    String? place,
    bool? isCurrentSemester,
  }) => Course(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    name: name ?? this.name,
    teacher: teacher ?? this.teacher,
    locationIndex: locationIndex ?? this.locationIndex,
    time: time ?? this.time,
    place: place ?? this.place,
    isCurrentSemester: isCurrentSemester ?? this.isCurrentSemester,
  );

  /// 同步时的身份键。一门课在一个学期里可以有多次课（不同格子/不同周次），
  /// 所以格子和周次都要进键，否则重复的行会被误判成新增。
  Object get identity =>
      '$courseId-${isCurrentSemester ? 1 : 0}-$locationIndex-$time';

  @override
  bool operator ==(Object other) =>
      other is Course &&
      other.courseId == courseId &&
      other.name == name &&
      other.teacher == teacher &&
      other.locationIndex == locationIndex &&
      other.time == time &&
      other.place == place &&
      other.isCurrentSemester == isCurrentSemester;

  @override
  int get hashCode => Object.hash(
    courseId,
    name,
    teacher,
    locationIndex,
    time,
    place,
    isCurrentSemester,
  );
}

/// 课程备注（旧 jsonclass/CourseNote.kt）。
@immutable
class CourseNote {
  const CourseNote({required this.courseId, this.note = ''});

  final String courseId;
  final String note;
}
