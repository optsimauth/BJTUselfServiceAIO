import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../models/homework/homework_model.dart';

/// 作业解析。
///
/// 平台的 JSON 是**蛇形命名**（`course_id` / `end_time` / `stu_score`…），
/// 和数据库列名对不上，写在这里而不是让模型去猜。
/// 端点见旧项目 `SmartCurriculumPlatformRepository`。
abstract final class HomeworkParser {
  /// 某门课某一类作业。响应是 `{"courseNoteList": [...]}`。
  ///
  /// 返回值里的 [course] 用来兜底：平台偶尔不给 `course_name`，
  /// 但我们知道这门课是谁。
  static List<Homework> parseList(
    String raw, {
    required HomeworkType homeworkType,
    required String courseName,
    required int courseId,
  }) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['courseNoteList'] as List<dynamic>? ??
              decoded['homeWorkList'] as List<dynamic>? ??
              const [])
        : (decoded as List<dynamic>);

    return [
      for (final item in list)
        if (item is Map)
          parseOne(
            item.cast<String, dynamic>(),
            homeworkType: homeworkType,
            fallbackCourseName: courseName,
            fallbackCourseId: courseId,
          ),
    ].where((homework) => homework.upId != 0).toList();
  }

  /// 一条作业。字段名按平台原文，不做驼峰兼容 ——
  /// 平台偶尔改字段名，与其猜不如让这里少一个字段、界面上少显示一行。
  static Homework parseOne(
    Map<String, dynamic> json, {
    required HomeworkType homeworkType,
    String fallbackCourseName = '',
    int fallbackCourseId = 0,
  }) {
    return Homework(
      upId: _int(json['id']) ?? 0,
      idSnId: _int(json['snId']),
      score: _text(json['stu_score']),
      userId: 0,
      courseId: _int(json['course_id']) ?? fallbackCourseId,
      courseName: _nonEmpty(_text(json['course_name'])) ?? fallbackCourseName,
      title: _text(json['title']),
      content: _text(json['content']),
      createDate: _text(json['create_date']),
      endTime: _text(json['end_time']),
      openDate: _text(json['open_date']),
      status: _int(json['status']) ?? 0,
      submitCount: _int(json['submitCount']) ?? 0,
      allCount: _int(json['allCount']) ?? 0,
      subStatus: _text(json['subStatus']),
      scoreId: _int(json['scoreId']) ?? 0,
      homeworkType: homeworkType,
    );
  }

  /// 作业详情：正文在 `homeWork`，附件在 `picList`。
  ///
  /// `STATUS != 0` 是平台自己的错误约定（旧项目据此抛异常），
  /// 这里返回 [HomeworkDetail.failed]，让上层决定怎么提示。
  static HomeworkDetail parseDetail(String raw, {String fallbackContent = ''}) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return HomeworkDetail(content: fallbackContent);
    }

    if (_text(decoded['STATUS']) != '0') {
      final message = _nonEmpty(_text(decoded['message']));
      return HomeworkDetail.failed(message ?? '平台没有返回作业详情');
    }

    final note = (decoded['homeWork'] as Map?)?.cast<String, dynamic>();
    final content = _nonEmpty(_text(note?['content'])) ?? fallbackContent;

    final attachments = <HomeworkAttachment>[
      for (final item in (decoded['picList'] as List<dynamic>? ?? const []))
        if (item is Map) _attachmentOf(item.cast<String, dynamic>()),
    ];

    return HomeworkDetail(content: content, attachments: attachments);
  }

  static HomeworkAttachment _attachmentOf(Map<String, dynamic> json) {
    final id = _int(json['id']) ?? 0;
    return HomeworkAttachment(
      id: id,
      // 平台把空格存成了 `+`，直接用会得到 `第1章+习题.pdf`。
      fileName: (_nonEmpty(_text(json['file_name'])) ?? '附件 $id').replaceAll(
        '+',
        ' ',
      ),
      sizeBytes: _int(json['pic_size']) ?? 0,
      sourcePath: _text(json['url']),
    );
  }

  /// 上传第一步的返回：`fileNameNoExt` / `fileExtName` / `fileSize` / `visitName`。
  /// 提交时要把它原样塞进 `fileList`。
  static String uploadedFileEntry(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return '{}';
    return jsonEncode({
      'fileNameNoExt': _text(decoded['fileNameNoExt']),
      'fileExtName': _text(decoded['fileExtName']),
      'fileSize': _text(decoded['fileSize']),
      'visitName': _text(decoded['visitName']),
      'pid': '',
      'ftype': 'insert',
    });
  }

  /// 分数页是个 HTML，分数藏在 `input#oldScore` 的 `value` 里
  /// （旧项目 `getHomeworkGrade`）。没有就是空串，不返回 "N/A"。
  static String parseScoreFromHtml(String html) {
    final document = html_parser.parse(html);
    final field = document.querySelector('#oldScore');
    final value = field?.attributes['value']?.trim();
    return value == null || value.isEmpty || value == 'null' ? '' : value;
  }

  // ---- 小工具 ----

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;

  static int? _int(Object? value) {
    final text = _text(value);
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }
}
