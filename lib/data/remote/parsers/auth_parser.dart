import 'package:html/parser.dart' as html_parser;

import '../../models/account/account_model.dart';

/// CAS 登录页的隐藏字段。不同学期字段名会变，全部集中在这里。
class LoginFields {
  const LoginFields({required this.csrf, required this.captchaKey, this.next});

  final String csrf;

  /// 对应 input#id_captcha_0，图片地址就是 /image/{captchaKey}/。
  final String captchaKey;
  final String? next;
}

/// MIS + CAS 登录页面的解析。
abstract final class AuthParser {
  static const String loginFormSelector = 'form#login';

  /// 优先在 form#login 内找，取不到再全页兜底（Android 版就是全页找的）。
  static String? fieldValue(String html, String selector) {
    final document = html_parser.parse(html);
    return document
            .querySelector('$loginFormSelector $selector')
            ?.attributes['value'] ??
        document.querySelector(selector)?.attributes['value'];
  }

  static LoginFields? parseLoginFields(String html) {
    final csrf = fieldValue(html, 'input[name=csrfmiddlewaretoken]');
    final captchaKey = fieldValue(html, 'input#id_captcha_0');
    if (csrf == null ||
        csrf.isEmpty ||
        captchaKey == null ||
        captchaKey.isEmpty) {
      return null;
    }
    return LoginFields(
      csrf: csrf,
      captchaKey: captchaKey,
      next: fieldValue(html, 'input[name=next]'),
    );
  }

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
        document.querySelector(loginFormSelector) == null;
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
