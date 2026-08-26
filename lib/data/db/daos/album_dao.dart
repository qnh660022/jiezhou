/// 行程相册 DAO。
library;
import 'package:drift/drift.dart';
import '../tables.dart';
import '../database.dart';
part 'album_dao.g.dart';
@DriftAccessor(tables: [AlbumPhotos])
class AlbumDao extends DatabaseAccessor<AppDatabase> with _$AlbumDaoMixin {
  AlbumDao(AppDatabase db) : super(db);
  Stream<List<AlbumPhoto>> watchByTrip(String tid) => (select(albumPhotos)..where((a)=>a.tripId.equals(tid))..orderBy([(a)=>OrderingTerm.desc(a.createdAt)])).watch();
  Future<void> insertPhoto(AlbumPhotosCompanion a) => into(albumPhotos).insert(a);
  Future<void> deletePhoto(String id) async { await (delete(albumPhotos)..where((a)=>a.id.equals(id))).go(); }
  Future<void> deleteByTrip(String tid) async { await (delete(albumPhotos)..where((a)=>a.tripId.equals(tid))).go(); }
}
