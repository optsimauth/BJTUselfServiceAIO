import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/core/database/database.dart';
import 'package:bjtuselfserviceaio/core/state/data_sync_manager.dart';
import 'package:bjtuselfserviceaio/core/state/sync_module.dart';
import 'package:bjtuselfserviceaio/core/state/sync_result.dart';
import 'package:bjtuselfserviceaio/data/local/local_stores.dart';
import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/models/grade/grade_model.dart';
import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';

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
      manager.detectChanges(
        remote: [_course('2')],
        local: await store.getAll(),
      ),
    );

    expect((await store.getAll()).map((course) => course.courseId), ['2']);
  });

  test('空远端结果保留本地缓存，避免登录失效被误判为全量删除', () async {
    await store.upsert([_course('1')]);
    await manager.apply(
      manager.detectChanges(remote: const [], local: await store.getAll()),
    );
    expect((await store.getAll()).map((course) => course.courseId), ['1']);
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

  group('作业详情缓存', () {
    late HomeworkDetailLocalStore detailStore;

    setUp(() => detailStore = HomeworkDetailLocalStore(db.homeworkDetailDao));

    test('写进去能原样读回来，附件字段一个不少', () async {
      await detailStore.write(
        '大学物理-7',
        const HomeworkDetail(
          content: '<p>周五前交实验报告</p>',
          attachments: [
            HomeworkAttachment(
              id: 3,
              fileName: '第1章 习题.pdf',
              sizeBytes: 2048,
              sourcePath: '/a/b',
            ),
          ],
        ),
      );

      final loaded = await detailStore.read('大学物理-7');
      expect(loaded!.content, '<p>周五前交实验报告</p>');
      expect(loaded.attachments.single.fileName, '第1章 习题.pdf');
      expect(loaded.attachments.single.sizeBytes, 2048);
      // 时间戳是写的时候自己打的，界面靠它判断缓存新不新鲜。
      expect(loaded.fetchedAt, isNotNull);
      expect(loaded.isFresh(const Duration(minutes: 5)), isTrue);
    });

    test('没缓存过返回 null，而不是一份空详情', () async {
      expect(await detailStore.read('不存在的课-1'), isNull);
    });

    test('retainOnly 只留下还在列表里的作业', () async {
      await detailStore.write('A-1', const HomeworkDetail(content: 'a'));
      await detailStore.write('B-2', const HomeworkDetail(content: 'b'));

      await detailStore.retainOnly(const ['A-1']);

      expect(await detailStore.read('A-1'), isNotNull);
      expect(await detailStore.read('B-2'), isNull);
    });

    test('附件 JSON 坏了当没有附件，不把弹窗带崩', () async {
      await db
          .into(db.homeworkDetailTable)
          .insert(
            HomeworkDetailTableCompanion.insert(
              identity: '坏数据-1',
              content: const Value('<p>x</p>'),
              attachments: const Value('{不是数组'),
            ),
          );

      final loaded = await detailStore.read('坏数据-1');
      expect(loaded!.content, '<p>x</p>');
      expect(loaded.attachments, isEmpty);
    });
  });
}
