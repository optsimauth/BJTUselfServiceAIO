import 'data_sync_manager.dart';
import 'sync_module.dart';

final class SyncFieldChange {
  const SyncFieldChange({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  bool get changed => before != after;
}

final class SyncChangeDetail {
  const SyncChangeDetail({
    required this.kind,
    required this.title,
    required this.fields,
  });

  final DataChangeKind kind;
  final String title;
  final List<SyncFieldChange> fields;
}

final class SyncResult {
  const SyncResult({
    required this.module,
    required this.added,
    required this.modified,
    required this.deleted,
    this.details = const [],
  });

  static SyncResult fromChanges<T>(
    SyncModule module,
    List<DataChange<T>> changes, {
    SyncChangeDetail Function(T item, T? previous, DataChangeKind kind)?
    describe,
  }) {
    int count(DataChangeKind kind) => changes
        .where((change) => change.kind == kind)
        .fold(0, (total, change) => total + change.items.length);
    final details = <SyncChangeDetail>[];
    if (describe != null) {
      for (final change in changes) {
        for (var index = 0; index < change.items.length; index++) {
          final previous = index < change.previousItems.length
              ? change.previousItems[index]
              : null;
          details.add(describe(change.items[index], previous, change.kind));
        }
      }
    }
    return SyncResult(
      module: module,
      added: count(DataChangeKind.added),
      modified: count(DataChangeKind.modified),
      deleted: count(DataChangeKind.deleted),
      details: details,
    );
  }

  final SyncModule module;
  final int added;
  final int modified;
  final int deleted;
  final List<SyncChangeDetail> details;

  bool get hasChanges => added + modified + deleted > 0;
  int get totalChanges => added + modified + deleted;

  String get message {
    final parts = <String>[];
    if (added > 0) parts.add('新增 $added');
    if (modified > 0) parts.add('变更 $modified');
    if (deleted > 0) parts.add('删除 $deleted');
    return '${module.label}：${parts.join('，')}';
  }
}
