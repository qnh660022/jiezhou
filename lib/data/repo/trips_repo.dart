/// 行程仓储。
library;
import "dart:typed_data";
import "package:drift/drift.dart";
import "../db/database.dart";
import "../../core/uid.dart";
import "../../domain/day_shift_engine.dart";
import "../../domain/trip_backup.dart";
import "../../domain/records.dart";
import "../../export/backup_format.dart";
import "../sync/sync_outbox_service.dart";
import "wishlist_repo.dart";

class TripsRepository {
  TripsRepository(this.db);
  final AppDatabase db;

  // ===== Streams =====
  Stream<List<Trip>> watchAll() => (db.select(db.trips)..orderBy([(t)=>OrderingTerm.desc(t.createdAt)])).watch();
  Stream<List<Trip>> watchTrips() => watchAll();
  Stream<Trip?> watchTrip(String id) => (db.select(db.trips)..where((t)=>t.id.equals(id))).watchSingleOrNull();
  Stream<List<TripItem>> watchItems(String tid) => (db.select(db.tripItems)..where((t)=>t.tripId.equals(tid))..orderBy([(t)=>OrderingTerm.asc(t.dateEpochDay),(t)=>OrderingTerm.asc(t.sortOrder)])).watch();
  Stream<List<TripItem>> watchItemsForDay(String tid, int day) => (db.select(db.tripItems)..where((t)=>t.tripId.equals(tid)&t.dateEpochDay.equals(day))..orderBy([(t)=>OrderingTerm.asc(t.sortOrder)])).watch();
  Stream<List<TripItem>> watchItemsByTrip(String tid) => watchItems(tid);
  Stream<List<Trip>> watchTripsByGroup(String gid) => (db.select(db.trips)..where((t)=>t.groupId.equals(gid))..orderBy([(t)=>OrderingTerm.desc(t.createdAt)])).watch();
  Stream<List<AlbumPhoto>> watchPhotos(String tid) => (db.select(db.albumPhotos)..where((a)=>a.tripId.equals(tid))..orderBy([(a)=>OrderingTerm.desc(a.createdAt)])).watch();

  // ===== One-shot queries =====
  Future<Trip?> getById(String id) async { final l = await (db.select(db.trips)..where((t)=>t.id.equals(id))).get(); return l.firstOrNull; }
  Future<TripItem?> getItem(String id) async { final l = await (db.select(db.tripItems)..where((t)=>t.id.equals(id))).get(); return l.firstOrNull; }
  Future<List<TripItem>> getItems(String tid) => (db.select(db.tripItems)..where((t)=>t.tripId.equals(tid))).get();

  /// drift 行 → 领域镜像（纯算法引擎 S2/S7 的入参映射）。
  static TripItemRecord tripItemToRecord(TripItem r) => TripItemRecord(
        id: r.id,
        tripId: r.tripId,
        dateEpochDay: r.dateEpochDay,
        type: r.type,
        name: r.name,
        address: r.address,
        lat: r.lat,
        lng: r.lng,
        photoUri: r.photoUri,
        startTimeMin: r.startTimeMin,
        durationMin: r.durationMin,
        costCents: r.costCents,
        costCurrency: r.costCurrency,
        note: r.note,
        fromName: r.fromName,
        fromAddress: r.fromAddress,
        fromLat: r.fromLat,
        fromLng: r.fromLng,
        toName: r.toName,
        toAddress: r.toAddress,
        toLat: r.toLat,
        toLng: r.toLng,
        flightNo: r.flightNo,
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        guideRef: r.guideRef,
        backupOf: r.backupOf,
      );

  /// 全部安排卡转领域镜像。
  Future<List<TripItemRecord>> getItemRecords(String tid) async =>
      [for (final r in await getItems(tid)) tripItemToRecord(r)];

