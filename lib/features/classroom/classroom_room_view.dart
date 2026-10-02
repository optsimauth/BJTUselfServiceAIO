import 'package:flutter/foundation.dart';

import '../../data/models/classroom/classroom_model.dart';

/// 一间教室在界面上的完整样子：教务给的整周占用 + 容量，第三方给的此刻人数。
///
/// [status] 是主源，**没有它这间教室就不存在**（列表由它决定）；
/// [people] 是副源，挂不上就显示「人数未知」，但课表照画。
@immutable
class ClassroomRoomView {
  const ClassroomRoomView({required this.status, this.people});

  final ClassroomStatus status;

  /// 第三方容量服务给的人数。null = 这栋楼不在服务覆盖范围，或没查到。
  final ClassroomCapacity? people;

  String get roomName => status.roomName;

  /// 座位数。优先用教务的（和这一周的排课同源），教务没给才退到第三方。
  int get capacity =>
      status.capacity > 0 ? status.capacity : (people?.capacity ?? 0);

  /// 此刻人数。null = 读不到（这栋楼不覆盖 / 服务没数据 / 被借用时返回满员）。
  ///
  /// 宁可报「未知」也不报「坐满了」—— 后者会直接把人引到一间进不去的教室。
  int? get used {
    final source = people;
    if (source == null || source.capacity <= 0 || source.isCountUnavailable) {
      return null;
    }
    return source.used;
  }

  /// 此刻占用率 0..1。人数读不到时按 0 算。
  double get occupancy {
    final count = used;
    return count == null || capacity <= 0 ? 0 : count / capacity;
  }

  /// 此刻还坐得下人。人数读不到时按 false —— 不拿「未知」当「有座」。
  bool get seatsAvailable {
    final count = used;
    return count != null && capacity - count > 0;
  }

  /// 此刻一个人都没有。
  bool get isPeopleEmpty => used == 0;

  ClassroomPeriodState stateAt(int weekday, int section) =>
      status.stateAt(weekday, section);

  /// 一周里有几天一节没排。课表排序默认按它降序 —— 它只依赖主源，
  /// 副源（人数）在不覆盖的楼里拿不到，用它当默认排序才不会整列同分。
  int get freeDayCount {
    var count = 0;
    for (var weekday = 1; weekday <= ClassroomStatus.weekdayCount; weekday++) {
      if (status.isFreeAllDay(weekday)) count++;
    }
    return count;
  }
}

/// 把两个数据源合成界面要的形态。
abstract final class ClassroomRooms {
  /// 主源决定列表（教务这一页就是这栋楼的教室清单），副源按教室名往上挂人数。
  ///
  /// 名字对不上时退到门牌号：room_view 给 `SY101`，第三方给 `思源楼101`。
  static List<ClassroomRoomView> merge({
    required ClassroomWeekStatus? status,
    required List<ClassroomCapacity> capacities,
  }) {
    if (status == null || status.rooms.isEmpty) return const [];
    final byName = <String, ClassroomCapacity>{
      for (final capacity in capacities) capacity.roomName: capacity,
    };
    final byNumber = <String, ClassroomCapacity>{};
    for (final capacity in capacities) {
      final number = ClassroomWeekStatus.roomNumberOf(capacity.roomName);
      if (number.isNotEmpty) byNumber.putIfAbsent(number, () => capacity);
    }
    return [
      for (final room in status.rooms)
        ClassroomRoomView(
          status: room,
          people: _peopleOf(room, byName, byNumber),
        ),
    ];
  }

  static ClassroomCapacity? _peopleOf(
    ClassroomStatus room,
    Map<String, ClassroomCapacity> byName,
    Map<String, ClassroomCapacity> byNumber,
  ) {
    final exact = byName[room.roomName];
    if (exact != null) return exact;
    final number = ClassroomWeekStatus.roomNumberOf(room.roomName);
    return number.isEmpty ? null : byNumber[number];
  }
}
