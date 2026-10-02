/// 本地实体仓库契约：core 定义，data/local 用 drift 实现。
/// 有了它，DataSyncManager 不需要认识 drift。
abstract interface class LocalEntityStore<T> {
  Future<List<T>> getAll();
  Stream<List<T>> watchAll();
  Future<void> upsert(List<T> items);
  Future<void> remove(List<T> items);
  Future<void> clear();
}

enum DataChangeKind { added, modified, deleted }

final class DataChange<T> {
  const DataChange(this.kind, this.items, {this.previousItems = const []});

  final DataChangeKind kind;
  final List<T> items;
  final List<T> previousItems;

  bool get isEmpty => items.isEmpty;
}

class DataSyncManager<T> {
  const DataSyncManager({
    this.store,
    required this.identity,
    required this.changed,
    this.mergeIds,
  });

  /// 落库口。留空表示「这个 manager 只用来比较」—— 课件的本地库是一棵
  /// JSON 缓存树，写入由 CoursewareRepository.refreshTree 自己管，
  /// 硬塞一个假 store 反而会骗人。
  final LocalEntityStore<T>? store;
  final Object Function(T item) identity;
  final bool Function(T current, T previous) changed;
  final T Function(T current, T previous)? mergeIds;

  List<DataChange<T>> detectChanges({
    required List<T> remote,
    required List<T> local,
    bool detectDeleted = true,
  }) {
    final localMap = {for (final item in local) identity(item): item};
    final remoteKeys = {for (final item in remote) identity(item)};
    final added = remote
        .where((item) => !localMap.containsKey(identity(item)))
        .toList();
    final modifiedItems = <T>[];
    final previousItems = <T>[];
    for (final item in remote) {
      final previous = localMap[identity(item)];
      if (previous != null && changed(item, previous)) {
        modifiedItems.add(mergeIds?.call(item, previous) ?? item);
        previousItems.add(previous);
      }
    }
    final deleted = detectDeleted
        ? local.where((item) => !remoteKeys.contains(identity(item))).toList()
        : <T>[];
    return [
      if (added.isNotEmpty) DataChange<T>(DataChangeKind.added, added),
      if (modifiedItems.isNotEmpty)
        DataChange<T>(
          DataChangeKind.modified,
          modifiedItems,
          previousItems: previousItems,
        ),
      if (deleted.isNotEmpty) DataChange<T>(DataChangeKind.deleted, deleted),
    ];
  }

  Future<void> apply(List<DataChange<T>> changes) async {
    final store = this.store;
    if (store == null) {
      throw StateError('这个 DataSyncManager 只用于比较，没有落库口');
    }
    for (final change in changes) {
      switch (change.kind) {
        case DataChangeKind.added:
        case DataChangeKind.modified:
          await store.upsert(change.items);
        case DataChangeKind.deleted:
          await store.remove(change.items);
      }
    }
  }
}
