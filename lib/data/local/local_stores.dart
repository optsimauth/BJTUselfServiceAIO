import 'package:drift/drift.dart';

import '../../core/database/dao/course_dao.dart';
import '../../core/database/dao/exam_dao.dart';
import '../../core/database/dao/grade_dao.dart';
import '../../core/database/dao/homework_dao.dart';
import '../../core/database/database.dart';
import '../../core/state/data_sync_manager.dart';
import '../models/course/course_model.dart';
import '../models/exam/exam_model.dart';
import '../models/grade/grade_model.dart';
import '../models/homework/homework_model.dart';

/// drift DAO 与 LocalEntityStore 之间的适配层。
/// 模型 <-> 数据行的映射只在这里出现，别让 drift 的类型漏到上层。
List<int> _ids<T>(List<T> items) =>
    items.map((item) => (item as dynamic).id as int).toList();

class CourseLocalStore implements LocalEntityStore<Course> {
  CourseLocalStore(this._dao);

  final CourseDao _dao;

  @override
  Stream<List<Course>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_fromRow).toList());

  @override
  Future<List<Course>> getAll() async =>
      (await _dao.getAll()).map(_fromRow).toList();

  @override
  Future<void> upsert(List<Course> items) =>
      _dao.upsertAll(items.map(_toCompanion).toList());

  @override
  Future<void> remove(List<Course> items) => _dao.removeIds(_ids(items));

  @override
  Future<void> clear() => _dao.clear();

  Course _fromRow(CourseRow row) => Course(
    id: row.id,
    courseId: row.courseId,
    name: row.courseName,
    teacher: row.courseTeacher,
    locationIndex: row.courseLocationIndex,
    time: row.courseTime,
    place: row.coursePlace,
    isCurrentSemester: row.isCurrentSemester,
  );

  CourseTableCompanion _toCompanion(Course course) => CourseTableCompanion(
    id: course.id == 0 ? const Value.absent() : Value(course.id),
    courseId: Value(course.courseId),
    courseName: Value(course.name),
    courseTeacher: Value(course.teacher),
    courseLocationIndex: Value(course.locationIndex),
    courseTime: Value(course.time),
    coursePlace: Value(course.place),
    isCurrentSemester: Value(course.isCurrentSemester),
  );
}

class GradeLocalStore implements LocalEntityStore<Grade> {
  GradeLocalStore(this._dao);

  final GradeDao _dao;

  @override
  Stream<List<Grade>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_fromRow).toList());

  @override
  Future<List<Grade>> getAll() async =>
      (await _dao.getAll()).map(_fromRow).toList();

  @override
  Future<void> upsert(List<Grade> items) =>
      _dao.upsertAll(items.map(_toCompanion).toList());

  @override
  Future<void> remove(List<Grade> items) => _dao.removeIds(_ids(items));

  @override
  Future<void> clear() => _dao.clear();

  Grade _fromRow(GradeRow row) => Grade(
    id: row.id,
    courseName: row.courseName,
    courseTeacher: row.courseTeacher,
    courseScore: row.courseScore,
    courseCredits: row.courseCredits,
    courseYear: row.courseYear,
    tag: row.tag,
    detail: row.detail,
  );

  GradeTableCompanion _toCompanion(Grade grade) => GradeTableCompanion(
    id: grade.id == 0 ? const Value.absent() : Value(grade.id),
    courseName: Value(grade.courseName),
    courseTeacher: Value(grade.courseTeacher),
    courseScore: Value(grade.courseScore),
    courseCredits: Value(grade.courseCredits),
    courseYear: Value(grade.courseYear),
    tag: Value(grade.tag),
    detail: Value(grade.detail),
  );
}

class ExamLocalStore implements LocalEntityStore<ExamSchedule> {
  ExamLocalStore(this._dao);

  final ExamDao _dao;

  @override
  Stream<List<ExamSchedule>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_fromRow).toList());

  @override
  Future<List<ExamSchedule>> getAll() async =>
      (await _dao.getAll()).map(_fromRow).toList();

  @override
  Future<void> upsert(List<ExamSchedule> items) =>
      _dao.upsertAll(items.map(_toCompanion).toList());

  @override
  Future<void> remove(List<ExamSchedule> items) => _dao.removeIds(_ids(items));

  @override
  Future<void> clear() => _dao.clear();

  ExamSchedule _fromRow(ExamRow row) => ExamSchedule(
    id: row.id,
    examType: row.examType,
    courseName: row.courseName,
    examTimeAndPlace: row.examTimeAndPlace,
    examStatus: row.examStatus,
    detail: row.detail,
  );

  ExamTableCompanion _toCompanion(ExamSchedule exam) => ExamTableCompanion(
    id: exam.id == 0 ? const Value.absent() : Value(exam.id),
    examType: Value(exam.examType),
    courseName: Value(exam.courseName),
    examTimeAndPlace: Value(exam.examTimeAndPlace),
    examStatus: Value(exam.examStatus),
    detail: Value(exam.detail),
  );
}

class HomeworkLocalStore implements LocalEntityStore<Homework> {
  HomeworkLocalStore(this._dao);

  final HomeworkDao _dao;

  @override
  Stream<List<Homework>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_fromRow).toList());

  @override
  Future<List<Homework>> getAll() async =>
      (await _dao.getAll()).map(_fromRow).toList();

  @override
  Future<void> upsert(List<Homework> items) =>
      _dao.upsertAll(items.map(_toCompanion).toList());

  @override
  Future<void> remove(List<Homework> items) => _dao.removeIds(_ids(items));

  @override
  Future<void> clear() => _dao.clear();

  Homework _fromRow(HomeworkRow row) => Homework(
    id: row.id,
    upId: row.upId,
    idSnId: row.idSnId,
    score: row.score,
    userId: row.userId,
    courseId: row.courseId,
    courseName: row.courseName,
    title: row.title,
    content: row.content,
    createDate: row.createDate,
    endTime: row.endTime,
    openDate: row.openDate,
    status: row.status,
    submitCount: row.submitCount,
    allCount: row.allCount,
    subStatus: row.subStatus,
    scoreId: row.scoreId,
    homeworkType: HomeworkType.fromValue(row.homeworkType),
  );

  HomeworkTableCompanion _toCompanion(Homework homework) =>
      HomeworkTableCompanion(
        id: homework.id == 0 ? const Value.absent() : Value(homework.id),
        upId: Value(homework.upId),
        idSnId: Value(homework.idSnId),
        score: Value(homework.score),
        userId: Value(homework.userId),
        courseId: Value(homework.courseId),
        courseName: Value(homework.courseName),
        title: Value(homework.title),
        content: Value(homework.content),
        createDate: Value(homework.createDate),
        endTime: Value(homework.endTime),
        openDate: Value(homework.openDate),
        status: Value(homework.status),
        submitCount: Value(homework.submitCount),
        allCount: Value(homework.allCount),
        subStatus: Value(homework.subStatus),
        scoreId: Value(homework.scoreId),
        homeworkType: Value(homework.homeworkType.value),
      );
}
