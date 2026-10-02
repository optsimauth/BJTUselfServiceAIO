import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../models/classroom/classroom_model.dart';

/// 教室相关的两个数据源 -> 模型。
///
/// 两个来源互补，缺一不可：
/// 1. 教务教室使用查询 room_view（HTML，**主源**）：给某栋楼某一个教学周的
///    **整周 49 格**占用 + 每间教室的容量，只有「排了什么」，没有「现在多少人」；
/// 2. 第三方容量服务（JSON，副源）：给某栋楼此刻每间教室的人数与容量。
///
/// 主源驱动列表（它决定这栋楼有哪些教室），副源只往每间教室上补一个人数字段。
abstract final class ClassroomParser {
  /// 一行 = 行首教室格 + 星期 1-7 × 节次 1-7 共 49 格。
  static const int _cellsPerRow = ClassroomStatus.totalCells;

  /// 教室状态页的 `background-color` -> 状态。
  ///
  /// key 一律是归一化之后（展开三位简写）的小写六位色值。
  static const Map<String, ClassroomPeriodState> _byColor = {
    '#ffffff': ClassroomPeriodState.free,
    '#e46868': ClassroomPeriodState.busyRed,
    '#9e6868': ClassroomPeriodState.busyBrown,
    '#394ed6': ClassroomPeriodState.busyBlue,
    '#77bf6d': ClassroomPeriodState.busyGreen,
    '#d8cc56': ClassroomPeriodState.busyYellow,
  };

  // ---- 第三方容量服务（JSON，副源）----

