import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/download/download_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// 刚结束的任务还留在屏上多久。0 就看不到「已完成」了，3 秒够看清一句结果。
const downloadLinger = Duration(seconds: 3);

/// 该显示哪些任务：进行中的，加上刚结束还在停留期内的。
///
/// 纯函数：不碰 widget，所以能直接测。排序按加入顺序（Map 的插入序），
/// 队列是先来先下，界面上就跟着这个顺序走。
List<DownloadTask> visibleDownloads(
  Iterable<DownloadTask> tasks,
  DateTime now, {
  Duration linger = downloadLinger,
}) => tasks
    .where(
      (task) =>
          task.isActive ||
          (task.finishedAt != null &&
              now.difference(task.finishedAt!) < linger),
    )
    .toList(growable: false);

/// 一批下载的汇总：完成数 / 总数，以及按字节加权的总进度。
///
/// 用字节加权而不是「每个文件进度求平均」——一个 60MB 的视频和一个 8KB 的
/// 图各占一半进度条是骗人的。
({int finished, int total, int receivedBytes, int totalBytes, int failed})
summarizeDownloads(Iterable<DownloadTask> tasks) {
  var finished = 0, failed = 0, received = 0, bytes = 0;
  for (final task in tasks) {
    received += task.receivedBytes;
    bytes += task.totalBytes;
    if (task.status == DownloadStatus.completed) finished++;
    if (task.status == DownloadStatus.failed) failed++;
  }
  return (
    finished: finished,
    total: tasks.length,
    receivedBytes: received,
    totalBytes: bytes,
    failed: failed,
  );
}

/// 一条人类看得懂的体积：`8.2 MB`。小于 1KB 就给字节数。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

/// 全局下载进度条。
///
/// 挂在 `app.dart` 的 builder 里（[MaterialApp.router] 的 `builder`），
/// 于是**任何页面**发起的下载都会浮在底部：单文件一条，多文件折叠成
/// 汇总一条 + 可展开的每文件列表。
///
/// 没有自己的数据源，只吃一个 `Stream<Map<String, DownloadTask>>` ——
/// 数据是 [DownloadService] 的，这里只管显示。
class DownloadProgressBar extends StatefulWidget {
  const DownloadProgressBar({super.key, required this.tasks});

  final Stream<Map<String, DownloadTask>> tasks;

  @override
  State<DownloadProgressBar> createState() => _DownloadProgressBarState();
}

class _DownloadProgressBarState extends State<DownloadProgressBar> {
  /// 1 秒一跳：结束的任务要等停留期过了才消失，光靠流的新事件是等不到的
  /// （最后一批下完就不再有事件了）。没任务时定时器关掉，不空转。
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, DownloadTask>>(
      stream: widget.tasks,
      builder: (context, snapshot) {
        final visible = visibleDownloads(
          snapshot.data?.values ?? const <DownloadTask>[],
          DateTime.now(),
        );
        if (visible.isEmpty) return const SizedBox.shrink();
        return _DownloadPanel(tasks: visible);
      },
    );
  }
}

class _DownloadPanel extends StatefulWidget {
  const _DownloadPanel({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  State<_DownloadPanel> createState() => _DownloadPanelState();
}

class _DownloadPanelState extends State<_DownloadPanel> {
  /// 批量下载时默认折叠：一次下十几个文件，逐行展开会把整个屏幕糊住。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = widget.tasks;
    // 一个任务就是单文件下载，直接摊开给用户看；多个才折叠。
    final batch = tasks.length > 1;
    final summary = summarizeDownloads(tasks);
    final running = tasks.where((task) => task.isActive).length;
    final progress = summary.totalBytes <= 0
        ? 0.0
        : summary.receivedBytes / summary.totalBytes;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (running > 0)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      summary.failed > 0
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: summary.failed > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      batch
                          ? (running > 0
                                ? '正在下载 ${summary.finished}/${summary.total}'
                                : '下载结束 ${summary.finished}/${summary.total}')
                          : tasks.single.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (summary.failed > 0)
                    Text(
                      '${summary.failed} 失败',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (batch)
                    IconButton(
                      tooltip: _expanded ? '收起' : '展开',
                      visualDensity: VisualDensity.compact,
                      // 紧凑只是外观，命中区域仍按 HIG 的 44 走。
                      constraints: const BoxConstraints(
                        minWidth: AppTouch.minimum,
                        minHeight: AppTouch.minimum,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: AppRadius.bar,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.transparent,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatBytes(summary.receivedBytes)} / ${formatBytes(summary.totalBytes)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (tasks.any((task) => (task.error ?? '') != ''))
                    Text(
                      '失败：${tasks.firstWhere((task) => (task.error ?? '') != '').error}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
              if (batch && _expanded)
                for (final task in tasks) _FileRow(task: task),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展开后的单文件行：一个名字 + 一条细进度 + 大小。
class _FileRow extends StatelessWidget {
  const _FileRow({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = task.status == DownloadStatus.failed;
    final done = task.status == DownloadStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            failed
                ? Icons.error_outline
                : done
                ? Icons.check
                : Icons.downloading_outlined,
            size: 14,
            color: failed ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: AppRadius.bar,
                  child: LinearProgressIndicator(
                    value: failed ? 0 : task.progress,
                    minHeight: 2,
                    backgroundColor: AppColors.transparent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            task.totalBytes <= 0
                ? '${(task.progress * 100).toStringAsFixed(0)}%'
                : formatBytes(task.receivedBytes),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
