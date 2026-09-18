/// 想去池 DAO：WishlistItems / SharedWishlistItems 读写。
///
/// ⚠️ 写方法**不触发上云入队**（与 trips_dao 同约定）：正式写路径是
/// `lib/data/repo/wishlist_repo.dart` 与 `trips_repo.dart` 的落卡/级联路径，
/// 那里逐处 `SyncOutboxService.notifyWrite(...)`。
library;
import 'package:drift/drift.dart';
import '../tables.dart';
import '../database.dart';
part 'wishlist_dao.g.dart';

@DriftAccessor(tables: [WishlistItems, SharedWishlistItems])
class WishlistDao extends DatabaseAccessor<AppDatabase> with _$WishlistDaoMixin {
  WishlistDao(AppDatabase db) : super(db);

  Stream<List<WishlistItem>> watchByTrip(String tripId) =>
      (select(wishlistItems)..where((t) => t.tripId.equals(tripId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  Future<List<WishlistItem>> getByTrip(String tripId) =>
      (select(wishlistItems)..where((t) => t.tripId.equals(tripId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  Future<WishlistItem?> getItem(String id) =>
      (select(wishlistItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<SharedWishlistItem>> getSharedByTrip(String tripId) =>
      (select(sharedWishlistItems)..where((t) => t.tripId.equals(tripId))).get();

  Future<void> insertItem(WishlistItemsCompanion c) => into(wishlistItems).insert(c);

  Future<void> replaceItem(WishlistItemsCompanion c) => update(wishlistItems).replace(c);

  Future<int> deleteItem(String id) =>
      (delete(wishlistItems)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByTrip(String tripId) =>
      (delete(wishlistItems)..where((t) => t.tripId.equals(tripId))).go();

  Future<int> deleteSharedByTrip(String tripId) =>
      (delete(sharedWishlistItems)..where((t) => t.tripId.equals(tripId))).go();

  /// 同行程内同名（trim 后全等）条目是否存在（手动表单去重用，可空类型排除）。
  Future<bool> existsSameName(String tripId, String name, {String? excludeId}) async {
    final rows = await (select(wishlistItems)..where((t) => t.tripId.equals(tripId))).get();
    final target = name.trim();
    return rows.any((r) =>
        r.name.trim() == target && (excludeId == null || r.id != excludeId));
  }
}
