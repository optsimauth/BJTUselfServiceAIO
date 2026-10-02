import 'dart:convert';

import 'package:dio/dio.dart';

import 'network_exception.dart';

/// 一次取回的文本 + 它最终落地的地址。
class FetchedText {
  const FetchedText({required this.body, required this.finalUri});

  final String body;
  final Uri finalUri;

  /// 最终地址上的查询参数。
  String? queryParameter(String key) => finalUri.queryParameters[key];
}

/// 一次 HEAD 的结果：状态码 + 响应头。
///
/// 课件的最终文件名只写在 `Content-Disposition` 里，文件本体在另一个域名上，
/// 所以要先用 HEAD 探一次头，别为了一个文件名把整份 PDF 拉下来。
class FetchedHead {
  const FetchedHead({required this.statusCode, required this.headers});

  final int statusCode;

  /// 响应头名一律小写。
  final Map<String, String> headers;

  String? header(String name) => headers[name.toLowerCase()];

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}

/// 所有网络调用的入口。业务层只拿 [RequestManager]，不碰 Dio 细节。
///
/// 没有队列、没有排队去重：调了就直接发。
class RequestManager {
  RequestManager({required this.dio, required this.ensureLoggedIn});

  final Dio dio;

  /// 没登录就抛异常。由 [AccountRepository] 提供，这里只知道调它。
  final void Function() ensureLoggedIn;

  /// 发一条请求：先过登录门闸，再执行 [send]，Dio 异常统一转成 [NetworkException] 抛出。
  ///
  /// [requireLogin] 传 false 表示这条请求免登录（登录流程自己用）：
  /// 登录/取验证码这类「把状态从没登录变成已登录」的请求必须传 false。
  Future<T> request<T>(
    Future<T> Function() send, {
    bool requireLogin = true,
  }) async {
    if (requireLogin) {
      ensureLoggedIn();
    }
    try {
      return await send();
    } on DioException catch (error) {
      throw NetworkException.fromDio(error);
    }
  }

  Future<String> getText(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<String>(() async {
      final response = await dio.get<String>(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain, headers: headers),
      );
      return response.data ?? '';
    }, requireLogin: requireLogin);
  }

  /// 拿文本 + 跳转后的最终地址。
  ///
  /// 教务有些页面把参数藏在 302 之后（例如教室状态页把当前教学周放在
  /// `zc` 查询参数里），只拿到 body 是不够的。
  Future<FetchedText> getTextWithFinalUri(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<FetchedText>(() async {
      final response = await dio.get<String>(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain, headers: headers),
      );
      return FetchedText(body: response.data ?? '', finalUri: response.realUri);
    }, requireLogin: requireLogin);
  }

  Future<String> postForm(
    String url,
    Map<String, dynamic> form, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<String>(() async {
      final response = await dio.post<String>(
        url,
        queryParameters: query,
        data: FormData.fromMap(form),
        options: Options(responseType: ResponseType.plain, headers: headers),
      );
      return response.data ?? '';
    }, requireLogin: requireLogin);
  }

  /// [body] 传 Map 走 jsonEncode；传 String 则原样当请求体发出去。
  /// Coremail 的 `!!date` 日期字面量不是合法 JSON，只有这条路能发出去。
  Future<String> postJson(
    String url, {
    required Object body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<String>(() async {
      final response = await dio.post<String>(
        url,
        queryParameters: query,
        data: body is String ? body : jsonEncode(body),
        options: Options(
          responseType: ResponseType.plain,
          contentType: 'text/x-json; tz="Asia/Shanghai"',
          headers: headers,
        ),
      );
      return response.data ?? '';
    }, requireLogin: requireLogin);
  }

  Future<String> postFormUrlEncoded(
    String url,
    Map<String, dynamic> form, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<String>(() async {
      final response = await dio.post<String>(
        url,
        queryParameters: query,
        data: form,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          headers: headers,
        ),
      );
      return response.data ?? '';
    }, requireLogin: requireLogin);
  }

  /// 只取响应头（HEAD）。文件本体不下。
  Future<FetchedHead> head(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<FetchedHead>(() async {
      final response = await dio.head<String>(
        url,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          // 405/501 一律按失败抛出去，调用方会退回用平台自己的文件名。
          validateStatus: _isHeadOk,
        ),
      );
      return FetchedHead(
        statusCode: response.statusCode ?? 0,
        headers: _flattenHeaders(response.headers.map),
      );
    }, requireLogin: requireLogin);
  }

  /// 只接受 2xx。返回 false 时 Dio 抛 [DioException]，由外层转成网络错误。
  static bool _isHeadOk(int? status) =>
      status != null && status >= 200 && status < 300;

  /// Dio 的头是多值列表，展平成「小写名 -> 逗号连接的值」。
  static Map<String, String> _flattenHeaders(Map<String, List<String>> raw) {
    final result = <String, String>{};
    raw.forEach((name, values) {
      result[name.toLowerCase()] = values.join(', ');
    });
    return result;
  }

  /// 带文件的表单提交（作业上传）。
  ///
  /// [FormData.fromMap] 会把字符串当普通字段，文件必须显式包成
  /// [MultipartFile]，否则服务端收不到文件本体。
  Future<String> postMultipart(
    String url, {
    required String fileField,
    required String filePath,
    String? fileName,
    Map<String, String> fields = const {},
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requireLogin = true,
  }) {
    return request<String>(() async {
      final form = FormData.fromMap({
        ...fields,
        fileField: await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await dio.post<String>(
        url,
        queryParameters: query,
        data: form,
        options: Options(responseType: ResponseType.plain, headers: headers),
      );
      return response.data ?? '';
    }, requireLogin: requireLogin);
  }

  /// 下载二进制（成绩单 PDF、课件、作业附件）。
  Future<List<int>> downloadBytes(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    ProgressCallback? onReceiveProgress,
    bool requireLogin = true,
  }) {
    return request<List<int>>(() async {
      final response = await dio.get<List<int>>(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes, headers: headers),
        onReceiveProgress: onReceiveProgress,
      );
      return response.data ?? const <int>[];
    }, requireLogin: requireLogin);
  }
}
