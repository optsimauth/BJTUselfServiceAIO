import 'package:flutter/foundation.dart';

/// 第三方容量服务给的一间教室：容量 + 此刻人数。**只有「此刻」**。
@immutable
class ClassroomCapacity {
  const ClassroomCapacity({
    required this.roomName,
    this.capacity = 0,
    this.used = 0,
  });

  final String roomName;
  final int capacity;
  final int used;

  int get free => capacity - used;

  /// 还坐得下人。「只看空闲」用的就是这个口径 —— 只剩两个座位的教室也算，
  /// 否则考试周满楼找座位的场景就没得选了。
  bool get isFree => free > 0;

  /// 一间人都没有。跟 [isFree] 不是一回事：半空的教室也 [isFree]，
  /// 但没人是为了「找间空教室」跑去一间坐了三十人的屋子。
  bool get isEmpty => capacity > 0 && used == 0;

  /// 占用率 0..1。容量读不到时按 0 算 —— 宁可显示「没人」也不要除以零。
  double get occupancy => capacity <= 0 ? 0 : used / capacity;

  /// 人数读不到。第三方服务在教室被借用、没开放、或者干脆没数据时都会返回
  /// `used == capacity`，这时候报一个「坐满了」会直接把人引到一间根本进不去的教室去。
  bool get isCountUnavailable => capacity > 0 && used >= capacity;
}

/// 一栋楼此刻的人数（第三方容量服务的一次回答）。
@immutable
class BuildingInfo {
  const BuildingInfo({
    required this.buildingName,
    this.effectiveDateStart = '',
    this.effectiveDateEnd = '',
    this.classrooms = const [],
  });

  final String buildingName;

  /// 有效期起止，原样透传（格式由服务方决定，不在这里猜）。
  final String effectiveDateStart;
  final String effectiveDateEnd;

  final List<ClassroomCapacity> classrooms;

  int get freeRoomCount => classrooms.where((room) => room.isFree).length;

  int get totalSeats => classrooms.fold(0, (sum, room) => sum + room.capacity);

  bool get hasEffectivePeriod =>
      effectiveDateStart.isNotEmpty && effectiveDateEnd.isNotEmpty;

  /// 有效期一句话。两个字段都拿到才拼，缺一个就整句不显示。
  String? get effectivePeriodText =>
      hasEffectivePeriod ? '$effectiveDateStart 至 $effectiveDateEnd' : null;
}

/// 教室某一节课的占用情况。
///
/// 教务的教室使用查询页**不给文字**，只给每个格子的 `background-color`。
/// 五种占用色对应页面图例上的五种安排（排课/调课/考试/实验/其他），白色为空闲；
/// [unknown] 是认不出来的兜底 —— 学校加了新颜色，或那一格根本没给样式。
enum ClassroomPeriodState {
  /// 空闲（白底）。
  free(0, '空闲'),

  /// `#e46868` 排课。
  busyRed(1, '排课', 0xFFE46868),

  /// `#9e6868` 调课。
  busyBrown(2, '调课', 0xFF9E6868),

  /// `#394ed6` 考试。
  busyBlue(3, '考试', 0xFF394ED6),

  /// `#77bf6d` 实验。
  busyGreen(4, '实验', 0xFF77BF6D),

  /// `#d8cc56` 其他安排。
  busyYellow(5, '其他', 0xFFD8CC56),

  /// 认不出来的色值。
  unknown(-1, '未知');

  const ClassroomPeriodState(this.code, this.label, [this.argb = 0]);

  /// 教务页面上的编号。0 = 空闲，1..5 = 占用，-1 = 认不出来。
  final int code;

  /// 图例 / 详情弹层上写的话。
  final String label;

  /// 页面底色（ARGB）。`free` 与 `unknown` 是 0 —— 它们靠描边和主题色表达，
  /// 画一块实色反而像「有安排」。
  final int argb;

  bool get isFree => this == ClassroomPeriodState.free;

  bool get isOccupied => code > 0;

  bool get isKnown => this != ClassroomPeriodState.unknown;

  /// 同一天七格里「最值得说」的是哪一格。课表上一格只放一个颜色，
  /// 按这个顺序挑出来：排课 > 调课 > 考试 > 实验 > 其他 > 空闲 > 未知。
  int get severity => switch (this) {
    ClassroomPeriodState.unknown => 0,
    ClassroomPeriodState.free => 1,
    ClassroomPeriodState.busyYellow => 2,
    ClassroomPeriodState.busyGreen => 3,
    ClassroomPeriodState.busyBlue => 4,
    ClassroomPeriodState.busyBrown => 5,
    ClassroomPeriodState.busyRed => 6,
  };
}

/// 教室状态页里的一间教室：名字 + 容量 + 一整周 49 格的占用情况。
@immutable
class ClassroomStatus {
  const ClassroomStatus({
    required this.roomName,
    this.capacity = 0,
    this.cells = const [],
  });

  final String roomName;

  /// 行首 `SY101 (90)` 里的座位数。和占用同源，所以课表上的容量
  /// 和这一周的排课一定对得上。
  final int capacity;

