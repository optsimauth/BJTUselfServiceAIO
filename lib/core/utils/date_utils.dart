/// 课表用到的日期/周次计算。Android 侧这份逻辑散在 CourseScheduleScreen 里。
abstract final class AppDateUtils {
  /// 一周 7 天 * 每天 8 节 = 56 个课表格子，对应旧库里的 courseLocationIndex(0..55)。
  static const int slotsPerDay = 8;
  static const int daysPerWeek = 7;
  static const int slotsPerWeek = slotsPerDay * daysPerWeek;

  /// DateTime.weekday 是 1(周一)..7(周日)，格子索引从 0 开始。
  static int slotIndexFor(DateTime time, int section) =>
      (time.weekday - 1) * slotsPerDay + section;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String formatDate(DateTime time) =>
      '${time.year}-${_pad(time.month)}-${_pad(time.day)}';

  static String formatTime(DateTime time) =>
      '${_pad(time.hour)}:${_pad(time.minute)}';

  /// 学期起始日 + 当前日期推算教学周。旧代码靠接口拿 weekCode，这里作为本地兜底。
  static int teachingWeekOf({
    required DateTime semesterStart,
    required DateTime now,
  }) {
    final elapsedDays = now
        .difference(
          DateTime(semesterStart.year, semesterStart.month, semesterStart.day),
        )
        .inDays;
    if (elapsedDays < 0) {
      return 1;
    }
    return elapsedDays ~/ 7 + 1;
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
