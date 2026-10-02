import 'dart:convert';

import '../../core/platform/platform_service.dart';
import '../../core/state/data_sync_manager.dart';
import '../../core/state/pending_sync.dart';
import '../../core/state/sync_module.dart';
import '../../core/state/sync_result.dart';
import '../../services/download/download_service.dart';
import '../local/local_stores.dart';
import '../mock/mock_lists.dart';
import '../models/course/platform_course.dart';
import '../models/homework/homework_model.dart';
import '../remote/api/homework_api.dart';
import '../remote/parsers/homework_parser.dart';
import '../remote/platform_session.dart';
import 'platform_course_repository.dart';

/// 作业：按课程逐门拉列表 + 详情 + 上传 + 附件下载。
class HomeworkRepository {
  HomeworkRepository({
    required HomeworkApi api,
    required HomeworkLocalStore localStore,
    required PlatformCourseRepository courseRepository,
    required CoursePlatformSession session,
    required DownloadService downloadService,
    required PlatformService platformService,
  }) : _api = api,
       _localStore = localStore,
       _courseRepository = courseRepository,
       _session = session,
       _downloadService = downloadService,
       _platformService = platformService,
       _syncManager = DataSyncManager<Homework>(
         store: localStore,
         identity: (homework) => homework.identity,
         changed: (current, previous) =>
             current.score != previous.score ||
             current.subStatus != previous.subStatus ||
             current.status != previous.status ||
             current.idSnId != previous.idSnId ||
             current.endTime != previous.endTime ||
             current.title != previous.title,
         mergeIds: (current, previous) => current.copyWith(id: previous.id),
       );

  final HomeworkApi _api;
  final HomeworkLocalStore _localStore;
  final PlatformCourseRepository _courseRepository;
  final CoursePlatformSession _session;
  final DownloadService _downloadService;
  final PlatformService _platformService;
  final DataSyncManager<Homework> _syncManager;

  Stream<List<Homework>> watchAll() => _localStore.watchAll();

  Future<SyncResult> sync() async => (await prepareSync()).commit();

  /// 每门课、每种作业独立比较；请求失败的分片完全不参与删除。
  Future<PendingSync> prepareSync() async {
    final courses = await _courses();
    if (courses.isEmpty && !MockList.homework) throw StateError('作业刷新失败：没有课程');
    final headers = await _session.headers();
    final local = await _localStore.getAll();
    final changes = <DataChange<Homework>>[];
    var succeeded = false;
    for (final course in courses) {
      for (final type in HomeworkType.values) {
        final remote = await _tryFetch(course, type, headers);
        if (remote == null) continue;
        final withScores = await Future.wait(remote.map(_tryAttachScore));
        final localSlice = local
            .where(
              (item) => item.courseId == course.id && item.homeworkType == type,
            )
            .toList();
        changes.addAll(
          _syncManager.detectChanges(remote: withScores, local: localSlice),
        );
        succeeded = true;
      }
    }
    if (MockList.homework) {
      changes.addAll(_mockChanges(local));
      succeeded = true;
    }
    if (!succeeded) throw StateError('作业刷新失败');
    return _pendingSync(changes, describe: _describeHomeworkChange);
  }

  /// mock 作业按 (平台课程 id, 类型) 单独比较，切法和主循环一致 ——
  /// 否则上次入库的 mock 记录会被主循环当成「删除」。
  List<DataChange<Homework>> _mockChanges(List<Homework> local) {
    final slices = <String, List<Homework>>{};
    for (final item in local) {
      slices
          .putIfAbsent(_sliceKey(item.courseId, item.homeworkType), () => [])
          .add(item);
    }
    final changes = <DataChange<Homework>>[];
    for (final mock in MockList.homeworks) {
      final slice = slices.putIfAbsent(
        _sliceKey(mock.courseId, mock.homeworkType),
        () => [],
      );
      final diff = _syncManager.detectChanges(remote: [mock], local: slice);
      if (diff.isEmpty) continue;
      changes.addAll(diff);
      slice.add(mock);
    }
    return changes;
  }

  static String _sliceKey(int courseId, HomeworkType type) =>
      '$courseId-${type.value}';

  PendingSync _pendingSync(
    List<DataChange<Homework>> changes, {
    required SyncChangeDetail Function(Homework, Homework?, DataChangeKind)
    describe,
  }) {
    final result = SyncResult.fromChanges(
      SyncModule.homework,
      changes,
      describe: describe,
    );
    return PendingSync(
      result: result,
      commit: () async {
        await _syncManager.apply(changes);
        return result;
      },
    );
  }