  /// 一周 49 格，下标 `(weekday - 1) * 7 + (section - 1)`。
  ///
  /// 解析时按格子的 `title="星期X 第Y节"` 定位，学校调整列顺序也不会错位。
  /// 认不出来的格子记 [ClassroomPeriodState.unknown] 占位，**不留空** ——
  /// 少一格会让后面所有下标整体前移，一间教室的周二会跑到周一去。
  final List<ClassroomPeriodState> cells;

  /// 教务那张表一天 7 列。
  static const int weekdayCount = 7;
  static const int sectionCount = 7;

  static const int totalCells = weekdayCount * sectionCount;

  /// 第 [weekday] 天（1 = 周一）第 [section] 节（1 起）的状态。
  /// 越界或没解析到一律 [ClassroomPeriodState.unknown]，不抛。
  ClassroomPeriodState stateAt(int weekday, int section) {
    if (weekday < 1 || weekday > weekdayCount) {
      return ClassroomPeriodState.unknown;
    }
    if (section < 1 || section > sectionCount) {
      return ClassroomPeriodState.unknown;
    }
    final index = (weekday - 1) * sectionCount + (section - 1);
    return index < cells.length ? cells[index] : ClassroomPeriodState.unknown;
  }

  /// 某天空闲几节。格子没查全时照实数，不会假装满格空闲。
  int freeCountOn(int weekday) {
    var count = 0;
    for (var section = 1; section <= sectionCount; section++) {
      if (stateAt(weekday, section).isFree) count++;
    }
    return count;
  }

  /// 某个格子有没有安排。
  bool isOccupiedAt(int weekday, int section) =>
      stateAt(weekday, section).isOccupied;

  /// 一周空闲几节。
  int get freeCountInWeek => cells.where((state) => state.isFree).length;

  /// [weekday] 那天一节没排。格子必须齐 49 个才算，缺格不算全空。
  bool isFreeAllDay(int weekday) =>
      cells.length >= totalCells && freeCountOn(weekday) == sectionCount;

  /// 一周 49 节全空。
  bool get isFreeAllWeek =>
      cells.length >= totalCells && freeCountInWeek == totalCells;

  /// 某天最「重」的那一格 —— 课表上一天只画一个颜色，用它。
  ClassroomPeriodState dominantOn(int weekday) {
    var best = ClassroomPeriodState.unknown;
    for (var section = 1; section <= sectionCount; section++) {
      final state = stateAt(weekday, section);
      if (state.severity > best.severity) best = state;
    }
    return best;
  }
}

/// 一次教室状态查询的结果：某个教学周 + 该楼每间教室整周的占用。
@immutable
class ClassroomWeekStatus {
  /// 查名表在这里建一次，而不是每次 `statusOf` 现算 ——
  /// 一栋楼几十间教室，翻页时每行都要查一次，不建表就是 O(n²)。
  factory ClassroomWeekStatus({
    required int week,
    List<ClassroomStatus> rooms = const [],
  }) {
    final byName = <String, ClassroomStatus>{};
    final byNumber = <String, ClassroomStatus>{};
    for (final room in rooms) {
      byName[room.roomName] = room;
      final number = roomNumberOf(room.roomName);
      // 门牌号重复时保留先出现的那个：宁可配错一间，也不能把后面的全顶掉。
      if (number.isNotEmpty) byNumber.putIfAbsent(number, () => room);
    }
    return ClassroomWeekStatus._(
      week: week,
      rooms: List<ClassroomStatus>.unmodifiable(rooms),
      byName: Map<String, ClassroomStatus>.unmodifiable(byName),
      byNumber: Map<String, ClassroomStatus>.unmodifiable(byNumber),
    );
  }

  const ClassroomWeekStatus._({
    required this.week,
    required this.rooms,
    required Map<String, ClassroomStatus> byName,
    required Map<String, ClassroomStatus> byNumber,
  }) : _byName = byName,
       _byNumber = byNumber;

  /// 教学周（`zc` 参数）。
  final int week;

  final List<ClassroomStatus> rooms;

  final Map<String, ClassroomStatus> _byName;
  final Map<String, ClassroomStatus> _byNumber;

  /// 某一间教室。两个数据源的教室名写法不一致（room_view 给 `SY101`，
  /// 第三方服务给 `思源楼101`），所以先按整名找，再退到门牌号相同。
  ClassroomStatus? statusOf(String roomName) {
    final trimmed = roomName.trim();
    final exact = _byName[trimmed];
    if (exact != null) return exact;
    final number = roomNumberOf(trimmed);
    return number.isEmpty ? null : _byNumber[number];
  }

  /// [weekday] 那天一节没排的教室数。
  int freeCountAt(int weekday) =>
      rooms.where((room) => room.isFreeAllDay(weekday)).length;

  bool get isEmpty => rooms.isEmpty;

  /// 某天是几号星期（1 = 周一 .. 7 = 周日）。
  /// 界面上要写清「今天」是谁，所以这个换算只留这一处。
  static int weekdayIndexOf(DateTime now) => now.weekday - DateTime.monday + 1;

