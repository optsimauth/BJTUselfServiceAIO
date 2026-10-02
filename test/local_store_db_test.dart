import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/core/database/database.dart';
import 'package:bjtuselfserviceaio/core/state/data_sync_manager.dart';
import 'package:bjtuselfserviceaio/core/state/sync_module.dart';
import 'package:bjtuselfserviceaio/core/state/sync_result.dart';
import 'package:bjtuselfserviceaio/data/local/local_stores.dart';
import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/models/grade/grade_model.dart';

Course _course(String id, {String place = 'A'}) => Course(
  courseId: id,
  name: '课程$id',
  teacher: 'T',
  locationIndex: 1,
  time: '周一1',
  place: place,
);

const Grade _mockGrade = Grade(
  courseName: '【Mock】测试成绩',
  courseTeacher: '调试',
  courseScore: '99',
  courseCredits: '1.0',
  courseYear: '2025-2026-1',
  tag: '2025-2026-1',
);

void main() {
  late AppDatabase db;
  late CourseLocalStore store;
  late DataSyncManager<Course> manager;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = CourseLocalStore(db.courseDao);
    manager = DataSyncManager<Course>(
      store: store,
      identity: (course) => course.identity,
      changed: (current, previous) => current.place != previous.place,
      mergeIds: (current, previous) => current.copyWith(id: previous.id),
    );
  });

  tearDown(() => db.close());

  test('新增落到真实数据库', () async {
    await manager.apply(
      manager.detectChanges(remote: [_course('1')], local: const []),
    );

    final rows = await store.getAll();
    expect(rows.single.courseId, '1');
    expect(rows.single.place, 'A');
  });

  test('变更更新同一行，不新增副本', () async {
    await manager.apply(
      manager.detectChanges(remote: [_course('1')], local: const []),
    );
    final first = (await store.getAll()).single;

    await manager.apply(
      manager.detectChanges(
        remote: [_course('1', place: 'B')],
        local: await store.getAll(),
      ),
    );

    final rows = await store.getAll();
    expect(rows.length, 1);
    expect(rows.single.place, 'B');
    expect(rows.single.id, first.id);
  });

  test('删除从数据库移除', () async {
    await manager.apply(
      manager.detectChanges(remote: [_course('1')], local: const []),
    );
    await manager.apply(
      manager.detectChanges(remote: const [], local: await store.getAll()),
    );

    expect(await store.getAll(), isEmpty);
  });

  test('watchAll 把落库结果推给页面', () async {
    final pushed = store.watchAll().firstWhere((rows) => rows.isNotEmpty);

    await manager.apply(
      manager.detectChanges(remote: [_course('9')], local: const []),
    );

    expect((await pushed).single.courseId, '9');
  });

  test('假成绩：先提示「新增 1」，落库后改分数提示「变更 1」', () async {
    final gradeStore = GradeLocalStore(db.gradeDao);
    final gradeManager = DataSyncManager<Grade>(
      store: gradeStore,
      identity: (grade) => grade.identity,
      changed: (current, previous) =>
          current.courseScore != previous.courseScore,
      mergeIds: (current, previous) => current.copyWith(id: previous.id),
    );

    final first = SyncResult.fromChanges(
      SyncModule.grade,
      gradeManager.detectChanges(remote: const [_mockGrade], local: const []),
    );
    expect(first.message, '成绩：新增 1');

    await gradeManager.apply(
      gradeManager.detectChanges(remote: const [_mockGrade], local: const []),
    );
    final stored = await gradeStore.getAll();
    expect(stored.single.courseName, '【Mock】测试成绩');
    expect(stored.single.courseScore, '99');

    final second = SyncResult.fromChanges(
      SyncModule.grade,
      gradeManager.detectChanges(
        remote: [_mockGrade.copyWith(courseScore: '88')],
        local: stored,
      ),
    );
    expect(second.message, '成绩：变更 1');
  });
}
