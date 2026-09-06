/// 拉取游标读写（sync_meta 表；复合游标第二段 idAfter 引擎内存态，每页成功落库）。
library;
import 'package:drift/drift.dart';

import '../db/database.dart';

class SyncMetaService {
  SyncMetaService(this.db);

  final AppDatabase db;

  Future<int> lastPulledMs(String entity) async {
    final rows = await (db.select(db.syncMeta)..where((m) => m.entity.equals(entity))).get();
    return rows.isEmpty ? 0 : rows.first.lastPulledMs;
  }

  Future<void> advance(String entity, int lastPulledMs) async {
    await db.into(db.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion.insert(entity: entity, lastPulledMs: Value(lastPulledMs)),
        );
  }

  /// 重置某实体游标（加入协作后全量重拉 / purge 后归零）。
  Future<void> reset(String entity) async {
    await (db.delete(db.syncMeta)..where((m) => m.entity.equals(entity))).go();
  }

  Future<void> resetAll() async {
    await db.delete(db.syncMeta).go();
  }
}
