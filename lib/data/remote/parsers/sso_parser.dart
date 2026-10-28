import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/auth_exception.dart';

class SsoLoginForm {
  const SsoLoginForm({
    required this.action,
    required this.fields,
    required this.publicKey,
  });
  final Uri action;
  final Map<String, String> fields;
  final String? publicKey;
}

/// 学校新版 SSO 协议；只解析数据，不执行页面脚本。
abstract final class SsoParser {
  static SsoLoginForm parseLoginForm(String html, Uri pageUri) {
    requireSsoUri(pageUri);
    final document = html_parser.parse(html);
    final scripts = inlineScripts(document);
    requirePasswordLogin(scripts);
    final form = requireLoginForm(document);
    final action = pageUri.resolve(form.attributes['action'] ?? '');
    requireSsoUri(action);
    if (action.path != '/sso/login' || action.hasQuery) {
      throw const SsoLoginException('认证提交地址发生变化，请更新应用后重试');
    }
    final fields = successfulFields(form);
    requireOauthFields(fields);
    return SsoLoginForm(
      action: action,
      fields: fields,
      publicKey: encryptionKey(scripts),
    );
  }

  static void requireSsoUri(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != 'sso.bjtu.edu.cn' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const SsoLoginException('认证地址不可信，已停止提交账号密码');
    }
  }

  static String inlineScripts(Document document) => document
      .querySelectorAll('script:not([src])')
      .map((script) => script.text)
      .join('\n');

  static void requirePasswordLogin(String scripts) {
    final error = objectVariable(scripts, 'error');
    final data = error?['data'];
    final page = RegExp(r'''\bvar\s+pageName\s*=\s*["']([^"']+)["']''')
        .firstMatch(scripts)
        ?.group(1);
    if (error?['code'] == 41100 ||
        error?['code'] == 41102 ||
        (data is Map && data.containsKey('captchaType')) ||
        (page != null && page != 'login')) {
      throw const SsoLoginException('学校要求额外身份验证，请先在学校统一认证网页完成验证后重试');
    }
  }

  static Element requireLoginForm(Document document) {
    final form = document.querySelector('form#loginForm');
    if (form == null || form.attributes['method']?.toLowerCase() != 'post') {
      throw const SsoLoginException('未找到新版统一认证表单，请稍后重试');
    }
    return form;
  }

  static Map<String, String> successfulFields(Element form) => {
    for (final input in form.querySelectorAll('input[name]'))
      if (isSuccessfulInput(input))
        input.attributes['name']!: input.attributes['value'] ?? '',
  };

  static bool isSuccessfulInput(Element input) {
    final type = input.attributes['type']?.toLowerCase() ?? 'text';
    if (input.attributes.containsKey('disabled') ||
        ['reset', 'button', 'file', 'submit', 'image'].contains(type)) {
      return false;
    }
    return !['checkbox', 'radio'].contains(type) ||
        input.attributes.containsKey('checked');
  }

  static void requireOauthFields(Map<String, String> fields) {
    final callback = Uri.tryParse(fields['redirect_uri'] ?? '');
    if ([
          'flowId',
          'client_id',
          'state',
        ].any((key) => fields[key]?.isNotEmpty != true) ||
        fields['response_type'] != 'code' ||
        callback == null ||
        callback.scheme != 'https' ||
        callback.host != 'mis.bjtu.edu.cn' ||
        callback.port != 443 ||
        callback.userInfo.isNotEmpty ||
        callback.path != '/auth/ncallback/' ||
        callback.hasFragment) {
      throw const SsoLoginException('统一认证参数不完整或回调不可信，请重新登录');
    }
  }

  static String? encryptionKey(String scripts) {
    final config = objectVariable(scripts, 'ssoConfig');
    final sm2 = config?['sm2'];
    if (sm2 is! Map || sm2['enabled'] is! bool) {
      throw const SsoLoginException('统一认证加密配置无效');
    }
    if (sm2['enabled'] == false) return null;
    final key = sm2['publicKey'];
    if (key is! String || key.isEmpty) {
      throw const SsoLoginException('统一认证缺少密码加密公钥');
    }
    return key;
  }

  static Map<String, dynamic>? objectVariable(String scripts, String name) {
    final pattern = RegExp(
      '\\bvar\\s+${RegExp.escape(name)}\\s*=\\s*(\\{.*?\\}|null)\\s*;',
      dotAll: true,
    );
    final raw = pattern.firstMatch(scripts)?.group(1);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      throw const SsoLoginException('统一认证页面配置无法解析');
    }
  }

  static bool isMisHome(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == Uri.parse(ApiConstants.misHost).host &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      ['/home', '/home/'].contains(uri.path);

  static Never rejectLogin(String html) {
    requirePasswordLogin(inlineScripts(html_parser.parse(html)));
    throw const SsoLoginException('登录未成功，请检查学号和密码后重试');
  }
}
