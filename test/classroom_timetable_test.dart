import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/data/remote/parsers/classroom_parser.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_filter.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_room_view.dart';
import 'package:bjtuselfserviceaio/features/course/lesson_period.dart';
import 'package:flutter_test/flutter_test.dart';

/// 一行教室：行首 `SY101 (90)` + 49 个格子。
/// [titles] 给 null 时不写 title，解析器就该退回按列序推算。
String _roomRow(
  String header,
  List<String> styles, {
  List<String>? titles,
}) {
  final tds = <String>['<td>$header</td>'];
  for (var i = 0; i < styles.length; i++) {
    final title = titles != null && i < titles.length ? titles[i] : '';
    tds.add(
      '<td${title.isEmpty ? '' : ' title="$title"'} '
      'style="background-color:${styles[i]}"></td>',
    );
  }
  return '<tr>${tds.join()}</tr>';
}

List<String> _titles() => [
  for (var day = 1; day <= 7; day++)
    for (var section = 1; section <= 7; section++)
      '星期${const ['一', '二', '三', '四', '五', '六', '日'][day - 1]} 第$section 节',
];

String _page(List<String> rows) =>
    '<html><body><table><thead><tr><th>教室</th></tr></thead>'
    '<tbody>${rows.join()}</tbody></table></body></html>';

List<String> _flat(List<String> values) => List<String>.filled(49, values.first, growable: false);

