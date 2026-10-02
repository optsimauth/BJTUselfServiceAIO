import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/network/request_manager.dart';
import '../../core/platform/platform_service.dart';
import '../../core/storage/preferences.dart';

enum DownloadStatus { queued, running, completed, failed }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.fileName,
    required this.url,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.localPath,
    this.error,
    this.finishedAt,
  });

  final String id;
  final String fileName;
  final String url;
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String? localPath;
  final Object? error;

  /// 结束（成功或失败）的时刻。用来判断「这条要不要再显示一会儿」——
  /// 没有它，界面只能一直挂着上一批下载的记录。
  final DateTime? finishedAt;

  /// 还在排队或正在传。
  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.running;

  double get progress => totalBytes <= 0 ? 0 : receivedBytes / totalBytes;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? localPath,
    Object? error,
    DateTime? finishedAt,
  }) => DownloadTask(
    id: id,
    fileName: fileName,
    url: url,
    status: status ?? this.status,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    localPath: localPath ?? this.localPath,
    error: error ?? this.error,
    finishedAt: finishedAt ?? this.finishedAt,
  );
}

/// 下载网关：并发上限 + 进度广播，替代旧 DownloadUtil。
///
/// 落盘位置只有这一处决定：[targetDirectory]。所有下载 —— 课件、成绩单、
/// 校历、教学日历、导出的课表 .ics —— 都落在同一个目录下：
///
///     <设置里选的目录 或 系统下载目录>/bjtuselfserviceaio/[子目录...]
///
/// 真正「往哪写文件」交给 PlatformService。
class DownloadService {
  DownloadService({
    required RequestManager request,
    required PlatformService platform,
    required AppPreferences preferences,
    this.maxConcurrent = AppConstants.maxConcurrentDownloads,
  }) : _request = request,
       _platform = platform,
       _preferences = preferences;

  final RequestManager _request;
  final PlatformService _platform;
  final AppPreferences _preferences;
  final int maxConcurrent;

  final Queue<_PendingDownload> _pending = Queue<_PendingDownload>();
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  final StreamController<Map<String, DownloadTask>> _controller =
      StreamController<Map<String, DownloadTask>>.broadcast();

  int _active = 0;

  Stream<Map<String, DownloadTask>> get tasks => _controller.stream;

  Map<String, DownloadTask> get snapshot => Map.unmodifiable(_tasks);

  Future<String> download({
    required String url,
    required String fileName,
    String? name,
    Map<String, String>? headers,

    /// app 文件夹之下的子目录（如课件的「高等数学/第1章」）。
    List<String> folders = const [],
  }) {
    final taskId = name ?? url;
    final completer = Completer<String>();
    _pending.add(
      _PendingDownload(
        taskId: taskId,
        url: url,
        fileName: fileName,
        headers: headers,
        completer: completer,
        folders: folders,
      ),
    );
    _tasks[taskId] = DownloadTask(id: taskId, fileName: fileName, url: url);
    _publish();
    _pump();
    return completer.future;
  }

  /// 已经在内存里的字节（成绩单、校历、课表 .ics 等）直接落盘。
  Future<String> saveBytes({
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    List<String> folders = const [],
  }) async {
    final path = await _platform.saveToDownloads(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      directory: await targetDirectory(folders),
    );
    if (path == null || path.isEmpty) {
      throw StateError('保存 $fileName 失败');
    }
    return path;
  }

  /// 下载落盘的目录：<根目录>/bjtuselfserviceaio/[folders...]。
  ///
  /// 根目录 = 设置里选的目录；没选就用系统下载目录。
  /// [folders] 是 app 文件夹之下的子目录（课件按课程分层）。
  Future<String> targetDirectory(List<String> folders) async {
    final root = _preferences.downloadDirectory.trim();
    final base = root.isEmpty
        ? await _platform.downloadsDirectory()
        : Directory(root);
    return p.joinAll([base.path, AppConstants.downloadAppFolder, ...folders]);
  }

  void _pump() {
    while (_pending.isNotEmpty && _active < maxConcurrent) {
      final job = _pending.removeFirst();
      _active++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_PendingDownload job) async {
    _update(job.taskId, status: DownloadStatus.running);
    try {
      final bytes = await _request.downloadBytes(
        job.url,
        headers: job.headers,
        onReceiveProgress: (received, total) =>
            _update(job.taskId, receivedBytes: received, totalBytes: total),
      );
      // 平台层写盘失败只记进 task 的 error 里，下载本身仍按成功计。
      final path =
          await _platform.saveToDownloads(
            fileName: job.fileName,
            bytes: bytes,
            directory: await targetDirectory(job.folders),
          ) ??
          job.fileName;
      _update(job.taskId, status: DownloadStatus.completed, localPath: path);
      job.completer.complete(path);
    } catch (error) {
      _update(job.taskId, status: DownloadStatus.failed, error: error);
      job.completer.completeError(error);
    } finally {
      _active--;
      _pump();
    }
  }

  void _update(
    String taskId, {
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? localPath,
    Object? error,
  }) {
    final current = _tasks[taskId];
    if (current == null) {
      return;
    }
    _tasks[taskId] = current.copyWith(
      status: status,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      localPath: localPath,
      error: error,
      // 成功/失败那一刻记时间：界面靠它决定「再显示 3 秒就收起来」。
      finishedAt:
          status == DownloadStatus.completed || status == DownloadStatus.failed
          ? DateTime.now()
          : null,
    );
    _publish();
  }

  void _publish() {
    if (!_controller.isClosed) {
      _controller.add(Map.unmodifiable(_tasks));
    }
  }

  void dispose() {
    _controller.close();
    _pending.clear();
  }
}

final class _PendingDownload {
  _PendingDownload({
    required this.taskId,
    required this.url,
    required this.fileName,
    required this.completer,
    this.headers,
    this.folders = const [],
  });

  final String taskId;
  final String url;
  final String fileName;
  final Map<String, String>? headers;
  final Completer<String> completer;
  final List<String> folders;
}
