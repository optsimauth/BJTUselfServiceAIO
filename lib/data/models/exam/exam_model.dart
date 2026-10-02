import 'package:flutter/foundation.dart';

/// 考试安排。旧库 ExamScheduleEntity 字段一一对应。
@immutable
class ExamSchedule {
  const ExamSchedule({
    this.id = 0,
    required this.examType,
    required this.courseName,
    this.examTimeAndPlace = '',
    this.examStatus = '',
    this.detail = '',
  });

  final int id;

  /// 期中 / 期末 / 补考。
  final String examType;
  final String courseName;
  final String examTimeAndPlace;
  final String examStatus;
  final String detail;

  Object get identity => '$examType-$courseName';

  ExamSchedule copyWith({
    int? id,
    String? examType,
    String? courseName,
    String? examTimeAndPlace,
    String? examStatus,
    String? detail,
  }) => ExamSchedule(
    id: id ?? this.id,
    examType: examType ?? this.examType,
    courseName: courseName ?? this.courseName,
    examTimeAndPlace: examTimeAndPlace ?? this.examTimeAndPlace,
    examStatus: examStatus ?? this.examStatus,
    detail: detail ?? this.detail,
  );

  @override
  bool operator ==(Object other) =>
      other is ExamSchedule &&
      other.examType == examType &&
      other.courseName == courseName &&
      other.examTimeAndPlace == examTimeAndPlace &&
      other.examStatus == examStatus &&
      other.detail == detail;

  @override
  int get hashCode =>
      Object.hash(examType, courseName, examTimeAndPlace, examStatus, detail);
}
