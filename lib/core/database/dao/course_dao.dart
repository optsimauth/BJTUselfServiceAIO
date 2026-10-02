import 'package:drift/drift.dart';

import '../database.dart';

part 'course_dao.g.dart';

@DriftAccessor(tables: [CourseTable])
class CourseDao extends DatabaseAccessor<AppDatabase> with _$CourseDaoMixin {
  CourseDao(super.db);

  Stream<List<CourseRow>> watchAll() => select(courseTable).watch();

  Stream<List<CourseRow>> watchBySemester({required bool isCurrentSemester}) =>
      (select(courseTable)
            ..where((row) => row.isCurrentSemester.equals(isCurrentSemester)))
          .watch();

  Future<List<CourseRow>> getAll() => select(courseTable).get();

  Future<void> upsertAll(List<Insertable<CourseRow>> rows) async {
    await batch((batch) => batch.insertAllOnConflictUpdate(courseTable, rows));
  }

  Future<void> removeIds(List<int> ids) async {
    await (delete(courseTable)..where((table) => table.id.isIn(ids))).go();
  }

  Future<void> clear() => delete(courseTable).go();
}
