import 'package:drift/drift.dart';

import '../database.dart';

part 'homework_detail_dao.g.dart';

/// 作业详情缓存表。按 `identity`（`courseName-upId`）一条。
@DriftAccessor(tables: [HomeworkDetailTable])
class HomeworkDetailDao extends DatabaseAccessor<AppDatabase>
    with _$HomeworkDetailDaoMixin {
  HomeworkDetailDao(super.db);

  Future<HomeworkDetailRow?> find(String identity) =>
      (select(homeworkDetailTable)
            ..where((table) => table.identity.equals(identity)))
          .getSingleOrNull();

  Future<void> upsertOne(HomeworkDetailTableCompanion row) =>
      into(homeworkDetailTable).insertOnConflictUpdate(row);

  /// 作业被平台删掉后，缓存也跟着走；否则表只增不减。
  Future<void> retainOnly(List<String> identities) async {
    if (identities.isEmpty) return;
    await (delete(
      homeworkDetailTable,
    )..where((table) => table.identity.isNotIn(identities))).go();
  }

  Future<void> remove(String identity) async {
    await (delete(
      homeworkDetailTable,
    )..where((table) => table.identity.equals(identity))).go();
  }

  Future<void> clear() => delete(homeworkDetailTable).go();
}
