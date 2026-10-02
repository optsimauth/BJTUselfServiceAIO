import 'dart:convert';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../../models/grade/grade_model.dart';
import '../../models/grade/grade_score_format.dart';

/// 成绩解析。旧代码在 `MisDataManager.getGrade` 里直接抠 HTML 表格。
///
/// 教务成绩页的表格列（tr 里的一组 td）：
/// `0 序号 / 1 学年学期 / 2 课程名称 / 3 学分 / 4 成绩 / 5 绩点 / 6 任课教师 / 7 备注`。
/// 备注列藏在一个 `span[data-content]` 里，是 HTML 片段，旧代码抠出来后还要
/// 再剖一层 `div[style*=200px]` 才拿得到正文。
abstract final class GradeParser {
  static List<Grade> parse(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _parseJson(raw);
    }
    return _parseHtml(raw);
  }

  // ---- HTML（aa 教务成绩页）----

  static List<Grade> _parseHtml(String raw) {
    final document = html_parser.parse(raw);
    final result = <Grade>[];
    for (final row in document.querySelectorAll('table tr')) {
      final grade = _gradeFromRow(row);
      if (grade != null) {
        result.add(grade);
      }
    }
    return result;
  }

  /// 一行 td 转一条成绩。表头是 th 不产生 td（天然跳过）；「合计」这类行
  /// 课程名是空的，也跳过 —— 不用旧代码「remove 掉第一行」那种位置硬编码。
  static Grade? _gradeFromRow(html_dom.Element row) {
    final tds = row.querySelectorAll('td');
    // 至少要有 序号/学期/名称/学分/成绩 这五列；更瘦的行不是成绩行。
    if (tds.length < 5) {
      return null;
    }
    String textAt(int index) => _clean(tds[index].text);
    final courseName = textAt(2);
    if (courseName.isEmpty) {
      return null;
    }
    final year = textAt(1); // 学年学期，courseYear 和 tag 都填它（旧代码同款）。
    // 「合计/平均」这类页脚行只有合计列有字，学年学期是空的，直接不算成绩。
    if (year.isEmpty) {
      return null;
    }
    var credits = textAt(3);
    if (credits.isEmpty) {
      credits = '0.0'; // 旧代码缺学分写 0.0，防止加权计算把这一门算炸。
    }
    return Grade(
      courseName: courseName,
      courseTeacher: tds.length > 6 ? textAt(6) : '',
      courseScore: GradeScoreFormat.format(textAt(4)),
      courseCredits: credits,
      courseYear: year,
      tag: year,
      detail: tds.length > 7 ? _detailFrom(tds[7]) : '',
    );
  }

  /// 备注列：`span[data-content]` 里的 HTML 片段 -> 多行文本。
  static String _detailFrom(html_dom.Element td) {
    final span = td.querySelector('span[data-content]');
    final content = span?.attributes['data-content'];
    if (content == null || content.isEmpty) {
      return '';
    }
    final fragment = html_parser.parseFragment(content);
    final container = fragment.querySelector('[style*="200px"]') ?? fragment;
    final buffer = StringBuffer();
    void visit(html_dom.Node node) {
      if (node is html_dom.Text) {
        buffer.write(node.text);
      } else if (node is html_dom.Element) {
        if (node.localName == 'br') {
          buffer.write('\n');
        } else {
          node.nodes.forEach(visit);
        }
      }
    }

    visit(container);
    final lines = buffer
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return lines.join('\n');
  }

  // ---- JSON（少数接口直接给 JSON，兜底）----

  static List<Grade> _parseJson(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['gradeList'] as List<dynamic>? ?? const <dynamic>[])
        : (decoded as List<dynamic>);
    return list.map((item) {
      final json = (item as Map).cast<String, dynamic>();
      return Grade(
        courseName: json['courseName']?.toString() ?? '',
        courseTeacher: json['courseTeacher']?.toString() ?? '',
        courseScore: GradeScoreFormat.format(
          json['courseScore']?.toString() ?? '',
        ),
        courseCredits: json['courseCredits']?.toString() ?? '',
        courseYear: json['courseYear']?.toString() ?? '',
        tag: json['tag']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
      );
    }).toList();
  }

  /// 两个来源（ln / lr）合并，去掉完全重复的一条（旧代码按三元组 distinct）。
  static List<Grade> merge(List<Grade> first, List<Grade> second) {
    final seen = <String, Grade>{};
    for (final grade in [...first, ...second]) {
      final key =
          '${grade.courseName}|${grade.courseScore}|${grade.courseCredits}';
      seen.putIfAbsent(key, () => grade);
    }
    return seen.values.toList();
  }

  /// 清掉 td 文本里的换行 / 制表 / 空格 —— HTTP 表格里这些是排版残留。
  static String _clean(String text) => text.replaceAll(RegExp(r'\s+'), '');
}
