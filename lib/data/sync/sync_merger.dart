/// 单行合流判定 mergeRow（V2.6 §3.7.3 SPEC，纯逻辑，重点单测）。
///
/// 时间戳口径：
/// - 有 updatedAt 列的实体（trips/tripItems/groups）：本地 updatedMs = updatedAt；
/// - 无 updatedAt 列的实体（members/expenses/settlements）：本地以 createdAt 承载
///   （云端胜写回时 createdAt = 云端 updated_ms，等效 seq）；
/// - categories：本地无时间戳列，本地有效值 = outbox pending 事件时间（无则 0）；
///   为免"云端恒胜"造成无谓重写，行数据与云端全等时不动作。
/// 防环：本地胜再入队产生一条比云端更新的事件（事件时点单调递增），下一轮推上即收敛。
library;
import '../db/database.dart';
import 'sync_codec.dart';
import 'sync_models.dart';
import 'sync_outbox_service.dart';

class SyncMerger {
  SyncMerger(this.db, this.outbox);

  final AppDatabase db;
  final SyncOutboxService outbox;

  /// 当前账号 id（引擎在 pull 前刷新）；用于把可见行分流到业务表 / 共享镜像表。
  String? currentUserId;

  /// 我参与的共享团 id 集合（引擎每次 pull 前 via list_my_collabs 刷新）。
  Set<String> collabGroupIds = {};

  Future<void> mergeRow(SyncEntity entity, Map<String, dynamic> cloud) async {
    final id = cloud[entity.idColumn] as String?;
    if (id == null || id.isEmpty) return;
    final cloudMs = (cloud['updated_ms'] as num?)?.toInt() ?? 0;

    // ---- 软删下行：本地行删除（幂等） ----
    if (cloud['deleted'] == true) {
      await _deleteLocal(entity, id);
      return;
    }

    // ---- 分流：共享镜像 or 业务表 ----
    final toShared = _routeToShared(entity, cloud);
    if (toShared == null) return; // 非本人且不在协作名单 → 不可见/跳过

    final local = await _readLocal(entity, id, toShared);
    final localMs = await _effectiveLocalMs(entity, id, local);

    if (local == null || cloudMs > localMs) {
      await _upsertLocal(entity, cloud, toShared); // 云端胜
    } else if (cloudMs < localMs) {
      await outbox.enqueue(entity.name, id, 'upsert',
          localMs > _nowHint ? localMs : _nowHint); // 本地胜：排队上行（防环收敛）
    }
    // 相等：不动作（防抖）
  }

  int _nowHint = DateTime.now().millisecondsSinceEpoch;

  /// 更新身份上下文（每轮 pull 前由引擎调用）。
  void refreshContext({String? userId, required Set<String> collabGroups}) {
    currentUserId = userId;
    collabGroupIds = collabGroups;
    _nowHint = DateTime.now().millisecondsSinceEpoch;
  }

  /// null = 该行对当前账号无意义（非本人、也不在其协作团内）。
  bool? _routeToShared(SyncEntity entity, Map<String, dynamic> cloud) {
    switch (entity) {
      case SyncEntity.trips:
      case SyncEntity.tripItems:
      case SyncEntity.categories:
        return false; // 行程/字典不协作，RLS 也只对 owner 可见
      case SyncEntity.groups:
        final owner = cloud['owner_user_id'] as String?;
        if (owner != null && owner == currentUserId) return false;
        return collabGroupIds.contains(cloud['id']);
      case SyncEntity.members:
      case SyncEntity.expenses:
      case SyncEntity.settlements:
        final owner = cloud['owner_user_id'] as String?;
        if (owner != null && owner == currentUserId) return false;
        return collabGroupIds.contains(cloud['group_id']);
    }
  }

  // ===== 本地读 =====

