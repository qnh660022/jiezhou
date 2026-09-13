/// 旅伴空间仓储（V2.6.6.2 §4.1）。
///
/// 职责边界（与共享账本镜像模式同构）：
/// * **本地表只是云端镜像**：空间的增删改一律先走 RPC（`SpaceService`），
///   RPC 成功后再把服务端结果回写本地表；本地表不承担"先写后同步"的职责
///   （空间/成员/动态都是跨账号语义，必须由服务端裁决）。
/// * 因此本仓储的 `mirror*` 方法才调 [SyncOutboxService.notifyWrite]，且**一律在
///   `db.transaction` 提交之后**（§0.3.4 红线：事务内触发 debounce→drain 会读到
///   未提交行，走 delete 分支可能把云端已有行软删）。
/// * 上云闸门（`SyncEngine.init` 的 `isEntityEnabled`）保证只有空间 owner 会真正
///   上行空间/成员行，成员端仅本地镜像，不会把必被 RLS 拒绝的行塞进 outbox。
library;
import 'package:drift/drift.dart';

import '../db/database.dart';
import '../sync/sync_outbox_service.dart';

/// 空间动态 action → 中文短语（§3.4 枚举；未知一律显示"更新了空间"）。
String spaceActionLabel(String action) => switch (action) {
      'space_created' => '创建了空间',
      'space_renamed' => '改了空间名',
      'member_joined' => '加入了空间',
      'member_left' => '离开了空间',
      'member_role_changed' => '调整了成员角色',
      'trip_item_added' => '新增了行程安排',
      'trip_item_updated' => '改了行程安排',
      'trip_item_deleted' => '删了行程安排',
      'expense_added' => '记了一笔账',
      'expense_updated' => '改了账单',
      'expense_deleted' => '删了账单',
      'settlement_created' => '发起了一轮结算',
      _ => '更新了空间',
    };

class TravelSpacesRepository {
  TravelSpacesRepository(this.db);

  final AppDatabase db;

  // ===== 流（UI 只读本地镜像） =====

  /// 已删除（`deleted_ms` 非空）的空间不进列表：删除后客户端本地也会被
  /// 合流层的墓碑清掉，这里再兜一层，避免残留行闪现在"我的空间"。
  Stream<List<TravelSpace>> watchSpaces({bool includeArchived = false}) {
    final q = db.select(db.travelSpaces)
      ..where((s) => s.deletedMs.isNull())
      ..orderBy([
        (s) => OrderingTerm.desc(s.updatedMs),
      ]);
    if (!includeArchived) {
      q.where((s) => s.status.equals('active'));
    }
    return q.watch();
  }

  /// 含归档（空间设置页用）。
  Stream<List<TravelSpace>> watchAllSpaces() => watchSpaces(includeArchived: true);

  Stream<TravelSpace?> watchSpace(String id) =>
      (db.select(db.travelSpaces)..where((s) => s.id.equals(id))).watchSingleOrNull();

  Stream<List<SpaceMember>> watchMembers(String spaceId) => (db.select(db.spaceMembers)
        ..where((m) => m.spaceId.equals(spaceId) & m.deletedMs.isNull())
        ..orderBy([
          (m) => OrderingTerm.asc(m.joinedMs),
        ]))
      .watch();

