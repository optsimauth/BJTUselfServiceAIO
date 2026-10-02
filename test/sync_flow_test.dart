import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/core/state/data_sync_manager.dart';
import 'package:bjtuselfserviceaio/core/state/sync_module.dart';
import 'package:bjtuselfserviceaio/core/state/sync_result.dart';

class _Item {
  const _Item(this.identity, {this.label = ''});

  final Object identity;
  final String label;
}

class _MemoryStore implements LocalEntityStore<_Item> {
  _MemoryStore([this.rows = const []]);

  List<_Item> rows;

  @override
  Future<List<_Item>> getAll() async => rows;

  @override
  Stream<List<_Item>> watchAll() => Stream<List<_Item>>.value(rows);

  @override
  Future<void> upsert(List<_Item> items) async => rows = [...rows, ...items];

  @override
  Future<void> remove(List<_Item> items) async =>
      rows = rows.where((row) => !items.contains(row)).toList();

  @override
  Future<void> clear() async => rows = const [];
}

DataSyncManager<_Item> _manager(_MemoryStore store) => DataSyncManager<_Item>(
  store: store,
  identity: (item) => item.identity,
  changed: (current, previous) => current.label != previous.label,
);

void main() {
  test('识别新增 / 变更 / 删除', () {
    const local = [_Item('a', label: '旧'), _Item('b'), _Item('gone')];
    const remote = [_Item('a', label: '新'), _Item('b'), _Item('c')];

    final changes = _manager(_MemoryStore(local))
        .detectChanges(remote: remote, local: local);
    final result = SyncResult.fromChanges(SyncModule.grade, changes);

    expect(result.added, 1);
    expect(result.modified, 1);
    expect(result.deleted, 1);
    expect(result.message, '成绩：新增 1，变更 1，删除 1');
  });

  test('没有变化时不产生消息', () {
    const rows = [_Item('a', label: '同')];
    final changes = _manager(_MemoryStore(rows))
        .detectChanges(remote: rows, local: rows);
    final result = SyncResult.fromChanges(SyncModule.homework, changes);

    expect(changes, isEmpty);
    expect(result.hasChanges, isFalse);
    expect(result.totalChanges, 0);
  });

  test('分片失败时本地数据不被判成删除', () {
    const local = [_Item('a'), _Item('只在这个没拉到的分片里')];
    const remote = [_Item('a'), _Item('b')];

    final changes = _manager(_MemoryStore(local))
        .detectChanges(remote: remote, local: local, detectDeleted: false);
    final result = SyncResult.fromChanges(SyncModule.homework, changes);

    expect(result.added, 1);
    expect(result.deleted, 0);
  });

  test('变更结果携带修改前后的字段值', () {
    const oldItem = _Item('grade', label: '60');
    const newItem = _Item('grade', label: '88');
    final changes = _manager(_MemoryStore([oldItem]))
        .detectChanges(remote: const [newItem], local: const [oldItem]);

    final result = SyncResult.fromChanges(
      SyncModule.grade,
      changes,
      describe: (item, previous, kind) => SyncChangeDetail(
        kind: kind,
        title: item.identity.toString(),
        fields: [
          SyncFieldChange(
            label: '成绩',
            before: previous?.label ?? '',
            after: item.label,
          ),
        ],
      ),
    );

    expect(result.details.single.fields.single.before, '60');
    expect(result.details.single.fields.single.after, '88');
    expect(result.details.single.fields.single.changed, isTrue);
  });

  test('落库时新增走 upsert、删除走 remove', () async {
    final store = _MemoryStore(const [_Item('gone')]);
    final manager = _manager(store);
    final changes = manager.detectChanges(
      remote: const [_Item('new', label: 'x')],
      local: const [_Item('gone')],
    );

    await manager.apply(changes);

    expect(store.rows.map((row) => row.identity), ['new']);
  });
}
