/// 上行发件箱服务：入队、覆盖式合并、分批取件、失败计数。
///
/// 合并规则（V2.6 §3.5.3 SPEC）：同一 (entity,rowId) pending 时新事件覆盖旧行——
/// 更新 updatedMs、op 取最新、attemptCount 归零；不产生多 seq。
library;
import 'package:drift/drift.dart';

import '../db/database.dart';

class OutboxEntry {
  OutboxEntry({
    required this.entity,
    required this.rowId,
    required this.op,
    required this.updatedMs,
    this.attemptCount = 0,
  });

  final String entity;
  final String rowId;
  final String op; // upsert | delete
  final int updatedMs;
  final int attemptCount;
}

class SyncOutboxService {
  SyncOutboxService(this.db);

  final AppDatabase db;

  /// 入队（op 取字符串便于跨层调用）。同 (entity,rowId) 已 pending 则覆盖合并。
  Future<void> enqueue(String entity, String rowId, String op, int updatedMs) async {
    await db.into(db.syncOutbox).insertOnConflictUpdate(
          SyncOutboxCompanion.insert(
            entity: entity,
            rowId: rowId,
            op: op,
            updatedMs: updatedMs,
          ),
        );
  }

  /// 全局入队入口（仓库层写路径调用；运行期由引擎注入，未挂载时 no-op）。
  static void Function(String entity, String rowId, String op, int updatedMs)? hook;

  /// 供仓库层调用的静态便捷入口：引擎未初始化（未开云功能）时静默跳过。
  static void notifyWrite(String entity, String rowId, {String op = 'upsert'}) {
    final h = hook;
    if (h != null) h(entity, rowId, op, DateTime.now().millisecondsSinceEpoch);
  }

  /// 取一批（updatedMs 升序），单实体超批上限拆批由调用方聚合。
  Future<List<OutboxEntry>> selectBatch({int limit = 50}) async {
    final rows = await (db.select(db.syncOutbox)
          ..orderBy([(o) => OrderingTerm.asc(o.updatedMs)])
          ..limit(limit))
        .get();
    return rows
        .map((r) => OutboxEntry(
              entity: r.entity,
              rowId: r.rowId,
              op: r.op,
              updatedMs: r.updatedMs,
              attemptCount: r.attemptCount,
            ))
        .toList();
  }

  Future<void> delete(List<OutboxEntry> batch) async {
    await db.transaction(() async {
      for (final e in batch) {
        await (db.delete(db.syncOutbox)
              ..where((o) => o.entity.equals(e.entity) & o.rowId.equals(e.rowId)))
            .go();
      }
    });
  }

  /// 失败重试计数 +1（死信判定：attemptCount ≥ 8 停自动重试）。
  Future<void> markAttempt(List<OutboxEntry> batch) async {
    await db.transaction(() async {
      for (final e in batch) {
        await (db.update(db.syncOutbox)
              ..where((o) => o.entity.equals(e.entity) & o.rowId.equals(e.rowId)))
            .write(SyncOutboxCompanion(attemptCount: Value(e.attemptCount + 1)));
      }
    });
  }

  /// 用户一键重置死信（attemptCount=0 重新自动重试）。
  Future<int> resetDeadLetters() async {
    final rows = await (db.select(db.syncOutbox)
          ..where((o) => o.attemptCount.isBiggerOrEqualValue(8)))
        .get();
    await (db.update(db.syncOutbox)..where((o) => o.attemptCount.isBiggerOrEqualValue(8)))
        .write(const SyncOutboxCompanion(attemptCount: Value(0)));
    return rows.length;
  }

  Future<int> pendingCount() async =>
      (await db.select(db.syncOutbox).get()).length;

  Future<int> deadLetterCount() async =>
      (await (db.select(db.syncOutbox)..where((o) => o.attemptCount.isBiggerOrEqualValue(8))).get())
          .length;

  /// 某实体某行当前 pending 的 updatedAt（merge 比较用；无 pending 返回 null）。
  Future<int?> pendingUpdatedMs(String entity, String rowId) async {
    final rows = await (db.select(db.syncOutbox)
          ..where((o) => o.entity.equals(entity) & o.rowId.equals(rowId)))
        .get();
    return rows.isEmpty ? null : rows.first.updatedMs;
  }

  /// 清空某实体的 outbox（关闭上云开关-删云端数据后防残差上行）。
  Future<void> clearEntity(String entity) async {
    await (db.delete(db.syncOutbox)..where((o) => o.entity.equals(entity))).go();
  }

  /// 清空全部（登出不删、purge_my_data 后清空）。
  Future<void> clearAll() async {
    await db.delete(db.syncOutbox).go();
  }

  /// 某实体全部本地行入队 upsert（重开开关全量幂等重传 / 首次引导全量上传）。
  Future<int> enqueueEntityAll(String entity, int updatedMs) async {
    final ids = await _allRowIds(entity);
    for (final id in ids) {
      await enqueue(entity, id, 'upsert', updatedMs);
    }
    return ids.length;
  }

  Future<List<String>> _allRowIds(String entity) async {
    switch (entity) {
      case 'trips':
        return (await db.select(db.trips).get()).map((r) => r.id).toList();
      case 'trip_items':
        return (await db.select(db.tripItems).get()).map((r) => r.id).toList();
      case 'groups':
        return (await db.select(db.groups).get()).map((r) => r.id).toList();
      case 'members':
        return (await db.select(db.members).get()).map((r) => r.id).toList();
      case 'expenses':
        return (await db.select(db.expenses).get()).map((r) => r.id).toList();
      case 'settlements':
        return (await db.select(db.settlements).get()).map((r) => r.id).toList();
      case 'categories':
        return (await db.select(db.categories).get()).map((r) => r.key).toList();
    }
    return const [];
  }
}
