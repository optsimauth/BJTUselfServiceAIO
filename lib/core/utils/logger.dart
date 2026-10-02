import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'log_recorder.dart';

enum LogLevel { debug, info, warn, error }

/// 全局日志入口，替代 Android 里的 Log.d/e + 散落的 println。
final class Logger {
  const Logger(this.tag);

  final String tag;

  void d(Object? message) => _log(LogLevel.debug, message);

  void i(Object? message) => _log(LogLevel.info, message);

  void w(Object? message, [Object? error]) =>
      _log(LogLevel.warn, message, error);

  void e(Object? message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    Object? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kReleaseMode && level.index < LogLevel.warn.index) {
      return;
    }
    // 报错额外落一份盘，崩了以后还能捞到（install 没跑完时静默跳过）。
    if (level == LogLevel.error) {
      LogRecorder.instance.record(level, tag, message, error, stackTrace);
    }
    developer.log(
      error == null ? '$message' : '$message | $error',
      name: tag,
      level: _levelValue(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _levelValue(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warn => 900,
    LogLevel.error => 1000,
  };
}
