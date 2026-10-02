import 'package:flutter/foundation.dart';

import '../../data/models/classroom/classroom_model.dart';
import 'classroom_room_view.dart';

/// 排序依据。
enum ClassroomSortKey {
  freeDays('空闲天数'),
  used('此刻人数'),
  occupancy('此刻占比'),
  capacity('容量'),
  roomName('教室号');

  const ClassroomSortKey(this.label);

  /// 排序下拉里的字。
  final String label;
}

/// 「空教室」按什么口径算空。四选一，不做组合 ——
/// 组合起来（「空闲且坐得下人且占比低」）没有一次能说清，且筛出来的差别
/// 用户自己看不出来，只会以为页面在乱跳。
enum ClassroomFreeFilter {
  /// 不筛。
  any('不限'),

  /// 当前这一节没排课，而且此刻还坐得下人。「我现在能不能进去坐」。
  nowFree('此刻空闲'),

  /// 所选那天 7 节全空。「我今天要在里面待一天」。
  dayFree('整天空闲'),

  /// 一周 49 节全空。「这间教室这学期没人用」。
  weekFree('整周全空');

  const ClassroomFreeFilter(this.label);

  final String label;

  bool get isActive => this != ClassroomFreeFilter.any;
}

/// 教室课表的「现在在看什么」：搜哪个、按什么口径筛空、按什么排。
///
/// 纯计算，不碰网络也不碰 widget，所以每一条都能单测。
@immutable
class ClassroomFilter {
  const ClassroomFilter({
    this.sortKey = ClassroomSortKey.freeDays,
    this.descending = true,
    this.freeFilter = ClassroomFreeFilter.any,
    this.maxUsed,
    this.query = '',
  });

  final ClassroomSortKey sortKey;

  /// 空闲天数默认降序（多的在前），其余默认升序（少的在前）——
  /// 「找一间空的」两种方向都指向同一头，默认降序是给空闲天数定的。
  final bool descending;

  final ClassroomFreeFilter freeFilter;

  /// 此刻人数上限。null = 不限。只对「此刻」有效，UI 上写明。
  final int? maxUsed;

  /// 教室号关键词。
  final String query;

  /// 有没有在筛。用来决定要不要显示「清空筛选」。
  bool get isFiltered =>
      freeFilter.isActive || maxUsed != null || query.trim().isNotEmpty;

  /// 归一化后的关键词，空格也算没筛。
  String get keyword => query.trim().toLowerCase();

  ClassroomFilter copyWith({
    ClassroomSortKey? sortKey,
    bool? descending,
    ClassroomFreeFilter? freeFilter,
    int? Function()? maxUsed,
    String? query,
  }) => ClassroomFilter(
    sortKey: sortKey ?? this.sortKey,
    descending: descending ?? this.descending,
    freeFilter: freeFilter ?? this.freeFilter,
    maxUsed: maxUsed == null ? this.maxUsed : maxUsed(),
    query: query ?? this.query,
  );

  /// 换排序依据。方向不动 —— 用户点「人数」时多半是想看人最少的几个，
  /// 但升/降序是用户自己按出来的，替他翻掉会让人以为按钮失灵。
  ClassroomFilter withSortKey(ClassroomSortKey key) =>
      copyWith(sortKey: key, descending: defaultDescendingOf(key));

  /// 每种排序的默认方向：人少/占比低/教室号正序在前；空闲天数与容量多的在前。
  static bool defaultDescendingOf(ClassroomSortKey key) =>
      key == ClassroomSortKey.freeDays || key == ClassroomSortKey.capacity;

  ClassroomFilter toggleDescending() => copyWith(descending: !descending);

  ClassroomFilter withFreeFilter(ClassroomFreeFilter value) =>
      copyWith(freeFilter: value);

  /// 传 null 表示「不限人数」。
  ClassroomFilter withMaxUsed(int? value) =>
      copyWith(maxUsed: () => value);

  ClassroomFilter withQuery(String value) => copyWith(query: value);

  /// 只清掉「筛」的部分（关键词 / 空闲口径 / 人数上限），排序偏好留着 ——
  /// 排序是用户选出来的口味，不该被一次「清空」顺手抹掉。
  ClassroomFilter withoutFilters() =>
      copyWith(freeFilter: ClassroomFreeFilter.any, maxUsed: () => null, query: '');

  bool get hasFilters => isFiltered;

  static const ClassroomFilter initial = ClassroomFilter();

  bool matches(ClassroomRoomView view, {required int weekday, int? section}) {
    if (!matchesFree(view, weekday: weekday, section: section)) return false;
    final limit = maxUsed;
    // 人数读不到的教室在「限人数」下出局 —— 用户要的是「坐得下人的空房」，
    // 把未知混进来等于把找座位的路堵死。
    if (limit != null) {
      final used = view.used;
      if (used == null || used > limit) return false;
    }
    final word = keyword;
    if (word.isEmpty) return true;
    final name = view.roomName.toLowerCase();
    if (name.contains(word)) return true;
    // 只写门牌号也能搜到：`101` 命中 `SY101`、`思源楼101`。
    return ClassroomWeekStatus.roomNumberOf(view.roomName) == word;
  }

  bool matchesFree(
    ClassroomRoomView view, {
    required int weekday,
    int? section,
  }) => switch (freeFilter) {
    ClassroomFreeFilter.any => true,
    // 不在作息时间内就是没课在上，按「这一格空着」算，不把整层楼都筛没。
    ClassroomFreeFilter.nowFree =>
      (section == null || !view.status.isOccupiedAt(weekday, section)) &&
          view.seatsAvailable,
    ClassroomFreeFilter.dayFree => view.status.isFreeAllDay(weekday),
    ClassroomFreeFilter.weekFree => view.status.isFreeAllWeek,
  };

  /// 筛完再排。返回值是新列表，调用方可以随便改。
  List<ClassroomRoomView> apply(
    List<ClassroomRoomView> views, {
    required int weekday,
    int? section,
  }) => views
      .where((view) => matches(view, weekday: weekday, section: section))
      .toList()
    ..sort(compare);

  /// 升 / 降序写进比较函数，而不是排完再把整个列表 `reversed` ——
  /// 那样会把并列时的兜底顺序也一起翻过来，同键的几间教室在两次刷新之间
  /// 看起来就在乱跳。
  int compare(ClassroomRoomView a, ClassroomRoomView b) {
    final primary = switch (sortKey) {
      ClassroomSortKey.roomName => _signed(a.roomName.compareTo(b.roomName)),
      ClassroomSortKey.used => _byNumber(a.used, b.used),
      ClassroomSortKey.occupancy => _byNumber(a.occupancy, b.occupancy),
      ClassroomSortKey.capacity => _signed(a.capacity.compareTo(b.capacity)),
      ClassroomSortKey.freeDays =>
        _signed(a.freeDayCount.compareTo(b.freeDayCount)),
    };
    if (primary != 0) return primary;
    return a.roomName.compareTo(b.roomName);
  }

  int _signed(int value) => descending ? -value : value;

  /// 人数读不到（null）一律沉底，**不管升序还是降序** ——
  /// 「读不到」不是「最少」，把它排到降序的头部就是在骗人。
  static int _byNumber(num? a, num? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
