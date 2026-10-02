import 'package:drift/drift.dart';

import '../database.dart';

part 'homework_dao.g.dart';

@DriftAccessor(tables: [HomeworkTable])
class HomeworkDao extends DatabaseAccessor<AppDatabase>
    with _$HomeworkDaoMixin {
  HomeworkDao(super.db);

  Stream<List<HomeworkRow>> watchAll() => select(homeworkTable).watch();

  Future<List<HomeworkRow>> getAll() => select(homeworkTable).get();

  Future<void> upsertAll(List<Insertable<HomeworkRow>> rows) async {
    await batch(
      (batch) => batch.insertAllOnConflictUpdate(homeworkTable, rows),
    );
  }

  Future<void> removeIds(List<int> ids) async {
    await (delete(homeworkTable)..where((table) => table.id.isIn(ids))).go();
  }

  Future<void> clear() => delete(homeworkTable).go();
}