  Stream<List<SpaceEvent>> watchEvents(String spaceId, {int limit = 200}) =>
      (db.select(db.spaceEvents)
            ..where((e) => e.spaceId.equals(spaceId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.createdMs),
            ])
            ..limit(limit))
          .watch();

  /// 我参与的协作行程镜像（他人行程）。
  Stream<List<SharedTrip>> watchCollabTrips() =>
      (db.select(db.sharedTrips)..orderBy([(t) => OrderingTerm.desc(t.startEpochDay)]))
          .watch();

  /// 某行程的协作项镜像（他人行程的行程项）。
  Stream<List<SharedTripItem>> watchCollabTripItems(String tripId) =>
      (db.select(db.sharedTripItems)
            ..where((i) => i.tripId.equals(tripId))
            ..orderBy([
              (i) => OrderingTerm.asc(i.dateEpochDay),
              (i) => OrderingTerm.asc(i.sortOrder),
            ]))
          .watch();

  // ===== 一次性查询 =====

  Future<TravelSpace?> getById(String id) async =>
      (await (db.select(db.travelSpaces)..where((s) => s.id.equals(id))).get())
          .firstOrNull;

  Future<List<SpaceMember>> members(String spaceId) => (db.select(db.spaceMembers)
        ..where((m) => m.spaceId.equals(spaceId) & m.deletedMs.isNull()))
      .get();

  Future<int> memberCount(String spaceId) async => (await members(spaceId)).length;

  Future<String?> groupIdOf(String spaceId) async => (await getById(spaceId))?.groupId;

  Future<String?> tripIdOf(String spaceId) async => (await getById(spaceId))?.tripId;

  /// 当前用户在某空间的角色（本地镜像行；未同步到则 null，UI 回退到引擎上下文）。
  Future<String?> myRoleIn(String spaceId, String? userId) async {
    if (userId == null) return null;
    final rows = await (db.select(db.spaceMembers)
          ..where((m) =>
              m.spaceId.equals(spaceId) &
              m.userId.equals(userId) &
              m.deletedMs.isNull()))
        .get();
    return rows.isEmpty ? null : rows.first.role;
  }

  /// 该行程是否属于我（决定空间行程区走业务表还是协作镜像表）。
  Future<bool> isMyTrip(String tripId) async {
    final rows =
        await (db.select(db.trips)..where((t) => t.id.equals(tripId))).get();
    return rows.isNotEmpty;
  }

  // ===== 写（RPC 成功后本地镜像） =====

  /// 镜像空间行（建/改空间 RPC 成功后调用）。
  ///
  /// [enqueue] = true 时在事务提交后入队上行（仅对 owner 有意义；闸门会兜底）。
  Future<void> mirrorSpace(
    TravelSpacesCompanion row, {
    bool enqueue = true,
  }) async {
    await db.transaction(() async {
      await db.into(db.travelSpaces).insertOnConflictUpdate(row);
    });
    if (enqueue) {
      SyncOutboxService.notifyWrite('travel_spaces', row.id.value);
    }
  }

  /// 镜像成员行（加入/改角色/邀请加入后调用）。
  Future<void> mirrorMember(
    SpaceMembersCompanion row, {
    bool enqueue = false,
  }) async {
    await db.transaction(() async {
      await db.into(db.spaceMembers).insertOnConflictUpdate(row);
    });
    if (enqueue) {
      SyncOutboxService.notifyWrite('space_members', row.id.value);
    }
  }

  /// 本地软删成员行（被移除/退出后调用；云端软删由 RPC 完成）。
  Future<void> markMemberRemoved(String spaceId, String userId, int nowMs) async {
    await db.transaction(() async {
      await (db.update(db.spaceMembers)
            ..where((m) =>
                m.spaceId.equals(spaceId) &
                m.userId.equals(userId) &
                m.deletedMs.isNull()))
          .write(SpaceMembersCompanion(
        deletedMs: Value(nowMs),
        updatedMs: Value(nowMs),
      ));
    });
  }

  /// 追加一条动态（客户端直写成功后本地立即可见；§4.2 尽力而为）。
  ///
  /// 故意**不入 outbox**：动态流是展示素材，失败不应重试、不应放大为死信。
  /// 服务端 RPC 自己写的动态会在下一次 pull 时增量合流进来。
  Future<void> appendEventLocal({
    required String id,
    required String spaceId,
    required String actorUser,
    required String action,
    required String entityKind,
    String? entityId,
    String summary = '',
    int? nowMs,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.into(db.spaceEvents).insertOnConflictUpdate(
            SpaceEventsCompanion.insert(
              id: id,
              spaceId: spaceId,
              actorUser: actorUser,
              action: action,
              entityKind: entityKind,
              entityId: Value(entityId),
              summary: Value(summary),
              createdMs: now,
              updatedMs: now,
            ),
          );
    });
  }

  /// 镜像协作行程行（RPC 写回结果或直接写回；也用于用户改后立即本地回显）。
  Future<void> mirrorCollabTripItem(Map<String, dynamic> row) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.into(db.sharedTripItems).insertOnConflictUpdate(
            SharedTripItemsCompanion.insert(
              id: row['id'] as String,
              tripId: (row['trip_id'] as String?) ?? '',
              dateEpochDay: Value((row['date_epoch_day'] as num?)?.toInt() ?? 0),
              type: Value((row['type'] as String?) ?? 'attraction'),
              name: Value((row['name'] as String?) ?? ''),
              address: Value((row['address'] as String?) ?? ''),
              lat: Value((row['lat'] as num?)?.toDouble()),
              lng: Value((row['lng'] as num?)?.toDouble()),
              photoUri: Value(row['photo_uri'] as String?),
              startTimeMin: Value((row['start_time_min'] as num?)?.toInt()),
              durationMin: Value((row['duration_min'] as num?)?.toInt()),
              costCents: Value((row['cost_cents'] as num?)?.toInt()),
              costCurrency: Value((row['cost_currency'] as String?) ?? 'CNY'),
              note: Value((row['note'] as String?) ?? ''),
              fromName: Value((row['from_name'] as String?) ?? ''),
              fromAddress: Value((row['from_address'] as String?) ?? ''),
              fromLat: Value((row['from_lat'] as num?)?.toDouble()),
              fromLng: Value((row['from_lng'] as num?)?.toDouble()),
              toName: Value((row['to_name'] as String?) ?? ''),
              toAddress: Value((row['to_address'] as String?) ?? ''),
              toLat: Value((row['to_lat'] as num?)?.toDouble()),
              toLng: Value((row['to_lng'] as num?)?.toDouble()),
              flightNo: Value(row['flight_no'] as String?),
              sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
              createdAt: (row['created_ms'] as num?)?.toInt() ?? now,
              updatedAt: (row['updated_ms'] as num?)?.toInt() ?? now,
            ),
          );
    });
  }

  /// 本地移除协作行程项（RPC 删除成功后回显）。
  Future<void> removeCollabTripItem(String id) async {
    await db.transaction(() async {
      await (db.delete(db.sharedTripItems)..where((i) => i.id.equals(id))).go();
    });
  }

  /// 本地清掉一个空间（退出/被移出/空间被删后调用）。
  Future<void> clearSpaceLocal(String spaceId) async {
    await db.transaction(() async {
      await (db.delete(db.spaceMembers)..where((m) => m.spaceId.equals(spaceId))).go();
      await (db.delete(db.spaceEvents)..where((e) => e.spaceId.equals(spaceId))).go();
      await (db.delete(db.travelSpaces)..where((s) => s.id.equals(spaceId))).go();
    });
  }
}
