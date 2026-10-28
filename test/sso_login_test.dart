import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gm_crypto/gm_crypto.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:bjtuselfserviceaio/core/constants/api_constants.dart';
import 'package:bjtuselfserviceaio/core/model/common_models.dart';
import 'package:bjtuselfserviceaio/core/network/auth_exception.dart';
import 'package:bjtuselfserviceaio/core/network/cookie_manager.dart';
import 'package:bjtuselfserviceaio/core/network/http_client.dart';
import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/core/network/redirect_follower.dart';
import 'package:bjtuselfserviceaio/data/remote/api/auth_api.dart';
import 'package:bjtuselfserviceaio/data/remote/parsers/auth_parser.dart';
import 'package:bjtuselfserviceaio/data/remote/parsers/sso_parser.dart';
import 'package:bjtuselfserviceaio/services/auth/sso_password_cipher.dart';

const _publicHex =
    '0432C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0';
final _publicKey = base64Encode(SsoPasswordCipher.fromHex(_publicHex));
final _pageUri = Uri.parse(
  'https://sso.bjtu.edu.cn/o/authorize/?state=dynamic',
);
const _home = '<div class="name_right"><h3><a>测试用户</a></h3></div>';

String loginPage({
  String action = '/sso/login',
  bool encrypt = true,
  String extra = '',
}) =>
    '''
<script>var pageName = "login";
var ssoConfig = {"sm2":{"enabled":$encrypt,"publicKey":"$_publicKey"}};</script>
<form id="loginForm" method="post" action="$action">
<input name="flowId" value="flow-test"><input name="client_id" value="client-test">
<input name="redirect_uri" value="https://mis.bjtu.edu.cn/auth/ncallback/">
<input name="response_type" value="code"><input name="state" value="state-test">
<input name="username"><input name="password">
<input name="disabled" disabled value="no"><input name="unchecked" type="checkbox">
<input name="remember" type="checkbox" checked value="yes">$extra</form>
''';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  test('新版入口使用 nsso，保留动态 OAuth 字段并过滤禁用输入', () {
    expect(
      ApiConstants.ssoUrl,
      'https://mis.bjtu.edu.cn/auth/nsso/?next=/home/',
    );
    final form = SsoParser.parseLoginForm(loginPage(), _pageUri);
    expect(form.action.toString(), 'https://sso.bjtu.edu.cn/sso/login');
    expect(form.fields['state'], 'state-test');
    expect(form.fields['remember'], 'yes');
    expect(form.fields, isNot(contains('disabled')));
    expect(form.fields, isNot(contains('unchecked')));
    expect(form.publicKey, _publicKey);
  });

  for (final action in [
    'https://example.com/sso/login',
    'http://sso.bjtu.edu.cn/sso/login',
    'https://sso.bjtu.edu.cn:444/sso/login',
    'https://user@sso.bjtu.edu.cn/sso/login',
    '/wrong',
    '/sso/login?target=evil',
  ]) {
    test('拒绝不可信表单目标 $action', () {
      expect(
        () => SsoParser.parseLoginForm(loginPage(action: action), _pageUri),
        throwsA(isA<SsoLoginException>()),
      );
    });
  }

  for (final field in [
    'flowId',
    'client_id',
    'state',
    'response_type',
    'redirect_uri',
  ]) {
    test('缺少 $field 时不提交凭据', () {
      final html = loginPage().replaceAll('name="$field"', 'name="missing"');
      expect(
        () => SsoParser.parseLoginForm(html, _pageUri),
        throwsA(isA<SsoLoginException>()),
      );
    });
  }

  test('拒绝错误回调和未知页面来源', () {
    expect(
      () => SsoParser.parseLoginForm(
        loginPage().replaceAll(
          'https://mis.bjtu.edu.cn/auth/ncallback/',
          'https://example.com/auth/ncallback/',
        ),
        _pageUri,
      ),
      throwsA(isA<SsoLoginException>()),
    );
    expect(
      () => SsoParser.parseLoginForm(
        loginPage(),
        Uri.parse('https://example.com'),
      ),
      throwsA(isA<SsoLoginException>()),
    );
  });

  for (final script in [
    'var error = {"code":41100};',
    'var error = {"data":{"captchaType":"slider"}};',
    'var pageName = "mfa";',
  ]) {
    test('额外验证不会伪装成密码错误：$script', () {
      expect(
        () => SsoParser.requirePasswordLogin(script),
        throwsA(
          isA<SsoLoginException>().having(
            (e) => e.message,
            'message',
            contains('额外身份验证'),
          ),
        ),
      );
    });
  }

  test('无加密配置时失败，有明确关闭配置时遵循学校协议', () {
    expect(
      SsoParser.parseLoginForm(loginPage(encrypt: false), _pageUri).publicKey,
      isNull,
    );
    expect(
      () => SsoParser.encryptionKey(''),
      throwsA(isA<SsoLoginException>()),
    );
    expect(
      () => SsoParser.objectVariable('var error = {bad};', 'error'),
      throwsA(isA<SsoLoginException>()),
    );
    expect(
      () => SsoParser.requireLoginForm(html_parser.parse('')),
      throwsA(isA<SsoLoginException>()),
    );
  });

  test('MIS 成功检测必须同时满足可信地址与主页身份标记', () {
    expect(
      SsoParser.isMisHome(Uri.parse('${ApiConstants.misHost}/home/')),
      isTrue,
    );
    expect(
      SsoParser.isMisHome(Uri.parse('https://evil.example/home/')),
      isFalse,
    );
    expect(AuthParser.isAuthenticated(_home), isTrue);
    expect(
      AuthParser.isAuthenticated('$_home<form id="loginForm"></form>'),
      isFalse,
    );
  });

  for (final password in ['temporary-password', '临时密码123']) {
    test('SM2 C1C3C2 去前缀与 UTF-8：$password', () {
      final wire = SsoPasswordCipher.encrypt(password, _publicKey);
      final bytes = base64Decode(wire);
      expect(bytes.length, 96 + utf8.encode(password).length);
      expect(SM2.decrypt('04${SsoPasswordCipher.toHex(bytes)}', '1'), password);
      expect(SsoPasswordCipher.encrypt(password, _publicKey), isNot(wire));
    });
  }

  test('坏公钥返回安全错误，不回显密码', () {
    expect(
      () => SsoPasswordCipher.encrypt('secret', 'bad-key'),
      throwsA(
        isA<SsoLoginException>().having(
          (e) => e.message,
          'message',
          isNot(contains('secret')),
        ),
      ),
    );
  });

  test('完整模拟 SSO 链逐跳保存 Cookie，发送加密表单并落到 MIS 首页', () async {
    final cookies = AppCookieManager();
    final dio = HttpClientFactory.create(cookieManager: cookies);
    final requests = <RequestOptions>[];
    dio.httpClientAdapter = _Adapter((options) {
      requests.add(options);
      switch (requests.length) {
        case 1:
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [_pageUri.toString()],
              'set-cookie': ['mis_state=test; Path=/; Secure'],
            },
          );
        case 2:
          return ResponseBody.fromString(
            loginPage(),
            200,
            headers: {
              'set-cookie': ['sso_session=test; Path=/; Secure'],
            },
          );
        case 3:
          expect(options.method, 'POST');
          expect(
            options.contentType,
            contains('application/x-www-form-urlencoded'),
          );
          expect(options.headers['Origin'], 'https://sso.bjtu.edu.cn');
          expect(options.headers['cookie'], contains('sso_session=test'));
          expect(options.headers['cookie'], isNot(contains('mis_state')));
          final form = options.data as Map;
          expect(form['username'], 'test-student');
          expect(form['state'], 'state-test');
          expect(form['password'], isNot('test-password'));
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [
                '${ApiConstants.misHost}/auth/ncallback/?code=ticket',
              ],
              'set-cookie': ['sso_ticket=t; Path=/; Secure'],
            },
          );
        case 4:
          expect(options.method, 'GET');
          expect(options.data, isNull);
          expect(options.headers['cookie'], contains('mis_state=test'));
          expect(options.headers['cookie'], isNot(contains('sso_ticket')));
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['/home/'],
              'set-cookie': ['sessionid=authenticated; Path=/; Secure'],
            },
          );
        default:
          expect(
            options.headers['cookie'],
            contains('sessionid=authenticated'),
          );
          return ResponseBody.fromString(_home, 200);
      }
    });
    final api = AuthApi(
      RequestManager(dio: dio, ensureLoggedIn: () => fail('认证请求不能经过登录门闸')),
    );
    await api.login(
      const Credentials(username: 'test-student', password: 'test-password'),
    );
    expect(requests.length, 5);
    dio.close();
  });

  test('跳转检查只限制认证链，保留课程平台原 HTTP 入口', () {
    final follower = RedirectFollower();
    expect(
      follower.isUnsafeAuthRedirect(
        _pageUri,
        Uri.parse('http://mis.bjtu.edu.cn/home/'),
      ),
      isTrue,
    );
    expect(
      follower.isUnsafeAuthRedirect(
        _pageUri,
        Uri.parse('https://evil.example/'),
      ),
      isTrue,
    );
    expect(
      follower.isUnsafeAuthRedirect(
        Uri.parse('${ApiConstants.misHost}/module/module/28/'),
        Uri.parse(ApiConstants.coursePlatformHost),
      ),
      isFalse,
    );
  });
}
