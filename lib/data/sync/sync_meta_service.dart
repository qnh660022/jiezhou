/// 拉取游标读写（sync_meta 表；复合游标第二段 idAfter）。
///
/// V2.6 §3.7.2 要求 `(updated_ms, id)` **两段都持久化**（每页成功即落库）：
/// 只存 ms 时，同毫秒的尾行会在下次 pull 时被重复拉取（`id > ''` 恒真）。
/// 第二段走 SharedPreferences（key `sync.cursor.<entity>.lastId`）而不是给
/// drift 表加列——后者要升 schemaVersion + 重跑 build_runner，收益不匹配。
/// [prefs] 缺省（单测直接用内存库）时第二段退化为不持久化，行为与旧版一致。
library;
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import 'sync_models.dart';

class SyncMetaService {
  SyncMetaService(this.db, {this.prefs});

  final AppDatabase db;
  final SharedPreferences? prefs;

  static String _idKey(String entity) => 'sync.cursor.$entity.lastId';

  Future<int> lastPulledMs(String entity) async {
    final rows = await (db.select(db.syncMeta)..where((m) => m.entity.equals(entity))).get();
    return rows.isEmpty ? 0 : rows.first.lastPulledMs;
  }

  /// 复合游标第二段（无记录返回空串 → 服务端 `id > ''` 恒真）。
  Future<String> lastPulledId(String entity) async =>
      prefs?.getString(_idKey(entity)) ?? '';

  Future<void> advance(String entity, int lastPulledMs, {String lastId = ''}) async {
    await db.into(db.syncMeta).insertOnConflictUpdate(
          SyncMetaCompanion.insert(entity: entity, lastPulledMs: Value(lastPulledMs)),
        );
    final p = prefs;
    if (p != null) await p.setString(_idKey(entity), lastId);
  }

  /// 重置某实体游标（加入协作后全量重拉 / purge 后归零）。
  Future<void> reset(String entity) async {
    await (db.delete(db.syncMeta)..where((m) => m.entity.equals(entity))).go();
    await prefs?.remove(_idKey(entity));
  }

  Future<void> resetAll() async {
    await db.delete(db.syncMeta).go();
    final p = prefs;
    if (p == null) return;
    for (final k in p.getKeys().where((k) => k.startsWith('sync.cursor.'))) {
      await p.remove(k);
    }
  }

  /// 把历史遗留的游标键归一（`tripItems` → `trip_items`），返回搬迁的实体数。
  ///
  /// 与 `SyncOutboxService.normalizeEntityKeys` 同源（bug H10）：游标键修复前取
  /// `SyncEntity.name`，`tripItems` 与全仓库使用的 `trip_items` 不一致。迁移时
  /// 位置取「更靠前」的一方（ms 取大）；id 段若规范键已有值则不覆盖。多拉是幂等的，
  /// 漏拉才会丢数据，故宁可偏保守。
  Future<int> normalizeEntityKeys() async {
    var moved = 0;
    for (final e in SyncEntity.values) {
      if (e.name == e.localKey) continue;
      final legacy = await (db.select(db.syncMeta)
            ..where((m) => m.entity.equals(e.name)))
          .get();
      if (legacy.isEmpty) continue;
      final cur = await (db.select(db.syncMeta)
            ..where((m) => m.entity.equals(e.localKey)))
          .get();
      if (cur.isEmpty || legacy.first.lastPulledMs > cur.first.lastPulledMs) {
        await db.into(db.syncMeta).insertOnConflictUpdate(SyncMetaCompanion.insert(
              entity: e.localKey,
              lastPulledMs: Value(legacy.first.lastPulledMs),
            ));
      }
      await (db.delete(db.syncMeta)..where((m) => m.entity.equals(e.name))).go();
      final p = prefs;
      if (p != null) {
        final legacyId = p.getString(_idKey(e.name));
        if (legacyId != null && p.getString(_idKey(e.localKey)) == null) {
          await p.setString(_idKey(e.localKey), legacyId);
        }
        await p.remove(_idKey(e.name));
      }
      moved++;
    }
    return moved;
  }
}
