import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../data/models/grade/grade_model.dart';
import '../../data/repositories/grade_repository.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/cards/app_card.dart';
import '../../shared/widgets/dialog/app_dialog.dart';
import '../../shared/theme/colors.dart';
import 'grade_controller.dart';
import 'grade_math.dart';
import 'grade_sort.dart';
import 'grade_view.dart';
import '../../shared/theme/spacing.dart';

/// 成绩页。
///
/// 三件事，从上到下正好是三个层次：
/// - 加权平均分卡片：回答「我这学期学得怎么样」，跟着下面的筛选 / 勾选走；
/// - 筛选条：学期多选 + 排序，决定看哪些课；
/// - 「自选课程计算」：临时勾几门课，卡片只算这几门的加权。
///
/// 呈现层不直接碰勾选持久化 —— 控制器按「课程名|教师|学年|学期」存记录，
/// 学号从登录凭据里解出来（路由不传参，页面上自己查）。
class GradePage extends StatefulWidget {
  const GradePage({
    super.key,
    this.repository,
    this.studentId = '',
    this.controller,
  });

  /// 数据来源。不传就从 [ServiceScope] 拿，测试里注入内存实现。
  final GradeRepository? repository;

  /// 学号，用于区分不同账号的勾选记录。不传就从登录凭据里读。
  final String studentId;

