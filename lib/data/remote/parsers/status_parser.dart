import 'dart:convert';

import '../../models/account/account_status.dart';

/// `osys_ajax_wrap` 的 JSON 解析。
///
/// 只认明确的三个字段。解析不出任何字段就抛 [FormatException] —— 登录失效时
/// 这个地址会返回登录页 HTML，绝不能把那种响应当成「余额 0」显示出来。
abstract final class StatusParser {
  static const String ecardKey = 'ecard_yuer';
  static const String netKey = 'net_fee';
  static const String mailKey = 'newmail_count';

  static AccountStatus parse(String raw) {
    final text = raw.trim();
    if (!text.startsWith('{')) {
      throw const FormatException('状态接口返回的不是 JSON，可能登录已失效');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('状态接口返回的 JSON 不是对象');
    }
    final ecard = _text(decoded[ecardKey]);
    final net = _text(decoded[netKey]);
    final mail = _int(decoded[mailKey]);
    if (ecard == null && net == null && mail == null) {
      throw const FormatException('状态接口没有返回余额或未读数');
    }
    return AccountStatus(
      ecardBalance: ecard,
      netBalance: net,
      unreadMail: mail,
    );
  }

  /// 学校有时给数字、有时给字符串。
  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value is String ? value.trim() : '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(_text(value) ?? '');
  }
}