  // ===== Trip CRUD =====
  Future<String> createTrip({required String name, required String dest, String emoji="✈️", String cover="ocean", required int start, required int end, String note="", String? groupId}) async {
    final id = newId("trip"); final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.trips).insert(TripsCompanion(id:Value(id),name:Value(name),destination:Value(dest),emoji:Value(emoji),cover:Value(cover),startEpochDay:Value(start),endEpochDay:Value(end),note:Value(note),groupId:Value(groupId),createdAt:Value(now),updatedAt:Value(now)));
    SyncOutboxService.notifyWrite("trips", id);
    return id;
  }

  Future<void> upsertTrip(Trip trip) async {
    final existing = await getById(trip.id);
    if (existing == null) {
      await db.into(db.trips).insert(TripsCompanion(id:Value(trip.id),name:Value(trip.name),destination:Value(trip.destination),emoji:Value(trip.emoji),cover:Value(trip.cover),startEpochDay:Value(trip.startEpochDay),endEpochDay:Value(trip.endEpochDay),note:Value(trip.note),groupId:Value(trip.groupId),archived:Value(trip.archived),createdAt:Value(trip.createdAt),updatedAt:Value(trip.updatedAt)));
      // 新建分支此前漏了入队：只在本地落库，云端永远看不到这条行程（bug B7）。
      SyncOutboxService.notifyWrite("trips", trip.id);
    } else {
      await updateTrip(trip);
    }
  }

  Future<void> updateTrip(Trip trip) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.trips)..where((t)=>t.id.equals(trip.id))).write(TripsCompanion(name:Value(trip.name),destination:Value(trip.destination),emoji:Value(trip.emoji),cover:Value(trip.cover),startEpochDay:Value(trip.startEpochDay),endEpochDay:Value(trip.endEpochDay),note:Value(trip.note),groupId:Value(trip.groupId),archived:Value(trip.archived),updatedAt:Value(now)));
    SyncOutboxService.notifyWrite("trips", trip.id);
  }

  Future<void> deleteTrip(String id) async {
    // 先收集子行 id：删除/摘链后就读不到了，无法再补墓碑或重上行（bug B8）。
    final itemIds = (await getItems(id)).map((i) => i.id).toList();
    final wishlistIds = (await (db.select(db.wishlistItems)
              ..where((w) => w.tripId.equals(id)))
            .get())
        .map((w) => w.id)
        .toList();
    final linkedExpenseIds = (await (db.select(db.expenses)
              ..where((e) => e.tripId.equals(id)))
            .get())
        .map((e) => e.id)
        .toList();
    await (db.update(db.expenses)..where((e)=>e.tripId.equals(id))).write(ExpensesCompanion(tripId:Value(null),tripItemId:Value(null)));
    await (db.delete(db.tripItems)..where((t)=>t.tripId.equals(id))).go();
    // V2.7.2：想去池随行程级联清空（含受邀端镜像行）
    await (db.delete(db.wishlistItems)..where((w)=>w.tripId.equals(id))).go();
    await (db.delete(db.sharedWishlistItems)..where((w)=>w.tripId.equals(id))).go();
    await (db.delete(db.checklistItems)..where((c)=>c.tripId.equals(id))).go();
    await (db.delete(db.albumPhotos)..where((a)=>a.tripId.equals(id))).go();
    await (db.delete(db.trips)..where((t)=>t.id.equals(id))).go();
    // 关联账单被摘掉 tripId，需重新上行；行程安排逐条发墓碑。
    SyncOutboxService.notifyWrite("trips", id, op: "delete");
    for (final iid in itemIds) {
      SyncOutboxService.notifyWrite("trip_items", iid, op: "delete");
    }
    // 想去池行逐行发墓碑（登记 9：删行程级联清池）
    for (final wid in wishlistIds) {
      SyncOutboxService.notifyWrite("wishlist_items", wid, op: "delete");
    }
    for (final eid in linkedExpenseIds) {
      SyncOutboxService.notifyWrite("expenses", eid);
    }
  }

  Future<void> archiveTrip(String id, bool v) async { await (db.update(db.trips)..where((t)=>t.id.equals(id))).write(TripsCompanion(archived:Value(v),updatedAt:Value(DateTime.now().millisecondsSinceEpoch))); SyncOutboxService.notifyWrite("trips", id); }

  Future<String> copyTrip(String srcId) async {
    final newId_ = newId("trip"); final now = DateTime.now().millisecondsSinceEpoch;
    final s = await (db.select(db.trips)..where((t)=>t.id.equals(srcId))).getSingle();
    await db.into(db.trips).insert(TripsCompanion(id:Value(newId_),name:Value(s.name),destination:Value(s.destination),emoji:Value(s.emoji),cover:Value(s.cover),startEpochDay:Value(s.startEpochDay),endEpochDay:Value(s.endEpochDay),note:Value(s.note),archived:Value(false),createdAt:Value(now),updatedAt:Value(now)));
    final copiedItemIds = <String>[];
    for (final i in await getItems(srcId)) {
      final iid = i.id + "_cp";
      copiedItemIds.add(iid);
      await db.into(db.tripItems).insert(TripItemsCompanion(id:Value(iid),tripId:Value(newId_),dateEpochDay:Value(i.dateEpochDay),type:Value(i.type),name:Value(i.name),address:Value(i.address),lat:Value(i.lat),lng:Value(i.lng),photoUri:Value(i.photoUri),startTimeMin:Value(i.startTimeMin),durationMin:Value(i.durationMin),costCents:Value(i.costCents),costCurrency:Value(i.costCurrency),note:Value(i.note),sortOrder:Value(i.sortOrder),fromName:Value(i.fromName),fromAddress:Value(i.fromAddress),fromLat:Value(i.fromLat),fromLng:Value(i.fromLng),toName:Value(i.toName),toAddress:Value(i.toAddress),toLat:Value(i.toLat),toLng:Value(i.toLng),flightNo:Value(i.flightNo),createdAt:Value(now),updatedAt:Value(now)));
    }
    // 复制出的副本也要上行（此前整条路径零入队：本地可见、云端没有 —— bug B6）。
    SyncOutboxService.notifyWrite("trips", newId_);
    for (final iid in copiedItemIds) {
      SyncOutboxService.notifyWrite("trip_items", iid);
    }
    return newId_;
  }

  // ===== Item CRUD =====
  Future<void> insertItem(TripItemsCompanion c) async { await db.into(db.tripItems).insert(c); SyncOutboxService.notifyWrite("trip_items", c.id.value); }
  Future<void> updateItem(String id, TripItemsCompanion c) async { await (db.update(db.tripItems)..where((t)=>t.id.equals(id))).write(c.copyWith(updatedAt:Value(DateTime.now().millisecondsSinceEpoch))); SyncOutboxService.notifyWrite("trip_items", id); }
  Future<void> saveItem(TripItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.tripItems)..where((t)=>t.id.equals(item.id))).write(TripItemsCompanion(name:Value(item.name),address:Value(item.address),type:Value(item.type),lat:Value(item.lat),lng:Value(item.lng),photoUri:Value(item.photoUri),startTimeMin:Value(item.startTimeMin),durationMin:Value(item.durationMin),costCents:Value(item.costCents),costCurrency:Value(item.costCurrency),note:Value(item.note),fromName:Value(item.fromName),fromAddress:Value(item.fromAddress),fromLat:Value(item.fromLat),fromLng:Value(item.fromLng),toName:Value(item.toName),toAddress:Value(item.toAddress),toLat:Value(item.toLat),toLng:Value(item.toLng),flightNo:Value(item.flightNo),sortOrder:Value(item.sortOrder),dateEpochDay:Value(item.dateEpochDay),updatedAt:Value(now)));
    SyncOutboxService.notifyWrite("trip_items", item.id);
  }

  Future<void> deleteItem(String id) async {
    await (db.update(db.expenses)..where((e)=>e.tripItemId.equals(id))).write(ExpensesCompanion(tripItemId:Value(null)));
    await (db.delete(db.tripItems)..where((t)=>t.id.equals(id))).go();
    SyncOutboxService.notifyWrite("trip_items", id, op: "delete");
  }

  // ===== Date range management =====
  Future<void> updateDates(String tid, int s, int e) async {
    for (final i in await getItems(tid)) {
      int d = i.dateEpochDay;
      if (d < s) d = s;
      if (d > e) d = e;
      if (d != i.dateEpochDay) {
        await (db.update(db.tripItems)..where((t)=>t.id.equals(i.id))).write(TripItemsCompanion(dateEpochDay:Value(d),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
        SyncOutboxService.notifyWrite("trip_items", i.id);
      }
    }
    await (db.update(db.trips)..where((t)=>t.id.equals(tid))).write(TripsCompanion(startEpochDay:Value(s),endEpochDay:Value(e),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
    // 行程起止日变了也要上行（此前只改了本地 —— bug B6）。
    SyncOutboxService.notifyWrite("trips", tid);
  }

  // ===== 增减天数顺延（V2.7.2 S2） =====

  /// 执行顺延引擎输出的变更动作：单事务内先改行后改 Trips，提交后逐行
  /// notifyWrite（discard 的 OpDeleteItem 发墓碑 op:'delete'）。
  Future<void> applyDayOps(String tripId, List<DayOp> ops) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final op in ops) {
        switch (op) {
          case OpShiftItem(:final itemId, :final newEpochDay, :final newSortOrder):
            await (db.update(db.tripItems)..where((t) => t.id.equals(itemId))).write(
                TripItemsCompanion(
                    dateEpochDay: Value(newEpochDay),
                    sortOrder: Value(newSortOrder),
                    updatedAt: Value(now)));
          case OpDeleteItem(:final itemId):
            // 关联账单先摘链（与 deleteItem 同口径），再物理删
            await (db.update(db.expenses)..where((e) => e.tripItemId.equals(itemId)))
                .write(ExpensesCompanion(tripItemId: Value(null)));
            await (db.delete(db.tripItems)..where((t) => t.id.equals(itemId))).go();
          case OpSetEnd(:final newEndEpochDay):
            await (db.update(db.trips)..where((t) => t.id.equals(tripId))).write(
                TripsCompanion(endEpochDay: Value(newEndEpochDay), updatedAt: Value(now)));
        }
      }
    });
    // 事务提交成功后再逐行补发（批量操作在事务外逐行 notifyWrite）
    for (final op in ops) {
      switch (op) {
        case OpShiftItem(:final itemId):
          SyncOutboxService.notifyWrite("trip_items", itemId);
        case OpDeleteItem(:final itemId):
          SyncOutboxService.notifyWrite("trip_items", itemId, op: "delete");
        case OpSetEnd():
          SyncOutboxService.notifyWrite("trips", tripId);
      }
    }
  }

  // ===== 拖拽排序与跨天批量（V2.7.2 S4） =====

  /// 当天重排：[orderedIds] 为该天全部卡的最终顺序；当天 sortOrder 整体重编
  /// 10,20,30…（单事务；提交后仅对**变更行**逐行 notifyWrite）。
  Future<void> reorderDay(String tripId, int day, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final before = <String, int>{};
    for (final it in await getItems(tripId)) {
      if (it.dateEpochDay == day) before[it.id] = it.sortOrder;
    }
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        final newOrder = (i + 1) * 10;
        final old = before[orderedIds[i]];
        if (old == null || old == newOrder) continue;
        await (db.update(db.tripItems)..where((t) => t.id.equals(orderedIds[i])))
            .write(TripItemsCompanion(sortOrder: Value(newOrder), updatedAt: Value(now)));
      }
    });
    for (final id in orderedIds) {
      final old = before[id];
      if (old == null) continue;
      final newOrder = (orderedIds.indexOf(id) + 1) * 10;
      if (old == newOrder) continue;
      SyncOutboxService.notifyWrite("trip_items", id);
    }
  }

  /// 单卡跨天移动：写 dateEpochDay + sortOrder 追加目标天末尾。
  Future<void> moveItemToDay(String tripId, String itemId, int targetDay) =>
      batchMove(tripId, [itemId], targetDay);

  /// 批量跨天移动：单事务逐行移动（sortOrder 依次追加目标天末尾，步长 10）；
  /// 提交后逐行 notifyWrite。
  Future<void> batchMove(String tripId, List<String> itemIds, int targetDay) async {
    if (itemIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      final target = await (db.select(db.tripItems)
            ..where((t) => t.tripId.equals(tripId) & t.dateEpochDay.equals(targetDay)))
          .get();
      var order = 0;
      for (final r in target) {
        if (r.sortOrder > order) order = r.sortOrder;
      }
      for (final id in itemIds) {
        order += 10;
        await (db.update(db.tripItems)..where((t) => t.id.equals(id))).write(
            TripItemsCompanion(
                dateEpochDay: Value(targetDay),
                sortOrder: Value(order),
                updatedAt: Value(now)));
      }
    });
    for (final id in itemIds) {
      SyncOutboxService.notifyWrite("trip_items", id);
    }
  }

  /// 批量删除：单事务逐行摘链（关联账单）+ 物理删；提交后逐行墓碑。
  Future<void> batchDelete(String tripId, List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    await db.transaction(() async {
      for (final id in itemIds) {
        await (db.update(db.expenses)..where((e) => e.tripItemId.equals(id)))
            .write(const ExpensesCompanion(tripItemId: Value(null)));
        await (db.delete(db.tripItems)..where((t) => t.id.equals(id))).go();
      }
    });
    for (final id in itemIds) {
      SyncOutboxService.notifyWrite("trip_items", id, op: "delete");
    }
  }

  /// S5 攻略「直接排」：按 §8.3 字段映射建正式卡（guideRef 弱关联，
  /// 不复制种子长文）。sortOrder 追加该天末尾（步长 10）。
  Future<String> addItemWithGuideRef({
    required String tripId,
    required int dateEpochDay,
    required String name,
    required String type, // spots→attraction / food→food（调用方映射）
    required String guideRef,
    String address = '',
    int? durationMin,
    int? startTimeMin,
  }) async {
    final id = newId("item");
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayItems = await (db.select(db.tripItems)
          ..where((t) =>
              t.tripId.equals(tripId) & t.dateEpochDay.equals(dateEpochDay)))
        .get();
    var maxSort = 0;
    for (final it in dayItems) {
      if (it.sortOrder > maxSort) maxSort = it.sortOrder;
    }
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: id,
          tripId: tripId,
          dateEpochDay: Value(dateEpochDay),
          type: Value(type),
          name: Value(name),
          address: Value(address),
          startTimeMin: Value(startTimeMin),
          durationMin: Value(durationMin),
          sortOrder: Value(maxSort + 10),
          guideRef: Value(guideRef),
          createdAt: now,
          updatedAt: now,
        ));
    SyncOutboxService.notifyWrite("trip_items", id);
    return id;
  }

  /// S5 互链反查：按 guideRef 前缀（cityKey#栏#）取同行程全部命中卡。
  /// 前缀匹配 + 内存过滤；顺延引擎改天后 dateEpochDay 联动正确。
  Future<List<TripItem>> findByGuideRefPrefix(String tripId, String prefix) =>
      (db.select(db.tripItems)
            ..where((t) =>
                t.tripId.equals(tripId) & t.guideRef.like('$prefix%'))
            ..orderBy([
              (t) => OrderingTerm.asc(t.dateEpochDay),
              (t) => OrderingTerm.asc(t.sortOrder),
            ]))
          .get();

  /// S7 装配台落点：同事务建卡 + 删池行（委托 wishlist_repo.placeToDay，
  /// 收口规则 1）。
  Future<String> assemblePlace({
    required String tripId,
    required String wishlistId,
    required int dateEpochDay,
    int? startTimeMin,
    int? durationMin,
  }) =>
      WishlistRepository(db).placeToDay(
        tripId: tripId,
        wishlistId: wishlistId,
        dateEpochDay: dateEpochDay,
        startTimeMin: startTimeMin,
        durationMin: durationMin,
      );

  // ===== Plan B 备选项（V2.7.2 S8） =====
  //
  // backupOf 语义：null=正式卡；''=无主备胎；非空=有主备胎（指向同行程
  // 正式卡 id）。一层约束：backupOf 指向的卡自身必须是正式卡，违反抛 StateError。

  /// 正式卡「转为备选」：挂到该天首个正式卡；当天无正式卡 → ''（无主）。
  Future<void> convertToBackup(String tripId, String itemId) async {
    final item = await getItem(itemId);
    if (item == null || item.tripId != tripId) return;
    if (item.backupOf != null) {
      throw StateError('备胎不能再转为备胎（至多一层）');
    }
    final dayFormal = await (db.select(db.tripItems)
          ..where((t) =>
              t.tripId.equals(tripId) &
              t.dateEpochDay.equals(item.dateEpochDay) &
              t.backupOf.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final main = dayFormal.where((e) => e.id != itemId).firstOrNull;
    await updateItem(
        itemId, TripItemsCompanion(backupOf: Value(main?.id ?? '')));
  }

  /// 一键替换（互换身份）：同事务两行更新——正式卡 backupOf=备胎id、
  /// 备胎转正（null）。时间与日期字段不互换（转正卡沿用自身 startTimeMin）。
  Future<void> swapBackup(String mainId, String backupId) async {
    final main = await getItem(mainId);
    final backup = await getItem(backupId);
    if (main == null || backup == null) {
      throw StateError('替换的卡不存在');
    }
    if (main.backupOf != null) {
      throw StateError('目标不是正式卡（backupOf 非空）');
    }
    if (backup.backupOf == null) {
      throw StateError('备胎卡 backupOf 为空，无法参与替换');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await (db.update(db.tripItems)..where((t) => t.id.equals(mainId))).write(
          TripItemsCompanion(backupOf: Value(backupId), updatedAt: Value(now)));
      await (db.update(db.tripItems)..where((t) => t.id.equals(backupId)))
          .write(TripItemsCompanion(
              backupOf: Value(null), updatedAt: Value(now)));
    });
    SyncOutboxService.notifyWrite("trip_items", mainId);
    SyncOutboxService.notifyWrite("trip_items", backupId);
  }

  /// 备胎「转正（独立）」：backupOf = null。
  Future<void> promoteBackup(String tripId, String itemId) async {
    final item = await getItem(itemId);
    if (item == null || item.tripId != tripId) return;
    if (item.backupOf == null) throw StateError('该卡已是正式卡');
    await updateItem(
        itemId, TripItemsCompanion(backupOf: Value(null)));
  }

  /// 备胎「退回想去」：同事务删卡 + 建池行（继承
  /// name/address/type/durationMin/guideRef/tag→无/notes），提交后双行 notify。
  Future<String> returnBackupToWishlist(String tripId, String itemId) async {
    final item = await getItem(itemId);
    if (item == null || item.tripId != tripId) {
      throw StateError('备胎卡不存在');
    }
    final wishId = newId('wish');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.into(db.wishlistItems).insert(WishlistItemsCompanion.insert(
            id: wishId,
            tripId: tripId,
            cityKey: const Value(''),
            name: Value(item.name),
            address: Value(item.address),
            type: Value(item.type),
            durationMin: Value(item.durationMin),
            guideRef: Value(item.guideRef),
            sortOrder: const Value(0),
            createdAt: now,
            updatedAt: now,
          ));
      await (db.delete(db.tripItems)..where((t) => t.id.equals(itemId))).go();
    });
    SyncOutboxService.notifyWrite('wishlist_items', wishId);
    SyncOutboxService.notifyWrite('trip_items', itemId, op: 'delete');
    return wishId;
  }

  /// 装配台「转为备胎」：池条目 → 无主备胎卡（backupOf=''、日期=当前天），
  /// 同事务删池行（收口规则 1）。
  Future<String> assemblePlaceAsBackup({
    required String tripId,
    required String wishlistId,
    required int dateEpochDay,
  }) =>
      WishlistRepository(db).placeToDay(
        tripId: tripId,
        wishlistId: wishlistId,
        dateEpochDay: dateEpochDay,
        asBackup: true,
      );

  // ===== Album =====
  Future<void> addPhoto(String uri, int dayEpochDay) async {
    final id = newId("photo");
    final now = DateTime.now().millisecondsSinceEpoch;
    // Need tripId - caller must supply it via tripId lookup or pass it
    // This is a simplified version; the album screen already has trip context
    await db.into(db.albumPhotos).insert(AlbumPhotosCompanion(id:Value(id),tripId:Value(""),uri:Value(uri),dayEpochDay:Value(dayEpochDay),createdAt:Value(now)));
  }

  Future<void> addPhotoToTrip(String tripId, String uri, int dayEpochDay) async {
    final id = newId("photo");
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.albumPhotos).insert(AlbumPhotosCompanion(id:Value(id),tripId:Value(tripId),uri:Value(uri),dayEpochDay:Value(dayEpochDay),createdAt:Value(now)));
  }

  Future<void> deletePhoto(String id) async {
    await (db.delete(db.albumPhotos)..where((a)=>a.id.equals(id))).go();
  }

  // === 专有格式备份（.tat） ===
  /// 导出单行程完整备份（行程+安排+相册uri+清单+想去池）为二进制 .tat。
  Future<Uint8List> exportTripBackupBytes(String tid) async {
    final t = await getById(tid);
    if (t == null) throw StateError('行程不存在');
    final items = await getItems(tid);
    final photos = await (db.select(db.albumPhotos)..where((a) => a.tripId.equals(tid))).get();
    final checklist = await (db.select(db.checklistItems)..where((c) => c.tripId.equals(tid))).get();
    final wishlist = await (db.select(db.wishlistItems)..where((w) => w.tripId.equals(tid))).get();
    final backup = buildTripBackup(
      trip: t.toJson(),
      items: [for (final i in items) i.toJson()],
      photos: [for (final p in photos) p.toJson()],
      checklist: [for (final c in checklist) c.toJson()],
      wishlist: [for (final w in wishlist) w.toJson()],
    );
    return encodeBackup(kTripBackupMagic, backup);
  }

  /// 导入专有 .tat 行程备份（独立副本，groupId 置空）。
  Future<TripImportReport> importTripBackupBytes(Uint8List bytes) async {
    Map<String, dynamic> root;
    if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kTripBackupMagic])) {
      root = decodeBackup(bytes, acceptedMagics: [kTripBackupMagic]);
    } else {
      throw const FormatException('不是「芥舟」的行程备份文件');
    }
    return importTripBackupMap(root);
  }

  /// 从已解码的行程备份根节点导入（同步码/二维码复用）。
  Future<TripImportReport> importTripBackupMap(Map<String, dynamic> root) async {
    final backup = parseTripBackupMap(root);
    final result = applyTripImport(backup);
    final report = await db.transaction<TripImportReport>(() async {
      await _insertTripBackup(result);
      final name = (result.trip['name'] as String? ?? '').trim();
      return TripImportReport(
        trip: name.isEmpty ? '导入的行程' : name,
        items: result.stats.items,
        photos: result.stats.photos,
        checklist: result.stats.checklist,
      );
    });
    // 提交后入队：导入的行程/安排是本地新写入，必须同步到云端（此前零入队 —— bug B6）。
    // ⚠️ 必须在事务提交之后：hook 会触发 debounce→drain，若在事务内触发，
    // assemble 读不到未提交的行会走 delete 分支，可能把云端已有行软删。
    final importedTripId = result.trip['id'];
    if (importedTripId is String) {
      SyncOutboxService.notifyWrite("trips", importedTripId);
      for (final it in result.items) {
        final iid = it['id'];
        if (iid is String) SyncOutboxService.notifyWrite("trip_items", iid);
      }
      for (final w in result.wishlist) {
        final wid = w['id'];
        if (wid is String) SyncOutboxService.notifyWrite("wishlist_items", wid);
      }
    }
    return report;
  }

  Future<void> _insertTripBackup(TripImportResult r) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.trips).insert(TripsCompanion(
      id: Value(r.trip['id'] as String),
      name: Value(_nonEmptyTrip(r.trip['name'] as String?, '导入的行程')),
      destination: Value((r.trip['destination'] as String? ?? '')),
      emoji: Value(_nonEmptyTrip(r.trip['emoji'] as String?, '✈️')),
      cover: Value(_nonEmptyTrip(r.trip['cover'] as String?, 'ocean')),
      startEpochDay: Value(r.trip['startEpochDay'] is int ? r.trip['startEpochDay'] as int : 0),
      endEpochDay: Value(r.trip['endEpochDay'] is int ? r.trip['endEpochDay'] as int : 0),
      note: Value((r.trip['note'] as String? ?? '')),
      groupId: const Value(null),
      archived: Value(r.trip['archived'] is bool ? r.trip['archived'] as bool : false),
      createdAt: Value(r.trip['createdAt'] is int ? r.trip['createdAt'] as int : now),
      updatedAt: Value(now),
    ));
    for (final it in r.items) {
      await db.into(db.tripItems).insert(_tripBackupItemCompanion(it, now, r.trip['id'] as String));
    }
    for (final p in r.photos) {
      await db.into(db.albumPhotos).insert(AlbumPhotosCompanion(
        id: Value(p['id'] as String),
        tripId: Value(p['tripId'] as String),
        uri: Value((p['uri'] as String? ?? '')),
        dayEpochDay: Value(p['dayEpochDay'] is int ? p['dayEpochDay'] as int? : null),
        createdAt: Value(p['createdAt'] is int ? p['createdAt'] as int : now),
      ));
    }
    for (final c in r.checklist) {
      await db.into(db.checklistItems).insert(ChecklistItemsCompanion(
        id: Value(c['id'] as String),
        scope: Value('trip'),
        tripId: Value(c['tripId'] as String),
        category: Value(_nonEmptyTrip(c['category'] as String?, 'other')),
        label: Value(_nonEmptyTrip(c['label'] as String?, '事项')),
        done: Value(c['done'] is bool ? c['done'] as bool : false),
        sortOrder: Value(c['sortOrder'] is int ? c['sortOrder'] as int : 0),
      ));
    }
    for (final w in r.wishlist) {
      await db.into(db.wishlistItems).insert(_wishlistBackupCompanion(w, now, r.trip['id'] as String));
    }
  }

  WishlistItemsCompanion _wishlistBackupCompanion(Map<String, dynamic> w, int now, String tripId) {
    return WishlistItemsCompanion(
      id: Value(w['id'] as String),
      tripId: Value(tripId),
      cityKey: Value(w['cityKey'] as String? ?? ''),
      name: Value(_nonEmptyTrip(w['name'] as String?, '想去的地方')),
      address: Value(w['address'] as String? ?? ''),
      type: Value(_nonEmptyTrip(w['type'] as String?, 'attraction')),
      durationMin: Value(w['durationMin'] is int ? w['durationMin'] as int? : null),
      tag: Value(w['tag'] as String?),
      guideRef: Value(w['guideRef'] as String?),
      note: Value(w['note'] as String? ?? ''),
      sortOrder: Value(w['sortOrder'] is int ? w['sortOrder'] as int : 0),
      createdAt: Value(w['createdAt'] is int ? w['createdAt'] as int : now),
      updatedAt: Value(now),
    );
  }

  TripItemsCompanion _tripBackupItemCompanion(Map<String, dynamic> it, int now, String tripId) {
    return TripItemsCompanion(
      id: Value(it['id'] as String),
      tripId: Value(tripId),
      dateEpochDay: Value(it['dateEpochDay'] is int ? it['dateEpochDay'] as int : 0),
      type: Value(_nonEmptyTrip(it['type'] as String?, 'attraction')),
      name: Value(_nonEmptyTrip(it['name'] as String?, '安排')),
      address: Value((it['address'] as String? ?? '')),
      lat: Value(it['lat'] is num ? (it['lat'] as num).toDouble() : null),
      lng: Value(it['lng'] is num ? (it['lng'] as num).toDouble() : null),
      photoUri: Value(it['photoUri'] as String?),
      startTimeMin: Value(it['startTimeMin'] is int ? it['startTimeMin'] as int? : null),
      durationMin: Value(it['durationMin'] is int ? it['durationMin'] as int? : null),
      costCents: Value(it['costCents'] is int ? it['costCents'] as int? : null),
      costCurrency: Value(_nonEmptyTrip(it['costCurrency'] as String?, 'CNY')),
      note: Value((it['note'] as String? ?? '')),
      fromName: Value((it['fromName'] as String? ?? '')),
      fromAddress: Value((it['fromAddress'] as String? ?? '')),
      fromLat: Value(it['fromLat'] is num ? (it['fromLat'] as num).toDouble() : null),
      fromLng: Value(it['fromLng'] is num ? (it['fromLng'] as num).toDouble() : null),
      toName: Value((it['toName'] as String? ?? '')),
      toAddress: Value((it['toAddress'] as String? ?? '')),
      toLat: Value(it['toLat'] is num ? (it['toLat'] as num).toDouble() : null),
      toLng: Value(it['toLng'] is num ? (it['toLng'] as num).toDouble() : null),
      flightNo: Value(it['flightNo'] as String?),
      sortOrder: Value(it['sortOrder'] is int ? it['sortOrder'] as int : 0),
      createdAt: Value(it['createdAt'] is int ? it['createdAt'] as int : now),
      updatedAt: Value(now),
    );
  }

  String _nonEmptyTrip(String? v, String fallback) {
    final t = (v ?? '').trim();
    return t.isEmpty ? fallback : t;
  }
}