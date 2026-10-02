import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/service_locator.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/github_repository.dart';
import '../../shared/theme/colors.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/cards/app_card.dart';
import '../../shared/widgets/error_text.dart';

/// 项目 Star 变化页。
///
/// GitHub 的 API 只给**当前**星数，不给历史曲线，所以「变化」是本机记下来的：
/// 每 12 小时（或星数一变）存一个采样点，攒够了才能画出趋势。
/// 刚装上只有一个点，此时如实写「数据还在攒」，不画假曲线。
class StarPage extends StatefulWidget {
  const StarPage({super.key});

  @override
  State<StarPage> createState() => _StarPageState();
}

class _StarPageState extends State<StarPage> {
  late final _repository = ServiceScope.of(context).githubRepository;

  Future<RepoSnapshot>? _snapshot;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final future = _repository.fetchSnapshot(AppConstants.githubRepository);
    setState(() => _snapshot = future);
    try {
      await future;
    } catch (_) {
      // 错误交给下面的 FutureBuilder 显示，这里不重复处理。
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('项目 Star'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '重新拉取',
          ),
        ],
      ),
      body: FutureBuilder<RepoSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorText(snapshot.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _refresh, child: const Text('重试')),
                ],
              ),
            );
          }
          return _Body(snapshot: snapshot.requireData, onRefresh: _refresh);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot, required this.onRefresh});

  final RepoSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          _StarCount(snapshot: snapshot),
          const SizedBox(height: AppSpacing.stack),
          _TrendCard(snapshot: snapshot),
          const SizedBox(height: AppSpacing.stack),
          _RepoCard(snapshot: snapshot),
        ],
      ),
    );
  }
}

/// 当前星数 + 相对上次 / 相对第一次的变化。
class _StarCount extends StatelessWidget {
  const _StarCount({required this.snapshot});

  final RepoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前 Star',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${snapshot.stars}',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: AppSpacing.md),
              _DeltaChip(delta: snapshot.delta),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '更新于 ${DateFormat('MM-dd HH:mm').format(snapshot.latest.at)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 「较上次 +3」这种小徽章。变化为 0 时不显示徽章，别拿「+0」占位。
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return Text(
        '与上次持平',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    final up = delta > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: up ? AppColors.success : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 2),
        Text(
          '${delta.abs()}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: up ? AppColors.success : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Star 趋势曲线 + 区间说明。
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.snapshot});

  final RepoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = snapshot.history;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '变化趋势',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: points.length < 2
                ? Center(
                    child: Text(
                      '还在攒数据，多开几次就有曲线了',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : CustomPaint(
                    painter: _SparklinePainter(
                      counts: [for (final point in points) point.count],
                      color: theme.colorScheme.primary,
                      grid: theme.colorScheme.outlineVariant,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '共 ${points.length} 次采样 · 区间内 '
            '${snapshot.totalDelta >= 0 ? '+' : ''}${snapshot.totalDelta}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({required this.snapshot});

  final RepoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () async {
        final url = Uri.tryParse(snapshot.htmlUrl);
        if (url == null) return;
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('打不开浏览器')),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConstants.githubRepository,
            style: theme.textTheme.titleSmall,
          ),
          if (snapshot.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(snapshot.description, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Metric(label: 'Star', value: snapshot.stars),
              _Metric(label: 'Fork', value: snapshot.forks),
              _Metric(label: 'Issue', value: snapshot.openIssues),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text('$value', style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// 迷你折线图。
///
/// 只有一个点就画不出趋势，所以调用方要先挡掉点数 < 2 的情况。
/// 纵轴不从 0 开始：Star 通常在几十到几千之间，从 0 起会把变化压成一条直线，
/// 看不出任何波动。
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.counts,
    required this.color,
    required this.grid,
  });

  final List<int> counts;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final line = _linePath(size);
    canvas.drawPath(line, Paint()..color = color..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round);
    _paintEndDot(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintEndDot(Canvas canvas, Size size) {
    final last = _pointAt(size, counts.length - 1);
    canvas.drawCircle(last, 3.5, Paint()..color = color);
  }

  Path _linePath(Size size) {
    final path = Path();
    for (var i = 0; i < counts.length; i++) {
      final point = _pointAt(size, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  /// 第 [index] 个采样点在画布上的坐标。
  Offset _pointAt(Size size, int index) {
    final min = counts.reduce((a, b) => a < b ? a : b);
    final max = counts.reduce((a, b) => a > b ? a : b);
    // 全程没变过：画在正中，别把线画到顶边上。
    final span = (max - min).toDouble();
    final ratio = span == 0 ? 0.5 : (counts[index] - min) / span;
    final x = counts.length == 1
        ? size.width / 2
        : size.width * (index / (counts.length - 1));
    return Offset(x, size.height * (1 - ratio));
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.counts != counts || old.color != color;
}
