// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homework_dao.dart';

// ignore_for_file: type=lint
mixin _$HomeworkDaoMixin on DatabaseAccessor<AppDatabase> {
  $HomeworkTableTable get homeworkTable => attachedDatabase.homeworkTable;
  HomeworkDaoManager get managers => HomeworkDaoManager(this);
}

class HomeworkDaoManager {
  final _$HomeworkDaoMixin _db;
  HomeworkDaoManager(this._db);
  $$HomeworkTableTableTableManager get homeworkTable =>
      $$HomeworkTableTableTableManager(_db.attachedDatabase, _db.homeworkTable);
}
