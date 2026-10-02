import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../data/models/classroom/classroom_model.dart';
import '../../data/repositories/classroom_repository.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/login_required.dart';
import '../course/lesson_period.dart';
import 'classroom_controller.dart';
import 'classroom_room_view.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/theme/typography.dart';

/// 一栋教学楼的**教室占用课表**。
///
/// 顺序按用户想问题的顺序来：先定周数，再选星期几，然后每间教室**一行七个时间段**，
/// 一眼看完那天哪几节空着。没有搜索、没有筛选 —— 想找某间教室时翻列表比打字快。
///
/// 两个数据源：教务教室使用查询给整周占用和容量（主源，决定列表里有哪些教室）；
/// 第三方容量服务给此刻人数（副源，挂不上就少一条信息，不影响课表）。
class ClassroomPage extends StatefulWidget {
  const ClassroomPage({
    super.key,
    required this.building,
    this.repository,
    this.clock,
  });

  final ClassroomBuilding building;

  /// 数据来源。不传就从 [ServiceScope] 拿，测试里注入内存实现。
  final ClassroomRepository? repository;

  /// 当前时间。测试里注入固定时刻，才能断言「今天」高亮和当前节次。
  final DateTime Function()? clock;

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  late final ClassroomController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClassroomController(
      repository:
          widget.repository ?? ServiceScope.of(context).classroomRepository,
      building: widget.building,
      clock: widget.clock,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(widget.building.name),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: '刷新',
              onPressed: _controller.statusState.isLoading
                  ? null
                  : _controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: LoginRequired(
        builder: (context) => ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => AsyncView<ClassroomWeekStatus>(
            state: _controller.statusState,
            onRetry: _controller.load,
            loadingMessage: '正在查教室占用…',
            isEmpty: (status) => status.rooms.isEmpty,
            emptyBuilder: (_) =>
                EmptyClassroomView(buildingName: widget.building.name),
            builder: (context, _) => _ClassroomBody(controller: _controller),
          ),
        ),
      ),
    );
  }
}

class _ClassroomBody extends StatelessWidget {
  const _ClassroomBody({required this.controller});

  final ClassroomController controller;

