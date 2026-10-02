import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// 错误日志落盘 + 手动导出。
///
/// 目录：设置里选的绝对路径；空 = 应用私有目录下的 `logs/`（和课件下载位置同一套逻辑）。
/// 文件：一天一个 `log-yyyy-MM-dd.txt`，纯文本追加，超大自动换新文件。
///
/// 硬规则：写日志失败绝不能把程序带崩。所有 IO 都吞掉异常。
class LogRecorder {
  LogRecorder._();

  static final LogRecorder instance = LogRecorder._();

  /// 单个文件超过这个大小就换新文件，防止一次死循环写满磁盘。
  static const int maxFileBytes = 512 * 1024;

  /// 启动时删掉比这更旧的日志。
  static const int keepDays = 7;

  /// 空 = 用应用私有目录。
  static const String _defaultFolderName = 'logs';

  static final DateFormat _day = DateFormat('yyyy-MM-dd');
  static final DateFormat _stamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  static final DateFormat _suffix = DateFormat('HHmmss');

  String _overrideDirectory = '';
  Directory? _directory;
  Future<void> _queue = Future<void>.value();

  /// 设置里选的那个目录，空串表示还没选过。
  String get overrideDirectory => _overrideDirectory;

  /// 当前生效的目录。解析失败是 null（写日志静默跳过）。
  Directory? get directory => _directory;

  /// 挂错误钩子。必须在 `runApp` 之前调，晚挂就丢了启动期崩溃。
  Future<void> install(String overrideDirectory) async {
    await setOverrideDirectory(overrideDirectory);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // 先照旧交给框架打印，debug 的红屏和 console 输出不能丢。
      previousOnError?.call(details);
      record(
        LogLevel.error,
        'FlutterError',
        '框架异常：${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
    };

    // 根 zone 里没被 catch 住的异步异常。返回 true = 我们处理了，别再往上抛。
    // ponytail: 没跑后台 isolate，所以不装 Isolate.addErrorListener；真有了再加。
    PlatformDispatcher.instance.onError = (error, stack) {
      record(LogLevel.error, 'PlatformDispatcher', '未捕获的异步异常', error, stack);
      return true;
    };

    unawaited(_purge());
  }

  /// 设置页改目录时调，之后的新日志立刻写进新地方。
  Future<void> setOverrideDirectory(String path) async {
    _overrideDirectory = path.trim();
    _directory = await _resolveDirectory();
  }

  void record(
    LogLevel level,
    String tag,
    Object? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final directory = _directory;
    // install 还没跑完就先不记，丢一条启动期日志比写日志把程序搞崩划算。
    if (directory == null) return;
    // 串行追加：并发写同一文件会交错成半行。
    _queue = _queue
        .then((_) => _append(directory, level, tag, message, error, stackTrace))
        .catchError((_) {});
  }

  /// 日志文件列表，最新的在前。
  Future<List<File>> listFiles() async {
    final directory = _directory;
    if (directory == null || !await directory.exists()) return const [];
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.txt'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// 把所有日志复制到 [target]，返回复制了几份。目录不存在就跳过。
  Future<int> exportTo(Directory target) async {
    await target.create(recursive: true);
    var count = 0;
    for (final file in await listFiles()) {
      await file.copy(p.join(target.path, p.basename(file.path)));
      count++;
    }
    return count;
  }

  Future<void> clear() async {
    for (final file in await listFiles()) {
      await file.delete();
    }
  }

  Future<Directory?> _resolveDirectory() async {
    try {
      final directory = _overrideDirectory.isEmpty
          ? Directory(
              p.join(
                (await getApplicationSupportDirectory()).path,
                _defaultFolderName,
              ),
            )
          : Directory(_overrideDirectory);
      await directory.create(recursive: true);
      return directory;
    } catch (error) {
      debugPrint('日志目录不可用，已禁用落盘：$error');
      return null;
    }
  }

  Future<void> _append(
    Directory directory,
    LogLevel level,
    String tag,
    Object? message,
    Object? error,
    StackTrace? stackTrace,
  ) async {
    try {
      final now = DateTime.now();
      final stamp = _stamp.format(now);
      final line = StringBuffer()
        ..writeln('$stamp [${level.name.toUpperCase()}] $tag: $message');
      // **每一行**都带时间戳，不只是第一行。
      //
      // 之前只有头一行有时间戳，error 和 stack 全是裸行；把几段错误贴到聊天里
      // 时根本分不清哪一帧属于哪一次崩溃 —— 每行独立可排序才算能查。
      if (error != null) {
        line.writeln(_stamped(stamp, '  error: $error'));
      }
      if (stackTrace != null) {
        line.writeln(_stamped(stamp, stackTrace.toString()));
      }
      line.writeln();
      final file = await _targetFile(directory, now);
      await file.writeAsString(
        line.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (error) {
      debugPrint('写日志失败：$error');
    }
  }

  /// 给多行文本的**每一行**补上同一个时间戳前缀，空行保持空行。
  ///
  /// 一条日志被贴到别处（issue、聊天）之后，每行都能自己说明属于哪一次事件；
  /// 只有首行带戳的话，中间的 stack 帧就是一堆没有上下文的裸行。
  static String _stamped(String stamp, String body) => body
      .trimRight()
      .split('\n')
      .map((text) => text.trim().isEmpty ? '' : '$stamp $text')
      .join('\n');

  /// 当天的文件没超限就继续追加，超了就另起一个带时间后缀的。
  Future<File> _targetFile(Directory directory, DateTime now) async {
    final daily = File(p.join(directory.path, 'log-${_day.format(now)}.txt'));
    if (!await daily.exists() || await daily.length() < maxFileBytes) {
      return daily;
    }
    final rotated = File(
      p.join(
        directory.path,
        'log-${_day.format(now)}-${_suffix.format(now)}.txt',
      ),
    );
    return await rotated.exists() ? _nextSuffix(directory, now) : rotated;
  }

  /// 同一秒内又超限：加毫秒当后缀。
  File _nextSuffix(Directory directory, DateTime now) => File(
    p.join(
      directory.path,
      'log-${_day.format(now)}-${DateFormat('HHmmss_SSS').format(now)}.txt',
    ),
  );

  /// 启动时清一次老文件，按修改时间算，比从文件名解析日期省事。
  Future<void> _purge() async {
    final directory = _directory;
    if (directory == null) return;
    final deadline = DateTime.now().subtract(const Duration(days: keepDays));
    for (final file in await listFiles()) {
      try {
        if ((await file.stat()).modified.isBefore(deadline)) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('清理旧日志失败：$error');
      }
    }
  }
}
