import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../constants/app_constants.dart';
import 'cookie_manager.dart';
import 'redirect_follower.dart';

/// 统一的 Dio 工厂。
/// 学校旧站点证书链经常不完整（旧版 OkHttp 也是直接信任全部证书），
/// 所以这里显式放开证书校验，并统一 UA / 超时 / cookie。
abstract final class HttpClientFactory {
  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36 Edg/137.0.0.0';

  static Dio create({
    AppCookieManager? cookieManager,
    String baseUrl = '',
    Map<String, String> headers = const {},
    Duration timeout = AppConstants.requestTimeout,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        followRedirects: true,
        // 学校接口大量返回 302 + HTML，别让 dio 直接抛错。
        validateStatus: (status) => status != null && status < 500,
        headers: {'User-Agent': userAgent, ...headers},
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // 学校旧站点证书链不完整：直接信任，和旧版 OkHttp 的行为保持一致。
        client.badCertificateCallback = (_, _, _) => true;
        client.connectionTimeout = timeout;
        return client;
      },
    );

    // 顺序要紧：CookieManager 在前，跟随器在后。
    // dio 的响应拦截器按注册顺序执行，所以每一跳的 Set-Cookie 会**先**被
    // CookieManager 收进 cookie 罐，跟随器才决定要不要重发下一跳——
    // 下一跳正好用得到刚存下的票据。
    if (cookieManager != null) {
      dio.interceptors.add(cookieManager.interceptor);
    }
    dio.interceptors.add(RedirectFollower(dio: dio));
    return dio;
  }
}
