/// 单行合流判定 mergeRow（V2.6 §3.7.3 SPEC，纯逻辑，重点单测）。
///
/// 时间戳口径：
/// - 有 updatedAt 列的实体（trips/tripItems/groups）：本地 updatedMs = updatedAt；
/// - 无 updatedAt 列的实体（members/expenses/settlements）：本地以 createdAt 承载
///   （云端胜写回时 createdAt = 云端 updated_ms，等效 seq）；
/// - categories：本地无时间戳列，本地有效值 = outbox pending 事件时间（无则 -1
///   表示云端恒胜，同值幂等覆盖）。
/// 防环：本地胜再入队产生一条比云端更新的事件（事件时点单调递增），下一轮推上即收敛。
library;
import '../db/database.dart';
import '../repo/observability_repo.dart';
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

  /// 我参与的协作空间所关联的行程 id 集合（引擎每次 pull 前 via list_my_spaces 刷新）。
  ///
  /// 别人的行程 / 行程项是否落本地镜像，只由这个集合判定（§3.3 读权限放宽后的分流）。
  Set<String> collabTripIds = {};

  /// 协作名单是否**成功加载过**（list_my_collabs 失败时为 false）。
  ///
  /// 名单未知时，任何「非本人」的云端行一律跳过：既不落本地业务表（否则他人
  /// 共享账本数据会被当成自己的账本，还可能被后续 push 上行——历史 bug H7），
  /// 也不落镜像（避免把「已退出但名单过期」的团又拉回来）。
  bool collabContextKnown = false;

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
    if (toShared == null) return; // 非本人且名单未知/不在协作名单 → 跳过，绝不落业务表

    final local = await _readLocal(entity, id, toShared);
    final pending = await outbox.pendingEntry(entity.localKey, id);

    // 本地行已不存在，但 outbox 还压着未上行的事件（删除/重建意图）→
    // 不复活、不覆盖，交给 push 把本地意图发上去。否则「离线删除 → 云端胜
    // 插回本地 → assemble 又推回云端」会让删除被静默撤销（历史 bug H1）。
    if (local == null && pending != null) return;

    final localMs = await _effectiveLocalMs(entity, id, local, pending);

    if (local == null || cloudMs > localMs) {
      // ---- S12.2 冲突回执（纯观测，不改判定） ----
      // 条件精确化（规格原文「双方都存在未合入改动」不可判定）：
      //   本地行存在 ∧ 本地有未上行事件（pending）∧ 云端 updated_ms 更大
      //   → 云端胜、本地那次未上行的改动被静默覆盖 → 记一条回执。
      // 本地胜不记：本地会重推并自动收敛，记了只是噪声。
      if (local != null && pending != null && cloudMs > localMs) {
        // 归属团：业务表取 group_id；团自身取 id；没有归属（独立行程等）不记。
        final gid = (cloud['group_id'] as String?) ??
            (entity == SyncEntity.groups ? id : '');
        await recordConflict(
          db,
          groupId: gid,
          entity: entity.localKey,
          entityId: id,
          localUpdatedMs: localMs,
          remoteUpdatedMs: cloudMs,
        );
      }
      await _upsertLocal(entity, cloud, toShared); // 云端胜
    } else if (cloudMs < localMs) {
      // 本地胜：排队上行（防环收敛）。走 hook 以便统一触发 debounce（否则该行
      // 进了 outbox 却没人排 push，只能等下一次业务写入或手动同步——历史 bug H6）。
      final at = localMs > _nowHint ? localMs : _nowHint;
      if (SyncOutboxService.hook != null) {
        SyncOutboxService.notifyWriteAt(entity.localKey, id, 'upsert', at);
      } else {
        await outbox.enqueue(entity.localKey, id, 'upsert', at);
      }
    }
    // 相等：不动作（防抖）
  }

  int _nowHint = DateTime.now().millisecondsSinceEpoch;

  /// 更新身份上下文（每轮 pull 前由引擎调用）。
  ///
  /// [known] 传 null 表示沿用上次的「名单是否可靠」结论（引擎在 rpc 前先刷一次
  /// 身份，rpc 后再用真实结果刷新）。
  void refreshContext(
      {String? userId,
      required Set<String> collabGroups,
      Set<String>? collabTrips,
      bool? known}) {
    currentUserId = userId;
    collabGroupIds = collabGroups;
    if (collabTrips != null) collabTripIds = collabTrips;
    if (known != null) collabContextKnown = known;
    _nowHint = DateTime.now().millisecondsSinceEpoch;
  }

  /// null = 该行对当前账号无意义（不落业务表、不落镜像）。
  ///
  /// 规则：本人的行 → false（落本地业务表）；他人的行 → 仅当协作名单**已成功
  /// 加载**且该行归属在名单内才落共享镜像（true），否则一律 null 跳过。
  bool? _routeToShared(SyncEntity entity, Map<String, dynamic> cloud) {
    switch (entity) {
      // 空间三实体没有镜像表：「我创建的」与「我加入的」共处一张本地表，
      // 云端 RLS 已把范围限定为我可见的行，直接落本地即可。
      case SyncEntity.spaces:
      case SyncEntity.spaceMembers:
      case SyncEntity.spaceEvents:
      case SyncEntity.categories:
        return false;
      case SyncEntity.trips:
        final owner = cloud['owner_user_id'] as String?;
        if (owner == null || owner == currentUserId) return false;
        if (!collabContextKnown) return null;
        return collabTripIds.contains((cloud['id'] as String?) ?? '') ? true : null;
      case SyncEntity.tripItems:
        final owner = cloud['owner_user_id'] as String?;
        if (owner == null || owner == currentUserId) return false;
        if (!collabContextKnown) return null;
        return collabTripIds.contains((cloud['trip_id'] as String?) ?? '') ? true : null;
      case SyncEntity.wishlistItems:
        // 与 tripItems 同口径：本人的池行落业务表；他人的行仅当其行程在
        // 协作名单内才落 SharedWishlistItems 镜像。
        final owner = cloud['owner_user_id'] as String?;
        if (owner == null || owner == currentUserId) return false;
        if (!collabContextKnown) return null;
        return collabTripIds.contains((cloud['trip_id'] as String?) ?? '') ? true : null;
      case SyncEntity.groups:
        final owner = cloud['owner_user_id'] as String?;
        if (owner == null || owner == currentUserId) return false;
        if (!collabContextKnown) return null;
        return collabGroupIds.contains(cloud['id']) ? true : null;
      case SyncEntity.members:
      case SyncEntity.expenses:
      case SyncEntity.settlements:
        final owner = cloud['owner_user_id'] as String?;
        if (owner == null || owner == currentUserId) return false;
        if (!collabContextKnown) return null;
        return collabGroupIds.contains(cloud['group_id']) ? true : null;
      // V2.7.1：公款池 / 收件箱属业务表，且**没有协作镜像表**（S1 未建 Shared 变体）。
      // 自己的行落业务表；他人行一律跳过——绝不复现 H7（把他人账本数据写进本地
      // 业务表，随后又被 assemble 上行成云端重复行）。
      case SyncEntity.funds:
      case SyncEntity.inboxItems:
        final owner = cloud['owner_user_id'] as String?;
        if (owner == null || owner == currentUserId) return false;
        return null;
    }
  }

  // ===== 本地读 =====

  Future<dynamic> _readLocal(SyncEntity entity, String id, bool shared) async {
    switch (entity) {
      case SyncEntity.spaces:
        return (await (db.select(db.travelSpaces)..where((t) => t.id.equals(id))).get())
            .firstOrNull;
      case SyncEntity.spaceMembers:
        return (await (db.select(db.spaceMembers)..where((t) => t.id.equals(id))).get())
            .firstOrNull;
      case SyncEntity.spaceEvents:
        return (await (db.select(db.spaceEvents)..where((t) => t.id.equals(id))).get())
            .firstOrNull;
      case SyncEntity.trips:
        if (shared) {
          return (await (db.select(db.sharedTrips)..where((t) => t.id.equals(id))).get())
              .firstOrNull;
        }
        return (await (db.select(db.trips)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.tripItems:
        if (shared) {
          return (await (db.select(db.sharedTripItems)..where((t) => t.id.equals(id))).get())
              .firstOrNull;
        }
        return (await (db.select(db.tripItems)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.wishlistItems:
        if (shared) {
          return (await (db.select(db.sharedWishlistItems)..where((t) => t.id.equals(id))).get())
              .firstOrNull;
        }
        return (await (db.select(db.wishlistItems)..where((t) => t.id.equals(id))).get())
            .firstOrNull;
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
      case SyncEntity.funds:
        return (await (db.select(db.funds)..where((t) => t.id.equals(id))).get()).firstOrNull;
      case SyncEntity.inboxItems:
        return (await (db.select(db.inboxItems)..where((t) => t.id.equals(id))).get()).firstOrNull;
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

  Future<int> _effectiveLocalMs(
      SyncEntity entity, String id, dynamic local, OutboxEntry? pending) async {
    if (local == null) return 0;
    if (entity == SyncEntity.categories) {
      // categories 无本地时间戳列：本地有效值 = pending 事件时点，下界为「当前」
      // （只要有本地待上行意图就让本地胜，避免 pending 时点 ≤ 云端 updated_ms
      // 时本地改名被云端旧值静默吃掉——历史 bug L1）。无 pending 返回 -1 →
      // 云端恒胜（同值幂等覆盖，无语义变化）。
      if (pending == null) return -1;
      return pending.updatedMs > _nowHint ? pending.updatedMs : _nowHint;
    }
    final rowMs = SyncCodec.rowUpdatedMs(entity, local);
    final pendingMs = pending?.updatedMs;
    if (pendingMs != null && pendingMs > rowMs) return pendingMs;
    return rowMs;
  }

  // ===== 写 =====

  Future<void> _upsertLocal(SyncEntity entity, Map<String, dynamic> cloud, bool shared) async {
    switch (entity) {
      case SyncEntity.spaces:
        await db.into(db.travelSpaces).insertOnConflictUpdate(SyncCodec.spaceFromCloud(cloud));
      case SyncEntity.spaceMembers:
        await db.into(db.spaceMembers).insertOnConflictUpdate(SyncCodec.spaceMemberFromCloud(cloud));
      case SyncEntity.spaceEvents:
        await db.into(db.spaceEvents).insertOnConflictUpdate(SyncCodec.spaceEventFromCloud(cloud));
      case SyncEntity.trips:
        if (shared) {
          await db.into(db.sharedTrips).insertOnConflictUpdate(SyncCodec.sharedTripFromCloud(cloud));
        } else {
          await db.into(db.trips).insertOnConflictUpdate(SyncCodec.tripFromCloud(cloud));
        }
      case SyncEntity.tripItems:
        if (shared) {
          await db.into(db.sharedTripItems).insertOnConflictUpdate(SyncCodec.sharedTripItemFromCloud(cloud));
        } else {
          await db.into(db.tripItems).insertOnConflictUpdate(SyncCodec.tripItemFromCloud(cloud));
        }
      case SyncEntity.wishlistItems:
        if (shared) {
          await db.into(db.sharedWishlistItems).insertOnConflictUpdate(SyncCodec.sharedWishlistItemFromCloud(cloud));
        } else {
          await db.into(db.wishlistItems).insertOnConflictUpdate(SyncCodec.wishlistItemFromCloud(cloud));
        }
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
      case SyncEntity.funds:
        await db.into(db.funds).insertOnConflictUpdate(SyncCodec.fundFromCloud(cloud));
      case SyncEntity.inboxItems:
        await db.into(db.inboxItems).insertOnConflictUpdate(SyncCodec.inboxItemFromCloud(cloud));
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
      case SyncEntity.spaces:
        await (db.delete(db.travelSpaces)..where((t) => t.id.equals(id))).go();
        // 级联：空间没了，其成员与（仅本机缓存的）动态行一并清掉，避免孤儿行
        await (db.delete(db.spaceMembers)..where((t) => t.spaceId.equals(id))).go();
        await (db.delete(db.spaceEvents)..where((t) => t.spaceId.equals(id))).go();
      case SyncEntity.spaceMembers:
        await (db.delete(db.spaceMembers)..where((t) => t.id.equals(id))).go();
      case SyncEntity.spaceEvents:
        await (db.delete(db.spaceEvents)..where((t) => t.id.equals(id))).go();
      case SyncEntity.trips:
        await (db.delete(db.trips)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedTrips)..where((t) => t.id.equals(id))).go();
      case SyncEntity.tripItems:
        await (db.delete(db.tripItems)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedTripItems)..where((t) => t.id.equals(id))).go();
      case SyncEntity.wishlistItems:
        await (db.delete(db.wishlistItems)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedWishlistItems)..where((t) => t.id.equals(id))).go();
      case SyncEntity.categories:
        await (db.delete(db.categories)..where((c) => c.key.equals(id))).go();
      case SyncEntity.groups:
        await (db.delete(db.groups)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedGroups)..where((t) => t.id.equals(id))).go();
      case SyncEntity.members:
        await (db.delete(db.members)..where((t) => t.id.equals(id))).go();
        await (db.delete(db.sharedMembers)..where((t) => t.id.equals(id))).go();
      case SyncEntity.funds:
        await (db.delete(db.funds)..where((t) => t.id.equals(id))).go();
      case SyncEntity.inboxItems:
        await (db.delete(db.inboxItems)..where((t) => t.id.equals(id))).go();
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

  /// 清除某协作行程的全部镜像（退出空间 / 被移出 / 空间删除）。
  Future<void> clearSharedTrip(String tripId) async {
    await (db.delete(db.sharedTrips)..where((t) => t.id.equals(tripId))).go();
    await (db.delete(db.sharedTripItems)..where((t) => t.tripId.equals(tripId))).go();
    // V2.7.2：想去池镜像一并清掉（与行程项同属行程域子实体）
    await (db.delete(db.sharedWishlistItems)..where((t) => t.tripId.equals(tripId))).go();
  }

  /// 清除某空间的本地行（空间被删除 / 我退出后的本地清理）。
  Future<void> clearSpace(String spaceId) async {
    await (db.delete(db.travelSpaces)..where((t) => t.id.equals(spaceId))).go();
    await (db.delete(db.spaceMembers)..where((t) => t.spaceId.equals(spaceId))).go();
    await (db.delete(db.spaceEvents)..where((t) => t.spaceId.equals(spaceId))).go();
  }
}
