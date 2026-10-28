import 'package:flutter/foundation.dart';

/// MIS 首页的账户状态：校园卡余额、校园网余额、未读邮件数。
///
/// 数据来自 `mis.bjtu.edu.cn/osys_ajax_wrap/`（旧项目 `MisDataManager.getStatus`），
/// 三个字段学校都给字符串，且可能是 `0`、`0.00`、`12.3` 这种不稳定格式，
/// 所以这里原样保留字符串，展示层再决定怎么写。
@immutable
class AccountStatus {
  const AccountStatus({this.ecardBalance, this.netBalance, this.unreadMail});

  static const AccountStatus empty = AccountStatus();

  /// 校园卡余额（元），学校原样返回，如 `23.50`。
  final String? ecardBalance;

  /// 校园网余额（元）。
  final String? netBalance;

  /// 未读邮件数。学校给的是字符串，解析不出数字就是 null。
  final int? unreadMail;

  bool get hasAny =>
      ecardBalance != null || netBalance != null || unreadMail != null;

  /// 校园卡余额低于 20 元时的提醒门槛 —— 旧项目同一阈值（`formatEcardBalance`）。
  static const double lowEcardThreshold = 20;

  bool get ecardIsLow {
    final value = double.tryParse(ecardBalance?.trim() ?? '');
    return value != null && value < lowEcardThreshold;
  }

  /// 校园网没钱了。`0` / `0.00` / `0.0` 都算。
  bool get netIsEmpty {
    final value = double.tryParse(netBalance?.trim() ?? '');
    return value != null && value <= 0;
  }

  AccountStatus copyWith({
    String? ecardBalance,
    String? netBalance,
    int? unreadMail,
  }) => AccountStatus(
    ecardBalance: ecardBalance ?? this.ecardBalance,
    netBalance: netBalance ?? this.netBalance,
    unreadMail: unreadMail ?? this.unreadMail,
  );
}