void main() {
  group('教室占用表解析', () {
    test('行首的教室号和座位数都取出来，49 格按 title 落位', () {
      final styles = _flat(['#ffffff']);
      final html = _page([_roomRow('SY101 (90)', styles, titles: _titles())]);

      final status = ClassroomParser.parseWeekStatus(html, week: 5);

      expect(status.week, 5);
      expect(status.rooms, hasLength(1));
      final room = status.rooms.single;
      expect(room.roomName, 'SY101');
      expect(room.capacity, 90);
      expect(room.cells, hasLength(49));
      expect(room.stateAt(1, 1), ClassroomPeriodState.free);
      expect(room.stateAt(7, 7), ClassroomPeriodState.free);
      expect(room.isFreeAllWeek, isTrue);
      expect(room.freeCountOn(3), 7);
    });

    test('title 优先于列序：学校调了列顺序也不会错位', () {
      final styles = _flat(['#ffffff']);
      final titles = _titles();
      // 两格对调 title：按列序它们在「周二 第4节」和「周四 第3节」，
      // 按 title 却各自属于对方。学校改列顺序时就是这个效果。
      final swap = List<String>.of(titles);
      swap[10] = titles[23]; // 周二第4节 -> 周四第3节
      swap[23] = titles[10]; // 周四第3节 -> 周二第4节
      styles[10] = '#394ed6';
      styles[23] = '#77bf6d';

      final html = _page([_roomRow('SY101 (90)', styles, titles: swap)]);
      final room = ClassroomParser.parseWeekStatus(html, week: 1).rooms.single;

      expect(room.stateAt(4, 3), ClassroomPeriodState.busyBlue);
      expect(room.stateAt(2, 4), ClassroomPeriodState.busyGreen);
      expect(room.freeCountInWeek, 47, reason: '整周只有这两格被占了');
      expect(room.stateAt(1, 1), ClassroomPeriodState.free);
      expect(room.dominantOn(4), ClassroomPeriodState.busyBlue);
      expect(room.freeCountOn(4), 6);
      expect(room.isFreeAllDay(4), isFalse);
      expect(room.isFreeAllDay(1), isTrue);
    });

    test('没有 title 时按列序推算', () {
      final styles = _flat(['#ffffff']);
      styles[14] = '#77bf6d'; // 周三 第1节
      final html = _page([_roomRow('SY101 (90)', styles)]);

      final room = ClassroomParser.parseWeekStatus(html, week: 1).rooms.single;

      expect(room.stateAt(3, 1), ClassroomPeriodState.busyGreen);
      expect(room.stateAt(1, 1), ClassroomPeriodState.free);
    });

    test('认不出来的色值占住格子，不会让后面的下标整体前移', () {
      final styles = _flat(['#ffffff']);
      styles[0] = '#123456';
      final html = _page([_roomRow('SY101', styles, titles: _titles())]);

      final room = ClassroomParser.parseWeekStatus(html, week: 1).rooms.single;

      expect(room.cells, hasLength(49));
      expect(room.stateAt(1, 1), ClassroomPeriodState.unknown);
      expect(room.stateAt(1, 2), ClassroomPeriodState.free);
      expect(room.freeCountOn(1), 6);
    });

    test('三位简写色、大小写和多余空白都认；没有背景色算未知', () {
      final styles = _flat(['#FFF']);
      styles[1] = '#E46868  ';
      final html = _page([_roomRow('SY101', styles)]);

      final room = ClassroomParser.parseWeekStatus(html, week: 1).rooms.single;

      expect(room.stateAt(1, 1), ClassroomPeriodState.free);
      expect(room.stateAt(1, 2), ClassroomPeriodState.busyRed);
      expect(
        ClassroomParser.stateOfStyle('padding:4px'),
        ClassroomPeriodState.unknown,
      );
    });

    test('只有表头 = 这栋楼没有教室，按空结果处理而不是报错', () {
      final status = ClassroomParser.parseWeekStatus(
        _page(const []),
        week: 3,
      );
      expect(status.rooms, isEmpty);
    });

    test('整个页面没有表格 -> 抛出可读错误', () {
      expect(
        () => ClassroomParser.parseWeekStatus('<html></html>', week: 1),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('两个数据源合并', () {
    test('教室名写法不一致时按门牌号把人数挂上去', () {
      final status = ClassroomWeekStatus(
        week: 1,
        rooms: const [ClassroomStatus(roomName: 'SY101', capacity: 90)],
      );
      final views = ClassroomRooms.merge(
        status: status,
        capacities: const [
          ClassroomCapacity(roomName: '思源楼101', capacity: 120, used: 30),
        ],
      );

      expect(views, hasLength(1));
      expect(views.single.used, 30);
      expect(views.single.capacity, 90, reason: '容量以教务那一半为准');
      expect(views.single.occupancy, closeTo(0.333, 0.01));
      expect(views.single.seatsAvailable, isTrue);
    });

    test('副源返回满员 = 人数读不到，报未知而不是报坐满', () {
      final views = ClassroomRooms.merge(
        status: ClassroomWeekStatus(
          week: 1,
          rooms: const [ClassroomStatus(roomName: 'SY101', capacity: 90)],
        ),
        capacities: const [
          ClassroomCapacity(roomName: 'SY101', capacity: 90, used: 90),
        ],
      );
      expect(views.single.used, isNull);
      expect(views.single.seatsAvailable, isFalse);
    });

    test('主源没查到 -> 没有列表（副源不单独撑起一页）', () {
      expect(
        ClassroomRooms.merge(
          status: null,
          capacities: const [
            ClassroomCapacity(roomName: 'SY101', capacity: 90),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('空闲口径与排序', () {
    /// [busy] 记 49 格里哪些被占了（用扁平下标，(day-1)*7 + section-1）。
    List<ClassroomPeriodState> cellsOf(Set<int> busy) {
      final cells = List<ClassroomPeriodState>.filled(
        49,
        ClassroomPeriodState.free,
      );
      for (final index in busy) {
        cells[index] = ClassroomPeriodState.busyRed;
      }
      return cells;
    }

    /// 周一两节有课、周三全天有课的那一间。
    List<ClassroomPeriodState> busyRoom() => cellsOf({
      0, // 周一第1节
      1, // 周一第2节
      14, 15, 16, 17, 18, 19, 20, // 周三全天
    });

    ClassroomRoomView viewOf(
      String name, {
      List<ClassroomPeriodState>? cells,
      int capacity = 100,
      int? used,
    }) => ClassroomRoomView(
      status: ClassroomStatus(
        roomName: name,
        capacity: capacity,
        cells: cells ?? cellsOf(const {}),
      ),
      people: used == null
          ? null
          : ClassroomCapacity(
              roomName: name,
              capacity: capacity,
              used: used,
            ),
    );

    test('空教室数按「整天一节没排」算', () {
      final status = ClassroomWeekStatus(
        week: 1,
        rooms: [
          ClassroomStatus(
            roomName: 'SY101',
            capacity: 100,
            cells: busyRoom(),
          ),
        ],
      );
      expect(status.freeCountAt(1), 0, reason: '周一两节有课');
      expect(status.freeCountAt(2), 1);
      expect(status.freeCountAt(3), 0);
      expect(status.freeCountAt(5), 1);
    });

    test('默认按空闲天数降序；空闲天数相同按教室名升序兜底', () {
      final views = [
        viewOf('SY102'),
        viewOf('SY103'),
        viewOf('SY101', cells: busyRoom()), // 排得最满 -> 垫底
      ];
      final sorted = const ClassroomFilter().apply(views, weekday: 1);

      expect(sorted.map((v) => v.roomName), ['SY102', 'SY103', 'SY101']);
    });

    test('「整天空闲」只留那天七节全空的', () {
      final views = [
        viewOf('SY101', cells: busyRoom()),
        viewOf('SY999'),
      ];
      final kept = const ClassroomFilter()
          .withFreeFilter(ClassroomFreeFilter.dayFree)
          .apply(views, weekday: 1);

      expect(kept.map((v) => v.roomName), ['SY999']);
    });

    test('「此刻空闲」= 这一节没排 且 还坐得下人', () {
      // 周一第1节：SY101 有课 -> 出局；SY102 空但坐满 -> 出局；
      // SY103 空且坐得下 -> 留下。
      final views = [
        viewOf('SY101', cells: busyRoom(), used: 10),
        viewOf('SY102', used: 100),
        viewOf('SY103', used: 5),
      ];
      final kept = const ClassroomFilter()
          .withFreeFilter(ClassroomFreeFilter.nowFree)
          .apply(views, weekday: 1, section: 1);

      expect(kept.map((v) => v.roomName), ['SY103']);
    });

    test('人数上限把读不到人数的教室一起筛掉', () {
      final views = [viewOf('SY101', used: 5), viewOf('SY102')];
      // SY102 没有副源数据 -> 人数未知 -> 出局。
      final kept = const ClassroomFilter()
          .withMaxUsed(10)
          .apply(views, weekday: 1);

      expect(kept.map((v) => v.roomName), ['SY101']);
    });

    test('搜教室号：整名和纯门牌号都能命中', () {
      final views = [viewOf('SY101'), viewOf('SY202')];
      expect(
        const ClassroomFilter().withQuery('SY101').matches(views.first, weekday: 1),
        isTrue,
      );
      expect(
        const ClassroomFilter().withQuery('202').matches(views.last, weekday: 1),
        isTrue,
      );
      expect(
        const ClassroomFilter().withQuery('303').matches(views.last, weekday: 1),
        isFalse,
      );
    });

    test('按人数排序：读不到人数的一律沉底', () {
      final views = [
        viewOf('SY101'),
        viewOf('SY102', used: 40),
        viewOf('SY103', used: 5),
      ];
      final sorted = const ClassroomFilter()
          .withSortKey(ClassroomSortKey.used)
          .apply(views, weekday: 1);

      expect(sorted.map((v) => v.roomName), ['SY103', 'SY102', 'SY101']);
    });

    test('清空只清筛选，排序偏好留着', () {
      final filter = const ClassroomFilter()
          .withSortKey(ClassroomSortKey.used)
          .withQuery('101')
          .withMaxUsed(10);

      final cleared = filter.withoutFilters();

      expect(cleared.hasFilters, isFalse);
      expect(cleared.sortKey, ClassroomSortKey.used);
    });
  });


  test('时间段格子写成 8:00~9:50 的紧凑形式', () {
    expect(SchedulePeriods.bySection(1)!.timeRangeShort, '8:00~9:50');
    expect(SchedulePeriods.bySection(6)!.timeRangeShort, '19:00~20:50');
  });
}
