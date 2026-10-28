/// 空教室规划（移植自旧项目 `utils/ClassroomPlanner.kt`）。
///
/// 问题：给若干个节次，各挑一间空教室，让上下节课之间的楼层差之和最小。
/// 做法：按节次分层，节点是「该节空闲的房间」，相邻层之间边的权重是楼层差绝对值，
/// 于是变成逐层最短路径（动态规划）。房间数几十间、节次 ≤ 7，DP 足够快。
///
/// 纯函数、不碰 IO —— 算法出问题能用单元测试直接盯住。
library;

/// 参与规划的房间。
class PlannerRoom {
  const PlannerRoom({required this.name, required this.capacity});

  final String name;
  final int capacity;
}

/// 规划结果的一步：第几节、去哪间、几楼。
class PlannerStep {
  const PlannerStep({
    required this.slot,
    required this.room,
    required this.floor,
  });

  /// 0 起的节次下标（0 = 第 1 节）。
  final int slot;
  final String room;
  final int floor;
}

sealed class PlannerResult {
  const PlannerResult();
}

class PlannerSuccess extends PlannerResult {
  const PlannerSuccess({required this.steps, required this.floorChanges});

  final List<PlannerStep> steps;

  /// 相邻两节之间楼层差之和。0 = 一直待在同一层。
  final int floorChanges;
}

class PlannerFailure extends PlannerResult {
  const PlannerFailure(this.reason);

  final String reason;
}

abstract final class ClassroomPlanner {
  /// 房间名里的楼层号：`SY302` → 3。取不到就是 0（不把缺楼层当成负楼层）。
  static int floorOf(String roomName) {
    final match = RegExp(r'(\d)').firstMatch(roomName);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  /// [slotsByRoom]：房间名 → 每个节次的状态码，0 表示空闲（与教务表格一致）。
  /// [slots]：要规划的节次（0 起，可乱序，内部会去重排序）。
  /// [minCapacity]：最小容量，0 = 不限。
  static PlannerResult plan({
    required List<PlannerRoom> rooms,
    required Map<String, List<int>> slotsByRoom,
    required List<int> slots,
    int minCapacity = 0,
  }) {
    if (slots.isEmpty) {
      return const PlannerFailure('请至少选择一个节次');
    }
    final ordered = slots.toSet().toList()..sort();
    final floors = {for (final room in rooms) room.name: floorOf(room.name)};

    final freeBySlot = <List<String>>[];
    for (final slot in ordered) {
      final free = rooms
          .where((room) => room.capacity >= minCapacity)
          .where((room) => slotsByRoom[room.name]?.elementAtOrNull(slot) == 0)
          .map((room) => room.name)
          .toList();
      if (free.isEmpty) {
        return PlannerFailure('第 ${slot + 1} 节没有满足容量要求的空闲教室');
      }
      freeBySlot.add(free);
    }

    var costs = {for (final name in freeBySlot.first) name: 0};
    final backPointers = <Map<String, String?>>[];

    for (var index = 1; index < freeBySlot.length; index++) {
      final nextCosts = <String, int>{};
      final back = <String, String?>{};
      for (final next in freeBySlot[index]) {
        var bestCost = 1 << 30;
        String? bestPrev;
        for (final entry in costs.entries) {
          final step = ((floors[entry.key] ?? 0) - (floors[next] ?? 0)).abs();
          final total = entry.value + step;
          if (total < bestCost) {
            bestCost = total;
            bestPrev = entry.key;
          }
        }
        nextCosts[next] = bestCost;
        back[next] = bestPrev;
      }
      costs = nextCosts;
      backPointers.add(back);
    }

    var lastRoom =
        (costs.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value)))
            .first
            .key;
    final path = <String>[lastRoom];
    for (var index = backPointers.length - 1; index >= 0; index--) {
      final prev = backPointers[index][lastRoom];
      if (prev == null) return const PlannerFailure('无法生成教室路径');
      path.insert(0, prev);
      lastRoom = prev;
    }

    final steps = <PlannerStep>[
      for (var index = 0; index < path.length; index++)
        PlannerStep(
          slot: ordered[index],
          room: path[index],
          floor: floors[path[index]] ?? 0,
        ),
    ];
    var changes = 0;
    for (var index = 1; index < steps.length; index++) {
      changes += (steps[index].floor - steps[index - 1].floor).abs();
    }
    return PlannerSuccess(steps: steps, floorChanges: changes);
  }
}