  Future<dynamic> _readLocal(SyncEntity entity, String id, bool shared) async {
    switch (entity) {
      case SyncEntity.trips:
        return (await (db.select(db.trips)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.tripItems:
        return (await (db.select(db.tripItems)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.categories:
        return (await (db.select(db.categories)..where((c) => c.key.equals(id))).get()).firstOrNull;
      case SyncEntity.groups:
        if (shared) {
          return (await (db.select(db.sharedGroups)..where((t) => t.id.equals(id))).get()).firstOrNull;
        }
        return (await (db.select(db.groups)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.members:
        if (shared) {
          return (await (db.select(db.sharedMembers)..where((t) => t.id.equals(id))).get()).firstOrNull;
        }
        return (await (db.select(db.members)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.expenses:
        if (shared) {
          return (await (db.select(db.sharedExpenses)..where((t) => t.id.equals(id))).get()).firstOrNull;
        }
        return (await (db.select(db.expenses)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.settlements:
        if (shared) {
          return (await (db.select(db.sharedSettlements)..where((t) => t.id.equals(id))).get()).firstOrNull;
        }
        return (await (db.select(db.settlements)..where((t) => t.id.equals(id))).get()).firstOrNull;
    }
  }

  Future<int> _effectiveLocalMs(SyncEntity entity, String id, dynamic local) async {
    if (local == null) return 0;
    if (entity == SyncEntity.categories) {
      // categories 无本地时间戳列：有 pending 事件则以事件时间为本地口径；
      // 无 pending 返回 -1 → 云端恒胜（同值幂等覆盖，无语义变化）。
      final pending = await outbox.pendingUpdatedMs(entity.name, id);
      return pending ?? -1;
    }
    final rowMs = SyncCodec.rowUpdatedMs(entity, local);
    final pending = await outbox.pendingUpdatedMs(entity.name, id);
    if (pending != null && pending > rowMs) return pending;
    return rowMs;
  }

  // ===== 写 =====

  Future<void> _upsertLocal(SyncEntity entity, Map<String, dynamic> cloud, bool shared) async {
    switch (entity) {
      case SyncEntity.trips:
        await db.into(db.trips).insertOnConflictUpdate(SyncCodec.tripFromCloud(cloud));
      case SyncEntity.tripItems:
        await db.into(db.tripItems).insertOnConflictUpdate(SyncCodec.tripItemFromCloud(cloud));
      case SyncEntity.categories:
        await db.into(db.categories).insertOnConflictUpdate(SyncCodec.categoryFromCloud(cloud));
      case SyncEntity.groups:
        if (shared) {
          await db.into(db.sharedGroups).insertOnConflictUpdate(SyncCodec.sharedGroupFromCloud(cloud));
        } else {
          await db.into(db.groups).insertOnConflictUpdate(SyncCodec.groupFromCloud(cloud));
        }
      case SyncEntity.members:
        if (shared) {
          await db.into(db.sharedMembers).insertOnConflictUpdate(SyncCodec.sharedMemberFromCloud(cloud));
        } else {
          await db.into(db.members).insertOnConflictUpdate(SyncCodec.memberFromCloud(cloud));
        }
      case SyncEntity.expenses:
        if (shared) {
          await db.into(db.sharedExpenses).insertOnConflictUpdate(SyncCodec.sharedExpenseFromCloud(cloud));
        } else {
          await db.into(db.expenses).insertOnConflictUpdate(SyncCodec.expenseFromCloud(cloud));
        }
      case SyncEntity.settlements:
        if (shared) {
          await db.into(db.sharedSettlements).insertOnConflictUpdate(SyncCodec.sharedSettlementFromCloud(cloud));
        } else {
          await db.into(db.settlements).insertOnConflictUpdate(SyncCodec.settlementFromCloud(cloud));
        }
    }
  }

  Future<void> _deleteLocal(SyncEntity entity, String id) async {
    switch (entity) {
      case SyncEntity.trips:
        await (db.delete(db.trips)..where((t) => t.id.equals(id))).go();
      case SyncEntity.tripItems:
        await (db.delete(db.tripItems)..where((t) => t.id.equals(id))).go();
      case SyncEntity.categories:
        await (db.delete(db.categories)..where((c) => c.key.equals(id))).go();
      case SyncEntity.groups:
        await (db.delete(db.groups)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedGroups)..where((t) => t.id.equals(id))).go();
      case SyncEntity.members:
        await (db.delete(db.members)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedMembers)..where((t) => t.id.equals(id))).go();
      case SyncEntity.expenses:
        await (db.delete(db.expenses)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedExpenses)..where((t) => t.id.equals(id))).go();
      case SyncEntity.settlements:
        await (db.delete(db.settlements)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedSettlements)..where((t) => t.id.equals(id))).go();
    }
  }

  /// 清除某共享团的全部镜像（退出协作 / 被移除 / 团被 owner 删除）。
  Future<void> clearSharedGroup(String groupId) async {
    await (db.delete(db.sharedGroups)..where((t) => t.id.equals(groupId))).go();
    await (db.delete(db.sharedMembers)..where((t) => t.groupId.equals(groupId))).go();
    await (db.delete(db.sharedExpenses)..where((t) => t.groupId.equals(groupId))).go();
    await (db.delete(db.sharedSettlements)..where((t) => t.groupId.equals(groupId))).go();
  }
}
