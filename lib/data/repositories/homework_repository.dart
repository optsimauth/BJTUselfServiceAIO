import 'dart:async';
import 'dart:convert';

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
    required HomeworkDetailLocalStore detailStore,
    required PlatformCourseRepository courseRepository,
    required CoursePlatformSession session,
    required DownloadService downloadService,
  }) : _api = api,
       _localStore = localStore,
       _detailStore = detailStore,
       _courseRepository = courseRepository,
       _session = session,
       _downloadService = downloadService,
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
  final HomeworkDetailLocalStore _detailStore;
  final PlatformCourseRepository _courseRepository;
  final CoursePlatformSession _session;
  final DownloadService _downloadService;
  final DataSyncManager<Homework> _syncManager;

  /// 详情缓存的有效期。
  ///
  /// 太长会让刚交完的作业看不到附件变化，太短等于没缓存 ——
  /// 5 分钟够学生连着看几门课的作业。
  static const Duration detailTtl = Duration(minutes: 5);

  /// 内存那一层：弹窗关掉再开不该连数据库都读一遍。
  final Map<String, HomeworkDetail> _detailCache = {};

  Stream<List<Homework>> watchAll() => _localStore.watchAll();

  Future<SyncResult> sync() async {
    final result = await (await prepareSync()).commit();
    await _pruneDetailCache();
    return result;
  }

  /// 平台删掉的作业，详情缓存也跟着删 —— 否则这张表只增不减。
  Future<void> _pruneDetailCache() async {
    final identities = (await _localStore.getAll())
        .map((homework) => homework.identity)
        .toList(growable: false);
    // 空列表意味着这次同步没拿到数据，别趁这个机会把缓存全清了。
    if (identities.isEmpty) return;
    final alive = identities.toSet();
    _detailCache.removeWhere((key, _) => !alive.contains(key));
    await _detailStore.retainOnly(identities);
  }

  /// 本地已有的详情（内存 → 数据库），没有就是 null。
  ///
  /// 界面用它先把正文铺上，网络请求退到后台 —— 这样打开弹窗不再
  /// 「先转圈再出字」。
  Future<HomeworkDetail?> cachedDetail(Homework homework) async {
    final identity = homework.identity;
    final memory = _detailCache[identity];
    if (memory != null) return memory;
    final stored = await _detailStore.read(identity);
    if (stored != null) _detailCache[identity] = stored;
    return stored;
  }

  /// 退出登录时清掉，别让下一个账号看到上一个人的作业正文。
  void invalidateDetailCache() {
    _detailCache.clear();
    unawaited(_detailStore.clear());
  }

  /// 每门课、每种作业独立比较；请求失败的分片完全不参与删除。
  Future<PendingSync> prepareSync() async {
    final courses = await _courses();
    if (courses.isEmpty) throw StateError('作业刷新失败：没有课程');
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
    if (MockList.enabled) {
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

  /// 取详情：缓存还在有效期内就直接给，否则回源并写回本地。
  ///
  /// [allowCache] = false 用于「刚交完作业」这类必须看到最新状态的场合。
  Future<HomeworkDetail> fetchDetail(
    Homework homework, {
    bool allowCache = true,
  }) async {
    if (allowCache) {
      final cached = await cachedDetail(homework);
      if (cached != null && cached.isFresh(detailTtl)) return cached;
    }
    final course = await _courseOf(homework);
    if (course == null) {
      return HomeworkDetail.failed('没找到这门课的平台信息，拿不到作业详情');
    }
    final raw = await _api.fetchDetailRaw(
      note: homework,
      course: course,
      headers: await _session.headers(),
    );
    final parsed = HomeworkParser.parseDetail(
      raw,
      fallbackContent: homework.content,
    );
    // 平台报错时不要把失败结果写进缓存：那会变成「永远打不开」。
    if (parsed.isFailed) return parsed;
    final detail = parsed.copyWith(fetchedAt: DateTime.now());
    _detailCache[homework.identity] = detail;
    await _detailStore.write(homework.identity, detail);
    return detail;
  }

  /// 两步：先传文件本体拿到 `visitName`，再把文件列表连同正文提交。
  ///
  /// 只做第一步不算交 —— 平台要 `fileList` 里有东西、并且走
  /// `sendStuHomeWorks` 才把状态改成「已提交」。
  ///
  /// 选文件**不在这里做**：数据层弹系统对话框，界面就没法回显「选了哪些」、
  /// 也没法把提交按钮做成「没选文件就不给按」。路径由提交弹窗选好后传进来。
  Future<String> upload(
    Homework homework, {
    required List<String> filePaths,
    String content = '',
  }) async {
    if (filePaths.isEmpty) {
      throw StateError('还没有选择要交给老师的文件');
    }
    final headers = await _session.headers();

    final entries = <String>[];
    for (final path in filePaths) {
      final raw = await _api.uploadFileRaw(
        note: homework,
        filePath: path,
        headers: headers,
      );
      entries.add(HomeworkParser.uploadedFileEntry(raw));
    }

    final receipt = await _api.submitRaw(
      note: homework,
      fileListJson: jsonEncode(entries),
      content: content,
      headers: headers,
    );
    // 交完之后正文和附件都可能变，缓存留着只会显示旧状态。
    _detailCache.remove(homework.identity);
    await _detailStore.remove(homework.identity);
    return receipt;
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

  /// 当前学期的课程清单。
  ///
  /// 拿不到就直接抛 —— 以前这里吞成空列表，界面只剩「作业刷新失败：没有课程」，
  /// 掩盖了会话过期、平台入口打不开这类真实原因（`docs/FEATURE_PARITY.md` 复盘）。
  Future<List<PlatformCourse>> _courses() => _courseRepository.currentCourses();

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
