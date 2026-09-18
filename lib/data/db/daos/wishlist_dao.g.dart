// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_dao.dart';

// ignore_for_file: type=lint
mixin _$WishlistDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $WishlistItemsTable get wishlistItems => attachedDatabase.wishlistItems;
  $SharedWishlistItemsTable get sharedWishlistItems =>
      attachedDatabase.sharedWishlistItems;
  WishlistDaoManager get managers => WishlistDaoManager(this);
}

class WishlistDaoManager {
  final _$WishlistDaoMixin _db;
  WishlistDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$WishlistItemsTableTableManager get wishlistItems =>
      $$WishlistItemsTableTableManager(_db.attachedDatabase, _db.wishlistItems);
  $$SharedWishlistItemsTableTableManager get sharedWishlistItems =>
      $$SharedWishlistItemsTableTableManager(
        _db.attachedDatabase,
        _db.sharedWishlistItems,
      );
}
