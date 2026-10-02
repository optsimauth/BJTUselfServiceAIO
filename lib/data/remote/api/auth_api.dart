import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';
import '../parsers/auth_parser.dart';

/// MIS + CAS 的原始请求。只负责拿到 HTML/字节，解析在 AuthParser 里。
///
/// 这里的每个请求都 `requireLogin: false`：它们是登录流程本身，
/// 要是还等"已登录"就死锁了（登录等请求、请求等登录）。
class AuthApi {
  const AuthApi(this._request);

  final RequestManager _request;

  /// 走 SSO 入口：已登录会直接落到 MIS 首页，未登录会 302 到 CAS 登录页。
  /// cookie 由 RequestManager 的 CookieJar 自动带上，不用手工拼 Cookie 头。
  Future<String> fetchSsoPage() =>
      _request.getText(ApiConstants.ssoUrl, requireLogin: false);

  /// 验证码图片。必须带 Referer，否则 CAS 会返回空图。
  Future<List<int>> fetchCaptchaImage({
    required String captchaKey,
    String? referer,
  }) => _request.downloadBytes(
    ApiConstants.captchaImageUrl(captchaKey),
    headers: {'Referer': referer ?? ApiConstants.casLoginPath},
    requireLogin: false,
  );

  /// 提交 CAS 登录表单。登录名/密码/验证码一次提交，不需要人工确认。
  Future<String> submitCasLogin(Map<String, String> form, {String? referer}) =>
      _request.postForm(
        ApiConstants.casLoginPath,
        form,
        requireLogin: false,
        headers: {
          'Referer': referer ?? ApiConstants.casLoginPath,
          'Origin': ApiConstants.casHost,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

  Future<String> checkMisCookie() =>
      _request.getText(ApiConstants.misModuleUrl, requireLogin: false);

  /// 课程平台入口。旧版先访问 module/28 建立跨站会话。
  Future<String> initializeCoursePlatform() =>
      _request.getText(ApiConstants.misModuleUrl, requireLogin: false);

  /// 教务入口不是最终页面：先解析 form#redirect，再访问 action 建立 AA 会话。
  Future<String> aaLogin() async {
    final page = await _request.getText(
      ApiConstants.misAaModuleUrl,
      requireLogin: false,
    );
    final action = AuthParser.parseRedirectAction(page);
    if (action == null) return page;
    final target = Uri.parse(ApiConstants.misAaModuleUrl).resolve(action);
    return _request.getText(
      target.toString(),
      headers: {'Referer': ApiConstants.misAaModuleUrl},
      requireLogin: false,
    );
  }

  Future<String> bksyLogin() =>
      _request.getText(ApiConstants.misBksyModuleUrl, requireLogin: false);
}