  /// 门牌号：名字里结尾的那段数字。
  ///
  /// 写法五花八门（`思源楼101` / `思源楼 101` / `思源楼-101` / 光秃秃的 `101`），
  /// 不按分隔符切，直接取结尾的数字：四种写法都能落到同一个 `101` 上。
  // ponytail: 只比门牌号，`SY4101` 和 `思源楼101` 会认成同一间。按楼查之后两个源
  // 都在同一栋楼里，撞号概率低；真撞了就让用户看到两次「101」，不加猜测逻辑。
  static String roomNumberOf(String roomName) =>
      RegExp(r'(\d+)\D*$').firstMatch(roomName.trim())?.group(1) ?? '';
}

/// 一栋教学楼。
///
/// [id] 是教务 room_view 页 `jxlh` 下拉的数字 ID，**请求必须传它** ——
/// 传中文楼名只会返回表头，一间教室都查不到（KMP 项目 2026-08-07 线上核对）。
/// [name] 是第三方容量服务的 `building` 参数，两个源各要各的，所以两个都得留着。
@immutable
class ClassroomBuilding {
  const ClassroomBuilding({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ClassroomBuilding && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 教学楼清单。
///
/// 名单来自教务 room_view 页 `jxlh` 下拉（全量 36 栋）。
/// 第三方容量服务只覆盖其中一部分楼 —— 见 [peopleSourceNames]，
/// 不在那份名单里的楼查得到课表、查不到此刻人数。
abstract final class ClassroomBuildings {
  static const List<ClassroomBuilding> all = [
    ClassroomBuilding(id: '13', name: '第十七号教学楼'),
    ClassroomBuilding(id: '100', name: '学生活动服务中心'),
    ClassroomBuilding(id: '1', name: '思源楼'),
    ClassroomBuilding(id: '2', name: '思源西楼'),
    ClassroomBuilding(id: '3', name: '思源东楼'),
    ClassroomBuilding(id: '4', name: '第九教学楼'),
    ClassroomBuilding(id: '5', name: '第八教学楼'),
    ClassroomBuilding(id: '6', name: '第五教学楼'),
    ClassroomBuilding(id: '7', name: '第二教学楼'),
    ClassroomBuilding(id: '11', name: '逸夫教学楼'),
    ClassroomBuilding(id: '12', name: '机械楼'),
    ClassroomBuilding(id: '91', name: '天佑会堂'),
    ClassroomBuilding(id: '92', name: '工程素质'),
    ClassroomBuilding(id: '93', name: '综合实验楼'),
    ClassroomBuilding(id: '94', name: '机械实验馆'),
    ClassroomBuilding(id: '9', name: '东区二教'),
    ClassroomBuilding(id: '8', name: '东区一教'),
    ClassroomBuilding(id: '10', name: '东教三楼'),
    ClassroomBuilding(id: '90', name: '科技大厦'),
    ClassroomBuilding(id: '14', name: '电气工程楼'),
    ClassroomBuilding(id: '101', name: '综合体育馆'),
    ClassroomBuilding(id: '102', name: '新综合体育馆'),
    ClassroomBuilding(id: '16', name: '东校区计算机机房'),
    ClassroomBuilding(id: '15', name: '交通运输科学馆'),
    ClassroomBuilding(id: '17', name: '工程训练中心'),
    ClassroomBuilding(id: '18', name: '第七教学楼'),
    ClassroomBuilding(id: '19', name: '工程结构实验楼'),
    ClassroomBuilding(id: '20', name: '土木工程楼'),
    ClassroomBuilding(id: '103', name: '科技楼'),
    ClassroomBuilding(id: '104', name: '思源楼A座'),
    ClassroomBuilding(id: '105', name: '思源楼B座'),
    ClassroomBuilding(id: '106', name: '致远楼'),
    ClassroomBuilding(id: '107', name: '知行楼'),
    ClassroomBuilding(id: '108', name: '逸夫楼'),
    ClassroomBuilding(id: '109', name: '信息楼'),
  ];

  /// 第三方容量服务支持的楼名。不在这份名单里的楼不查人数（省一次必然失败的请求）。
  static const Set<String> peopleSourceNames = {
    '第十七号教学楼',
    '思源楼',
    '思源西楼',
    '思源东楼',
    '第九教学楼',
    '第八教学楼',
    '第五教学楼',
    '逸夫教学楼',
    '机械楼',
    '东区二教',
    '东区一教',
  };

  static ClassroomBuilding? byName(String name) {
    for (final building in all) {
      if (building.name == name) return building;
    }
    return null;
  }

  static ClassroomBuilding? byId(String id) {
    for (final building in all) {
      if (building.id == id) return building;
    }
    return null;
  }
}

/// 周次范围。教务 zc 下拉可到 30，这里照抄。
abstract final class ClassroomWeeks {
  static const int min = 1;
  static const int max = 30;

  static int clamp(int week) => week < min ? min : (week > max ? max : week);
}
