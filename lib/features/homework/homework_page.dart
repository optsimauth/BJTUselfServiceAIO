import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../data/models/homework/homework_model.dart';
import '../../data/repositories/homework_repository.dart';
import '../../shared/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/dialog/app_dialog.dart';
import '../../shared/widgets/error_text.dart';
import '../../shared/widgets/login_required.dart';
import '../../shared/widgets/tinted_badge.dart';
import 'homework_controller.dart';
import 'homework_timeline.dart';
import '../../shared/theme/spacing.dart';

/// 作业页。
///
/// 交互分层（每层只回答一个问题）：
/// - 顶部卡片回答「我现在最该交什么」，一件不剩时退化成统计；
/// - 筛选条管「看哪一类」（类型 / 课程 / 只看待交）；
/// - 阶段分组列表本身就是导航：待提交 → 已提交 → 已批改。
///
/// 旧项目 HomeworkScreen.kt 1308 行，把筛选、排序、上传、详情全塞在一个
/// StatefulWidget 里；这里拆成 [HomeworkController]（状态）+ 下面几个叶子组件。
class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key, this.now, this.repository, this.controller});

  /// 「现在」的时间，测试可注入；正常运行时自己走。
  final DateTime? now;

  /// 数据来源。不传就从 [ServiceScope] 拿，测试里注入内存实现。
  final HomeworkRepository? repository;

  final HomeworkController? controller;

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  late final HomeworkController _controller;
  bool _ownsController = false;
  Timer? _clock;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _controller =
        widget.controller ??
        (widget.repository == null
            ? ServiceScope.of(context).homeworkController
            : HomeworkController(repository: widget.repository!));
    _ownsController = widget.controller == null && widget.repository != null;
    _controller.syncMessage.addListener(_showSyncMessage);
    if (_ownsController) _controller.refresh();
    if (widget.now == null) {
      // 倒计时自己走：跨过截止点时「快截止」要立刻变成「已截止」。
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  /// 同步完有变化才提示一次；读走就置空，避免重建又弹。
  void _showSyncMessage() {
    final message = _controller.syncMessage.value;
    if (message == null || !mounted) return;
    _controller.syncMessage.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.syncMessage.removeListener(_showSyncMessage);
    _clock?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('作业'),
        actions: [
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
              _HomeworkFilterBar(
                controller: _controller,
                onPickCourse: _showCourseSheet,
              ),
              Expanded(
                child: AsyncView<List<Homework>>(
                  state: _controller.state,
                  onRetry: _controller.refresh,
                  loadingMessage: '正在同步作业…',
                  isEmpty: (_) => _controller.totalCount() == 0,
                  emptyBuilder: (_) => const EmptyHomeworkView(),
                  builder: (context, _) => _HomeworkBody(
                    controller: _controller,
                    now: _now,
                    onRefresh: _controller.refresh,
                    scrollController: _controller.listScrollController,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 课程是多选里退化成单选的那种筛选：一次只看一门课，选项太多不适合挤在条上。
  Future<void> _showCourseSheet() async {
    final courses = _controller.availableCourses;
    if (courses.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CourseSheet(
        courses: courses,
        selected: _controller.filter.courseName,
        onSelect: (name) {
          _controller.toggleCourse(name);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// 列表主体：顶部卡片 + 阶段分组。
class _HomeworkBody extends StatelessWidget {
  const _HomeworkBody({
    required this.controller,
    required this.now,
    required this.onRefresh,
    required this.scrollController,
  });

  final HomeworkController controller;
  final DateTime now;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final groups = controller.groups(now: now);
    if (groups.isEmpty) {
      // 筛选太窄了：一份作业都不剩，不该让用户以为「真的一门都没有」。
      return EmptyHomeworkView(
        message: '没有符合条件的作业',
        onClearFilter: controller.clearFilter,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          _HomeworkSummaryCard(controller: controller, now: now),
          for (final group in groups) ...[
            _GroupHeader(
              key: ValueKey('homework-group-${group.stage.name}'),
              group: group,
            ),
            for (final entry in group.entries)
              _HomeworkCard(
                key: ValueKey('homework-${entry.homework.identity}'),
                entry: entry,
                now: now,
                onTap: () => openHomeworkDetail(
                  context,
                  controller,
                  entry.homework,
                  now,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 筛选条：课程 / 只看待交在前，类型在后面。
///
/// 顺序是有讲究的：学生最常用的两个筛选是「哪门课」和「还没交的」，
/// 所以它们必须在首屏；类型是平台定的三个固定值，用得少，放进可滚动区。
/// （反过来排的话，课程筛选会被四个类型 chip 顶到屏幕外。）
class _HomeworkFilterBar extends StatelessWidget {
  const _HomeworkFilterBar({
    required this.controller,
    required this.onPickCourse,
  });

  final HomeworkController controller;
  final VoidCallback onPickCourse;

  @override
  Widget build(BuildContext context) {
    final filter = controller.filter;
    return SizedBox(
      height: 52,
      child: ListView(
        key: const ValueKey('homework-filter-bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        children: [
          _TypeChip(
            label: filter.hasCourse ? filter.courseName! : '全部课程',
            selected: filter.hasCourse,
            icon: Icons.menu_book_outlined,
            onSelected: onPickCourse,
          ),
          _TypeChip(
            label: '仅待交',
            selected: filter.onlyPending,
            icon: Icons.pending_actions_outlined,
            onSelected: controller.toggleOnlyPending,
          ),
          const _ChipDivider(),
          _TypeChip(
            label: '全部类型',
            selected: filter.type == null,
            onSelected: controller.clearType,
          ),
          for (final type in controller.availableTypes)
            _TypeChip(
              label: type.label,
              selected: filter.type == type,
              onSelected: () => controller.toggleType(type),
            ),
        ],
      ),
    );
  }
}

/// 普通筛选片。`all` 段是「不限」，所以只有被选中时才需要点一下复位。
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: Center(
      child: Container(
        width: 1,
        height: 20,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

/// 课程选择弹层。课程名从数据来，所以选项有多少完全由同步结果决定。
class _CourseSheet extends StatelessWidget {
  const _CourseSheet({
    required this.courses,
    required this.selected,
    required this.onSelect,
  });

  final List<String> courses;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
              child: Text(
                '按课程筛选',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (selected != null)
              ListTile(
                dense: true,
                title: const Text('全部课程'),
                trailing: Icon(Icons.check, color: scheme.primary),
                onTap: () {
                  onSelect(selected!); // toggleCourse 会把同名的取消掉
                },
              ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return ListTile(
                    dense: true,
                    title: Text(course, overflow: TextOverflow.ellipsis),
                    trailing: course == selected
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () => onSelect(course),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部卡片：有待交的就说「下一件是什么」，否则说「一共多少件」。
class _HomeworkSummaryCard extends StatelessWidget {
  const _HomeworkSummaryCard({required this.controller, required this.now});

  final HomeworkController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = controller.pendingCount(now: now);
    final urgent = controller.urgentCount(now: now);
    final next = controller.nextTodo();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.surface, 0.35) ?? scheme.primary,
          ],
        ),
      ),
      child: pending == 0
          ? _summaryDone(context, controller.visibleCount())
          : _summaryTodo(context, pending: pending, urgent: urgent, next: next),
    );
  }

  /// 统计态：全部交了。
  Widget _summaryDone(BuildContext context, int total) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '作业',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 4),
        Text(
          '共 $total 项，全部已提交',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '老师批改后会出现在「已批改」分组里',
          style: AppTypography.captionMuted.copyWith(color: scheme.onPrimary),
        ),
      ],
    );
  }

  /// 待交态：主数字 + 下一件是什么。
  Widget _summaryTodo(
    BuildContext context, {
    required int pending,
    required int urgent,
    required HomeworkEntry? next,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          urgent > 0 ? '待办 $pending 项 · $urgent 项快截止' : '待办 $pending 项',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 4),
        if (next != null) ...[
          Text(
            next.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            next.title.isEmpty ? '未命名作业' : next.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionMuted.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '下一件 · ${next.timing.countdownLabel(now)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// 分组标题：竖条 + 名字 + 件数。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.group});

  final HomeworkGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _stageAccent(group.stage, scheme),
              borderRadius: AppRadius.bar,
            ),
          ),
          const SizedBox(width: 8),
          Text(group.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 6),
          Text(
            '${group.count}',
            style: AppTypography.captionMuted.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一条作业。已批改的那批整张卡降透明度，别跟「还要动手的」抢注意力。
class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    super.key,
    required this.entry,
    required this.now,
    required this.onTap,
  });

  final HomeworkEntry entry;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final homework = entry.homework;
    final muted = entry.stage == HomeworkStage.graded;
    final textColor = muted ? scheme.onSurfaceVariant : scheme.onSurface;

    return Opacity(
      opacity: muted ? 0.7 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        homework.title.isEmpty ? '未命名作业' : homework.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UrgencyBadge(
                      urgency: entry.timing.urgencyAt(now),
                      label: entry.timing.countdownLabel(now),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  homework.courseName.isEmpty ? '未知课程' : homework.courseName,
                  style: AppTypography.captionMuted.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                if (entry.timing.hasDeadline)
                  _InfoLine(
                    icon: Icons.event_outlined,
                    text: '截止 ${_deadlineText(entry)}',
                  ),
                if (homework.allCount > 0)
                  _InfoLine(
                    icon: Icons.people_outline,
                    text: '已交 ${homework.submitCount}/${homework.allCount}',
                  ),
                if (homework.isGraded)
                  _InfoLine(
                    icon: Icons.star_outline,
                    text: '分数 ${homework.score}',
                  ),
                if (homework.needsAction) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: onTap,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('去提交'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 有时间戳就精确到分；平台只给了原始文本就原样显示，不自己编。
  String _deadlineText(HomeworkEntry entry) {
    final deadline = entry.timing.deadline;
    if (deadline == null) return entry.timing.deadlineText;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${deadline.year}-${two(deadline.month)}-${two(deadline.day)} '
        '${two(deadline.hour)}:${two(deadline.minute)}';
  }
}

/// 紧迫度徽章。颜色越暖越该先看。
class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency, required this.label});

  final HomeworkUrgency urgency;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = _urgencyAccent(urgency, Theme.of(context).colorScheme);
    return TintedBadge(label: label, accent: accent);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// 打开作业详情弹层。抽成顶层函数，卡片和按钮共用一条路径。
Future<void> openHomeworkDetail(
  BuildContext context,
  HomeworkController controller,
  Homework homework,
  DateTime now,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HomeworkDetailSheet(
      controller: controller,
      homework: homework,
      now: now,
    ),
  );
}

/// 作业详情弹层：正文 + 附件 + 提交。
///
/// 弹层自己管 loading / 失败 / 提交中三种状态，父页面不用跟着转。
class _HomeworkDetailSheet extends StatefulWidget {
  const _HomeworkDetailSheet({
    required this.controller,
    required this.homework,
    required this.now,
  });

  final HomeworkController controller;
  final Homework homework;
  final DateTime now;

  @override
  State<_HomeworkDetailSheet> createState() => _HomeworkDetailSheetState();
}

class _HomeworkDetailSheetState extends State<_HomeworkDetailSheet> {
  late Future<HomeworkDetail> _detail;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.controller.detailOf(widget.homework);
  }

  @override
  Widget build(BuildContext context) {
    final homework = widget.homework;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailHeader(homework: homework, now: widget.now),
            Flexible(
              child: _DetailBody(
                future: _detail,
                homework: homework,
                controller: widget.controller,
              ),
            ),
            _SubmitBar(
              homework: homework,
              submitting: _submitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  /// 提交完要重取详情：交上去之后正文和附件都会变。
  ///
  /// 这里必须用块体而不是 `() => _detail = ...`：赋值表达式返回的是
  /// `detailOf` 的 Future，把它交给 `setState` 会撞上「setState 的回调
  /// 返回了 Future」这条断言。
  void _reload() {
    setState(() {
      _detail = widget.controller.detailOf(widget.homework);
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.controller.upload(widget.homework);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await AppDialog.error(context, error);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    _reload();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('作业已提交')));
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.homework, required this.now});

  final Homework homework;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timing = HomeworkTiming.parse(
      endTime: homework.endTime,
      openDate: homework.openDate,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homework.title.isEmpty ? '未命名作业' : homework.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            homework.courseName.isEmpty ? '未知课程' : homework.courseName,
            style: AppTypography.captionMuted.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                icon: Icons.category_outlined,
                label: homework.homeworkType.label,
              ),
              if (timing.hasDeadline)
                _MiniBadge(
                  icon: Icons.event_outlined,
                  label: timing.countdownLabel(now),
                ),
              if (homework.subStatus.isNotEmpty)
                _MiniBadge(
                  icon: Icons.flag_outlined,
                  label: homework.subStatus,
                ),
              if (homework.isGraded)
                _MiniBadge(
                  icon: Icons.star_outline,
                  label: '分数 ${homework.score}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 详情正文。三种状态各自成一个小组件，父级只做 FutureBuilder。
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.future,
    required this.homework,
    required this.controller,
  });

  final Future<HomeworkDetail> future;
  final Homework homework;
  final HomeworkController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeworkDetail>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _DetailMessage(
            icon: Icons.error_outline,
            text: errorText(snapshot.error!),
          );
        }
        final detail = snapshot.data!;
        if (detail.isFailed) {
          // 平台的 STATUS!=0 走这里：如实说是平台没给，而不是假装没内容。
          return _DetailMessage(icon: Icons.info_outline, text: detail.error);
        }
        return _DetailContent(
          detail: detail,
          homework: homework,
          controller: controller,
        );
      },
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.detail,
    required this.homework,
    required this.controller,
  });

  final HomeworkDetail detail;
  final Homework homework;
  final HomeworkController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
      children: [
        Text('作业内容', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SelectableText(
          detail.content.isEmpty ? '老师没有写具体要求' : detail.content,
          style: AppTypography.cardSubtitle,
        ),
        if (detail.hasAttachments) ...[
          const SizedBox(height: 20),
          Text('附件', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final file in detail.attachments)
            _AttachmentTile(
              file: file,
              onDownload: () => _download(context, file),
            ),
        ],
        if (homework.isGraded) ...[
          const SizedBox(height: 20),
          Text('批改', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.star, color: scheme.tertiary, size: 20),
              const SizedBox(width: 6),
              Text(
                '得分 ${homework.score}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Divider(color: scheme.outlineVariant),
      ],
    );
  }

  Future<void> _download(BuildContext context, HomeworkAttachment file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await controller.downloadAttachment(homework, file);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已保存到 $savedPath')));
    } catch (error) {
      if (!context.mounted) return;
      await AppDialog.error(context, error);
    }
  }
}

/// 附件行。文件名里的 `+` 在解析时已经换回空格了。
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.file, required this.onDownload});

  final HomeworkAttachment file;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = _formatSize(file.sizeBytes);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.attach_file, color: scheme.onSurfaceVariant),
      title: Text(file.fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: size.isEmpty ? null : Text(size),
      trailing: IconButton(
        tooltip: '下载',
        icon: const Icon(Icons.download_outlined),
        onPressed: onDownload,
      ),
      onTap: onDownload,
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.homework,
    required this.submitting,
    required this.onSubmit,
  });

  final Homework homework;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // 已批改的就不再给提交入口了 —— 那时候改的是已经录入的成绩。
    if (homework.isGraded) return const SizedBox.shrink();
    final label = homework.needsAction ? '提交作业' : '重新提交';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(submitting ? '提交中…' : label),
        ),
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTypography.cardSubtitle)),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.captionMuted.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阶段配色：还要动手的最显眼，已批改的退成中性。
Color _stageAccent(HomeworkStage stage, ColorScheme scheme) => switch (stage) {
  HomeworkStage.todo => scheme.error,
  HomeworkStage.submitted => scheme.primary,
  HomeworkStage.graded => scheme.tertiary,
};

/// 紧迫度配色。
Color _urgencyAccent(HomeworkUrgency urgency, ColorScheme scheme) =>
    switch (urgency) {
      HomeworkUrgency.overdue => scheme.error,
      HomeworkUrgency.soon => scheme.tertiary,
      HomeworkUrgency.normal => scheme.primary,
      HomeworkUrgency.unknown => scheme.onSurfaceVariant,
    };

/// 附件体积。平台不给大小就显示空串，而不是「0 B」。
String _formatSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 空态：区分「真的一份都没有」和「当前筛选下没有」。
class EmptyHomeworkView extends StatelessWidget {
  const EmptyHomeworkView({super.key, this.message, this.onClearFilter});

  final String? message;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              message ?? '老师还没有布置作业',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              onClearFilter == null ? '布置后点右上角刷新' : '换个筛选条件看看',
              style: AppTypography.captionMuted,
              textAlign: TextAlign.center,
            ),
            if (onClearFilter != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('看全部'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
