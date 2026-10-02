import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../data/models/exam/exam_model.dart';
import '../../data/repositories/exam_repository.dart';
import '../../shared/theme/typography.dart';
import '../../shared/widgets/tinted_badge.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import 'exam_controller.dart';
import 'exam_timeline.dart';
import '../../shared/theme/spacing.dart';

/// 考试安排页。
///
/// 交互分层：
/// - 顶部「下一场」卡片回答「最近要紧的是什么」，没有就退化成统计卡片；
/// - 筛选条管「看哪一类」；
/// - 分组列表按 今天 / 之后 / 时间待定 / 已结束 排列，本身就是导航。
class ExamPage extends StatefulWidget {
  const ExamPage({super.key, this.now, this.repository, this.controller});

  /// 「现在」的时间，测试可注入；正常运行时自己走。
  final DateTime? now;

  /// 数据来源。不传就从 [ServiceScope] 拿，测试里注入内存实现。
  final ExamRepository? repository;

  final ExamController? controller;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late final ExamController _controller;
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
            ? ServiceScope.of(context).examController
            : ExamController(repository: widget.repository!));
    _ownsController = widget.controller == null && widget.repository != null;
    _controller.syncMessage.addListener(_showSyncMessage);
    if (_ownsController) _controller.refresh();
    if (widget.now == null) {
      // 倒计时要自己走：跨过零点时「今天」那一组要换人。
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
        title: const Text('考试安排'),
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
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          children: [
            _ExamFilterBar(controller: _controller),
            Expanded(
              child: AsyncView<List<ExamSchedule>>(
                state: _controller.state,
                onRetry: _controller.refresh,
                loadingMessage: '正在同步考试安排…',
                isEmpty: (exams) => exams.isEmpty,
                emptyBuilder: (_) => const EmptyExamView(),
                builder: (context, _) => _ExamBody(
                  controller: _controller,
                  now: _now,
                  onRetry: _controller.refresh,
                  scrollController: _controller.scrollController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamBody extends StatelessWidget {
  const _ExamBody({
    required this.controller,
    required this.now,
    required this.onRetry,
    required this.scrollController,
  });

  final ExamController controller;
  final DateTime now;
  final Future<void> Function() onRetry;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final groups = controller.groups(now: now);
    if (groups.isEmpty) {
      // 选了「期末」但这一类一门都没有。
      return EmptyExamView(
        message: '没有${controller.filter.label}的考试',
        onClearFilter: controller.filter.isAll
            ? null
            : controller.selectFilterAll,
      );
    }
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          _NextExamCard(controller: controller, now: now),
          for (final group in groups) ...[
            _GroupHeader(
              key: ValueKey('exam-group-${group.phase.name}'),
              group: group,
            ),
            for (final entry in group.entries)
              _ExamCard(
                key: ValueKey('exam-${entry.exam.identity}'),
                entry: entry,
                now: now,
              ),
          ],
        ],
      ),
    );
  }
}

/// 顶部卡片：下一场考试。没有下一场时退化成「一共 N 场」的统计。
class _NextExamCard extends StatelessWidget {
  const _NextExamCard({required this.controller, required this.now});

  final ExamController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = controller.nextExam(now: now);
    final total = controller.state.valueOrNull?.length ?? 0;

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
      child: next == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '考试安排',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 $total 场',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '暂时没有待考的考试',
                  style: AppTypography.captionMuted.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下一场 · ${next.timing.countdownLabel(now)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _whenAndWhere(next),
                  style: AppTypography.captionMuted.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
    );
  }

  /// 「明天 08:00-10:00 · 教四403」。缺哪段就不写哪段。
  static String _whenAndWhere(ExamEntry entry) {
    final parts = <String>[
      if (entry.timing.timeText.isNotEmpty) entry.timing.timeText,
      if (entry.timing.place.isNotEmpty) entry.timing.place,
    ];
    return parts.isEmpty ? '时间地点待教务公布' : parts.join(' · ');
  }
}

/// 筛选条。考试类型是开放集合，选项来自数据本身。
class _ExamFilterBar extends StatelessWidget {
  const _ExamFilterBar({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        itemCount: controller.availableFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = controller.availableFilters[index];
          return ChoiceChip(
            label: Text(filter.label),
            selected: filter == controller.filter,
            onSelected: (_) => controller.selectFilter(filter),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.group});

  final ExamGroup group;

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
              color: _accentFor(group.phase, scheme),
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

/// 一场考试。已结束的整张卡降透明度，避免抢注意力。
class _ExamCard extends StatelessWidget {
  const _ExamCard({super.key, required this.entry, required this.now});

  final ExamEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = entry.phaseAt(now);
    final muted = phase == ExamPhase.finished;
    final textColor = muted ? scheme.onSurfaceVariant : scheme.onSurface;

    return Opacity(
      opacity: muted ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                      entry.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: textColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PhaseBadge(
                    phase: phase,
                    label: entry.timing.countdownLabel(now),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoLine(
                icon: Icons.category_outlined,
                text: entry.exam.examType.isEmpty ? '考试' : entry.exam.examType,
              ),
              // 没日期就别再写一遍「时间待定」—— 右上角徽章已经说了。
              if (entry.timing.hasDate)
                _InfoLine(icon: Icons.event_outlined, text: _whenText()),
              _InfoLine(
                icon: Icons.schedule_outlined,
                text: entry.timing.timeText.isEmpty
                    ? '时段待定'
                    : entry.timing.timeText,
              ),
              _InfoLine(
                icon: Icons.place_outlined,
                text: entry.timing.place.isEmpty ? '地点待定' : entry.timing.place,
              ),
              if (entry.exam.examStatus.isNotEmpty)
                _InfoLine(
                  icon: Icons.how_to_reg_outlined,
                  text: entry.exam.examStatus,
                ),
              if (entry.exam.detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                _Remark(text: entry.exam.detail),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 有日期就显示到星期几，学生最关心「周几考」；括号里的注释跟着日期一起。
  /// 调用方保证 [ExamTiming.hasDate] 为真。
  String _whenText() {
    final date = entry.timing.date;
    if (date == null) return '';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final note = entry.timing.note;
    return '${entry.timing.dateText} ${weekdays[date.weekday - 1]}'
        '${note.isEmpty ? '' : '（$note）'}';
  }
}

/// 右上角的阶段徽章：有日期才倒计时，没日期就写「待定」。
class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase, required this.label});

  final ExamPhase phase;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(phase, Theme.of(context).colorScheme);
    return TintedBadge(label: label, accent: accent);
  }
}

/// 备注通常是「闭卷」「携带学生证」这类，用浅底衬托一下。
class _Remark extends StatelessWidget {
  const _Remark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.sm,
      ),
      child: Text(text, style: AppTypography.captionMuted),
    );
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

/// 阶段配色：越近越显眼，已结束退成灰。
Color _accentFor(ExamPhase phase, ColorScheme scheme) => switch (phase) {
  ExamPhase.today => scheme.error,
  ExamPhase.upcoming => scheme.tertiary,
  ExamPhase.unknown => scheme.onSurfaceVariant,
  ExamPhase.finished => scheme.outline,
};

/// 空态：区分「一门考试都没有」和「当前筛选下没有」。
class EmptyExamView extends StatelessWidget {
  const EmptyExamView({super.key, this.message, this.onClearFilter});

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
            Icon(Icons.assignment_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              message ?? '这学期还没有考试安排',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              onClearFilter == null ? '教务发布后点右上角刷新' : '换个考试类型看看',
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
