import 'package:dio/dio.dart';

enum NetworkErrorKind {
  timeout,
  noConnection,
  badResponse,
  unauthorized,
  parse,
  cancelled,
  unknown,
}

/// 所有网络层异常的唯一出口类型，UI 只需要 switch 这个枚举。
class NetworkException implements Exception {
  const NetworkException(
    this.kind,
    this.message, {
    this.statusCode,
    this.cause,
  });

  factory NetworkException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => NetworkErrorKind.timeout,
      DioExceptionType.connectionError => NetworkErrorKind.noConnection,
      DioExceptionType.cancel => NetworkErrorKind.cancelled,
      DioExceptionType.badResponse
          when statusCode == 401 || statusCode == 403 =>
        NetworkErrorKind.unauthorized,
      DioExceptionType.badResponse => NetworkErrorKind.badResponse,
      DioExceptionType.badCertificate => NetworkErrorKind.badResponse,
      DioExceptionType.unknown => NetworkErrorKind.unknown,
    };
    return NetworkException(
      kind,
      error.message ?? kind.name,
      statusCode: statusCode,
      cause: error,
    );
  }

  final NetworkErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  /// 需要重新登录的场景（cookie 过期、被踢下线）。
  bool get requiresReLogin => kind == NetworkErrorKind.unauthorized;

  @override
  String toString() =>
      'NetworkException(${kind.name}, $message, status: $statusCode)';
}
