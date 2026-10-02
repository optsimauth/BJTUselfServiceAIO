/// 课表格子的坐标换算。
///
/// 教务系统把一周排成「7 天 x 8 节」，但接口给的 `courseLocationIndex`
/// 是一个**节次优先**的扁平下标：1..56，每 `stride`(=8) 个下标对应一个节次。
/// 其中下标满足 `index % 8 == 0`（换算成星期是 8）的位置恒为空位，
/// 真实只有 7 个工作日格子。这个约定来自旧项目 `_parseCourseCard`：
/// `courseLocationIndex = row * 8 + column + 1`。
abstract final class SchedulePosition {
  /// 每天 8 节（第一节到第八节）。
  static const int sectionCount = 8;

  /// 一周 7 天（周一到周日）。
  static const int weekdayCount = 7;

  /// locationIndex 的步长：跳过一整个节次需要的下标增量。
  static const int stride = sectionCount;

  /// 全部格子的上界（含空位）。
  static const int total = sectionCount * stride;

  /// 表示「没有格子信息」。JSON 接口拿不到位置时会落在这里。
  static const int unknown = 0;

  /// 节次 1..8、星期 1..7 -> 扁平下标 1..56。
  static int locationIndex({required int section, required int weekday}) =>
      (section - 1) * stride + weekday;

  /// 扁平下标 -> 节次 1..8。
  static int sectionOf(int locationIndex) => (locationIndex - 1) ~/ stride + 1;

  /// 扁平下标 -> 星期 1..7（周一是 1，周日是 7）。
  static int weekdayOf(int locationIndex) => (locationIndex - 1) % stride + 1;

  /// 这个下标能不能画到网格上：越界、空位、0 都不能。
  static bool isPlaced(int locationIndex) =>
      locationIndex >= 1 &&
      locationIndex <= total &&
      weekdayOf(locationIndex) <= weekdayCount;

  /// 一天里的第几分钟（0..1439），用于判断「这节课正在进行」。
  static int minuteOfDay(DateTime time) => time.hour * 60 + time.minute;

  /// 星期几（1=周一 .. 7=周日）对应的列下标（0..6）。
  static int columnOfWeekday(int weekday) => weekday - 1;
}
