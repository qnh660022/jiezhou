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
}
