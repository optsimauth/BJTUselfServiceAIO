import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_router.dart';
import '../../app/service_locator.dart';
import '../../data/models/calendar/calendar_week.dart';
import '../../data/models/course/course_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../core/state/sync_module.dart';
import '../../core/state/sync_result.dart';
import '../../shared/theme/colors.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/refresh_icon.dart';
import '../course/lesson_period.dart';
import 'change_details_dialog.dart';
import 'home_calendar.dart';
import 'home_event_dialog.dart';
import 'home_controller.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/theme/typography.dart';

/// 首页。旧项目 HomeScreen.kt（887 行）拆成：顶部状态卡 + 日历 + 今日课 + 待办 + 考试。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    final locator = ServiceScope.of(context);
    _controller = HomeController(
      accountRepository: locator.accountRepository,
      courseRepository: locator.courseRepository,
      homeworkRepository: locator.homeworkRepository,
      examRepository: locator.examRepository,
      syncCoordinator: locator.syncCoordinator,
    );
    // 先把本地库里的数据铺到屏幕上，再去网络上同步并对比。
    _controller.refresh().then((_) => _controller.syncAll());
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
        title: const Text('首页'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: RefreshIcon(
                isBusy: _controller.isSyncing,
                onPressed: _controller.syncAll,
              ),
            ),
          ),
        ],
      ),
      // Flutter 3.47 的 Scaffold 没有 bottom 参数，只能自己拼一条在最上面。
      body: Column(
        children: [
          _SessionBanner(
            listenable: ServiceScope.of(context).accountRepository.sessionState,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => AsyncView<HomeSummary>(
                state: _controller.state,
                onRetry: _controller.refresh,
                builder: (context, summary) => RefreshIndicator(
                  onRefresh: _controller.syncAll,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      // 顺序有讲究：先给「现在该去哪」，再给日历。
                      // 日历要挑一天才看得见东西，而下一节课不用点。
                      _NextClassCard(summary: summary),
                      if (_NextClassCard.pick(summary, DateTime.now()) != null)
                        const SizedBox(height: 12),
                      _HomeCalendar(summary: summary),
                      const SizedBox(height: 16),
                      _ChangeBanner(controller: _controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 正在上的课，或者今天下一节。整个首页最大的一个字。
///
/// 为什么放最上面：首页唯一的高频问题是「现在该去哪」，
/// 而原来这件事要先在日历里点出某一天才看得全课程。
class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.summary});

  final HomeSummary summary;

  /// 正在上 → 第一节还没到的课 → 今天的课上完了（返回 null）。
  static ({Course course, bool ongoing})? pick(
    HomeSummary summary,
    DateTime now,
  ) {
    final section = SchedulePeriods.currentSectionAt(now);
    Course? next;
    for (final course in summary.todayCourses) {
      if (!course.isPlaced) continue;
      if (section != null && course.section == section) {
        return (course: course, ongoing: true);
      }
      // todayCourses 已按节次升序，所以第一个更大的就是最近的一节。
      if (section == null || course.section > section) next ??= course;
    }
    return next == null ? null : (course: next, ongoing: false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final target = pick(summary, now);
    final scheme = Theme.of(context).colorScheme;

    // 今天没课/课上完了都不占地方：日历下面自己会说清楚，
    // 顶部再挂一句「今天没有课」只是重复。
    if (target == null) return const SizedBox.shrink();

    final course = target.course;
    final color = AppColors.forCourse(course.courseId);
    final time = _timeRangeOf(course);

    return _Shell(
      scheme: scheme,
      borderColor: target.ongoing ? color : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 课程色只出现在这条 4px 竖条和「正在上」标签上：
          // 一眼认出是哪门课，但不会让整张卡变成一块彩色。
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.bar,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (target.ongoing) '正在上',
                    if (course.place.isNotEmpty) course.place,
                    if (course.teacher.isNotEmpty) course.teacher,
                    if (time.isNotEmpty) time,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _Shell({
    required ColorScheme scheme,
    required Widget child,
    Color? borderColor,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.lg,
      border: borderColor == null
          ? null
          : Border.all(color: borderColor, width: 2),
    ),
    child: child,
  );
}

/// 首页顶部那一条：登录中是一条 2px 细进度条，登录失效是一条可点的灰条。
/// 本地数据一直在下面照常显示，不因为登录没成功就清空或挡住。
class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.listenable});

  final ValueListenable<SessionState> listenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionState>(
      valueListenable: listenable,
      builder: (context, session, _) => session == SessionState.loggedIn
          ? const SizedBox.shrink()
          : _bar(context, session),
    );
  }

  Widget _bar(BuildContext context, SessionState session) {
    final restoring = session == SessionState.restoring;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: restoring ? AppColors.transparent : scheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (restoring) const LinearProgressIndicator(minHeight: 2),
          InkWell(
            onTap: restoring ? null : () => context.push(AppRoutes.login),
            child: SizedBox(
              // 44 是 HIG 的最小触控高度。原来 28px 看着紧凑，
              // 但这一整条都带 onTap —— 手指粗一点就点不中。
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  if (!restoring)
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    restoring ? '正在登录…' : '登录已失效，点此重新登录',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!restoring)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: scheme.onSurfaceVariant,
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

String _weekTitle(
  DateTime focusedDay,
  int currentWeek, [
  TeachingCalendar? calendar,
]) {
  final week = weekNumberForDate(
    date: focusedDay,
    now: DateTime.now(),
    currentWeek: currentWeek,
    calendar: calendar,
  );
  return weekTitleOf(week);
}

/// 星期行样式：字号固定不跟随全局缩放，否则窄屏放不下三字标签。
DaysOfWeekStyle _daysOfWeekStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final style = TextStyle(
    fontSize: AppTypography.sizeFixed(12),
    fontWeight: FontWeight.w600,
    color: scheme.onSurfaceVariant,
  );
  return DaysOfWeekStyle(weekdayStyle: style, weekendStyle: style);
}

class _HomeCalendar extends StatefulWidget {
  const _HomeCalendar({required this.summary});

  final HomeSummary summary;

  @override
  State<_HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<_HomeCalendar> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final events = buildHomeCalendarEvents(
      homework: widget.summary.allHomework,
      exams: widget.summary.allExams,
      courses: widget.summary.allCourses,
      calendar: widget.summary.calendar,
      currentWeek: widget.summary.currentWeek,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          // 不 stretch 时，空日子下方日程会收缩成文字宽度、被这层摆到正中间；
          // 满格之后左对齐才和「有任务」时一致。
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TableCalendar<HomeCalendarEvent>(
              locale: 'zh_CN',
              firstDay: DateTime(2020),
              lastDay: DateTime(2035),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => eventsOn(events, day),
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.week,
              rowHeight: 72,
              availableCalendarFormats: const {CalendarFormat.week: '周'},
              // table_calendar 默认星期行只有 16px，全局字号放大后中文「周一」
              // 会被裁掉并压到日期格上。这里给足行高并用紧凑字号。
              daysOfWeekHeight: 40,
              daysOfWeekStyle: _daysOfWeekStyle(context),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextFormatter: (date, locale) => _weekTitle(
                  date,
                  widget.summary.currentWeek,
                  widget.summary.calendar,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left),
                rightChevronIcon: const Icon(Icons.chevron_right),
              ),
              onDaySelected: _selectDay,
              onPageChanged: (day) => setState(() => _focusedDay = day),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.all(AppSpacing.xs),
                todayDecoration: BoxDecoration(
                  color: AppColors.transparent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders<HomeCalendarEvent>(
                // 必须给一个非空的 markerBuilder：不给的话 table_calendar 会
                // 自己在格子底部画默认 marker —— 每个事件一个深色实心圆
                // (0xFF263238, 0.2×格宽)，比下面的「点+数量」还大。
                markerBuilder: (context, day, events) =>
                    const SizedBox.shrink(),
                defaultBuilder: (context, day, focusedDay) =>
                    _CalendarDay(day: day, events: eventsOn(events, day)),
                todayBuilder: (context, day, focusedDay) => _CalendarDay(
                  day: day,
                  events: eventsOn(events, day),
                  isToday: true,
                ),
                selectedBuilder: (context, day, focusedDay) => _CalendarDay(
                  day: day,
                  events: eventsOn(events, day),
                  isSelected: true,
                  isToday: isSameDay(day, DateTime.now()),
                ),
                outsideBuilder: (context, day, focusedDay) => _CalendarDay(
                  day: day,
                  events: eventsOn(events, day),
                  muted: true,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const _CalendarLegend(),
            const SizedBox(height: 12),
            _SelectedDayAgenda(
              summary: widget.summary,
              events: events,
              selectedDay: _selectedDay ?? DateTime.now(),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDay(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }
}

class _SelectedDayAgenda extends StatelessWidget {
  const _SelectedDayAgenda({
    required this.summary,
    required this.events,
    required this.selectedDay,
  });

  final HomeSummary summary;

  /// 日历已经展开好的事件表。这里只做一次「取当天 + 排序」。
  final Map<DateTime, List<HomeCalendarEvent>> events;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    // 课程 / 作业 / 考试走同一条渲染路径：类型、图标、颜色都由
    // HomeCalendarEventType 决定，以后加新类型不用再动这个列表。
    final dayEvents = [...eventsOn(events, selectedDay)]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AgendaHeading(day: selectedDay, week: _selectedWeek()),
        for (final event in dayEvents)
          _AgendaTile(
            color: _eventColor(context, event.type),
            icon: _eventIcon(event.type),
            title:
                '${event.typeLabel} · ${event.title.isEmpty ? '未命名' : event.title}',
            subtitle: _eventSubtitle(event),
            onTap: () => showHomeEventDialog(context, event: event),
          ),
        if (dayEvents.isEmpty) const _EmptyHint(text: '这一天没有课程、作业或考试'),
      ],
    );
  }

  int? _selectedWeek() => weekNumberForDate(
    date: selectedDay,
    now: DateTime.now(),
    currentWeek: summary.currentWeek,
    calendar: summary.calendar,
  );

  static Color _eventColor(BuildContext context, HomeCalendarEventType type) {
    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      HomeCalendarEventType.course => scheme.secondary,
      HomeCalendarEventType.homeworkStart => scheme.primary,
      HomeCalendarEventType.homeworkEnd => scheme.error,
      HomeCalendarEventType.exam => AppColors.exam(scheme),
    };
  }

  static IconData _eventIcon(HomeCalendarEventType type) => switch (type) {
    HomeCalendarEventType.course => Icons.menu_book_outlined,
    HomeCalendarEventType.homeworkStart => Icons.play_circle_outline,
    HomeCalendarEventType.homeworkEnd => Icons.warning_amber_outlined,
    HomeCalendarEventType.exam => Icons.assignment_outlined,
  };

  static String _eventSubtitle(HomeCalendarEvent event) {
    final course = event.course;
    if (course != null) {
      return [
        course.place.trim(),
        _timeRangeOf(course),
        course.time.trim(),
      ].where((part) => part.isNotEmpty).join(' · ');
    }
    final homework = event.homework;
    if (homework != null) {
      return event.type == HomeCalendarEventType.homeworkStart
          ? '开放时间：${homework.openDate}'
          : '截止时间：${homework.endTime}';
    }
    return event.exam?.examTimeAndPlace ?? '';
  }
}

class _AgendaHeading extends StatelessWidget {
  const _AgendaHeading({required this.day, required this.week});

  final DateTime day;

  /// null = 假期周（国庆那种），周数不推进，不能硬写成「第 N 周」。
  final int? week;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      '${day.month}月${day.day}日 · ${weekTitleOf(week)}',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  /// 点开详情弹层。null = 纯展示，不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: ListTile(
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: color),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

/// 一节课的上课时段（21:00-21:50）。
///
/// Course.time 不一定是时间 —— 有些课程它装的是「1-16周」这种周次，
/// 所以真正的钟点只能按节次去查作息表。
String _timeRangeOf(Course course) {
  final period = SchedulePeriods.bySection(course.section);
  if (period != null && period.start.isNotEmpty) return period.timeRange;
  return RegExp(r'^\d{1,2}:\d{2}').hasMatch(course.time) ? course.time : '';
}

Color _dotColor(HomeCalendarEventType type, ColorScheme scheme) =>
    switch (type) {
      HomeCalendarEventType.course => scheme.secondary,
      HomeCalendarEventType.homeworkStart => scheme.primary,
      HomeCalendarEventType.homeworkEnd => scheme.error,
      HomeCalendarEventType.exam => AppColors.exam(scheme),
    };

/// 日历格子：日期数字 + 下方的「点+数量」标记。
class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.events,
    this.isToday = false,
    this.isSelected = false,
    this.muted = false,
  });

  final DateTime day;
  final List<HomeCalendarEvent> events;
  final bool isToday;
  final bool isSelected;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = muted
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : scheme.onSurface;
    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : isToday
              ? scheme.primary.withValues(alpha: 0.1)
              : null,
          border: isToday
              ? Border.all(color: scheme.primary, width: 1.5)
              : null,
          borderRadius: AppRadius.sm,
        ),
        // 不用 Expanded 撑满：那样日期数字会被顶到上边。整体居中，
        // 下面只跟着「点+数量」这一行。
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
            const SizedBox(height: 2),
            _CountMarkers(counts: _countsByType()),
          ],
        ),
      ),
    );
  }

  Map<HomeCalendarEventType, int> _countsByType() {
    final counts = <HomeCalendarEventType, int>{};
    for (final event in events) {
      counts[event.type] = (counts[event.type] ?? 0) + 1;
    }
    return counts;
  }
}

