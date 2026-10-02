import 'package:drift/drift.dart';

import '../database.dart';

part 'grade_dao.g.dart';

@DriftAccessor(tables: [GradeTable])
class GradeDao extends DatabaseAccessor<AppDatabase> with _$GradeDaoMixin {
  GradeDao(super.db);

  Stream<List<GradeRow>> watchAll() => select(gradeTable).watch();

  Future<List<GradeRow>> getAll() => select(gradeTable).get();

  Future<void> upsertAll(List<Insertable<GradeRow>> rows) async {
    await batch((batch) => batch.insertAllOnConflictUpdate(gradeTable, rows));
  }

  Future<void> removeIds(List<int> ids) async {
    await (delete(gradeTable)..where((table) => table.id.isIn(ids))).go();
  }

  Future<void> clear() => delete(gradeTable).go();
}
