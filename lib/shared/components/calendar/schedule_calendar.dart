import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/course/course_model.dart';
import '../../../data/models/course/schedule_position.dart';
import '../../../features/course/lesson_period.dart';
import '../../../features/course/schedule_board.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../../shared/theme/spacing.dart';

/// 课表网格。
///
/// 布局分三层，窄屏 / 宽屏 / 桌面各自拿到合适的形态：
/// - 左列节次轨固定宽度，横向滚动时**不跟着动**（学生永远看得见"这是第几节"）；
/// - 7 个星期列共享一个 [ScrollController]，表头和内容横向同步滚动；
/// - 内容整体纵向滚动，行高按可用高度自适应（桌面上一屏放下 8 行）。
///
/// 只负责渲染，不做筛选：学期/周次筛选在 `CourseController` 里已经做完。
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.board,
    this.currentWeek,
    this.selectedWeek,
    this.onCourseTap,
    this.now,
    this.emptyBuilder,
  });

  /// 8 行 x 7 列，下标 [节次-1][星期-1]。
  final CourseBoard board;

  /// 当前教学周；用于在表头上标注"看的是不是本周"。
  final int? currentWeek;

  /// 正在查看的周次；0 / null 表示全部周。
  final int? selectedWeek;

  final ValueChanged<Course>? onCourseTap;

  /// 「现在」的时间，测试可注入。默认每 30 秒自走，跨节次时高亮会自动切换。
  final DateTime? now;

  /// 一节课都没有时的占位（默认给出"这一周没有课"的文案）。
  final WidgetBuilder? emptyBuilder;

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  // Flutter 不允许一个 ScrollController 挂到两个 ScrollView 上（表头和内容必须
  // 各有一个），所以这里用两个 + 双向监听把偏移锁在一起。
  final ScrollController _horizontal = ScrollController();
  final ScrollController _headerHorizontal = ScrollController();

  /// 纵向滚动的 controller 自己拿着 —— 常驻滚动条要靠它才知道画在哪。
  final ScrollController _vertical = ScrollController();

  /// 防止 A 带动 B、B 又带动 A 的回环。
  bool _syncing = false;

  Timer? _clock;
  late DateTime _now;

  static const double _sectionRailWidth = 54;
  static const double _minDayColumnWidth = 78;
  static const double _rowHeightFloor = 58;
  static const double _rowHeightCeiling = 96;
  static const double _headerHeight = 46;

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(() => _link(_horizontal, _headerHorizontal));
    _headerHorizontal.addListener(() => _link(_headerHorizontal, _horizontal));
    _now = widget.now ?? DateTime.now();
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void didUpdateWidget(ScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final injected = widget.now;
    if (injected != null && injected != _now) {
      _now = injected;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _horizontal.dispose();
    _headerHorizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  /// 把 [from] 的横向偏移抄给 [to]，两边永远同位置。
  void _link(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    final offset = from.offset;
    if (offset == to.offset) return;
    _syncing = true;
    to.jumpTo(
      offset.clamp(to.position.minScrollExtent, to.position.maxScrollExtent),
    );
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (ScheduleBoardQuery.isEmpty(widget.board)) {
      return widget.emptyBuilder?.call(context) ?? const EmptyScheduleView();
    }
    final activeSection = SchedulePeriods.currentSectionAt(_now);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = _dayColumnWidth(constraints.maxWidth);
        final rowHeight = _rowHeight(constraints.maxHeight);
        return Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _sectionRailWidth),
                  Expanded(
                    child: _SharedHorizontalScroll(
                      controller: _headerHorizontal,
                      child: _WeekdayHeader(
                        columnWidth: columnWidth,
                        today: _now.weekday,
                        isViewingCurrentWeek: _isViewingCurrentWeek,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _vertical,
                child: SingleChildScrollView(
                  controller: _vertical,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionRail(rowHeight: rowHeight),
                      Expanded(
                        child: _SharedHorizontalScroll(
                          controller: _horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var weekday = 1;
                                weekday <= SchedulePosition.weekdayCount;
                                weekday++
                              )
                                _DayColumn(
                                  board: widget.board,
                                  width: columnWidth,
                                  weekday: weekday,
                                  isToday: weekday == _now.weekday,
                                  rowHeight: rowHeight,
                                  activeSection: activeSection,
                                  onCourseTap: widget.onCourseTap,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 表头标"今天"只在看本周时才有意义：翻到第 9 周还说"今天"会误导。
  bool get _isViewingCurrentWeek {
    final selected = widget.selectedWeek;
    if (selected == null || selected <= 0) return true;
    final current = widget.currentWeek;
    return current == null || current <= 0 || selected == current;
  }

  /// 窄屏时一列至少 [_minDayColumnWidth]，再窄文字会挤成两行没法读。
  double _dayColumnWidth(double availableWidth) {
    final fairShare =
        (availableWidth - _sectionRailWidth) / SchedulePosition.weekdayCount;
    return fairShare < _minDayColumnWidth ? _minDayColumnWidth : fairShare;
  }

  /// 8 行尽量塞进一屏，但不低于 [_rowHeightFloor]，超出就纵向滚动。
  double _rowHeight(double availableHeight) {
    final fairShare = availableHeight / SchedulePosition.sectionCount;
    if (fairShare < _rowHeightFloor) return _rowHeightFloor;
    if (fairShare > _rowHeightCeiling) return _rowHeightCeiling;
    return fairShare;
  }
}

/// 共享 controller 的横向滚动容器：表头和内容都用它，滚动才会同步。
class _SharedHorizontalScroll extends StatelessWidget {
  const _SharedHorizontalScroll({
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    controller: controller,
    physics: const ClampingScrollPhysics(),
    child: child,
  );
}

/// 表头：星期几 + 今天高亮。
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({
    required this.columnWidth,
    required this.today,
    required this.isViewingCurrentWeek,
  });

  final double columnWidth;
  final int today;

  /// 决定要不要显示"今天"角标。
  final bool isViewingCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showBadge = isViewingCurrentWeek;
    return Row(
      children: [
        for (var index = 0; index < SchedulePosition.weekdayCount; index++)
          _HeaderCell(
            width: columnWidth,
            isToday: index + 1 == today,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  SchedulePeriods.weekdayTitles[index],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: index + 1 == today
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                ),
                Text(
                  showBadge && index + 1 == today ? '今天' : '',
                  style: AppTypography.captionMuted.copyWith(
                    fontSize: AppTypography.size(10),
                    height: 1.2,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.isToday,
    required this.child,
  });

  final double width;
  final bool isToday;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant),
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// 左列节次轨：第一节 08:00-09:50 这样的固定信息，横向滚动时不跟着动。
class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.rowHeight});

  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _ScheduleCalendarState._sectionRailWidth,
      child: Column(
        children: [
          for (
            var section = 1;
            section <= SchedulePosition.sectionCount;
            section++
          )
            _SectionLabel(
              section: section,
              height: rowHeight,
              background: scheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderColor: scheme.outlineVariant,
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.section,
    required this.height,
    required this.background,
    required this.borderColor,
  });

  final int section;
  final double height;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final time = SchedulePeriods.timeOf(section);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            SchedulePeriods.labelOf(section),
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (time.isNotEmpty)
            Text(
              time,
              textAlign: TextAlign.center,
              style: AppTypography.captionMuted.copyWith(
                fontSize: AppTypography.size(9),
                height: 1.25,
              ),
              maxLines: 2,
            ),
        ],
      ),
    );
  }
}

/// 一个星期日的所有课，从第一节排到第八节。
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.board,
    required this.width,
    required this.weekday,
    required this.isToday,
    required this.rowHeight,
    required this.activeSection,
    this.onCourseTap,
  });

  final CourseBoard board;
  final double width;
  final int weekday;
  final bool isToday;
  final double rowHeight;
  final int? activeSection;
  final ValueChanged<Course>? onCourseTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (
          var section = 1;
          section <= SchedulePosition.sectionCount;
          section++
        )
          _ScheduleCell(
            courses: ScheduleBoardQuery.at(board, section, weekday),
            width: width,
            height: rowHeight,
            isToday: isToday,
            isActive: activeSection == section,
            borderColor: scheme.outlineVariant,
            todayTint: scheme.primaryContainer.withValues(alpha: 0.16),
            onCourseTap: onCourseTap,
          ),
      ],
    );
  }
}