/// 格子下方的标记：每类一个小点，右边跟数量。格子窄时整体缩小，不会溢出。
class _CountMarkers extends StatelessWidget {
  const _CountMarkers({required this.counts});

  final Map<HomeCalendarEventType, int> counts;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in counts.entries)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EventDot(color: _dotColor(entry.key, scheme), size: 6),
                    const SizedBox(width: 2),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: AppTypography.sizeFixed(12),
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventDot extends StatelessWidget {
  const _EventDot({required this.color, this.size = 5});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: SizedBox(width: size, height: size),
  );
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendItem(color: scheme.secondary, label: '课程'),
        _LegendItem(color: scheme.primary, label: '作业开始'),
        _LegendItem(color: scheme.error, label: '作业截止'),
        _LegendItem(color: AppColors.exam(scheme), label: '考试'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _EventDot(color: color),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// 本次登录检测到的变化：一行一个模块，点进去看详情（进去时才写数据库）。
class _ChangeBanner extends StatelessWidget {
  const _ChangeBanner({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<SyncModule, SyncResult>>(
      valueListenable: controller.pendingChanges,
      builder: (context, changes, _) {
        if (changes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            children: [
              for (final change in changes.values)
                _ChangeTile(controller: controller, change: change),
            ],
          ),
        );
      },
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.controller, required this.change});

  final HomeController controller;
  final SyncResult change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: scheme.secondaryContainer,
      child: ListTile(
        key: ValueKey('home-change-${change.module.name}'),
        leading: Icon(
          _iconOf(change.module),
          color: scheme.onSecondaryContainer,
        ),
        title: Text(change.message),
        subtitle: Text('点进${change.module.label}查看'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (_opensDirectly(change.module)) {
      await _openModule(context);
      return;
    }
    final shouldOpen = await showSyncChangeDialog(context, result: change);
    if (shouldOpen == true && context.mounted) await _openModule(context);
  }

  Future<void> _openModule(BuildContext context) async {
    await context.push(_routeOf(change.module));
    controller.clearChange(change.module);
  }

  static bool _opensDirectly(SyncModule module) =>
      module == SyncModule.course || module == SyncModule.exam;

  static String _routeOf(SyncModule module) => switch (module) {
    SyncModule.course => AppRoutes.course,
    SyncModule.grade => AppRoutes.grade,
    SyncModule.exam => AppRoutes.exam,
    SyncModule.homework => AppRoutes.homework,
    SyncModule.courseware => AppRoutes.courseware,
  };

  static IconData _iconOf(SyncModule module) => switch (module) {
    SyncModule.course => Icons.calendar_view_week,
    SyncModule.grade => Icons.grade_outlined,
    SyncModule.exam => Icons.assignment_outlined,
    SyncModule.homework => Icons.edit_note,
    SyncModule.courseware => Icons.folder_outlined,
  };
}
