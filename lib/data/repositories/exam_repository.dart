import '../../core/state/data_sync_manager.dart';
import '../../core/state/pending_sync.dart';
import '../../core/state/sync_module.dart';
import '../../core/state/sync_result.dart';
import '../local/local_stores.dart';
import '../mock/mock_lists.dart';
import '../models/exam/exam_model.dart';
import '../remote/api/exam_api.dart';
import '../remote/parsers/exam_parser.dart';

/// 考试安排的唯一数据出口。页面只有「订阅本地数据」和「触发同步」两件事。
class ExamRepository {
  ExamRepository({required ExamApi api, required ExamLocalStore localStore})
    : _api = api,
      _localStore = localStore,
      _syncManager = DataSyncManager<ExamSchedule>(
        store: localStore,
        identity: (exam) => exam.identity,
        changed: (current, previous) =>
            current.examTimeAndPlace != previous.examTimeAndPlace ||
            current.examStatus != previous.examStatus ||
            current.detail != previous.detail,
        mergeIds: (current, previous) => current.copyWith(id: previous.id),
      );

  final ExamApi _api;
  final ExamLocalStore _localStore;
  final DataSyncManager<ExamSchedule> _syncManager;

  Stream<List<ExamSchedule>> watchAll() => _localStore.watchAll();

  Future<SyncResult> sync() async => (await prepareSync()).commit();

  Future<PendingSync> prepareSync() async {
    final parsed = ExamParser.parse(await _api.fetchExamScheduleRaw());
    final remote = [...parsed, if (MockList.enabled) ...MockList.exams];
    final changes = _syncManager.detectChanges(
      remote: remote,
      local: await _localStore.getAll(),
    );
    return _pendingSync(changes);
  }

  PendingSync _pendingSync(List<DataChange<ExamSchedule>> changes) {
    final result = SyncResult.fromChanges(SyncModule.exam, changes);
    return PendingSync(
      result: result,
      commit: () async {
        await _syncManager.apply(changes);
        return result;
      },
    );
  }
}
