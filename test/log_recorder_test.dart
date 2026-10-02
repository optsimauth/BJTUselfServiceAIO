import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:bjtuselfserviceaio/core/utils/log_recorder.dart';
import 'package:bjtuselfserviceaio/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// record() 是 fire-and-forget（内部串行队列），测试里等它把文件写出来。
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('log_recorder_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('error 落到当天文件里，含 message/error/stack', () async {
    await LogRecorder.instance.setOverrideDirectory(temp.path);
    LogRecorder.instance.record(
      LogLevel.error,
      'Login',
      '登录失败',
      StateError('bad password'),
      StackTrace.current,
    );
    await _settle();

    final files = await LogRecorder.instance.listFiles();
    expect(files, hasLength(1));
    expect(p.basename(files.single.path), startsWith('log-'));

    final text = await files.single.readAsString();
    expect(text, contains('[ERROR] Login: 登录失败'));
    expect(text, contains('bad password'));
    expect(text, contains('log_recorder_test'));
  });

  test('每一行都带时间戳，不只是第一行', () async {
    await LogRecorder.instance.setOverrideDirectory(temp.path);
    LogRecorder.instance.record(
      LogLevel.error,
      'Net',
      '请求炸了',
      StateError('boom'),
      StackTrace.current,
    );
    await _settle();

    final text = await (await LogRecorder.instance.listFiles()).single
        .readAsString();
    final stamp = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} ');
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    expect(lines.length, greaterThan(3), reason: '要有 error 行和多行 stack');
    for (final line in lines) {
      expect(stamp.hasMatch(line), isTrue, reason: '这一行没有时间戳：$line');
    }
  });

  test('Logger.e 也走落盘，Logger.d 不落盘', () async {
    await LogRecorder.instance.setOverrideDirectory(temp.path);
    const Logger('Net').d('只有 debug');
    const Logger('Net').e('真的炸了', 'boom');
    await _settle();

    final text = await (await LogRecorder.instance.listFiles()).single
        .readAsString();
    expect(text, isNot(contains('只有 debug')));
    expect(text, contains('真的炸了'));
  });

  test('install 会清掉超过 keepDays 的旧文件，保留新的', () async {
    final old = File('${temp.path}/log-2000-01-01.txt')
      ..writeAsStringSync('old');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 30)));
    final fresh = File('${temp.path}/log-today.txt')..writeAsStringSync('new');

    await LogRecorder.instance.install(temp.path);
    await _settle();

    expect(await old.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });

  test('exportTo 把日志复制到目标目录，源文件保留', () async {
    await LogRecorder.instance.setOverrideDirectory(temp.path);
    LogRecorder.instance.record(LogLevel.error, 'X', '一条');
    await _settle();

    final target = Directory('${temp.path}/exported');
    final count = await LogRecorder.instance.exportTo(target);

    expect(count, 1);
    expect(await target.list().length, 1);
    expect(await LogRecorder.instance.listFiles(), hasLength(1));
  });
}
