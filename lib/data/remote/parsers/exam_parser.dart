import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../models/exam/exam_model.dart';

/// 考试安排表 -> [ExamSchedule]。
///
/// 端口与旧项目 `_parseExamRow` 一致，但补了它缺的容错：
/// 旧实现直接 `cols.get(5)`，教务哪天少给一列就整个页面崩掉。
/// 这里所有列都是「越界返回空串」，并且把课程名为空的行丢掉
/// （登录失效页、提示行都会长这样）。表头是 `th`，自然也被丢掉。
abstract final class ExamParser {
  /// 课程名称所在列：序号 / 类型 / **课程** / 时间地点 / 状态 / 备注。
  /// 这一列空了说明整行不是数据行。
  static const int courseNameColumn = 2;

  static List<ExamSchedule> parse(String raw) {
    final host = _rowsHostOf(html_parser.parse(raw));
    if (host == null) return const [];
    return host
        .querySelectorAll('tr')
        .map(parseRow)
        .whereType<ExamSchedule>()
        .toList(growable: false);
  }

  /// 取行的地方：表头在 `thead` 里，所以优先只扫 `tbody`；
  /// 教务偶尔不给 `tbody`，这时退回第一个 `table`（表头是 `th`，会被丢掉）。
  static Element? _rowsHostOf(Document document) =>
      document.querySelector('tbody') ?? document.querySelector('table');

  /// 单行 -> ExamSchedule。不是数据行时返回 null。
  static ExamSchedule? parseRow(Element row) {
    final cells = row.querySelectorAll('td');
    final courseName = _cellText(cells, courseNameColumn);
    if (courseName.isEmpty) return null;
    return ExamSchedule(
      examType: _cellText(cells, 1),
      courseName: courseName,
      examTimeAndPlace: _squeeze(_cellText(cells, 3)),
      examStatus: _cellText(cells, 4),
      detail: _cellText(cells, 5),
    );
  }

  static String _cellText(List<Element> cells, int index) =>
      index < cells.length ? cells[index].text.trim() : '';

  /// 「考试时间地点」这一格里换行很多，先压成单行再展示。
  static String _squeeze(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