  /// `{"time": ["起", "止"], "data": [[教室名, ?, 已用, 容量], ...]}`。
  ///
  /// 和旧实现比多了两处容错：
  /// - 顶层不是对象（比如服务方回了个 HTML 错误页）时抛可读的错误，
  ///   而不是让 `as Map` 抛一个看不出所以然的类型错误；
  /// - 单行不是 4 段数组就跳过，不让一行脏数据把整栋楼废掉。
  static BuildingInfo parseBuildingInfo(
    String raw, {
    required String buildingName,
  }) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('教室容量接口返回的不是预期格式');
    }
    final json = decoded.cast<String, dynamic>();
    final timeRange = json['time'] as List<dynamic>? ?? const [];
    final rooms = <ClassroomCapacity>[];
    for (final item in json['data'] as List<dynamic>? ?? const []) {
      final room = _capacityOf(item);
      if (room != null) rooms.add(room);
    }
    return BuildingInfo(
      buildingName: buildingName,
      effectiveDateStart: timeRange.isNotEmpty ? '${timeRange[0]}'.trim() : '',
      effectiveDateEnd: timeRange.length > 1 ? '${timeRange[1]}'.trim() : '',
      classrooms: rooms,
    );
  }

  static ClassroomCapacity? _capacityOf(Object? item) {
    if (item is! List || item.length < 4) return null;
    final name = '${item[0]}'.trim();
    if (name.isEmpty) return null;
    return ClassroomCapacity(
      roomName: name,
      capacity: int.tryParse('${item[3]}'.trim()) ?? 0,
      used: int.tryParse('${item[2]}'.trim()) ?? 0,
    );
  }

  // ---- 教务教室使用查询（HTML 表格，主源）----

  /// room_view 教室占用表 -> 该栋楼整周的占用情况。
  ///
  /// 表格结构：每行第一格是 `SY101 (90)`（教室号 + 座位数），后面 49 格按
  /// `title="星期X 第Y节"` 定位，格子里没有文字，只有 `background-color`。
  ///
  /// 学校查不到教室时表格里只有表头（没有数据行），按合法空列表处理 —— 空楼是
  /// 正常结果，不是错误。
  static ClassroomWeekStatus parseWeekStatus(String html, {required int week}) {
    final table = html_parser.parse(html).querySelector('table');
    if (table == null) {
      throw StateError('教室占用页里没有表格（可能登录失效了）');
    }
    final rooms = <ClassroomStatus>[];
    for (final row in table.querySelectorAll('tr')) {
      final room = _statusOf(row);
      if (room != null) rooms.add(room);
    }
    return ClassroomWeekStatus(week: week, rooms: rooms);
  }

  /// 一行 -> 一间教室。不是数据行（表头、说明行）时返回 null。
  static ClassroomStatus? _statusOf(Element row) {
    final cells = row.querySelectorAll('td');
    // 少于 50 格说明这行不是教室行。整行丢掉而不是补空：错位的格子比没有更糟。
    if (cells.length < _cellsPerRow + 1) return null;
    final header = roomHeaderOf(cells.first.text);
    if (header == null) return null;
    final states = List<ClassroomPeriodState>.filled(
      _cellsPerRow,
      ClassroomPeriodState.unknown,
      growable: false,
    );
    // 哪些格子是 title 认领的。按列序推算出来的格子不许覆盖它们 ——
    // 一旦学校在某几格上丢了 title，推算值就会把 title 已经认对的格子顶掉，
    // 而且是「先认对、后顶掉」，肉眼完全看不出来。
    final claimed = List<bool>.filled(_cellsPerRow, false, growable: false);
    for (var offset = 1; offset <= _cellsPerRow; offset++) {
      final cell = cells[offset];
      final byTitle = _positionOf(cell.attributes['title'] ?? '');
      final position =
          byTitle ??
          (
            (offset - 1) ~/ ClassroomStatus.sectionCount + 1,
            (offset - 1) % ClassroomStatus.sectionCount + 1,
          );
      final index =
          (position.$1 - 1) * ClassroomStatus.sectionCount + (position.$2 - 1);
      if (byTitle == null && claimed[index]) continue;
      states[index] = stateOfStyle(cell.attributes['style'] ?? '');
      if (byTitle != null) claimed[index] = true;
    }
    return ClassroomStatus(
      roomName: header.room,
      capacity: header.capacity,
      cells: states,
    );
  }

  // 节次号前后都留 \s*：线上写的是 `第1节`，但一个空格漂移（`第1 节`）不该让整格
  // 定位失败 —— 定位一失败就退回按列序推算，学校一改列序整张表就跟着错位。
  static final RegExp _cellTitle = RegExp(
    r'星期([一二三四五六日天1-7])\s*第\s*(\d+)\s*节',
  );

  /// `星期一 第3节` -> (1, 3)。认不出来返回 null，交给调用方按列序推算。
  static (int, int)? _positionOf(String title) {
    final match = _cellTitle.firstMatch(title.trim());
    if (match == null) return null;
    const weekdays = {
      '一': 1, '1': 1,
      '二': 2, '2': 2,
      '三': 3, '3': 3,
      '四': 4, '4': 4,
      '五': 5, '5': 5,
      '六': 6, '6': 6,
      '日': 7, '天': 7, '7': 7,
    };
    final weekday = weekdays[match.group(1)!];
    if (weekday == null) return null;
    final section = int.tryParse(match.group(2)!);
    if (section == null ||
        section < 1 ||
        section > ClassroomStatus.sectionCount) {
      return null;
    }
    return (weekday, section);
  }

  /// 行首 `SY101 (90)` -> 教室号 + 座位数。座位数读不到就是 0。
  static ({String room, int capacity})? roomHeaderOf(String text) {
    final squeezed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (squeezed.isEmpty) return null;
    final room = squeezed.split(' ').first.split('(').first.trim();
    if (room.isEmpty) return null;
    final capacity =
        int.tryParse(RegExp(r'\((\d+)\)').firstMatch(squeezed)?.group(1) ?? '');
    return (room: room, capacity: capacity ?? 0);
  }

  /// 教室名：整格文字的第一个空白分隔段。
  ///
  /// 连续空白先压成单空格，否则 `思源楼  101` 会解析出带尾空格的 `思源楼`，
  /// 再拿去查名表就永远查不到。
  static String roomNameOf(String text) {
    final squeezed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (squeezed.isEmpty) return '';
    return squeezed.split(' ').first;
  }

  /// 一格的 `style` -> 状态。
  static ClassroomPeriodState stateOfStyle(String style) {
    final color = _backgroundColorOf(style);
    return color == null ? ClassroomPeriodState.unknown : stateOfColor(color);
  }

  /// 从 `style` 里抠出 `background-color` 的值。只认 `#rgb` / `#rrggbb`。
  static String? _backgroundColorOf(String style) {
    final match = RegExp(
      r'background-color\s*:\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(style);
    if (match == null) return null;
    return match.group(1)?.trim().toLowerCase();
  }

  /// 颜色值 -> 状态。大小写、多余空白、三位简写都归一化后再查表，
  /// 认不出来就是 [ClassroomPeriodState.unknown]。
  static ClassroomPeriodState stateOfColor(String color) {
    final normalized = _normalizeColor(color);
    return _byColor[normalized] ?? ClassroomPeriodState.unknown;
  }

  static String _normalizeColor(String color) {
    final squeezed = color.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final short = RegExp(r'^#([0-9a-f])([0-9a-f])([0-9a-f])$')
        .firstMatch(squeezed);
    if (short == null) return squeezed;
    return '#${short.group(1)}${short.group(1)}${short.group(2)}${short.group(2)}'
        '${short.group(3)}${short.group(3)}';
  }
}
