import 'package:flutter/foundation.dart';

/// 课程时间字段 -> 教学周集合。
///
/// 教务系统的时间字段是一个自由文本，真实见过的写法：
/// - `第1-16周`
/// - `第1周,3周,5周`
/// - `1-8周(单),9-16周(双)`
/// - `第2-16周(单)`
/// - `未知`（解析不出来）
/// - `2026-02-23~2026-07-05`（课程平台兜底只给日期）
///
/// 旧项目 `courseIncludesWeek` 只处理了前两种。这里补上单双周，
/// 并把「解析不出来时怎么办」显式定下来：**不隐藏课程**。宁可多显示一节课，
/// 也不要让学生以为今天没课。
abstract final class ScheduleWeeks {
  /// 「全部周」哨兵值：选中它时不做任何周次过滤。
  static const int allWeeks = 0;

  /// 学期最长周数（用于周次选择器的上界）。
  static const int maxWeek = 26;

  /// 半角/全角逗号、顿号、分号、空白都当作分隔符。
  static final RegExp _separator = RegExp(r'[,;、\s]+');

  /// 去掉「第」「周」这类包裹词，剩下的就是 `1-8`、`1,3` 这样的片段。
  static final RegExp _wrapper = RegExp(r'[第周]');

  /// 匹配到课程在第 [week] 周上课。
  ///
  /// [week] 传 [allWeeks] 一律为 true；时间字段解析不出周次时也为 true。
  static bool includesWeek(String courseTime, int week) {
    if (week <= allWeeks) return true;
    final weeks = weeksOf(courseTime);
    if (weeks.isEmpty) return true;
    return weeks.contains(week);
  }

  /// 展开成具体的周次集合；解析不出来时返回空集。
  static Set<int> weeksOf(String courseTime) {
    final result = <int>{};
    for (final token in _tokensOf(courseTime)) {
      result.addAll(_weeksOfToken(token));
    }
    return result;
  }

  /// 文本里出现过任何周次信息（用于界面上提示「这门课只在这几周上」）。
  static bool hasWeekInfo(String courseTime) => weeksOf(courseTime).isNotEmpty;

  /// 周次选择的显示文案。
  static String labelOf(int week) => week <= allWeeks ? '全部周' : '第 $week 周';

  /// `第1-8周(单)` -> `1-8(单)` -> `['1-8(单)']`。
  static List<String> _tokensOf(String courseTime) {
    if (courseTime.trim().isEmpty) return const [];
    return courseTime
        .replaceAll(_wrapper, '')
        .replaceAll('，', ',')
        .split(_separator)
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// 单个片段 -> 周次集合。支持 `1-8` 区间和 `3` 单周。
  static Set<int> _weeksOfToken(String token) {
    final numbers = RegExp(r'\d+')
        .allMatches(token)
        .map((match) => int.parse(match.group(0)!))
        .toList(growable: false);
    if (numbers.isEmpty) return const {};
    // 出现超出学期周数的数字说明这不是周次，而是日期（`2026-02-23~2026-07-05`
    // 这类课程平台兜底时间字段）。整段丢弃，否则 `2026-02` 会被当成区间
    // 展开成 2..26 周，把课程错误地过滤掉。
    if (numbers.any((value) => value < 1 || value > maxWeek)) return const {};
    if (numbers.length >= 2) {
      return _applyParity(_range(numbers[0], numbers[1]), token);
    }
    return _applyParity({numbers.first}, token);
  }

  /// 闭区间展开；起止颠倒时自动交换。
  static Set<int> _range(int start, int end) {
    final low = start <= end ? start : end;
    final high = start <= end ? end : start;
    // 上界兜底，避免脏数据把集合撑爆。
    final limit = high > maxWeek ? maxWeek : high;
    return {for (var week = low; week <= limit; week++) week};
  }

  /// 单双周过滤：`(单)` 只留奇数周，`(双)` 只留偶数周。
  static Set<int> _applyParity(Set<int> weeks, String token) {
    if (token.contains('单')) {
      return weeks.where((week) => week.isOdd).toSet();
    }
    if (token.contains('双')) {
      return weeks.where((week) => week.isEven).toSet();
    }
    return weeks;
  }
}

/// 周次选择器要展示的选项：`全部周` + 第 1..26 周。
@immutable
class WeekOption {
  const WeekOption(this.week);

  /// [ScheduleWeeks.allWeeks] 表示不过滤。
  final int week;

  String get label => ScheduleWeeks.labelOf(week);

  @override
  bool operator ==(Object other) => other is WeekOption && other.week == week;

  @override
  int get hashCode => week.hashCode;
}

/// 周次选择器的完整选项列表。
abstract final class WeekOptions {
  static List<WeekOption> get all => [
    const WeekOption(ScheduleWeeks.allWeeks),
    for (var week = 1; week <= ScheduleWeeks.maxWeek; week++) WeekOption(week),
  ];
}
