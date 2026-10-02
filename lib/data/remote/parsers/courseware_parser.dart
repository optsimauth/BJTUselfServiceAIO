import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../../core/constants/api_constants.dart';
import '../../models/course/platform_course.dart';
import '../../models/courseware/courseware_model.dart';

/// 课件解析。端点与字段见旧项目 `SmartCurriculumPlatformRepository` /
/// `CoursewareScreen`。
abstract final class CoursewareParser {
  /// 平台偶尔把空列表写成空串：`"resList": ""`。
  ///
  /// 这不是合法 JSON，`jsonDecode` 会直接抛，所以旧项目在解析前用正则把它
  /// 换成 `[]`。这里保留同样的预处理 —— 但用非贪婪的最小匹配，
  /// 免得同一份响应里有个文件名恰好含 `resList` 就被误伤。
  static final RegExp _emptyListField = RegExp(
    r'"(resList|bagList)"\s*:\s*""',
    caseSensitive: false,
  );

  static String _normalizeEmptyLists(String raw) => raw.replaceAllMapped(
    _emptyListField,
    (match) => '"${match.group(1)}": []',
  );

  /// 一层资源（某个 `up_id` 下的所有文件夹和文件）。
  ///
  /// 顺序和旧代码一致：先文件夹（要递归往下展开）后文件。
  static List<CoursewareNode> parseResourceLayer(
    String raw, {
    required PlatformCourse course,
  }) {
    final decoded = _decodeObject(_normalizeEmptyLists(raw));
    final nodes = <CoursewareNode>[];
    for (final bag in _listOf(decoded['bagList'])) {
      final node = _bag(bag, course: course);
      // 没有名字的文件夹在界面上没法显示，直接丢。
      if (node != null) nodes.add(node);
    }
    for (final res in _listOf(decoded['resList'])) {
      final node = _res(res, course: course);
      if (node != null) nodes.add(node);
    }
    return nodes;
  }

  /// 文件夹。`bag_name` 是显示名，`id` 拿去当下一层的 `up_id`。
  static CoursewareNode? _bag(Object? raw, {required PlatformCourse course}) {
    final json = _mapOf(raw);
    if (json == null) return null;
    final name = _string(json['bag_name']) ?? _string(json['bagName']);
    if (name == null) return null;
    return CoursewareNode(
      id: '${json['id'] ?? ''}',
      name: name,
      kind: CoursewareKind.bag,
      course: course,
    );
  }

  /// 文件。`rpId` 是下载必需的，`rpName` 是显示名。
  static CoursewareNode? _res(Object? raw, {required PlatformCourse course}) {
    final json = _mapOf(raw);
    if (json == null) return null;
    final name = _string(json['rpName']) ?? _string(json['rp_name']);
    if (name == null) return null;
    return CoursewareNode(
      id: '${json['resId'] ?? json['res_id'] ?? ''}',
      name: name,
      kind: CoursewareKind.res,
      rpId: _string(json['rpId']) ?? _string(json['rp_id']) ?? '',
      extension: (_string(json['extName']) ?? _string(json['ext_name']) ?? '')
          .replaceAll('.', '')
          .toLowerCase(),
      sizeText: _string(json['rpSize']) ?? _string(json['rp_size']) ?? '',
      teacherName:
          _string(json['teacherName']) ?? _string(json['teacher_name']) ?? '',
      updatedAt:
          _string(json['inputTime']) ?? _string(json['input_time']) ?? '',
      downloadCount:
          _int(json['downloadNum']) ?? _int(json['download_num']) ?? 0,
      course: course,
    );
  }

  /// 换下载地址的响应：`{"flag": true, "rpUrl": "http://..."}`。
  ///
  /// `rpUrl` 为空说明平台没给（一般是没权限），这里如实抛出去，
  /// 让界面显示平台给的 `message` 而不是笼统的「下载失败」。
  static String parseDownloadUrl(String raw) {
    final decoded = _decodeObject(raw);
    final url = _string(decoded['rpUrl']) ?? _string(decoded['rp_url']);
    if (url != null) return url;
    final message = _string(decoded['message']) ?? _string(decoded['msg']);
    throw StateError(message ?? '平台没有返回下载地址');
  }

  /// 课程平台页 -> 教学日历 PDF 地址。
  ///
  /// iframe 的 `src` 是文件服务器上的一个深层路径，真正的 PDF 在
  /// `123.121.147.7:1936/kk/rp/` 后面**再拼路径的最后 5 段**。
  /// 段数不够 5 就返回空串 —— 硬拼只会得到一个打不开的地址。
  static String parseTeachingCalendarUrl(String html) {
    final document = html_parser.parse(html);
    final src =
        document.querySelector('iframe#pdfIframe')?.attributes['src'] ?? '';
    if (src.isEmpty) return '';
    final segments = src
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length < 5) return '';
    return '${ApiConstants.teachingCalendarHost}'
        '${segments.sublist(segments.length - 5).join('/')}';
  }

  /// 课程平台页 -> 教师工号。教学日历那一步会先确认工号拿到了再往下走。
  static String parseTeacherId(String html) {
    final document = html_parser.parse(html);
    final value =
        document.querySelector('input#teacherId')?.attributes['value'] ?? '';
    return value.trim();
  }

  /// 从 `Content-Disposition` 里取文件名。取不到返回空串。
  ///
  /// 旧项目是 `split(";")[1].trim().split("=").last()`：只认分号分隔的第 1 段、
  /// 且假定等号后没有引号。真实响应有三种写法都会踩雷：
  /// - `attachment;filename=a.pdf`（没有空格）—— 分段没问题，等号后也干净；
  /// - `attachment; filename="第一章.pdf"` —— 残留一对引号，存盘就多两个字符；
  /// - `attachment; filename*=UTF-8''%E7%AC%AC...`（RFC 5987）—— 中文名全是百分号编码。
  ///
  /// 所以这里按优先级 `filename*` > `filename`，再去引号并做百分号解码。
  static String parseFileName(String? contentDisposition) {
    if (contentDisposition == null) return '';
    final extended = _parameter(contentDisposition, 'filename*');
    if (extended != null) {
      final decoded = _decodeExtendedValue(extended);
      if (decoded.isNotEmpty) return decoded;
    }
    final plain = _parameter(contentDisposition, 'filename');
    if (plain == null) return '';
    return plain.trim().replaceAll(RegExp(r'^"|"$'), '');
  }

  /// 取 `name=value` 里的 value，忽略大小写和两侧空白。
  static String? _parameter(String header, String name) {
    final pattern = RegExp(
      '${RegExp.escape(name)}\\s*=\\s*([^;]+)',
      caseSensitive: false,
    );
    return pattern.firstMatch(header)?.group(1);
  }

  /// `UTF-8''%E7%AC%AC%E4%B8%80%E7%AB%A0.pdf` -> `第一章.pdf`。
  static String _decodeExtendedValue(String value) {
    final parts = value.trim().split("'");
    final encoded = parts.length >= 3
        ? parts.sublist(2).join("'")
        : value.trim();
    return Uri.decodeComponent(encoded);
  }

  // ---- 小工具 ----

  static Map<String, dynamic> _decodeObject(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const FormatException('课件接口返回的不是对象');
  }

  static List<Object?> _listOf(Object? value) {
    if (value is List) return value;
    // 平台偶尔给 `"resList": null`，当空列表处理。
    return const [];
  }

  static Map<String, dynamic>? _mapOf(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) => int.tryParse('${value ?? ''}'.trim());
}
