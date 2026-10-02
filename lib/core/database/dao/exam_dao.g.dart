// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_dao.dart';

// ignore_for_file: type=lint
mixin _$ExamDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExamTableTable get examTable => attachedDatabase.examTable;
  ExamDaoManager get managers => ExamDaoManager(this);
}

class ExamDaoManager {
  final _$ExamDaoMixin _db;
  ExamDaoManager(this._db);
  $$ExamTableTableTableManager get examTable =>
      $$ExamTableTableTableManager(_db.attachedDatabase, _db.examTable);
}
