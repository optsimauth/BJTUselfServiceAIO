import '../../core/constants/api_constants.dart';
import 'api/course_api.dart';
import 'parsers/course_parser.dart';

/// 课程平台的会话头。
///
/// 平台所有 `.shtml` 接口都要带 `sessionid`，缺了就当未登录处理。
/// 这个 id 靠打一次 `message.shtml?method=getArticleList` 换回来
/// （旧项目 `getAndSetSessionIdInHeaders`），拿到就一直复用。
///
/// 并发的作业 / 课件同步共用同一次握手：[_pending] 保证它们不会各要一份。
class CoursePlatformSession {
  CoursePlatformSession({required CourseApi api}) : _api = api;

  final CourseApi _api;

  /// 平台拒绝非浏览器来源，Referer / XHR 头是必须的。
  static const Map<String, String> baseHeaders = {
    'Referer': ApiConstants.coursePlatformHost,
    'X-Requested-With': 'XMLHttpRequest',
  };

  Future<void>? _pending;

  String? _sessionId;

  /// 已经拿到的 sessionId；还没握手过是 null。
  String? get sessionId => _sessionId;

  /// 平台请求要带的头。
  ///
  /// 握手失败也照样返回基础头：让调用方拿到一个能读懂的接口错误，
  /// 比在网络层抛一个「null 头」强。
  Future<Map<String, String>> headers() async {
    await _handshake();
    final id = _sessionId;
    return id == null ? baseHeaders : {...baseHeaders, 'sessionid': id};
  }

  /// 丢掉缓存，下次 [headers] 重新握手。重新登录后调用。
  void invalidate() => _sessionId = null;

  Future<void> _handshake() =>
      _pending ??= _fetchOnce().whenComplete(() => _pending = null);

  Future<void> _fetchOnce() async {
    if (_sessionId != null) return;
    try {
      final raw = await _api.fetchPlatformSessionRaw(headers: baseHeaders);
      final id = CourseParser.parseSessionId(raw);
      if (id.isNotEmpty) _sessionId = id;
    } catch (_) {
      // 握手失败不缓存失败状态，下次调用会再试一次。
    }
  }
}
