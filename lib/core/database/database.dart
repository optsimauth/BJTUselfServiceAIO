import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../constants/app_constants.dart';
import 'dao/course_dao.dart';
import 'dao/exam_dao.dart';
import 'dao/grade_dao.dart';
import 'dao/homework_dao.dart';
import 'migration/migrations.dart';

part 'database.g.dart';

/// 表定义尽量沿用旧 Room 的表名/列名，方便以后做数据迁移对拍。
@DataClassName('CourseRow')
class CourseTable extends Table {
  @override
  String get tableName => 'CourseEntity';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get courseId => text()();

  TextColumn get courseName => text()();

  TextColumn get courseTeacher => text()();

  /// 0..55，一周 7 天 * 8 节。
  IntColumn get courseLocationIndex => integer()();

  TextColumn get courseTime => text()();

  TextColumn get coursePlace => text()();

  BoolColumn get isCurrentSemester => boolean()();
}

@DataClassName('GradeRow')
class GradeTable extends Table {
  @override
  String get tableName => 'GradeEntity';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get courseName => text()();

  TextColumn get courseTeacher => text()();

  TextColumn get courseScore => text()();

  TextColumn get courseCredits => text()();

  TextColumn get courseYear => text()();

  /// 旧库里有 tag / detail 两列，成绩选择功能在用。
  TextColumn get tag => text().withDefault(const Constant(''))();

  TextColumn get detail => text().withDefault(const Constant(''))();
}

@DataClassName('ExamRow')
class ExamTable extends Table {
  @override
  String get tableName => 'ExamScheduleEntity';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get examType => text()();

  TextColumn get courseName => text()();

  TextColumn get examTimeAndPlace => text()();

  TextColumn get examStatus => text()();

  TextColumn get detail => text().withDefault(const Constant(''))();
}

@DataClassName('HomeworkRow')
class HomeworkTable extends Table {
  @override
  String get tableName => 'HomeworkEntity';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get upId => integer()();

  IntColumn get idSnId => integer().nullable()();

  TextColumn get score => text().withDefault(const Constant(''))();

  IntColumn get userId => integer()();

  IntColumn get courseId => integer()();

  TextColumn get courseName => text()();

  TextColumn get title => text()();

  TextColumn get content => text().withDefault(const Constant(''))();

  TextColumn get createDate => text()();

  TextColumn get endTime => text()();

  TextColumn get openDate => text()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get submitCount => integer().withDefault(const Constant(0))();

  IntColumn get allCount => integer().withDefault(const Constant(0))();

  TextColumn get subStatus => text().withDefault(const Constant(''))();

  /// 与旧库 MIGRATION_1_2 对齐。
  IntColumn get scoreId => integer().withDefault(const Constant(0))();

  /// 0: 作业 1: 课程设计 2: 实验报告
  IntColumn get homeworkType => integer().withDefault(const Constant(0))();
}

@DriftDatabase(
  tables: [CourseTable, GradeTable, ExamTable, HomeworkTable],
  daos: [CourseDao, GradeDao, ExamDao, HomeworkDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: AppConstants.databaseName));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) =>
        DatabaseMigrations.run(this, migrator, from, to),
  );

  /// 退出登录时清空所有业务数据。
  Future<void> clearBusinessData() async {
    await transaction(() async {
      await delete(homeworkTable).go();
      await delete(examTable).go();
      await delete(gradeTable).go();
      await delete(courseTable).go();
    });
  }
}
