import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/logger.dart';

/// 手动跟随重定向的 dio 拦截器。
///
/// 为什么不能交给 dio 自己跟（`followRedirects: true`）：
/// dio 把跟随交给 `dart:io` 的 [HttpClient]，**每一跳都在 dio 之外发生**，
/// dio 的拦截器链只会拿到最后一跳的响应。CAS 登录成功后那条链是
///
///   POST /auth/login/    --302 + Set-Cookie: CASGC-->  GET /o/authorize/
///   GET  /o/authorize/   --302 + Set-Cookie: state-->  GET mis.bjtu.edu.cn/auth/callback/
///   GET  /auth/callback/ --302 + Set-Cookie: sessionid--> GET /home/
///
/// 中间几跳 302 上的 `Set-Cookie` 就是登录态本身（CAS 票据 + MIS 的 sessionid）。
/// 它们写在 302 上、而 dio 看不见，于是 cookie 罐里一个都没有：
/// 第二跳发现没有票据就把登录页原样甩回来，表现是
/// 「账号、密码或验证码错误」——**可账号密码和验证码其实都对**。
///
/// 所以这里把每一跳都重发成一次完整的 dio 请求：这样
/// `CookieManager` 拦截器就能看到每一跳的 `Set-Cookie`，逐跳收进 cookie 罐。
class RedirectFollower extends Interceptor {
  RedirectFollower({this.maxHops = 15, Dio? dio}) : _dio = dio;

  static const Logger _log = Logger('RedirectFollower');

  /// 超过这个跳数就判定为异常跳转（死循环 / 站点配置错误）。
  final int maxHops;

  final Dio? _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 关掉 dart:io 的自动跟随，改由 [onResponse] 一跳一跳重发。
    options.followRedirects = false;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final target = resolveRedirectTarget(response);
    if (target == null) {
      handler.next(response);
      return;
    }
    if (isHopLimitReached(response, maxHops)) {
      handler.reject(tooManyRedirectsError(response), true);
      return;
    }
    unawaited(_resolveNextHop(response, target, handler));
  }

  /// 重发下一跳并把结果交给 dio。因为要跨 await，单独拎出来保持 [onResponse] 扁平。
  Future<void> _resolveNextHop(
    Response<dynamic> response,
    Uri target,
    ResponseInterceptorHandler handler,
  ) async {
    try {
      handler.resolve(await refetch(response, target));
    } on DioException catch (error) {
      handler.reject(error, true);
    }
  }

  /// 已经跟满 [limit] 跳还在跳，就是死循环或站点配置坏了。
  bool isHopLimitReached(Response<dynamic> response, int limit) =>
      redirectHopOf(response.requestOptions) >= limit;

  // ---- 叶子函数：判断 ----

  /// 这一跳要跟吗？是重定向就返回解析后的绝对地址，否则 null。
  Uri? resolveRedirectTarget(Response<dynamic> response) {
    if (!isRedirectStatus(response.statusCode ?? 0)) {
      return null;
    }
    final location = firstLocationHeader(response);
    if (location == null) {
      return null;
    }
    return response.requestOptions.uri.resolve(location);
  }

  /// 3xx 里只有 301/302/303/307/308 是跳转，300(多选) 和 304(未修改) 不是。
  bool isRedirectStatus(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  /// dio 会把重复的 Location 头合并成一行，取第一个即可。
  String? firstLocationHeader(Response<dynamic> response) {
    final raw = response.headers.value(HttpHeaders.locationHeader);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.split(',').first.trim();
  }

  /// 已跟了多少跳。存在 extra 里，跟着请求一路传下去。
  int redirectHopOf(RequestOptions options) =>
      (options.extra[_hopKey] as int?) ?? 0;

  /// 303 一律丢 body；302 且原方法是 POST 也丢（浏览器就是这么做的）；
  /// 307/308 要求保持原方法与 body。
  bool shouldDropBody(String method, int responseStatus) {
    if (responseStatus == 303) {
      return true;
    }
    return responseStatus == 302 && method.toUpperCase() != 'GET';
  }

  // ---- 叶子函数：重发 ----

  /// 造下一跳的请求选项。
  ///
  /// Cookie 头必须清掉：`CookieManager` 是按**新 host** 重算 cookie 头的，
  /// 留着旧 host 的头会把 CAS 的票据泄漏到 MIS 上去。
  /// 跳到新地址后 query 已经在 URL 里，清掉以免拼两次。
  RequestOptions buildNextHopOptions(
    RequestOptions options,
    Uri target,
    int hop, {
    required int responseStatus,
  }) {
    final dropBody = shouldDropBody(options.method, responseStatus);
    final next = options.copyWith(
      path: target.toString(),
      method: dropBody ? 'GET' : options.method,
      headers: buildNextHopHeaders(options.headers, dropBody: dropBody),
      extra: {...options.extra, _hopKey: hop},
      queryParameters: const {},
    );
    // copyWith 有两处「传 null 等于不传」的坑，这里逐个显式清：
    //  1. data 用 `data ?? this.data`，传 null 会保留旧 body；
    //  2. contentType 是独立字段，光删请求头它会被 headers setter 又塞回来。
    if (dropBody) {
      next.data = null;
      next.headers.remove(Headers.contentTypeHeader);
      next.contentType = null;
    }
    return next;
  }

  /// 换跳要重置的请求头：不带上一个 host 的 Cookie，也不带已经失效的实体头。
  ///
  /// 头名按 HTTP 语义大小写不敏感，但 dio 的 [Headers] 会把键规范化成小写、
  /// 手写的 Map 又未必，所以这里统一按小写比较。
  Map<String, dynamic> buildNextHopHeaders(
    Map<String, dynamic> headers, {
    required bool dropBody,
  }) {
    final dropped = <String>{
      HttpHeaders.cookieHeader.toLowerCase(),
      if (dropBody) ...[
        Headers.contentTypeHeader.toLowerCase(),
        Headers.contentLengthHeader.toLowerCase(),
      ],
    };
    return <String, dynamic>{
      for (final entry in headers.entries)
        if (!dropped.contains(entry.key.toLowerCase())) entry.key: entry.value,
    };
  }

  /// 把这一跳重发出去。走完整 dio 流程，cookie 拦截器才看得到这一跳的 Set-Cookie。
  Future<Response<dynamic>> refetch(Response<dynamic> response, Uri target) {
    final options = response.requestOptions;
    final hop = redirectHopOf(options) + 1;
    _log.d('跟随第 $hop 跳 -> $target');
    final dio = _dio;
    if (dio == null) {
      return Future<Response<dynamic>>.error(
        tooManyRedirectsError(
          response,
          message: 'RedirectFollower 没有绑定 Dio 实例',
        ),
      );
    }
    final next = buildNextHopOptions(
      options,
      target,
      hop,
      responseStatus: response.statusCode ?? 0,
    );
    return dio.fetch<dynamic>(next);
  }

  DioException tooManyRedirectsError(
    Response<dynamic> response, {
    String? message,
  }) {
    final uri = response.requestOptions.uri;
    return DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: '重定向超过 $maxHops 跳仍未落地：$uri',
      message: message ?? '重定向次数过多（$maxHops 跳）：$uri',
    );
  }

  static const String _hopKey = 'bjtuself/redirectHop';
}
