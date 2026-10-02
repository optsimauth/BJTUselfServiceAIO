import 'package:flutter/foundation.dart';

/// 学生基本信息。对应旧代码的 StudentAccountManager.StuInfo / Status。
@immutable
class StudentProfile {
  const StudentProfile({
    this.studentId = '',
    this.name = '',
    this.gender = '',
    this.college = '',
    this.major = '',
    this.className = '',
    this.grade = '',
  });

  static const StudentProfile empty = StudentProfile();

  final String studentId;
  final String name;
  final String gender;
  final String college;
  final String major;
  final String className;
  final String grade;

  bool get isEmpty => studentId.isEmpty && name.isEmpty;

  StudentProfile copyWith({
    String? studentId,
    String? name,
    String? gender,
    String? college,
    String? major,
    String? className,
    String? grade,
  }) => StudentProfile(
    studentId: studentId ?? this.studentId,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    college: college ?? this.college,
    major: major ?? this.major,
    className: className ?? this.className,
    grade: grade ?? this.grade,
  );

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'name': name,
    'gender': gender,
    'college': college,
    'major': major,
    'className': className,
    'grade': grade,
  };

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
    studentId: json['studentId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    college: json['college'] as String? ?? '',
    major: json['major'] as String? ?? '',
    className: json['className'] as String? ?? '',
    grade: json['grade'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is StudentProfile && other.studentId == studentId;

  @override
  int get hashCode => studentId.hashCode;
}

/// 各子系统的登录态。MIS / 教务 / 本科生院是分开登录的（旧代码三个 boolean）。
@immutable
class AccountLoginStatus {
  const AccountLoginStatus({
    this.misLoggedIn = false,
    this.aaLoggedIn = false,
    this.bksyLoggedIn = false,
  });

  final bool misLoggedIn;
  final bool aaLoggedIn;
  final bool bksyLoggedIn;

  bool get allLoggedIn => misLoggedIn && aaLoggedIn && bksyLoggedIn;
}
