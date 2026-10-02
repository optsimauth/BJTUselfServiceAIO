import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/state/data_sync_manager.dart';
import '../../core/state/pending_sync.dart';
import '../../core/state/sync_module.dart';
import '../../core/state/sync_result.dart';
import '../../core/storage/preferences.dart';
import '../../services/download/download_service.dart';
import '../local/local_stores.dart';
import '../mock/mock_lists.dart';
import '../models/grade/grade_model.dart';
import '../remote/api/grade_api.dart';
import '../remote/parsers/grade_parser.dart';

/// 成绩：同步 + 用户勾选记录 + 成绩单下载。
class GradeRepository {
  GradeRepository({
    required GradeApi api,
    required GradeLocalStore localStore,
    required AppPreferences preferences,
    required DownloadService downloadService,
  }) : _api = api,
       _localStore = localStore,
       _preferences = preferences,
       _downloadService = downloadService,
       _syncManager = DataSyncManager<Grade>(
         store: localStore,
         identity: (grade) => grade.identity,
         changed: (current, previous) =>
             current.courseScore != previous.courseScore ||
             current.courseCredits != previous.courseCredits ||
             current.courseTeacher != previous.courseTeacher ||
             current.tag != previous.tag ||
             current.detail != previous.detail,
         mergeIds: (current, previous) => current.copyWith(id: previous.id),
       );

  final GradeApi _api;
  final GradeLocalStore _localStore;
  final AppPreferences _preferences;
  final DownloadService _downloadService;
  final DataSyncManager<Grade> _syncManager;

  Stream<List<Grade>> watchAll() => _localStore.watchAll();

  Future<SyncResult> sync() async => (await prepareSync()).commit();

  /// 单个来源失败时仍可发现新增和变更，但不执行删除。
  Future<PendingSync> prepareSync() async {
    final sources = <List<Grade>>[];
    for (final source in const ['ln', 'lr']) {
      try {
        sources.add(
          GradeParser.parse(await _api.fetchGradeRaw(source: source)),
        );
      } catch (_) {
        // 保留成功来源；两个都失败时在下面报错。
      }
    }
    if (sources.isEmpty) throw StateError('成绩刷新失败');
    final merged = sources.length == 1
        ? sources.first
        : GradeParser.merge(sources[0], sources[1]);
    final remote = [...merged, if (MockList.enabled) ...MockList.grades];
    final changes = _syncManager.detectChanges(
      remote: remote,
      local: await _localStore.getAll(),
      detectDeleted: sources.length == 2,
    );
    return _pendingSync(changes, describe: _describeGradeChange);
  }

  PendingSync _pendingSync(
    List<DataChange<Grade>> changes, {
    required SyncChangeDetail Function(Grade, Grade?, DataChangeKind) describe,
  }) {
    final result = SyncResult.fromChanges(
      SyncModule.grade,
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

  static SyncChangeDetail _describeGradeChange(
    Grade item,
    Grade? previous,
    DataChangeKind kind,
  ) {
    final before = kind == DataChangeKind.added ? null : previous ?? item;
    final after = kind == DataChangeKind.deleted ? null : item;
    return SyncChangeDetail(
      kind: kind,
      title: item.courseName,
      fields: [
        SyncFieldChange(
          label: '成绩',
          before: before?.courseScore ?? '',
          after: after?.courseScore ?? '',
        ),
        SyncFieldChange(
          label: '学分',
          before: before?.courseCredits ?? '',
          after: after?.courseCredits ?? '',
        ),
        SyncFieldChange(
          label: '教师',
          before: before?.courseTeacher ?? '',
          after: after?.courseTeacher ?? '',
        ),
        SyncFieldChange(
          label: '学期',
          before: before?.tag ?? '',
          after: after?.tag ?? '',
        ),
        SyncFieldChange(
          label: '备注',
          before: before?.detail ?? '',
          after: after?.detail ?? '',
        ),
      ],
    );
  }

  /// 成绩单 PDF 下载，返回落盘位置。
  Future<String> downloadReport({required bool english}) async {
    final bytes = await _api.downloadGradeReport(english: english);
    return _downloadService.saveBytes(
      fileName: english ? '英文成绩单.pdf' : '中文成绩单.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  // ---- 勾选记录（旧 DataStoreRepository 的 grade_selections_by_student）----

  /// 该学号勾选过的课程记录；空学号返回空表。
  List<GradeSelectionRecord> loadSelections(String studentId) {
    if (studentId.isEmpty) {
      return const [];
    }
    final raw = _preferences.readString(StorageKeys.gradeSelections);
    if (raw.isEmpty) {
      return const [];
    }
    final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final records = decoded[studentId] as List<dynamic>? ?? const [];
    return records
        .map(
          (item) => GradeSelectionRecord.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<void> saveSelections(
    String studentId,
    List<GradeSelectionRecord> records,
  ) async {
    if (studentId.isEmpty) {
      return;
    }
    final raw = _preferences.readString(StorageKeys.gradeSelections);
    final decoded = raw.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map).cast<String, dynamic>();
    if (records.isEmpty) {
      decoded.remove(studentId);
    } else {
      decoded[studentId] = records.map((record) => record.toJson()).toList();
    }
    await _preferences.writeString(
      StorageKeys.gradeSelections,
      jsonEncode(decoded),
    );
  }
}