/// 一个格子：可能 0 门、1 门或多门课。
class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.courses,
    required this.width,
    required this.height,
    required this.isToday,
    required this.isActive,
    required this.borderColor,
    required this.todayTint,
    this.onCourseTap,
  });

  final List<Course> courses;
  final double width;
  final double height;
  final bool isToday;
  final bool isActive;
  final Color borderColor;
  final Color todayTint;
  final ValueChanged<Course>? onCourseTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isToday ? todayTint : null,
        border: Border(
          right: BorderSide(color: borderColor.withValues(alpha: 0.5)),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      // 一格多课时让它们平分高度，最小 22，保证点得中。
      child: courses.isEmpty
          ? null
          : Column(
              children: [
                for (final course in courses)
                  Expanded(
                    child: CourseChip(
                      course: course,
                      isOngoing: isActive && isToday,
                      onTap: onCourseTap == null
                          ? null
                          : () => onCourseTap!(course),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 单节课的色块。同一门课固定取同一个颜色（[AppColors.forCourse]）。
class CourseChip extends StatelessWidget {
  const CourseChip({
    super.key,
    required this.course,
    this.isOngoing = false,
    this.onTap,
  });

  final Course course;

  /// 是不是「此刻正在上」。
  final bool isOngoing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forCourse(course.courseId);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: color.withValues(alpha: isOngoing ? 0.30 : 0.15),
        borderRadius: AppRadius.sm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.sm,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.sm,
              border: Border(
                left: BorderSide(color: color, width: isOngoing ? 4 : 3),
                top: isOngoing
                    ? BorderSide(color: color, width: 1.5)
                    : BorderSide.none,
                right: isOngoing
                    ? BorderSide(color: color, width: 1.5)
                    : BorderSide.none,
                bottom: isOngoing
                    ? BorderSide(color: color, width: 1.5)
                    : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: _CourseLabel(course: course),
          ),
        ),
      ),
    );
  }
}

/// 色块里的文字：只放课程名 + 地点。
///
/// 课号 / 教师 / 周次 / 时间全部留给详情弹层 —— 格子只有两行高，
/// 再塞就是一堆省略号。想看细节点一下色块。
class _CourseLabel extends StatelessWidget {
  const _CourseLabel({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 教务偶尔给出空课名，这时用课号顶上，别留一块空白格子。
    final name = course.name.trim().isEmpty ? course.courseId : course.name;
    final place = course.place.trim();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (place.isNotEmpty && place != '未知地点')
          Text(
            place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionMuted.copyWith(
              fontSize: AppTypography.sizeFixed(10),
              height: 1.1,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// 空态：区分「这一周没课」和「加载失败」。
class EmptyScheduleView extends StatelessWidget {
  const EmptyScheduleView({super.key, this.onPickAnotherWeek});

  /// 给一个「看全部周」的快捷入口。
  final VoidCallback? onPickAnotherWeek;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('这一周没有课', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '换个周次，或切到「全部周」看看整学期',
            style: AppTypography.captionMuted,
            textAlign: TextAlign.center,
          ),
          if (onPickAnotherWeek != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickAnotherWeek,
              icon: const Icon(Icons.all_inclusive, size: 18),
              label: const Text('看全部周'),
            ),
          ],
        ],
      ),
    ),
  );
}
