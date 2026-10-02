import 'package:flutter/foundation.dart';

/// 课程平台（本学期我在上的课）里的一门课。
///
/// 和 [Course] 是两回事，别混：
/// - [Course] 是**教务课表**里的格子，有星期/节次/地点，不落库到平台；
/// - [PlatformCourse] 是**智慧教学平台**的课程条目，作业和课件都按它来查。
///
/// [id] 是平台内部的数字主键，作业列表接口要拿它当 `cId`；
/// [teacherId] 是教师工号，作业详情接口不给就返回不了内容。
@immutable
class PlatformCourse {
  const PlatformCourse({
    required this.id,
    required this.courseNum,
    required this.name,
    this.teacherName = '',
    this.teacherId = '',
    this.fzId = '',
    this.semesterCode = '',
  });

  /// 平台主键（JSON 里的 `id`）。
  final int id;

  /// 课程号（`course_num`），也是课件接口的 `courseId`。
  final String courseNum;

  final String name;

  final String teacherName;

  /// 教师工号（`teacher_id`）。作业详情必须带。
  final String teacherId;

  /// 选课助手号（`fz_id`）。课件资源树和教学日历都要带。
  final String fzId;

  /// 学期号（`xq_code`）。课件资源树和教学日历都要带。
  final String semesterCode;

  /// 能不能用来查作业详情：没有教师工号平台不给内容。
  bool get canFetchHomeworkDetail => id != 0 && teacherId.isNotEmpty;

  /// 能不能查课件：资源树接口要课程号、选课助手号、学期号三者齐全，
  /// 少一个平台就当不是选了这门课，返回空列表。
  bool get canFetchCourseware =>
      courseNum.isNotEmpty && fzId.isNotEmpty && semesterCode.isNotEmpty;

  PlatformCourse copyWith({
    int? id,
    String? courseNum,
    String? name,
    String? teacherName,
    String? teacherId,
    String? fzId,
    String? semesterCode,
  }) => PlatformCourse(
    id: id ?? this.id,
    courseNum: courseNum ?? this.courseNum,
    name: name ?? this.name,
    teacherName: teacherName ?? this.teacherName,
    teacherId: teacherId ?? this.teacherId,
    fzId: fzId ?? this.fzId,
    semesterCode: semesterCode ?? this.semesterCode,
  );

  @override
  bool operator ==(Object other) =>
      other is PlatformCourse &&
      other.id == id &&
      other.courseNum == courseNum &&
      other.name == name &&
      other.teacherName == teacherName &&
      other.teacherId == teacherId &&
      other.fzId == fzId &&
      other.semesterCode == semesterCode;

  @override
  int get hashCode => Object.hash(
    id,
    courseNum,
    name,
    teacherName,
    teacherId,
    fzId,
    semesterCode,
  );

  @override
  String toString() => 'PlatformCourse($id, $courseNum, $name)';
}
