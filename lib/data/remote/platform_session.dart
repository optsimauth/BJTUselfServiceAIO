import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
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

  static const Logger _log = Logger('CoursePlatform');

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
  /// 会话没建立起来就抛错，**不能**静默用基础头继续请求：那样平台会把我们当匿名，
  /// 课程清单返回空数组，作业/课件页面只会显示一句「没有课程」，
  /// 真正的原因（登录过期 / 平台入口打不开）被吞掉。
  Future<Map<String, String>> headers() async {
    await _handshake();
    final id = _sessionId;
    if (id == null) {
      throw StateError('课程平台会话没建立（sessionid 为空），可能是登录已过期');
    }
    return {...baseHeaders, 'sessionid': id};
  }

  /// 丢掉缓存，下次 [headers] 重新握手。重新登录后调用。
  void invalidate() => _sessionId = null;

  Future<void> _handshake() =>
      _pending ??= _fetchOnce().whenComplete(() => _pending = null);

  Future<void> _fetchOnce() async {
    if (_sessionId != null) return;

    // 顺序不能换（旧项目 `initializeClient`）：
    // 1) 先访问 MIS 的课程平台模块入口，走它自己的跳转链、落下 MIS Cookie；
    // 2) 再打 message.shtml 换 sessionid。
    // 少了第 1 步，平台会当成匿名访问 —— 这正是「课程清单为空、作业和课件打不开」的原因。
    try {
      await _api.fetchMisCoursePage();
      _log.i('MIS 课程平台入口已访问');
    } catch (error) {
      _log.w('MIS 课程平台入口打不开', error);
      throw StateError('课程平台入口打不开：$error');
    }

    final raw = await _api.fetchPlatformSessionRaw(headers: baseHeaders);
    // 会话接口正常回 `{"sessionId": "..."}`；登录被踢回来的是登录页 HTML，
    // jsonDecode 会抛 —— 两种情况都归到「没拿到会话」这一句可操作的提示里。
    var id = '';
    try {
      id = CourseParser.parseSessionId(raw);
    } catch (_) {
      id = '';
    }
    if (id.isEmpty) {
      _log.w('会话接口没有 sessionid，返回内容开头：${raw.length > 80 ? raw.substring(0, 80) : raw}');
      throw StateError('课程平台没有返回 sessionid，可能是登录已过期，重新登录后再试');
    }
    _sessionId = id;
    _log.i('课程平台会话已建立');
  }
}
