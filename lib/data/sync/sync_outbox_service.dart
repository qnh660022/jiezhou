/// 上行发件箱服务：入队、覆盖式合并、分批取件、失败计数。
///
/// 合并规则（V2.6 §3.5.3 SPEC）：同一 (entity,rowId) pending 时新事件覆盖旧行——
/// 更新 updatedMs、op 取最新、attemptCount 归零；不产生多 seq。
library;
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'sync_models.dart';

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

  /// 入队（op 取字符串便于跨层调用）。同 (entity,rowId) 已 pending 则覆盖合并：
  /// 新事件覆盖旧行——attemptCount **必须归零**（SPEC §3.5.3），否则死信行被再次
  /// 编辑后仍是 8，永不自动重试（历史 bug：「待同步」长期挂着一行改不动的数据）。
  Future<void> enqueue(String entity, String rowId, String op, int updatedMs) async {
    await db.into(db.syncOutbox).insertOnConflictUpdate(
          SyncOutboxCompanion.insert(
            entity: entity,
            rowId: rowId,
            op: op,
            updatedMs: updatedMs,
            attemptCount: const Value(0),
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

  /// 指定事件时点的入队（合流「本地胜」防环路径用：时点必须由合流层给定，
  /// 不能重读时钟）。走 hook 以便统一触发 debounce；未挂载时由调用方回落直写。
  static void notifyWriteAt(String entity, String rowId, String op, int updatedMs) {
    final h = hook;
    if (h != null) h(entity, rowId, op, updatedMs);
  }

  /// 取一批（updatedMs 升序），单实体超批上限拆批由调用方聚合。
  ///
  /// [retryableOnly] 默认 true：SQL 层过滤死信（attemptCount ≥ 8），避免前排死信
  /// 占满取件窗口导致后续正常行永远取不到（历史 bug：死信堵住窗口后 drain 空转
  /// 却报 ok，用户看到「已同步」而数据没上去）。
  Future<List<OutboxEntry>> selectBatch({int limit = 50, bool retryableOnly = true}) async {
    final q = db.select(db.syncOutbox);
    if (retryableOnly) {
      q.where((o) => o.attemptCount.isSmallerThanValue(deadLetterThreshold));
    }
    final rows = await (q
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

  /// 死信判定阈值（attemptCount ≥ 该值不再自动重试）。
  static const int deadLetterThreshold = 8;

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
          ..where((o) => o.attemptCount.isBiggerOrEqualValue(deadLetterThreshold)))
        .get();
    await (db.update(db.syncOutbox)
          ..where((o) => o.attemptCount.isBiggerOrEqualValue(deadLetterThreshold)))
        .write(const SyncOutboxCompanion(attemptCount: Value(0)));
    return rows.length;
  }

  Future<int> pendingCount() async =>
      (await db.select(db.syncOutbox).get()).length;

  Future<int> deadLetterCount() async =>
      (await (db.select(db.syncOutbox)
                ..where((o) => o.attemptCount.isBiggerOrEqualValue(deadLetterThreshold)))
              .get())
          .length;

  /// 某实体某行当前 pending 的 updatedAt（merge 比较用；无 pending 返回 null）。
  Future<int?> pendingUpdatedMs(String entity, String rowId) async {
    final rows = await (db.select(db.syncOutbox)
          ..where((o) => o.entity.equals(entity) & o.rowId.equals(rowId)))
        .get();
    return rows.isEmpty ? null : rows.first.updatedMs;
  }

  /// 某实体某行当前 pending 的完整事件（含 op）；无 pending 返回 null。
  ///
  /// 合流用它判断「本地意图尚未上行」：本地行已不存在但 outbox 里还有事件时，
  /// 绝不能按「云端胜」把行插回来（否则删除被静默撤销，历史 bug H1）。
  Future<OutboxEntry?> pendingEntry(String entity, String rowId) async {
    final rows = await (db.select(db.syncOutbox)
          ..where((o) => o.entity.equals(entity) & o.rowId.equals(rowId)))
        .get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return OutboxEntry(
      entity: r.entity,
      rowId: r.rowId,
      op: r.op,
      updatedMs: r.updatedMs,
      attemptCount: r.attemptCount,
    );
  }

  /// 清空某实体的 outbox（关闭上云开关-删云端数据后防残差上行）。
  Future<void> clearEntity(String entity) async {
    await (db.delete(db.syncOutbox)..where((o) => o.entity.equals(entity))).go();
  }

  /// 清空全部（登出不删、purge_my_data 后清空）。
  Future<void> clearAll() async {
    await db.delete(db.syncOutbox).go();
  }

  /// 把历史遗留的非规范实体键归一（如 `tripItems` → `trip_items`），返回搬迁行数。
  ///
  /// 背景（bug H10）：修复前合流层「本地胜」路径用 `SyncEntity.name` 入队，
  /// `tripItems` 与仓库层写入的 `trip_items` 形成两套键名——同一行在 outbox
  /// 里可能并存两条，`pendingEntry` 只命中其一 → 「删除不复活」(H1) 判定失效。
  /// 引擎 [start] 时调用一次即可（幂等）。
  ///
  /// 搬运用「先规范键写入、再删旧行」而非直接 UPDATE：主键是 (entity,rowId)，
  /// 直接改 entity 会撞上已存在的规范键行。
  Future<int> normalizeEntityKeys() async {
    var moved = 0;
    for (final e in SyncEntity.values) {
      if (e.name == e.localKey) continue;
      final legacy =
          await (db.select(db.syncOutbox)..where((o) => o.entity.equals(e.name)))
              .get();
      for (final r in legacy) {
        final dup = await (db.select(db.syncOutbox)
              ..where((o) => o.entity.equals(e.localKey) & o.rowId.equals(r.rowId)))
            .get();
        if (dup.isEmpty) {
          await db.into(db.syncOutbox).insert(SyncOutboxCompanion.insert(
                entity: e.localKey,
                rowId: r.rowId,
                op: r.op,
                updatedMs: r.updatedMs,
                attemptCount: Value(r.attemptCount),
              ));
        } else if (r.updatedMs > dup.first.updatedMs) {
          // 两条并存时取事件更新的那条；attemptCount 取小值（更接近自动重试）。
          final cur = dup.first;
          await (db.update(db.syncOutbox)
                ..where(
                    (o) => o.entity.equals(e.localKey) & o.rowId.equals(r.rowId)))
              .write(SyncOutboxCompanion(
            op: Value(r.op),
            updatedMs: Value(r.updatedMs),
            attemptCount: Value(
                r.attemptCount < cur.attemptCount ? r.attemptCount : cur.attemptCount),
          ));
        }
        await (db.delete(db.syncOutbox)
              ..where((o) => o.entity.equals(e.name) & o.rowId.equals(r.rowId)))
            .go();
        moved++;
      }
    }
    return moved;
  }

  /// 某实体全部本地行入队 upsert（重开开关全量幂等重传 / 首次引导全量上传）。
  ///
  /// [filter] 返回 false 的行直接跳过（引导上传时按 per-id 上云开关预过滤，
  /// 免得先入队再被 drain 的开关闸门丢弃——白写一趟 outbox）。
  Future<int> enqueueEntityAll(String entity, int updatedMs,
      {bool Function(String rowId)? filter}) async {
    final ids = await _allRowIds(entity);
    var n = 0;
    for (final id in ids) {
      if (filter != null && !filter(id)) continue;
      await enqueue(entity, id, 'upsert', updatedMs);
      n++;
    }
    return n;
  }

  Future<List<String>> _allRowIds(String entity) async {
    switch (entity) {
      case 'travel_spaces':
        return (await db.select(db.travelSpaces).get()).map((r) => r.id).toList();
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
