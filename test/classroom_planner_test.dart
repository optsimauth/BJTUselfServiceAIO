import 'package:bjtuselfserviceaio/features/classroom/classroom_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// 0 = 空闲，1..5 = 占用（和教务表格的状态码一致）。
List<int> _freeEverywhere() => List<int>.filled(7, 0);

void main() {
  group('楼层解析', () {
    test('楼名里的第一位数字就是楼层', () {
      expect(ClassroomPlanner.floorOf('SY302'), 3);
      expect(ClassroomPlanner.floorOf('思源楼101'), 1);
      expect(ClassroomPlanner.floorOf('无编号'), 0);
    });
  });

  group('规划', () {
    test('只选一节：随便一间空闲教室，楼层差为 0', () {
      final result = ClassroomPlanner.plan(
        rooms: const [
          PlannerRoom(name: 'SY101', capacity: 90),
          PlannerRoom(name: 'SY502', capacity: 60),
        ],
        slotsByRoom: {
          'SY101': _freeEverywhere(),
          'SY502': _freeEverywhere(),
        },
        slots: const [2],
      );
      expect(result, isA<PlannerSuccess>());
      final success = result as PlannerSuccess;
      expect(success.steps, hasLength(1));
      expect(success.steps.single.slot, 2);
      expect(success.floorChanges, 0);
    });

    test('两节之间挑楼层差最小的，而不是按房间顺序挑', () {
      // 第 1 节空着 1 楼和 3 楼；第 2 节只剩 5 楼。
      // 从 3 楼上去只差 2 层，从 1 楼要差 4 层 —— 应该走 3 楼那间。
      final result = ClassroomPlanner.plan(
        rooms: const [
          PlannerRoom(name: 'SY101', capacity: 90),
          PlannerRoom(name: 'SY301', capacity: 90),
          PlannerRoom(name: 'SY501', capacity: 90),
        ],
        slotsByRoom: {
          'SY101': [0, 1, 1, 1, 1, 1, 1],
          'SY301': [0, 1, 1, 1, 1, 1, 1],
          'SY501': [1, 0, 1, 1, 1, 1, 1],
        },
        slots: const [0, 1],
      );
      final success = result as PlannerSuccess;
      expect(success.steps.map((step) => step.room), ['SY301', 'SY501']);
      expect(success.floorChanges, 2);
    });

    test('同层有两条路时楼层差为 0', () {
      final result = ClassroomPlanner.plan(
        rooms: const [
          PlannerRoom(name: 'SY201', capacity: 90),
          PlannerRoom(name: 'SY202', capacity: 90),
        ],
        slotsByRoom: {
          'SY201': [0, 1, 1, 1, 1, 1, 1],
          'SY202': [1, 0, 1, 1, 1, 1, 1],
        },
        slots: const [0, 1],
      );
      final success = result as PlannerSuccess;
      expect(success.floorChanges, 0);
      expect(success.steps.map((step) => step.room), ['SY201', 'SY202']);
    });

    test('容量不够的房间不参与', () {
      final result = ClassroomPlanner.plan(
        rooms: const [
          PlannerRoom(name: 'SY101', capacity: 30),
          PlannerRoom(name: 'SY201', capacity: 120),
        ],
        slotsByRoom: {
          'SY101': _freeEverywhere(),
          'SY201': _freeEverywhere(),
        },
        slots: const [0],
        minCapacity: 60,
      );
      final success = result as PlannerSuccess;
      expect(success.steps.single.room, 'SY201');
    });

    test('某一节没有可用教室时，说清是哪一节', () {
      final result = ClassroomPlanner.plan(
        rooms: const [PlannerRoom(name: 'SY101', capacity: 90)],
        slotsByRoom: {
          'SY101': [0, 1, 1, 1, 1, 1, 1],
        },
        slots: const [0, 1],
      );
      expect(result, isA<PlannerFailure>());
      expect((result as PlannerFailure).reason, contains('第 2 节'));
    });

    test('不选节次直接说清楚', () {
      final result = ClassroomPlanner.plan(
        rooms: const [],
        slotsByRoom: const {},
        slots: const [],
      );
      expect(result, isA<PlannerFailure>());
    });

    test('重复节次会去重排序', () {
      final result = ClassroomPlanner.plan(
        rooms: const [PlannerRoom(name: 'SY101', capacity: 90)],
        slotsByRoom: {
          'SY101': _freeEverywhere(),
        },
        slots: const [3, 1, 3],
      );
      final success = result as PlannerSuccess;
      expect(success.steps.map((step) => step.slot), [1, 3]);
    });
  });
}
