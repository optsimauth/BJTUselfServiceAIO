import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_router.dart';
import '../../app/service_locator.dart';
import '../../data/models/account/account_status.dart';
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
      statusRepository: locator.statusRepository,
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
        title: const Text('今日校园'),
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
          HomeSessionBanner(
            listenable: ServiceScope.of(context).accountRepository.sessionState,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => AsyncView<HomeSummary>(
                state: _controller.state,
                onRetry: _controller.refresh,
                builder: (context, summary) => StreamBuilder<String>(
                  // 背景图是偏好里的一个 key，改了要立刻反映到首页。
                  stream: ServiceScope.of(context).preferences.changes,
                  builder: (context, _) => HomeDashboard(
                    summary: summary,
                    wallpaperPath: ServiceScope.of(context)
                        .preferences
                        .backgroundImageUri,
                    onRefresh: _controller.syncAll,
                    changes: _ChangeBanner(controller: _controller),
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

/// 首页内容与服务装配分开，缓存与网络状态由页面控制。
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.summary,
    required this.onRefresh,
    required this.changes,
    this.wallpaperPath = '',
  });
  final HomeSummary summary;
  final Future<void> Function() onRefresh;
  final Widget changes;

  /// 用户自选的背景图（本地路径）。空串 = 没设置。
  final String wallpaperPath;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              constraints.maxWidth >= AppLayout.railMinWidth
                  ? AppSpacing.xl
                  : AppSpacing.lg,
            ),
            children: [
              if (wallpaperPath.isNotEmpty)
                _WallpaperCover(path: wallpaperPath),
              _TodayHeading(summary: summary),
              const SizedBox(height: AppSpacing.xl),
              _NextClassCard(summary: summary),
              if (_NextClassCard.pick(summary, DateTime.now()) != null)
                const SizedBox(height: AppSpacing.md),
              _StatusStrip(status: summary.status),
              const SizedBox(height: AppSpacing.xl),
              _HomeCalendar(summary: summary),
              const SizedBox(height: AppSpacing.lg),
              changes,
            ],
          ),
        ),
      ),
    ),
  );
}