  final GradeController? controller;

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  GradeController? _controller;
  bool _ownsController = false;
  bool _selectionMode = false;

  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null || widget.repository == null) {
      _bindController(
        widget.controller ?? ServiceScope.of(context).gradeController,
      );
    } else {
      _init();
    }
  }

  @override
  void dispose() {
    _controller?.scrollController.removeListener(_onScroll);
    _controller?.syncMessage.removeListener(_showSyncMessage);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  void _bindController(GradeController controller) {
    _controller = controller;
    controller.syncMessage.addListener(_showSyncMessage);
    controller.scrollController.addListener(_onScroll);
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    if (_controller != null) {
      return;
    }
    var studentId = widget.studentId;
    if (studentId.isEmpty) {
      final credentials = await ServiceScope.of(context).secureStorage
          .readCredentials();
      studentId = credentials.username;
    }
    if (!mounted) return;
    final controller = GradeController(
      repository: widget.repository!,
      studentId: studentId,
    );
    _bindController(controller);
    _ownsController = true;
    await controller.refresh();
  }

  /// 同步完有变化才提示一次；读走就置空，避免重建又弹。
  void _showSyncMessage() {
    final message = _controller?.syncMessage.value;
    if (message == null || !mounted) return;
    _controller!.syncMessage.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    final scroll = _controller?.scrollController;
    final show = scroll != null && scroll.hasClients && scroll.offset > 300;
    if (show != _showFab) {
      setState(() => _showFab = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('成绩'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '下载成绩单',
            onSelected: (value) => _downloadReport(english: value == 'en'),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'cn', child: Text('下载中文成绩单')),
              PopupMenuItem(value: 'en', child: Text('下载英文成绩单')),
            ],
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => IconButton(
              tooltip: '刷新',
              onPressed: controller.state.isLoading ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            _GradeActionRow(
              controller: controller,
              selectionMode: _selectionMode,
              onToggleSelectionMode: () =>
                  setState(() => _selectionMode = !_selectionMode),
            ),
            if (_selectionMode) _SelectionToolbar(controller: controller),
            Expanded(
              child: AsyncView<List<Grade>>(
                state: controller.state,
                onRetry: controller.refresh,
                loadingMessage: '正在同步成绩…',
                isEmpty: (grades) => grades.isEmpty,
                emptyBuilder: (_) =>
                    _EmptyGradesView(onRefresh: controller.refresh),
                builder: (context, _) => _GradeListBody(
                  controller: controller,
                  scroll: controller.scrollController,
                  selectionMode: _selectionMode,
                  onClearFilter: controller.clearFilter,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.small(
              tooltip: '回到顶部',
              onPressed: () => controller.scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(Icons.keyboard_arrow_up),
            )
          : null,
    );
  }

  Future<void> _downloadReport({required bool english}) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final path = await controller.downloadReport(english: english);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已保存：$path')));
    } catch (error) {
      if (mounted) {
        await AppDialog.error(context, error);
      }
    }
  }
}

/// 列表主体：加权平均分卡片 + 成绩卡片。空态分两种：一门都没有 / 筛选筛没了。
class _GradeListBody extends StatelessWidget {
  const _GradeListBody({
    required this.controller,
    required this.scroll,
    required this.selectionMode,
    required this.onClearFilter,
  });

  final GradeController controller;
  final ScrollController scroll;
  final bool selectionMode;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final views = controller.visibleViews();
    if (views.isEmpty) {
      return _NoGradesForFilter(
        hasFilter: !controller.filter.isAll,
        onClearFilter: onClearFilter,
        onRefresh: controller.refresh,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          _GpaCard(controller: controller, selectionMode: selectionMode),
          const SizedBox(height: 8),
          for (final view in views)
            _GradeCard(
              key: ValueKey('grade-${controller.selectionKeyOf(view.grade)}'),
              view: view,
              selectionMode: selectionMode,
              onToggle: () => controller.toggleSelected(view.grade),
              onDetail: () => _showDetail(context, view),
            ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, GradeView view) {
    showDialog<void>(
      context: context,
      builder: (_) => _GradeDetailDialog(view: view),
    );
  }
}

/// 加权平均分卡片。选中的学期 / 勾选的课程会实时改这个数字。
class _GpaCard extends StatelessWidget {
  const _GpaCard({required this.controller, required this.selectionMode});

  final GradeController controller;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gpa = controller.gpa(selectionMode: selectionMode);
    final average = gpa.average;
    final subtitle = _subtitleFor(controller, gpa, average);
    return Container(
      key: const ValueKey('grade-gpa'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                selectionMode ? '自选课程加权平均分' : '加权平均分',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
              ),
              const Spacer(),
              Text(
                '统计 ${gpa.countedCourses} 门',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.75)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                average == null ? '—' : average.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (average != null) ...[
                const SizedBox(width: 4),
                Text(
                  '分',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(
    GradeController controller,
    GradeGpa gpa,
    double? average,
  ) {
    if (average != null) {
      return gradeCommentFor(average);
    }
    if (selectionMode) {
      return controller.selectedCount == 0 ? '还没有勾选课程，点卡片上的勾选试试' : '勾选的课都还没出分';
    }
    return '成绩好像都没出来哦~';
  }
}

/// 顶部操作条：自选课程开关 + 学期多选 + 排序。
class _GradeActionRow extends StatelessWidget {
  const _GradeActionRow({
    required this.controller,
    required this.selectionMode,
    required this.onToggleSelectionMode,
  });

  final GradeController controller;
  final bool selectionMode;
  final VoidCallback onToggleSelectionMode;

  @override
  Widget build(BuildContext context) {
    final options = controller.semesterOptions;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            // 用 SingleChildScrollView + Row：芯片数量少，全部构建出来，
            // 测试里也能稳定点到每一个（ListView 懒构建会把屏外的芯片省掉）。
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  FilterChip(
                    avatar: selectionMode
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    label: Text(selectionMode ? '退出自选课程' : '自选课程计算'),
                    selected: selectionMode,
                    onSelected: (_) => onToggleSelectionMode(),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: controller.filter.isAll,
                    onSelected: (_) => controller.clearFilter(),
                  ),
                  for (final semester in options) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(semester.isEmpty ? '未标注学期' : semester),
                      selected: controller.filter.semesters.contains(semester),
                      onSelected: (_) => controller.selectFilter(
                        controller.filter.toggled(semester),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '排序：${controller.sort.label}',
            onPressed: controller.cycleSort,
            icon: Icon(switch (controller.sort) {
              GradeSortOrder.original => Icons.sort,
              GradeSortOrder.ascending => Icons.arrow_upward,
              GradeSortOrder.descending => Icons.arrow_downward,
            }),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// 「自选课程计算」模式的批量操作条。
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({required this.controller});

  final GradeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: controller.selectAllVisible,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('全选'),
                ),
                if (!controller.filter.isAll)
                  TextButton.icon(
                    onPressed: controller.deselectFilteredSemesters,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('清空本学期'),
                  ),
                TextButton.icon(
                  onPressed: controller.clearSelections,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('全部清空'),
                ),
              ],
            ),
          ),
          Text(
            '已选 ${controller.selectedCount} 门',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 一张成绩卡。正常模式点卡片看详情；自选模式右侧多一个勾选框。
class _GradeCard extends StatelessWidget {
  const _GradeCard({
    super.key,
    required this.view,
    required this.selectionMode,
    required this.onToggle,
    required this.onDetail,
  });

  final GradeView view;
  final bool selectionMode;
  final VoidCallback onToggle;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = view.score;
    final scoreColor = _scoreColor(scheme, score.numeric);
    final scoreText = score.isKnown ? _scoreText(score.numeric!) : '-';
    final badge =
        score.isKnown && score.letter.isNotEmpty && score.letter != '-'
        ? score.letter
        : null;
    return AppCard(
      onTap: onDetail,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectionMode)
            Checkbox(value: view.selected, onChanged: (_) => onToggle()),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                scoreText,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: scoreColor, fontWeight: FontWeight.w700),
              ),
              if (badge != null) ...[
                const SizedBox(height: 2),
                // 分数数字本身用满色（它在卡片底上，不是淡底上）；
                // 徽章是淡底，字色必须另算，否则淡洗上的字会糊掉。
                Builder(
                  builder: (context) {
                    final colors = AppColors.badge(scheme, scoreColor);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: AppRadius.chip,
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            view.grade.courseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InfoChip(
                icon: Icons.person_outline,
                text: view.grade.courseTeacher.isEmpty
                    ? '教师未标注'
                    : view.grade.courseTeacher,
              ),
              _InfoChip(
                icon: Icons.auto_stories_outlined,
                text: '${view.grade.courseCredits} 学分',
              ),
              _InfoChip(icon: Icons.event_outlined, text: view.semesterLabel),
            ],
          ),
        ],
      ),
    );
  }
}

/// 卡片里的一行小信息：图标 + 文字，包一层浅底让它扫起来是一组。
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 成绩详情弹窗。旧项目 GradeDetailDialog 的对应物。
class _GradeDetailDialog extends StatelessWidget {
  const _GradeDetailDialog({required this.view});

  final GradeView view;

  @override
  Widget build(BuildContext context) {
    final grade = view.grade;
    final score = view.score;
    final scoreText = score.isKnown
        ? '${score.letter.isEmpty ? '' : '${score.letter} · '}${_scoreText(score.numeric!)}'
        : '还没出分';
    final tag = grade.tag.trim();
    return AlertDialog(
      key: const ValueKey('grade-detail'),
      title: const Text('详情信息'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: '学年学期', value: tag.isEmpty ? '未标注' : tag),
            _DetailRow(label: '课程名称', value: grade.courseName),
            _DetailRow(label: '任课教师', value: grade.courseTeacher),
            _DetailRow(label: '学分', value: grade.courseCredits),
            _DetailRow(label: '成绩', value: scoreText),
            if (grade.detail.trim().isNotEmpty)
              _DetailRow(label: '备注', value: grade.detail.trim()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// 一门成绩都没有。
class _EmptyGradesView extends StatelessWidget {
  const _EmptyGradesView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grade_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text('还没有成绩', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '教务出分后点右上角刷新',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 有成绩，但当前筛选下一条都不剩。
class _NoGradesForFilter extends StatelessWidget {
  const _NoGradesForFilter({
    required this.hasFilter,
    required this.onClearFilter,
    required this.onRefresh,
  });

  final bool hasFilter;
  final VoidCallback onClearFilter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: scheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilter ? '没有所选学期的成绩' : '没有成绩',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              hasFilter ? '换个学期看看，或直接看全部' : '下拉刷新再试试',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (hasFilter) ...[
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

/// 成绩分数的颜色：红（低）-> 绿（高）。没出分用灰色。
Color _scoreColor(ColorScheme scheme, double? score) {
  if (score == null) {
    return scheme.onSurfaceVariant;
  }
  if (score < 60) {
    return scheme.error;
  }
  final t = ((score - 60) / 40).clamp(0.0, 1.0);
  return Color.lerp(scheme.error, scheme.primary, t)!;
}

/// 95 -> '95'，89.5 -> '89.5'，整数不带小数点。
String _scoreText(double score) => score == score.roundToDouble()
    ? score.round().toString()
    : score.toStringAsFixed(1);
