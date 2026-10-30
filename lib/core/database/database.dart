import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../constants/app_constants.dart';
import 'dao/course_dao.dart';
import 'dao/exam_dao.dart';
import 'dao/grade_dao.dart';
import 'dao/homework_dao.dart';
import 'dao/homework_detail_dao.dart';
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

/// 作业详情缓存。
///
/// 列表接口只有一份 `content`，正文里的完整 HTML 和附件清单得走
/// `queryStudentCourseNote` 单独拉 —— 每次打开弹窗都发一次请求，
/// 用户看到的就是「一片转圈之后才出字」。这张表把拉回来的详情留下来，
/// 下次打开先用本地那份渲染，请求退到后台。
///
/// 不并进 `HomeworkTable` 是为了避开同步：`DataSyncManager` 每次 upsert
/// 整行，详情列被写成空就会把缓存抹掉。
@DataClassName('HomeworkDetailRow')
class HomeworkDetailTable extends Table {
  @override
  String get tableName => 'HomeworkDetailEntity';

  /// 作业身份，与 `Homework.identity` 一致（`courseName-upId`）。
  TextColumn get identity => text()();

  /// 平台原文 HTML。
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 附件清单的 JSON，字段与 `HomeworkAttachment` 对齐。
  TextColumn get attachments => text().withDefault(const Constant(''))();

  /// 最后一次成功拉取的时间（毫秒时间戳）。0 表示还没拉过。
  IntColumn get fetchedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {identity};
}

@DriftDatabase(
  tables: [CourseTable, GradeTable, ExamTable, HomeworkTable, HomeworkDetailTable],
  daos: [CourseDao, GradeDao, ExamDao, HomeworkDao, HomeworkDetailDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: AppConstants.databaseName));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) =>
        DatabaseMigrations.run(this, migrator, from, to),
  );

  /// 退出登录时清空所有业务数据。
  Future<void> clearBusinessData() async {
    await transaction(() async {
      await delete(homeworkDetailTable).go();
      await delete(homeworkTable).go();
      await delete(examTable).go();
      await delete(gradeTable).go();
      await delete(courseTable).go();
    });
  }
}
