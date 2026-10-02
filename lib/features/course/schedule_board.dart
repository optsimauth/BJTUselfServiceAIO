import '../../data/models/course/course_model.dart';
import '../../data/models/course/schedule_position.dart';
import 'schedule_weeks.dart';

/// 课表网格。**第一维是 [节次 - 1]，第二维是 [星期 - 1]，第三维是该格里的课**。
///
/// 也就是 8 行 x 7 列 x N 门课。同一格可能有多门课（上下午连堂、不同课撞在
/// 一个时段），所以格子本身是列表而不是单个 [Course]。
///
/// 旧项目返回的是 56 格的扁平列表，UI 每次都要自己换算下标；
/// 这里直接把结构定成「行 = 节次、列 = 星期」，渲染端按行列取即可，
/// 不用再关心 locationIndex 的跳位规则。
typedef CourseBoard = List<List<List<Course>>>;

/// 网格的构建与查询。全部是纯函数，方便单测。
abstract final class ScheduleBoardBuilder {
  /// 8 x 7 的空网格。
  ///
  /// 类型参数写全：嵌套的 `List.generate` 靠上下文推断会把 `T` 推成内层类型，
  /// 这里显式写死免得踩这个坑。
  static CourseBoard empty() => List<List<List<Course>>>.generate(
    SchedulePosition.sectionCount,
    (_) => List<List<Course>>.generate(
      SchedulePosition.weekdayCount,
      (_) => <Course>[],
      growable: true,
    ),
    growable: false,
  );

  /// 把课程摊进网格。位置未知的课程（比如只从 JSON 接口拿到的行）不落格，
  /// 但会出现在 [unplaced] 里，界面上可以提示「有 N 门课没有排期信息」。
  static CourseBoard build(Iterable<Course> courses, {List<Course>? unplaced}) {
    final board = empty();
    for (final course in courses) {
      if (!course.isPlaced) {
        unplaced?.add(course);
        continue;
      }
      board[course.sectionIndex][course.dayIndex].add(course);
    }
    for (final row in board) {
      _sortRow(row);
    }
    return board;
  }

  /// 按学期 + 周次筛完再落格。这是页面上最主要的组合。
  static CourseBoard buildFiltered({
    required Iterable<Course> courses,
    required bool Function(Course course) isCurrentSemester,
    int week = ScheduleWeeks.allWeeks,
    List<Course>? unplaced,
  }) {
    return build(
      courses.where(
        (course) =>
            isCurrentSemester(course) &&
            ScheduleWeeks.includesWeek(course.time, week),
      ),
      unplaced: unplaced,
    );
  }

  /// 同一格里按课程名排，保证每次刷新顺序稳定（否则滚动/复用会闪）。
  static void _sortRow(List<List<Course>> row) {
    for (final cell in row) {
      cell.sort((a, b) => a.name.compareTo(b.name));
    }
  }
}

/// 网格的只读查询。
abstract final class ScheduleBoardQuery {
  /// 越界安全：节次 1..8、星期 1..7。
  static List<Course> at(CourseBoard board, int section, int weekday) {
    if (section < 1 || section > SchedulePosition.sectionCount) return const [];
    if (weekday < 1 || weekday > SchedulePosition.weekdayCount) return const [];
    return board[section - 1][weekday - 1];
  }

  /// 整行（第 N 节的 7 节课）。
  static List<Course> row(CourseBoard board, int section) => List.generate(
    SchedulePosition.weekdayCount,
    (column) => at(board, section, column + 1),
  ).expand((cell) => cell).toList(growable: false);

  /// 整列（某一天的所有课，按节次从早到晚）。
  static List<Course> column(CourseBoard board, int weekday) {
    if (weekday < 1 || weekday > SchedulePosition.weekdayCount) return const [];
    return [
      for (var section = 1; section <= SchedulePosition.sectionCount; section++)
        ...at(board, section, weekday),
    ];
  }

  /// 网格上共有多少节课（同一门课占多个格子就重复计数，和界面上看到的色块数一致）。
  static int courseCount(CourseBoard board) => board.fold(
    0,
    (sum, row) => sum + row.fold(0, (inner, cell) => inner + cell.length),
  );

  static bool isEmpty(CourseBoard board) => courseCount(board) == 0;

  /// 网格上出现过的所有格子（去重），用于「今天有课吗」这类判断。
  static Set<String> occupiedCellKeys(CourseBoard board) => {
    for (var section = 1; section <= SchedulePosition.sectionCount; section++)
      for (var weekday = 1; weekday <= SchedulePosition.weekdayCount; weekday++)
        if (at(board, section, weekday).isNotEmpty) '$section-$weekday',
  };
}
