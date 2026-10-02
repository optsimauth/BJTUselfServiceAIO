import 'package:drift/drift.dart';

import '../database.dart';

part 'exam_dao.g.dart';

@DriftAccessor(tables: [ExamTable])
class ExamDao extends DatabaseAccessor<AppDatabase> with _$ExamDaoMixin {
  ExamDao(super.db);

  Stream<List<ExamRow>> watchAll() => select(examTable).watch();

  Future<List<ExamRow>> getAll() => select(examTable).get();

  Future<void> upsertAll(List<Insertable<ExamRow>> rows) async {
    await batch((batch) => batch.insertAllOnConflictUpdate(examTable, rows));
  }

  Future<void> removeIds(List<int> ids) async {
    await (delete(examTable)..where((table) => table.id.isIn(ids))).go();
  }

  Future<void> clear() => delete(examTable).go();
}
