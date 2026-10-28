import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';
import '../../../core/model/common_models.dart';
import '../../../services/auth/sso_password_cipher.dart';
import '../parsers/auth_parser.dart';
import '../parsers/sso_parser.dart';

/// 新版 SSO 握手与 MIS 子系统入口，页面解析和密码加密分别交给专职模块。
///
/// 这里的每个请求都 `requireLogin: false`：它们是登录流程本身，
/// 要是还等"已登录"就死锁了（登录等请求、请求等登录）。
class AuthApi {
  const AuthApi(this._request);

  final RequestManager _request;

  /// 走 SSO 入口：已登录落到 MIS 首页，未登录跳到新版统一认证。
  /// cookie 由 RequestManager 的 CookieJar 自动带上，不用手工拼 Cookie 头。
  Future<String> fetchSsoPage() =>
      _request.getText(ApiConstants.ssoUrl, requireLogin: false);

  Future<FetchedText> openSsoLogin() =>
      _request.getTextWithFinalUri(ApiConstants.ssoUrl, requireLogin: false);

  Future<void> login(Credentials credentials) async {
    final page = await openSsoLogin();
    if (SsoParser.isMisHome(page.finalUri) &&
        AuthParser.isAuthenticated(page.body)) {
      return;
    }
    final form = SsoParser.parseLoginForm(page.body, page.finalUri);
    final response = await submitSsoLogin(form, page.finalUri, credentials);
    if (!SsoParser.isMisHome(response.finalUri) ||
        !AuthParser.isAuthenticated(response.body)) {
      SsoParser.rejectLogin(response.body);
    }
  }

  Future<FetchedText> submitSsoLogin(
    SsoLoginForm form,
    Uri referer,
    Credentials credentials,
  ) => _request.postFormWithFinalUri(
    form.action.toString(),
    {
      ...form.fields,
      'username': credentials.username,
      'password': form.publicKey == null
          ? credentials.password
          : SsoPasswordCipher.encrypt(credentials.password, form.publicKey!),
      'loginType': 'username_password',
    },
    headers: {
      'Referer': referer.toString(),
      'Origin': 'https://sso.bjtu.edu.cn',
    },
    requireLogin: false,
  );

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
