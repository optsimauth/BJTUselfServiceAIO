import '../models/account/account_status.dart';
import '../remote/api/status_api.dart';
import '../remote/parsers/status_parser.dart';

/// 账户状态（余额 / 未读邮件）。
///
/// 这是「附加信息」：拿不到不影响首页其他内容，所以失败只抛错，由调用方决定
/// 显示「未知」。成功结果留在内存里，页面重建和离线时还能显示上一次的数值。
class StatusRepository {
  StatusRepository({required StatusApi api}) : _api = api;

  final StatusApi _api;

  AccountStatus? _cached;

  /// 上一次成功拿到的状态；从没成功过是 null。
  AccountStatus? get cached => _cached;

  Future<AccountStatus> fetch() async {
    final raw = await _api.fetchRaw();
    final status = StatusParser.parse(raw);
    _cached = status;
    return status;
  }

  void clear() => _cached = null;
}