  @override
  Widget build(BuildContext context) {
    final rooms = controller.rooms();
    return Column(
      children: [
        _WeekBar(controller: controller),
        _WeekdayPicker(controller: controller),
        const _LegendRow(),
        _StatusBanner(controller: controller),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              itemCount: rooms.length,
              itemBuilder: (context, index) => _RoomCard(
                key: ValueKey('classroom-room-${rooms[index].roomName}'),
                view: rooms[index],
                weekday: controller.weekday,
                isCurrentWeek: controller.isCurrentWeek,
                todayWeekday: controller.todayWeekday,
                currentSection: controller.isCurrentWeek
                    ? controller.currentSection
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 周切换那一行：\`< 第 5 周 >\`，外加这栋楼此刻的一句话。
class _WeekBar extends StatelessWidget {
  const _WeekBar({required this.controller});

  final ClassroomController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = controller.statusState.isLoading;
    final weekdayName = SchedulePeriods.weekdayTitles[controller.weekday - 1];
    final free = controller.freeRoomCountOnWeekday;
    final total = controller.totalRooms;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _WeekArrowButton(
                tooltip: '上一周',
                icon: Icons.chevron_left,
                onPressed: controller.week > ClassroomWeeks.min && !loading
                    ? () => controller.nudgeWeek(-1)
                    : null,
              ),
              Expanded(
                child: Text(
                  controller.isCurrentWeek
                      ? '第 ${controller.week} 周 · 本周'
                      : '第 ${controller.week} 周',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _WeekArrowButton(
                tooltip: '下一周',
                icon: Icons.chevron_right,
                onPressed: controller.week < ClassroomWeeks.max && !loading
                    ? () => controller.nudgeWeek(1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              '$weekdayName · $total 间教室里有 $free 间一节没排',
              if (controller.effectivePeriod != null)
                '有效期 ${controller.effectivePeriod}',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!controller.isCurrentWeek)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.goCurrentWeek,
                child: const Text('回到本周'),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekArrowButton extends StatelessWidget {
  const _WeekArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

/// 星期几。切天只换本地状态，不发请求 —— 整周表已经在手上了。
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.controller});

  final ClassroomController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '看哪一天',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (
                    var weekday = 1;
                    weekday <= ClassroomStatus.weekdayCount;
                    weekday++
                  )
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: _DayPill(
                        label: SchedulePeriods.weekdayShortNames[weekday - 1],
                        selected: controller.weekday == weekday,
                        isToday:
                            controller.isCurrentWeek &&
                            weekday == controller.todayWeekday,
                        onTap: () => controller.setWeekday(weekday),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sheet,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.sheet,
          // 看别的周时「今天」没有意义，所以描边只在看本周时出现。
          border: isToday && !selected
              ? Border.all(color: scheme.primary)
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 图例：空闲 + 五种占用。跟时间段格子同色，所以看得懂。
class _LegendRow extends StatelessWidget {
  const _LegendRow();

  static const List<ClassroomPeriodState> _legend = [
    ClassroomPeriodState.free,
    ClassroomPeriodState.busyRed,
    ClassroomPeriodState.busyBrown,
    ClassroomPeriodState.busyBlue,
    ClassroomPeriodState.busyGreen,
    ClassroomPeriodState.busyYellow,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final state in _legend)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CellPaint(state: state, radius: 4, size: 12),
                const SizedBox(width: 4),
                Text(
                  state.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.controller});

  final ClassroomController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = controller.statusState;
    if (status is AsyncLoading<ClassroomWeekStatus>) {
      return const Padding(
        key: ValueKey('classroom-status-loading'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    // 切周失败但手上还有上一周的表：说清楚，别默默留着让人以为看的是这周。
    if (status is AsyncError<ClassroomWeekStatus> &&
        controller.status != null) {
      return Padding(
        key: ValueKey('classroom-status-stale'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          '第 ${controller.week} 周没查到，下面还是第 ${controller.status!.week} 周的',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }
    // 副源挂了：只是人数读不到，课表照旧。一句话说明，别让人以为整页坏了。
    if (controller.peopleState is AsyncError<BuildingInfo>) {
      return Padding(
        key: ValueKey('classroom-people-error'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          '此刻人数读不到，课表照常',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// 一间教室 = 一行：名字 / 座位 / 此刻人数，下面是**所选那天**的七个时间段。
class _RoomCard extends StatelessWidget {
  const _RoomCard({
    super.key,
    required this.view,
    required this.weekday,
    required this.isCurrentWeek,
    required this.todayWeekday,
    required this.currentSection,
  });

  final ClassroomRoomView view;

  /// 正被聚焦的那一天。
  final int weekday;

  /// 看的是本周吗。是的话才给「今天」和当前节次上标记。
  final bool isCurrentWeek;

  final int todayWeekday;

  final int? currentSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final used = view.used;
    final isToday = isCurrentWeek && weekday == todayWeekday;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    view.capacity > 0
                        ? '${view.roomName} · ${view.capacity} 座'
                        : view.roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  used == null
                      ? '此刻人数未知'
                      : '$used/${view.capacity} 人 · ${(view.occupancy * 100).round()}%',
                  // 这行是这一栏最重要的数据（还有多少空位），不是脚注：
                  // labelSmall 在大屏上小得几乎看不见。数字等宽，
                  // 人数刷新时右边缘不跳。
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (
                  var section = 1;
                  section <= ClassroomStatus.sectionCount;
                  section++
                )
                  Expanded(
                    child: _PeriodCell(
                      key: ValueKey('classroom-cell-${view.roomName}-$section'),
                      section: section,
                      state: view.stateAt(weekday, section),
                      // 「现在这一节」比「第几格」有用，所以今天此刻有课的格子描红边。
                      isNow: isToday && currentSection == section,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个时间段格子：上行节次号，下行时间段（如 1 / 8:00~9:50）。
/// 时间取自学校作息表，和课表页同一份常量。
class _PeriodCell extends StatelessWidget {
  const _PeriodCell({
    super.key,
    required this.section,
    required this.state,
    required this.isNow,
  });

  final int section;
  final ClassroomPeriodState state;

  /// 今天此刻正在上的那一节。
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = _cellColors(state, scheme);
    final period = SchedulePeriods.bySection(section);

    return Container(
      height: 44,
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadius.sm,
        border: isNow ? Border.all(color: scheme.error, width: 2) : null,
      ),
      child: Column(
        // 拉伸：让下面那行时间拿到格子的实际宽度，窄屏靠 FittedBox 缩字号，
        // 而不是被裁掉半截。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$section',
            style: TextStyle(
              fontSize: AppTypography.size(13),
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              period == null || period.start.isEmpty
                  ? ''
                  : period.timeRangeShort,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppTypography.size(9),
                height: 1.3,
                color: colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 占用状态的「底色 / 字色」。空闲用浅绿，五种占用用主题容器色，
/// 认不出来的格子退回中性灰 —— 底色和字色成对给出，不靠亮度碰运气。
({Color background, Color foreground}) _cellColors(
  ClassroomPeriodState state,
  ColorScheme scheme,
) => switch (state) {
  // 空闲 = 没有状态可报，用中性容器色；写死浅绿在深色底上是一块荧光。
  ClassroomPeriodState.free => (
    background: scheme.surfaceContainerHighest,
    foreground: scheme.onSurfaceVariant,
  ),
  ClassroomPeriodState.busyRed => (
    background: scheme.errorContainer,
    foreground: scheme.onErrorContainer,
  ),
  ClassroomPeriodState.busyBrown => (
    background: scheme.tertiaryContainer,
    foreground: scheme.onTertiaryContainer,
  ),
  ClassroomPeriodState.busyBlue => (
    background: scheme.primaryContainer,
    foreground: scheme.onPrimaryContainer,
  ),
  ClassroomPeriodState.busyGreen => (
    background: scheme.secondaryContainer,
    foreground: scheme.onSecondaryContainer,
  ),
  ClassroomPeriodState.busyYellow || ClassroomPeriodState.unknown => (
    background: scheme.surfaceContainerHighest,
    foreground: scheme.onSurfaceVariant,
  ),
};

/// 图例用的色块，只要底色。
class _CellPaint extends StatelessWidget {
  const _CellPaint({required this.state, required this.radius, this.size});

  final ClassroomPeriodState state;
  final double radius;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: _cellColors(state, scheme).background,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (size == null) return box;
    return SizedBox(width: size, height: size, child: box);
  }
}

class EmptyClassroomView extends StatelessWidget {
  const EmptyClassroomView({super.key, required this.buildingName});

  final String buildingName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              '$buildingName 暂时没查到教室占用',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '可能是这学期没排课，也可能是教务那边还没更新',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
