// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_dao.dart';

// ignore_for_file: type=lint
mixin _$AlbumDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $AlbumPhotosTable get albumPhotos => attachedDatabase.albumPhotos;
  AlbumDaoManager get managers => AlbumDaoManager(this);
}

class AlbumDaoManager {
  final _$AlbumDaoMixin _db;
  AlbumDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$AlbumPhotosTableTableManager get albumPhotos =>
      $$AlbumPhotosTableTableManager(_db.attachedDatabase, _db.albumPhotos);
}
