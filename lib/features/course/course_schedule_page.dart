import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/constants/api_constants.dart';
import '../../core/model/async_state.dart';
import '../../data/models/course/course_model.dart';
import '../../shared/components/calendar/schedule_calendar.dart';
import '../../shared/theme/colors.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/dialog/app_dialog.dart';
import '../../shared/widgets/login_required.dart';
import 'course_controller.dart';
import 'schedule_ics.dart';
import 'schedule_term.dart';
import 'schedule_weeks.dart';
import '../../shared/theme/spacing.dart';

/// 课表页。
///
/// 交互分层：
/// - 工具栏管「看什么」（本学期/历史课表 + 第几周）；
/// - 网格管「长什么样」（[ScheduleCalendar]）；
/// - 详情用底部弹层，不用对话框 —— 手机上拇指够得到，桌面上也居中好看。
class CourseSchedulePage extends StatefulWidget {
  const CourseSchedulePage({super.key, this.controller});

  final CourseController? controller;

  @override
  State<CourseSchedulePage> createState() => _CourseSchedulePageState();
}

class _CourseSchedulePageState extends State<CourseSchedulePage> {
  late final CourseController _controller;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final locator = ServiceScope.of(context);
    _controller = widget.controller ?? locator.courseController;
    _controller.syncMessage.addListener(_showSyncMessage);
    // 周次不持久化：每次进课表都从当前周开始。
    _controller.showCurrentWeek();
  }

  /// 同步完有变化才提示一次；读走就置空，避免重建又弹。
  void _showSyncMessage() {
    final message = _controller.syncMessage.value;
    if (message == null || !mounted) return;
    _controller.syncMessage.value = null;
    _toast(message);
  }

  @override
  void dispose() {
    _controller.syncMessage.removeListener(_showSyncMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('课程表'),
        actions: [
          IconButton(
            tooltip: _exporting ? '正在导出…' : '导出日历 (.ics)',
            onPressed: _exporting ? null : _exportIcs,
            icon: const Icon(Icons.event_available),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: '刷新',
              onPressed: _controller.state is AsyncLoading
                  ? null
                  : _controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: LoginRequired(
        builder: (context) => ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            children: [
              _ScheduleToolbar(controller: _controller),
              Expanded(
                child: AsyncView<List<Course>>(
                  state: _controller.state,
                  onRetry: _controller.refresh,
                  loadingMessage: '正在同步课表…',
                  builder: (context, _) => Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _controller.refresh,
                          child: ScheduleCalendar(
                            board: _controller.board,
                            currentWeek: _controller.currentWeek,
                            selectedWeek: _controller.selectedWeek,
                            onCourseTap: _showCourseDetail,
                            emptyBuilder: (context) => EmptyScheduleView(
                              onPickAnotherWeek: _controller.resetWeek,
                            ),
                          ),
                        ),
                      ),
                      _UnplacedHint(courses: _controller.unplacedCourses),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCourseDetail(Course course) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CourseDetailSheet(
        course: course,
        onDownloadCalendar: () =>
            _downloadTeachingCalendar(course, sheetContext),
      ),
    );
  }

  Future<void> _downloadTeachingCalendar(
    Course course,
    BuildContext sheetContext,
  ) async {
    final navigator = Navigator.of(sheetContext);
    try {
      await _controller.downloadTeachingCalendar(course);
      if (navigator.mounted) navigator.pop();
      if (mounted) _toast('教学日历已保存');
    } catch (error) {
      if (mounted) await AppDialog.error(context, error, title: '下载失败');
    }
  }

  /// 导出课表为 .ics，落到系统下载目录。
  Future<void> _exportIcs() async {
    final courses = _controller.exportableCourses;
    if (courses.isEmpty) {
      _toast('这个学期还没有能导出的课');
      return;
    }
    setState(() => _exporting = true);
    try {
      final ics = ScheduleIcs.build(
        courses: courses,
        firstWeekMonday: _controller.firstWeekMonday(),
        calendarName: '课程表 · ${_controller.term.label}',
      );
      final path = await ServiceScope.of(context).downloadService.saveBytes(
        fileName: '课程表.ics',
        bytes: utf8.encode(ics.text),
        mimeType: 'text/calendar;charset=utf-8',
      );
      if (!mounted) return;
      final skipped = ics.skipped > 0 ? '，${ics.skipped} 门没定时间未导出' : '';
      _toast('已导出 ${ics.events} 次课到：$path$skipped');
    } catch (error) {
      if (mounted) await AppDialog.error(context, error, title: '导出失败');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 工具栏：学期切换 + 周次导航。用 [Wrap] 保证窄屏自动换行而不是溢出。
class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({required this.controller});

  final CourseController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // 文案只认 ScheduleTerm.label —— 之前这里写死两份中文，
              // 改了枚举名（历史课表 -> 选课课表）按钮还是旧的。
              child: SegmentedButton<ScheduleTerm>(
                segments: [
                  for (final term in ScheduleTerm.values)
                    ButtonSegment(value: term, label: Text(term.label)),
                ],
                selected: {controller.term},
                onSelectionChanged: (value) =>
                    controller.selectTerm(value.first),
                showSelectedIcon: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _WeekStepper(controller: controller),
        ],
      ),
    );
  }
}

/// 周次步进器：`‹ 第 12 周 ›`。
class _WeekStepper extends StatelessWidget {
  const _WeekStepper({required this.controller});

  final CourseController controller;

  @override
  Widget build(BuildContext context) {
    final canGoBack = controller.selectedWeek > ScheduleWeeks.allWeeks;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '上一周',
          visualDensity: VisualDensity.compact,
          // 视觉上紧凑，命中区域不能跟着缩：AppTouch.minimum 是 HIG 的下限，
          // 44 才是手指和鼠标都点得中的尺寸。
          constraints: const BoxConstraints(
            minWidth: AppTouch.minimum,
            minHeight: AppTouch.minimum,
          ),
          padding: EdgeInsets.zero,
          onPressed: canGoBack ? () => controller.stepWeek(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        _WeekMenu(controller: controller),
        IconButton(
          tooltip: '下一周',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(
            minWidth: AppTouch.minimum,
            minHeight: AppTouch.minimum,
          ),
          padding: EdgeInsets.zero,
          onPressed: canGoBack ? () => controller.stepWeek(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// 周次下拉。
class _WeekMenu extends StatelessWidget {
  const _WeekMenu({required this.controller});

  final CourseController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      tooltip: '选择周次',
      initialValue: controller.selectedWeek,
      onSelected: controller.selectWeek,
      itemBuilder: (context) => [
        for (final option in WeekOptions.all)
          PopupMenuItem<int>(value: option.week, child: Text(option.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: AppRadius.sheet,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.selectedWeekLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 「有 N 门课没有排期信息」提示条。只在真出现时才占位。
class _UnplacedHint extends StatelessWidget {
  const _UnplacedHint({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${courses.length} 门课没有排期格子（教务课表页没取到时才会出现）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 课程详情底部弹层。
class _CourseDetailSheet extends StatelessWidget {
  const _CourseDetailSheet({
    required this.course,
    required this.onDownloadCalendar,
  });

  final Course course;
  final Future<void> Function() onDownloadCalendar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.forCourse(course.courseId);
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: AppRadius.bar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '课号 ${course.courseId}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.person_outline,
                label: '教师',
                value: course.teacher,
              ),
              _DetailRow(
                icon: Icons.schedule,
                label: '周次',
                value: _weekHint(course.time),
              ),
              _DetailRow(
                icon: Icons.event_note_outlined,
                label: '时间',
                value: _timeHint(course),
              ),
              _DetailRow(
                icon: Icons.place_outlined,
                label: '地点',
                value: course.place,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openMis(context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('教务系统'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDownloadCalendar,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('教学日历'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 时间字段有周次信息时补一句「共 N 周」，帮助学生判断选周次对不对。
  String _weekHint(String time) {
    final weeks = ScheduleWeeks.weeksOf(time);
    if (weeks.isEmpty) return time.isEmpty ? '未知' : time;
    return '$time（跨度 ${weeks.length} 周）';
  }

  /// 把「第N节 周X」拼成一句人话。
  String _timeHint(Course course) {
    final period = course.section > 0 ? _periodLabel(course.section) : '';
    if (period.isEmpty) return course.time.isEmpty ? '未知' : course.time;
    return '$period · ${course.time.isEmpty ? '未知' : course.time}';
  }

  String _periodLabel(int section) {
    const names = ['第一节', '第二节', '第三节', '第四节', '第五节', '第六节', '第七节', '第八节'];
    return section <= names.length ? names[section - 1] : '第 $section 节';
  }

  void _openMis(BuildContext context) {
    final uri = Uri.parse(ApiConstants.aaScheduleCurrentPage);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('教务课表页：$uri')));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