/// 用户自选背景图（设置 → 外观 → 背景图）。
///
/// 原项目是把图铺在整个 App 底下、文字一律转白；那会牺牲对比度
/// （`docs/UI_SPEC.md` 第 2 节：无障碍优先于视觉偏好）。这里改成首页顶部一张封面，
/// 底部渐变回 surface —— 下面的文字仍然落在实色上，2 倍字号和深色模式都不受影响。
class _WallpaperCover extends StatelessWidget {
  const _WallpaperCover({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final file = File(path);
    if (!file.existsSync()) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: Stack(
          children: [
            Image.file(
              file,
              width: double.infinity,
              height: 168,
              fit: BoxFit.cover,
              // 图片被删/损坏时退回纯色，不要把首页打成错误态。
              errorBuilder: (_, _, _) => SizedBox(
                height: 168,
                child: ColoredBox(color: scheme.surfaceContainerHighest),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surface.withValues(alpha: 0),
                      scheme.surface,
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账户状态条：未读邮件 / 校园卡余额 / 校园网余额。
///
/// 旧项目（`HomeScreen.kt` 的 `StatusInfo`）是三个竖排按钮。按 `docs/UI_SPEC.md`
/// 第 4 节「指标条」：一组相关数字放进一个容器、用分隔线切分，不做三张同构卡片。
/// 邮件格可点（去邮箱），余额格没有去处，就不做成按钮的样子。
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status});

  final AccountStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = this.status;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    final cells = <Widget>[
      _StatusCell(
        icon: Icons.mail_outline,
        label: '未读邮件',
        value: _mailText(status?.unreadMail),
        actionHint: '去邮箱',
        onTap: () => context.push(AppRoutes.email),
      ),
      _StatusCell(
        icon: Icons.credit_card,
        label: '校园卡余额',
        value: _moneyText(status?.ecardBalance),
        warn: status?.ecardIsLow == true ? '低于 20 元，该充了' : null,
      ),
      _StatusCell(
        icon: Icons.wifi,
        label: '校园网余额',
        value: _moneyText(status?.netBalance),
        warn: status?.netIsEmpty == true ? '余额为 0，可能断网' : null,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 2 倍字号或极窄屏下三个数字挤一行会各自被截断，改成竖排三行。
            final stacked = textScale >= 1.5 || constraints.maxWidth < 300;
            if (stacked) {
              return Column(
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: AppSpacing.xl,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      ),
                    cells[i],
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0)
                      VerticalDivider(width: 1, color: scheme.outlineVariant),
                    Expanded(child: cells[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.icon,
    required this.label,
    required this.value,
    this.warn,
    this.actionHint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// 需要提醒的一句（余额不足之类），没有就不占位。
  final String? warn;

  /// 可点格子右下角给一句动词提示，说明点下去会发生什么。
  final String? actionHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hint = warn;
    final action = actionHint;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSpacing.lg, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint,
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
            ),
          ] else if (action != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              action,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      // 48 是触控下限；格子本身已经比它高，这里只是兜底。
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouch.minimum),
        child: content,
      ),
    );
  }
}

String _mailText(int? count) => switch (count) {
  null => '未知',
  0 => '暂无未读',
  final value => '$value 封',
};

/// 学校给的是字符串：能当数字就当金额格式化，不能就原样显示。
String _moneyText(String? raw) {
  if (raw == null) return '未知';
  final value = double.tryParse(raw.trim());
  return value == null ? raw : '¥${value.toStringAsFixed(2)}';
}

class _TodayHeading extends StatelessWidget {
  const _TodayHeading({required this.summary});
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final name = summary.profile.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${now.month}月${now.day}日 · ${weekTitleOf(summary.currentWeek)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          name.isEmpty ? '今天的安排' : '$name，今天的安排',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_view_week_outlined),
              label: const Text('打开课表'),
              onPressed: () => context.push(AppRoutes.course),
            ),
            ActionChip(
              avatar: const Icon(Icons.edit_note_outlined),
              label: const Text('查看作业'),
              onPressed: () => context.push(AppRoutes.homework),
            ),
          ],
        ),
      ],
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

    return _shell(
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
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    target.ongoing ? '正在上课' : '下一节课',
                    if (course.place.isNotEmpty) course.place,
                    if (course.teacher.isNotEmpty) course.teacher,
                    if (time.isNotEmpty) time,
                  ].join(' · '),
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

  Widget _shell({
    required ColorScheme scheme,
    required Widget child,
    Color? borderColor,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.lg,
      border: Border.all(
        color: borderColor ?? scheme.outlineVariant,
        width: borderColor == null ? 1 : 2,
      ),
    ),
    child: child,
  );
}

/// 首页顶部那一条：登录中是一条 2px 细进度条，登录失效是一条可点的灰条。
/// 本地数据一直在下面照常显示，不因为登录没成功就清空或挡住。
class HomeSessionBanner extends StatelessWidget {
  const HomeSessionBanner({super.key, required this.listenable});

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppTouch.minimum),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                    Expanded(
                      child: Text(
                        restoring ? '正在登录…' : '登录已失效，点此重新登录',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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

/// 星期行复用主题标签字号，日历行高随系统字号增长。
DaysOfWeekStyle _daysOfWeekStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final style = Theme.of(context).textTheme.labelSmall!
      .copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant);
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
              rowHeight: MediaQuery.textScalerOf(context).scale(56),
              availableCalendarFormats: const {CalendarFormat.week: '周'},
              // table_calendar 默认星期行只有 16px，全局字号放大后中文「周一」
              // 会被裁掉并压到日期格上。这里给足行高并用紧凑字号。
              daysOfWeekHeight: MediaQuery.textScalerOf(context).scale(40),
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
        _AgendaHeading(
          day: selectedDay,
          week: _selectedWeek(),
          isToday: isSameDay(selectedDay, DateTime.now()),
        ),
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
  const _AgendaHeading({
    required this.day,
    required this.week,
    this.isToday = false,
  });

  final DateTime day;

  /// null = 假期周（国庆那种），周数不推进，不能硬写成「第 N 周」。
  final int? week;

  /// 选中的就是今天时，日期与周次页面顶部已经写过一次，不再重复。
  final bool isToday;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      isToday ? '今天' : '${day.month}月${day.day}日 · ${weekTitleOf(week)}',
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
            const SizedBox(height: AppSpacing.xs),
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
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${entry.value}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
      const SizedBox(width: AppSpacing.xs),
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
