import 'package:html/parser.dart' as html_parser;

import '../../models/account/account_model.dart';

/// MIS 首页与子系统跳转页面的解析。
abstract final class AuthParser {
  /// 读取 MIS 子系统跳转表单的 action。
  static String? parseRedirectAction(String html) {
    final document = html_parser.parse(html);
    final action = document
        .querySelector('form#redirect')
        ?.attributes['action'];
    return action == null || action.trim().isEmpty ? null : action.trim();
  }

  /// 重定向链最后落在 MIS 首页、页面里有用户名、且不再有登录表单 = 已登录。
  static bool isAuthenticated(String html) {
    final document = html_parser.parse(html);
    final userName =
        document.querySelector('.name_right h3 a')?.text.trim() ?? '';
    return userName.isNotEmpty &&
        document.querySelector('form#login, form#loginForm') == null;
  }

  /// 学生信息：姓名 / 部门 / 班级（旧 MisDataManager.getStatus 的三个字段）。
  static StudentProfile parseStudentProfile(
    String html, {
    String studentId = '',
  }) {
    final document = html_parser.parse(html);
    final name =
        document
            .querySelector('.name_right > h3 > a')
            ?.text
            .split('，')
            .first
            .trim() ??
        '';
    final spans = document.querySelectorAll('.name_right .nr_con span');

    String pick(String key) {
      final matched = spans.where((span) => span.text.contains(key)).toList();
      if (matched.isEmpty) {
        return '';
      }
      return matched.first.text
          .replaceFirst('$key：', '')
          .replaceFirst('$key:', '')
          .trim();
    }

    return StudentProfile(
      studentId: studentId,
      name: name,
      college: pick('部门'),
      className: pick('班级'),
    );
  }
}
