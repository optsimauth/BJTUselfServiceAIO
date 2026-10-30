// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homework_detail_dao.dart';

// ignore_for_file: type=lint
mixin _$HomeworkDetailDaoMixin on DatabaseAccessor<AppDatabase> {
  $HomeworkDetailTableTable get homeworkDetailTable =>
      attachedDatabase.homeworkDetailTable;
  HomeworkDetailDaoManager get managers => HomeworkDetailDaoManager(this);
}

class HomeworkDetailDaoManager {
  final _$HomeworkDetailDaoMixin _db;
  HomeworkDetailDaoManager(this._db);
  $$HomeworkDetailTableTableTableManager get homeworkDetailTable =>
      $$HomeworkDetailTableTableTableManager(
        _db.attachedDatabase,
        _db.homeworkDetailTable,
      );
}
