import 'package:drift/drift.dart';

import '../database.dart';

/// 迁移脚本集中在这里，对应旧项目的 MIGRATION_1_2 起。
abstract final class DatabaseMigrations {
  static Future<void> run(
    AppDatabase db,
    Migrator migrator,
    int from,
    int to,
  ) async {
    if (from < 2) {
      // 旧库 1→2：给作业表加 scoreId。
      await migrator.addColumn(db.homeworkTable, db.homeworkTable.scoreId);
    }
  }
}
