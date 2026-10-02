// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grade_dao.dart';

// ignore_for_file: type=lint
mixin _$GradeDaoMixin on DatabaseAccessor<AppDatabase> {
  $GradeTableTable get gradeTable => attachedDatabase.gradeTable;
  GradeDaoManager get managers => GradeDaoManager(this);
}

class GradeDaoManager {
  final _$GradeDaoMixin _db;
  GradeDaoManager(this._db);
  $$GradeTableTableTableManager get gradeTable =>
      $$GradeTableTableTableManager(_db.attachedDatabase, _db.gradeTable);
}
