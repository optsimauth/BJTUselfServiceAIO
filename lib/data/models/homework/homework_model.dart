import 'package:flutter/foundation.dart';

/// 作业类型，对应旧库 homeworkType 的 0/1/2。
enum HomeworkType {
  homework(0, '作业'),
  courseDesign(1, '课程设计'),
  experimentReport(2, '实验报告');

  const HomeworkType(this.value, this.label);

  final int value;
  final String label;

  static HomeworkType fromValue(int value) => HomeworkType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => HomeworkType.homework,
  );
}

@immutable
class HomeworkAttachment {
  const HomeworkAttachment({
    required this.id,
    required this.fileName,
    this.sizeBytes = 0,
    this.sourcePath = '',
  });

  final int id;
  final String fileName;
  final int sizeBytes;
  final String sourcePath;
}

/// 作业详情（正文 + 附件），旧代码的 SmartCurriculumPlatformRepository.HomeworkDetail。
@immutable
class HomeworkDetail {
  const HomeworkDetail({
    this.content = '',
    this.attachments = const [],
    this.error = '',
  });

  /// 平台返回错误时的详情。正文为空，界面据此显示失败原因。
  factory HomeworkDetail.failed(String message) =>
      HomeworkDetail(error: message);

  final String content;
  final List<HomeworkAttachment> attachments;

  /// 非空表示这次取详情失败了（平台 `STATUS != 0`）。
  final String error;

  bool get isFailed => error.isNotEmpty;

  bool get hasAttachments => attachments.isNotEmpty;
}

/// 作业。旧库 HomeworkEntity 字段一一对应。
@immutable
class Homework {
  const Homework({
    this.id = 0,
    required this.upId,
    this.idSnId,
    this.score = '',
    this.userId = 0,
    this.courseId = 0,
    required this.courseName,
    required this.title,
    this.content = '',
    this.createDate = '',
    this.endTime = '',
    this.openDate = '',
    this.status = 0,
    this.submitCount = 0,
    this.allCount = 0,
    this.subStatus = '',
    this.scoreId = 0,
    this.homeworkType = HomeworkType.homework,
  });

  final int id;
  final int upId;
  final int? idSnId;
  final String score;
  final int userId;
  final int courseId;
  final String courseName;
  final String title;
  final String content;
  final String createDate;
  final String endTime;
  final String openDate;
  final int status;
  final int submitCount;
  final int allCount;
  final String subStatus;
  final int scoreId;
  final HomeworkType homeworkType;

  Object get identity => '$courseName-$upId';

  /// 平台约定的「交了」的字面值。
  static const String submittedStatus = '已提交';

  /// 是不是已经交上去了。
  ///
  /// 只认平台的 `已提交` 这一个值：`subStatus` 还会是「已逾期」
  /// 「未提交」之类的别的字，那些都不是「交上去了」。
  bool get isSubmitted => subStatus.trim() == submittedStatus;

  /// 交了并且老师给过分。
  bool get isGraded => scoreId != 0 && score.trim().isNotEmpty;

  /// 没交、也没批改 —— 学生真正要动手的那一批。
  bool get needsAction => !isSubmitted && !isGraded;

  Homework copyWith({
    int? id,
    int? upId,
    int? idSnId,
    String? score,
    int? userId,
    int? courseId,
    String? courseName,
    String? title,
    String? content,
    String? createDate,
    String? endTime,
    String? openDate,
    int? status,
    int? submitCount,
    int? allCount,
    String? subStatus,
    int? scoreId,
    HomeworkType? homeworkType,
  }) => Homework(
    id: id ?? this.id,
    upId: upId ?? this.upId,
    idSnId: idSnId ?? this.idSnId,
    score: score ?? this.score,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    courseName: courseName ?? this.courseName,
    title: title ?? this.title,
    content: content ?? this.content,
    createDate: createDate ?? this.createDate,
    endTime: endTime ?? this.endTime,
    openDate: openDate ?? this.openDate,
    status: status ?? this.status,
    submitCount: submitCount ?? this.submitCount,
    allCount: allCount ?? this.allCount,
    subStatus: subStatus ?? this.subStatus,
    scoreId: scoreId ?? this.scoreId,
    homeworkType: homeworkType ?? this.homeworkType,
  );

  @override
  bool operator ==(Object other) =>
      other is Homework &&
      other.upId == upId &&
      other.courseName == courseName &&
      other.title == title &&
      other.score == score &&
      other.endTime == endTime &&
      other.subStatus == subStatus &&
      other.scoreId == scoreId &&
      other.idSnId == idSnId;

  @override
  int get hashCode => Object.hash(
    upId,
    courseName,
    title,
    score,
    endTime,
    subStatus,
    scoreId,
    idSnId,
  );
}
