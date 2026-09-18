/// 想去池仓储：行程 UI 访问 WishlistItems 的唯一桥接层（S1 建立，S6 补全）。
///
/// 口径（V2.7.2 规格 §1.3 / §九）：
/// - 条目无日期；落卡即移出（同事务建 TripItems 行 + 删池行 + 各自 notifyWrite）；
/// - 每个写方法提交后 `SyncOutboxService.notifyWrite('wishlist_items', id)`；
/// - 删除发墓碑（op:'delete'）；localKey 一律 'wishlist_items'（H10 契约）。
library;
import 'package:drift/drift.dart';

import '../db/database.dart';
import '../../core/uid.dart';
import '../../domain/models.dart';
import '../sync/sync_outbox_service.dart';

class WishlistRepository {
  WishlistRepository(this.db);
  final AppDatabase db;

  // ===== Streams =====

  Stream<List<WishlistItem>> watchByTrip(String tripId) =>
      (db.select(db.wishlistItems)..where((t) => t.tripId.equals(tripId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  Future<List<WishlistItem>> getByTrip(String tripId) =>
      (db.select(db.wishlistItems)..where((t) => t.tripId.equals(tripId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  Future<WishlistItem?> getItem(String id) =>
      (db.select(db.wishlistItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ===== 映射：drift 行 → 领域镜像 =====

  WishlistRecord toRecord(WishlistItem r) => WishlistRecord(
        id: r.id,
        tripId: r.tripId,
        cityKey: r.cityKey,
        name: r.name,
        address: r.address,
        type: r.type,
        durationMin: r.durationMin,
        tag: r.tag,
        guideRef: r.guideRef,
        note: r.note,
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  // ===== 写路径（notifyWrite 一律在提交后） =====

  /// 入池（攻略「先想去」/ 大纲纯标题行 / 手动表单共用底层）。
  Future<String> addItem({
    required String tripId,
    String cityKey = '',
    required String name,
    String address = '',
    String type = 'attraction',
    int? durationMin,
    String? tag,
    String? guideRef,
    String note = '',
    int? sortOrder,
  }) async {
    final id = newId('wish');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.wishlistItems).insert(WishlistItemsCompanion.insert(
          id: id,
          tripId: tripId,
          cityKey: Value(cityKey),
          name: Value(name),
          address: Value(address),
          type: Value(type),
          durationMin: Value(durationMin),
          tag: Value(tag),
          guideRef: Value(guideRef),
          note: Value(note),
          sortOrder: Value(sortOrder ?? 0),
          createdAt: now,
          updatedAt: now,
        ));
    SyncOutboxService.notifyWrite('wishlist_items', id);
    return id;
  }

  Future<void> updateItem(String id, WishlistItemsCompanion c) async {
    await (db.update(db.wishlistItems)..where((t) => t.id.equals(id)))
        .write(c.copyWith(updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
    SyncOutboxService.notifyWrite('wishlist_items', id);
  }

  /// 删除单条（物理删 + 墓碑）。
  Future<void> deleteItem(String id) async {
    await (db.delete(db.wishlistItems)..where((t) => t.id.equals(id))).go();
    SyncOutboxService.notifyWrite('wishlist_items', id, op: 'delete');
  }

  /// 行程删除级联清池（trips_repo.deleteTrip 的正式路径；此方法供备份覆盖恢复
  /// 等批量场景复用）：逐行墓碑。
  Future<void> clearTrip(String tripId) async {
    final ids = (await (db.select(db.wishlistItems)
              ..where((t) => t.tripId.equals(tripId)))
            .get())
        .map((w) => w.id)
        .toList();
    await (db.delete(db.wishlistItems)..where((t) => t.tripId.equals(tripId))).go();
    for (final id in ids) {
      SyncOutboxService.notifyWrite('wishlist_items', id, op: 'delete');
    }
  }

  /// 池内拖拽重排：整体按 10、20、30… 重编号（口径同 S4 reorderDay）；
  /// 提交后仅对传入行逐行 notifyWrite。
  Future<void> reorder(String tripId, List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.wishlistItems)
              ..where((t) => t.id.equals(orderedIds[i]) & t.tripId.equals(tripId)))
            .write(WishlistItemsCompanion(
                sortOrder: Value((i + 1) * 10), updatedAt: Value(now)));
      }
    });
    for (final id in orderedIds) {
      SyncOutboxService.notifyWrite('wishlist_items', id);
    }
  }

  /// 落卡即移出（收口规则 1）：同一事务内建 TripItems 行 + 删 WishlistItems 行，
  /// 提交后各自 notifyWrite（建卡 upsert + 删池墓碑）。
  ///
  /// 装配台落点（S7）与池内「排到第 N 天」（S6）都走本方法。
  /// [durationMin] 可覆盖池条目估时（补时长后落卡）；[type]/[sortOrder] 缺省继承/追加；
  /// [asBackup] = 装配台「转为备胎」（S8）：建无主备胎卡（backupOf=''），同样删池行
  /// （收口规则 1：已进日程体系）。
  Future<String> placeToDay({
    required String tripId,
    required String wishlistId,
    required int dateEpochDay,
    int? startTimeMin,
    int? durationMin,
    String? type,
    int? sortOrder,
    bool asBackup = false,
  }) async {
    final row = await getItem(wishlistId);
    if (row == null) throw StateError('想去条目不存在：$wishlistId');
    final cardId = newId('item');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      var maxSort = 0;
      if (sortOrder == null) {
        final dayItems = await (db.select(db.tripItems)
              ..where((t) =>
                  t.tripId.equals(tripId) &
                  t.dateEpochDay.equals(dateEpochDay)))
            .get();
        for (final it in dayItems) {
          if (it.sortOrder > maxSort) maxSort = it.sortOrder;
        }
      }
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: cardId,
            tripId: tripId,
            dateEpochDay: Value(dateEpochDay),
            type: Value(type ?? row.type),
            name: Value(row.name),
            address: Value(row.address),
            startTimeMin: Value(startTimeMin),
            durationMin: Value(durationMin ?? row.durationMin),
            guideRef: Value(row.guideRef),
            backupOf: Value(asBackup ? '' : null),
            sortOrder: Value(sortOrder ?? maxSort + 10),
            createdAt: now,
            updatedAt: now,
          ));
      await (db.delete(db.wishlistItems)..where((t) => t.id.equals(wishlistId)))
          .go();
    });
    SyncOutboxService.notifyWrite('trip_items', cardId);
    SyncOutboxService.notifyWrite('wishlist_items', wishlistId, op: 'delete');
    return cardId;
  }

  /// 以原 id 重建池行（装配台落点撤销 / Plan B 语义下恢复用）。
  /// 冲突覆盖（同 id 已存在则整行替换），提交后 notifyWrite。
  Future<void> restoreRow(WishlistRecord rec) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.wishlistItems).insertOnConflictUpdate(
          WishlistItemsCompanion.insert(
            id: rec.id,
            tripId: rec.tripId,
            cityKey: Value(rec.cityKey),
            name: Value(rec.name),
            address: Value(rec.address),
            type: Value(rec.type),
            durationMin: Value(rec.durationMin),
            tag: Value(rec.tag),
            guideRef: Value(rec.guideRef),
            note: Value(rec.note),
            sortOrder: Value(rec.sortOrder),
            createdAt: rec.createdAt,
            updatedAt: now,
          ),
        );
    SyncOutboxService.notifyWrite('wishlist_items', rec.id);
  }
}