  static SyncChangeDetail _describeHomeworkChange(
    Homework item,
    Homework? previous,
    DataChangeKind kind,
  ) {
    final before = kind == DataChangeKind.added ? null : previous ?? item;
    final after = kind == DataChangeKind.deleted ? null : item;
    return SyncChangeDetail(
      kind: kind,
      title: item.title.isEmpty ? item.courseName : item.title,
      fields: [
        SyncFieldChange(
          label: '课程',
          before: before?.courseName ?? '',
          after: after?.courseName ?? '',
        ),
        SyncFieldChange(
          label: '分数',
          before: before?.score ?? '',
          after: after?.score ?? '',
        ),
        SyncFieldChange(
          label: '状态',
          before: before?.subStatus ?? '',
          after: after?.subStatus ?? '',
        ),
        SyncFieldChange(
          label: '截止时间',
          before: before?.endTime ?? '',
          after: after?.endTime ?? '',
        ),
      ],
    );
  }

  Future<HomeworkDetail> fetchDetail(Homework homework) async {
    final course = await _courseOf(homework);
    if (course == null) {
      return HomeworkDetail.failed('没找到这门课的平台信息，拿不到作业详情');
    }
    final raw = await _api.fetchDetailRaw(
      note: homework,
      course: course,
      headers: await _session.headers(),
    );
    return HomeworkParser.parseDetail(raw, fallbackContent: homework.content);
  }

  /// 两步：先传文件本体拿到 `visitName`，再把文件列表连同正文提交。
  ///
  /// 只做第一步不算交 —— 平台要 `fileList` 里有东西、并且走
  /// `sendStuHomeWorks` 才把状态改成「已提交」。
  Future<String> upload(Homework homework, {String content = ''}) async {
    final files = await _platformService.pickFiles();
    if (files.isEmpty) {
      throw StateError('没有选择文件');
    }
    final headers = await _session.headers();

    final entries = <String>[];
    for (final path in files) {
      final raw = await _api.uploadFileRaw(
        note: homework,
        filePath: path,
        headers: headers,
      );
      entries.add(HomeworkParser.uploadedFileEntry(raw));
    }

    return _api.submitRaw(
      note: homework,
      fileListJson: jsonEncode(entries),
      content: content,
      headers: headers,
    );
  }

  Future<String> downloadAttachment(
    Homework note,
    HomeworkAttachment file,
  ) async {
    final bytes = await _api.downloadAttachment(
      note: note,
      attachmentId: file.id,
      headers: await _session.headers(),
    );
    if (bytes.isEmpty) {
      throw StateError('附件是空的');
    }
    return _downloadService.saveBytes(fileName: file.fileName, bytes: bytes);
  }

  /// 当前学期的课程清单。平台挂了返回空列表，界面据此显示「拉不到课程」。
  Future<List<PlatformCourse>> _courses() async {
    try {
      return await _courseRepository.currentCourses();
    } catch (_) {
      return const [];
    }
  }

  /// 按平台主键找课（作业详情要教师工号，只有平台清单里才有）。
  Future<PlatformCourse?> _courseOf(Homework homework) async {
    final courses = await _courses();
    for (final course in courses) {
      if (course.id == homework.courseId) return course;
    }
    return null;
  }

  /// 拉一门课的一类作业；失败返回空列表而不是抛出去。
  Future<List<Homework>?> _tryFetch(
    PlatformCourse course,
    HomeworkType type,
    Map<String, String> headers,
  ) async {
    try {
      final raw = await _api.fetchListRaw(
        courseId: course.id,
        type: type,
        headers: headers,
      );
      return HomeworkParser.parseList(
        raw,
        homeworkType: type,
        courseName: course.name,
        courseId: course.id,
      );
    } catch (_) {
      return null;
    }
  }

  /// 老师批改了才有分数页；拿不到就还是用列表里那个分数。
  Future<Homework> _tryAttachScore(Homework homework) async {
    if (!homework.isGraded) return homework;
    try {
      final html = await _api.fetchScorePageRaw(
        note: homework,
        headers: await _session.headers(),
      );
      final score = HomeworkParser.parseScoreFromHtml(html);
      return score.isEmpty ? homework : homework.copyWith(score: score);
    } catch (_) {
      return homework;
    }
  }
}
