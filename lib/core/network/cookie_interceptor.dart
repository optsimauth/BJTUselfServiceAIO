import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

/// 按 host 严格存取 cookie 的 dio 拦截器。
///
/// 为什么不用 `dio_cookie_manager`：它在响应是 3xx 时会把 `Set-Cookie`
/// **额外存到重定向目标 host**（见该包 `saveCookies` 里的 redirected 分支）。
/// CAS 登录成功后正好要跨 host 跳（cas.bjtu.edu.cn -> mis.bjtu.edu.cn），
/// 于是 CAS 的票据 `CASGC` 会被写进 MIS 的 cookie 罐、下一步原样发给 MIS；
/// Django 的 `csrftoken` 这种通用名更糟——两个站点的同名 cookie 会互相污染。
///
/// 浏览器只把 cookie 发给「设置它的那个 host」，所以这里也只按响应 host 存、
/// 按请求 host 取。配合 [RedirectFollower] 逐跳重发，每一跳的 `Set-Cookie`
/// 都能被这一跳自己的 host 接住。
class CookieStoreInterceptor extends Interceptor {
  CookieStoreInterceptor(this._jar);

  final CookieJar _jar;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final cookies = await _jar.loadForRequest(options.uri);
    // 没有 cookie 时置 null（而不是空串），免得发一个空的 Cookie 头出去。
    options.headers[HttpHeaders.cookieHeader] = cookies.isEmpty
        ? null
        : _buildCookieHeader(cookies);
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    await saveResponseCookies(response);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response != null) {
      await saveResponseCookies(response);
    }
    handler.next(err);
  }

  /// 把这一跳的 `Set-Cookie` 存到**发出这个响应的 host** 名下。
  Future<void> saveResponseCookies(Response<dynamic> response) {
    final cookies = parseSetCookieHeaders(response);
    if (cookies.isEmpty) {
      return Future<void>.value();
    }
    return _jar.saveFromResponse(response.requestOptions.uri, cookies);
  }

  /// 一个响应头里可能有多个 `Set-Cookie`，值本身也可能带逗号（Expires）。
  /// 逗号后面必须跟着 `名字=` 才是新 cookie 的开头。
  List<Cookie> parseSetCookieHeaders(Response<dynamic> response) {
    final raw = response.headers[HttpHeaders.setCookieHeader];
    if (raw == null || raw.isEmpty) {
      return const <Cookie>[];
    }
    return raw
        .expand((value) => value.split(_setCookieSeparator))
        .where((value) => value.trim().isNotEmpty)
        .map(parseSetCookieValue)
        .whereType<Cookie>()
        .toList();
  }

  /// 单条 `Set-Cookie` 解析。格式不对就跳过，不能让一个坏 cookie 打断整个请求。
  Cookie? parseSetCookieValue(String value) {
    try {
      return Cookie.fromSetCookieValue(value.trim());
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// 长路径的 cookie 排在前面（RFC 6265 里更具体的优先）。
  String _buildCookieHeader(List<Cookie> cookies) {
    if (cookies.isEmpty) {
      return '';
    }
    final sorted = [...cookies]
      ..sort((a, b) => (b.path ?? '').length.compareTo((a.path ?? '').length));
    return sorted.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  /// 逗号后面紧跟 `xxx=` 时才算新 cookie 开始。
  static final RegExp _setCookieSeparator = RegExp(r',(?=[^;]+?=)');
}
