// 下载进度：单文件、批量汇总、结束自动收起。
// 逻辑（visibleDownloads / summarizeDownloads）是纯函数，widget 只测渲染。
import 'dart:async';

import 'package:bjtuselfserviceaio/services/download/download_service.dart';
import 'package:bjtuselfserviceaio/shared/widgets/download_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadTask _task(
  String id, {
  DownloadStatus status = DownloadStatus.running,
  int received = 0,
  int total = 0,
  DateTime? finishedAt,
}) => DownloadTask(
  id: id,
  fileName: '$id.pdf',
  url: 'https://x/$id',
  status: status,
  receivedBytes: received,
  totalBytes: total,
  finishedAt: finishedAt,
);

/// 已结束的任务：真实服务会写 finishedAt，测试也得带上。
DownloadTask _done(
  String id,
  int received,
  int total, {
  DownloadStatus status = DownloadStatus.completed,
}) => _task(
  id,
  status: status,
  received: received,
  total: total,
  finishedAt: DateTime.now(),
);

void main() {
  group('显示哪些任务', () {
    final now = DateTime(2026, 10, 2, 12);

    test('进行中的永远显示', () {
      final visible = visibleDownloads([
        _task('a'),
        _task('b', status: DownloadStatus.queued),
      ], now);
      expect(visible.map((t) => t.id), ['a', 'b']);
    });

    test('刚结束的还留着，过了停留期就收走', () {
      final tasks = [
        _task('done', status: DownloadStatus.completed, finishedAt: now),
        _task(
          'old',
          status: DownloadStatus.completed,
          finishedAt: now.subtract(const Duration(seconds: 10)),
        ),
      ];
      expect(visibleDownloads(tasks, now).map((t) => t.id), ['done']);
    });

    test('一个任务都没有时什么都不显示（界面直接不占位）', () {
      expect(visibleDownloads(const [], now), isEmpty);
    });
  });

  group('批量汇总', () {
    test('按字节加权，不是按文件数平均', () {
      final summary = summarizeDownloads([
        _task('a', status: DownloadStatus.completed, received: 100, total: 100),
        _task('b', received: 10, total: 900),
      ]);
      expect(summary.finished, 1);
      expect(summary.total, 2);
      expect(summary.receivedBytes, 110);
      expect(summary.totalBytes, 1000);
      // 进度由调用方算，这里只给字节：110/1000 = 11%，不是 (100%+1%)/2
      expect(summary.receivedBytes / summary.totalBytes, closeTo(0.11, 0.001));
    });

    test('失败的单独计数', () {
      final summary = summarizeDownloads([
        _task('a', status: DownloadStatus.failed),
        _task('b', status: DownloadStatus.completed),
      ]);
      expect(summary.failed, 1);
      expect(summary.finished, 1);
    });
  });

  test('体积格式化', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
  });

  group('界面', () {
    late StreamController<Map<String, DownloadTask>> source;

    setUp(() => source = StreamController.broadcast());
    tearDown(() => source.close());

    Future<void> pumpBar(
      WidgetTester tester,
      Map<String, DownloadTask> tasks,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DownloadProgressBar(tasks: source.stream)),
        ),
      );
      source.add(tasks);
      await tester.pump();
    }

    testWidgets('单文件：直接显示文件名和百分比', (tester) async {
      await pumpBar(tester, {'a': _task('a', received: 5, total: 20)});
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('5 B / 20 B'), findsOneWidget);
    });

    testWidgets('多个文件：折叠成汇总，展开后逐个可见', (tester) async {
      await pumpBar(tester, {
        'a': _done('a', 1, 1),
        'b': _task('b', received: 1, total: 3),
        'c': _task('c', received: 0, total: 4),
      });

      // 汇总：1/3 完成，正在下 2 个
      expect(find.text('正在下载 1/3'), findsOneWidget);
      expect(find.text('a.pdf'), findsNothing, reason: '默认折叠');

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('b.pdf'), findsOneWidget);
      expect(find.text('c.pdf'), findsOneWidget);
    });

    testWidgets('全部失败时汇总行报失败数', (tester) async {
      await pumpBar(tester, {
        'a': _done('a', 0, 10, status: DownloadStatus.failed),
        'b': _done('b', 0, 10, status: DownloadStatus.failed),
      });
      expect(find.text('2 失败'), findsOneWidget);
    });

    testWidgets('没有任务时不占任何位置', (tester) async {
      await pumpBar(tester, const {});
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
