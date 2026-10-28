import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import 'cookie_interceptor.dart';

/// 登录态 cookie 的唯一持有者（内存 CookieJar）。
///
/// 冷启动用安全存储里的凭据重新完成 SSO，不把短期认证票据落盘。
class AppCookieManager {
  AppCookieManager({CookieJar? jar}) : _jar = jar ?? CookieJar();

  final CookieJar _jar;

  /// 挂到 Dio 上，让所有请求自动带 cookie / 自动回写 cookie。
  Interceptor get interceptor => CookieStoreInterceptor(_jar);

  CookieJar get jar => _jar;

  /// 手工拼 Cookie 头，给不走 Dio 的下载/WebView 场景复用。
  Future<String> cookieHeaderFor(Uri uri) async {
    final cookies = await _jar.loadForRequest(uri);
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Future<void> clear() => _jar.deleteAll();
}
