import 'package:flutter/material.dart';

import '../../core/state/data_sync_manager.dart';
import '../../core/state/sync_result.dart';
import '../../shared/theme/colors.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/tinted_badge.dart';

Future<bool?> showSyncChangeDialog(
  BuildContext context, {
  required SyncResult result,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SyncChangeDialog(result: result),
  );
}

class _SyncChangeDialog extends StatelessWidget {
  const _SyncChangeDialog({required this.result});

  final SyncResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${result.module.label}有更新'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: result.details.isEmpty
            ? const Text('检测到数量变化，进入页面查看详情。')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: result.details.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _ChangeDetailCard(detail: result.details[index]),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.open_in_new),
          label: const Text('去查看'),
        ),
      ],
    );
  }
}

class _ChangeDetailCard extends StatelessWidget {
  const _ChangeDetailCard({required this.detail});

  final SyncChangeDetail detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: AppRadius.badge,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _KindBadge(kind: detail.kind),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detail.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 一个字段一整行，整行宽度都给值。
            //
            // 原来是「原来 / 现在」两列并排：弹层 maxWidth 620，两张卡片一
            // 分，每列只剩 ~130px，「2026-09-05 23:59」被挤成一个字一行竖着
            // 排。改成一行 `标签 · 旧值 → 新值` 之后宽度全给值，而且只有真
            // 变了的那一行上底色，没变的自动淡化。
            for (final field in detail.fields)
              _FieldDiffRow(
                label: field.label,
                before: field.before,
                after: field.after,
                kind: detail.kind,
              ),
          ],
        ),
      ),
    );
  }
}

/// 一个字段的前后对照行。
///
/// modified：`旧值 → 新值`；added / deleted：只显示一条值，整行按类型染色。
class _FieldDiffRow extends StatelessWidget {
  const _FieldDiffRow({
    required this.label,
    required this.before,
    required this.after,
    required this.kind,
  });

  final String label;
  final String before;
  final String after;
  final DataChangeKind kind;

  bool get _isPair => kind == DataChangeKind.modified;

  /// 这一行到底变没变 —— 只有真变了才值得让人看。
  bool get _changed => before != after;

  static String _text(String value) => value.isEmpty ? '未填写' : value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final changed = _changed;
    final emphasized = _isPair && changed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: switch (kind) {
          DataChangeKind.added => scheme.primaryContainer,
          DataChangeKind.deleted => scheme.errorContainer,
          DataChangeKind.modified =>
            changed ? scheme.tertiaryContainer : AppColors.transparent,
        },
        borderRadius: AppRadius.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Expanded(
            // Wrap：旧值 + 箭头作为一组，放得下就同一行，放不下整组换行 ——
            // 不会像之前那样把日期拆成竖着的一列字。
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: 2,
              children: [
                if (_isPair)
                  Text(
                    _text(before),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      // 数字等宽：分数、日期刷新时不会左右抖。
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (_isPair)
                  Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                Text(
                  // 删除只有旧值，新增只有新值。
                  _text(kind == DataChangeKind.deleted ? before : after),
                  style:
                      (emphasized
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(
                            fontWeight: emphasized
                                ? FontWeight.w600
                                : FontWeight.w400,
                            // 染了底色的两行（新增/删除）必须用容器的字色，
                            // 否则在深色主题下会是「深底深字」。
                            color: switch (kind) {
                              DataChangeKind.added => scheme.onPrimaryContainer,
                              DataChangeKind.deleted => scheme.onErrorContainer,
                              DataChangeKind.modified => null,
                            },
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final DataChangeKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (kind) {
      DataChangeKind.added => ('新增', scheme.primary),
      DataChangeKind.modified => ('变更', scheme.tertiary),
      DataChangeKind.deleted => ('删除', scheme.error),
    };
    return TintedBadge(
      label: label,
      accent: color,
      borderRadius: AppRadius.chip,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    );
  }
}
