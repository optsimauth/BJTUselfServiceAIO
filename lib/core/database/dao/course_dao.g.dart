// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_dao.dart';

// ignore_for_file: type=lint
mixin _$CourseDaoMixin on DatabaseAccessor<AppDatabase> {
  $CourseTableTable get courseTable => attachedDatabase.courseTable;
  CourseDaoManager get managers => CourseDaoManager(this);
}

class CourseDaoManager {
  final _$CourseDaoMixin _db;
  CourseDaoManager(this._db);
  $$CourseTableTableTableManager get courseTable =>
      $$CourseTableTableTableManager(_db.attachedDatabase, _db.courseTable);
}
