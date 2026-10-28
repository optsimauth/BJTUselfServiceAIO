import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// MIS 首页状态接口。返回 JSON 文本，交给 `StatusParser` 解析。
class StatusApi {
  const StatusApi(this._request);

  final RequestManager _request;

  Future<String> fetchRaw() => _request.getText(
    ApiConstants.misStatusUrl,
    headers: const {'Accept': 'application/json, text/plain, */*'},
  );
}
