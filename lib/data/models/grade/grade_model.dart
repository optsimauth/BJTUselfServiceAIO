import 'package:flutter/foundation.dart';

/// 成绩。旧库 GradeEntity 里去掉了自增 id 之外的字段完全一致。
@immutable
class Grade {
  const Grade({
    this.id = 0,
    required this.courseName,
    this.courseTeacher = '',
    this.courseScore = '',
    this.courseCredits = '',
    this.courseYear = '',
    this.tag = '',
    this.detail = '',
  });

  final int id;
  final String courseName;
  final String courseTeacher;
  final String courseScore;
  final String courseCredits;
  final String courseYear;

  /// 成绩勾选功能用的学期标记（成绩表里的 tag 列）。
  final String tag;
  final String detail;

  bool get isFail => courseScore.contains('不及格') || courseScore == '0';

  Grade copyWith({
    int? id,
    String? courseName,
    String? courseTeacher,
    String? courseScore,
    String? courseCredits,
    String? courseYear,
    String? tag,
    String? detail,
  }) => Grade(
    id: id ?? this.id,
    courseName: courseName ?? this.courseName,
    courseTeacher: courseTeacher ?? this.courseTeacher,
    courseScore: courseScore ?? this.courseScore,
    courseCredits: courseCredits ?? this.courseCredits,
    courseYear: courseYear ?? this.courseYear,
    tag: tag ?? this.tag,
    detail: detail ?? this.detail,
  );

  Object get identity => courseName;

  @override
  bool operator ==(Object other) =>
      other is Grade &&
      other.courseName == courseName &&
      other.courseTeacher == courseTeacher &&
      other.courseScore == courseScore &&
      other.courseCredits == courseCredits &&
      other.courseYear == courseYear &&
      other.tag == tag &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(
    courseName,
    courseTeacher,
    courseScore,
    courseCredits,
    courseYear,
    tag,
    detail,
  );
}

/// 用户在成绩页手动勾选的记录，持久化在 AppPreferences 里（按学号分组）。
@immutable
class GradeSelectionRecord {
  const GradeSelectionRecord({
    required this.courseName,
    this.courseTeacher = '',
    this.courseYear = '',
    this.semester = '',
    this.lastKnownScore = '',
    this.lastKnownCredits = '',
    this.occurrence = 1,
  });

  final String courseName;
  final String courseTeacher;
  final String courseYear;
  final String semester;
  final String lastKnownScore;
  final String lastKnownCredits;
  final int occurrence;

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'courseTeacher': courseTeacher,
    'courseYear': courseYear,
    'semester': semester,
    'lastKnownScore': lastKnownScore,
    'lastKnownCredits': lastKnownCredits,
    'occurrence': occurrence,
  };

  factory GradeSelectionRecord.fromJson(Map<String, dynamic> json) =>
      GradeSelectionRecord(
        courseName: json['courseName'] as String? ?? '',
        courseTeacher: json['courseTeacher'] as String? ?? '',
        courseYear: json['courseYear'] as String? ?? '',
        semester: json['semester'] as String? ?? '',
        lastKnownScore: json['lastKnownScore'] as String? ?? '',
        lastKnownCredits: json['lastKnownCredits'] as String? ?? '',
        occurrence: json['occurrence'] as int? ?? 1,
      );
}
