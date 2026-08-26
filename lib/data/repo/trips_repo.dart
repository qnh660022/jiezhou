/// 行程仓储。
library;
import "package:drift/drift.dart";
import "../db/database.dart";
import "../db/tables.dart";
import "../../core/uid.dart";

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

  // ===== Trip CRUD =====
  Future<String> createTrip({required String name, required String dest, String emoji="✈️", String cover="ocean", required int start, required int end, String note="", String? groupId}) async {
    final id = newId("trip"); final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.trips).insert(TripsCompanion(id:Value(id),name:Value(name),destination:Value(dest),emoji:Value(emoji),cover:Value(cover),startEpochDay:Value(start),endEpochDay:Value(end),note:Value(note),groupId:Value(groupId),createdAt:Value(now),updatedAt:Value(now)));
    return id;
  }

  Future<void> upsertTrip(Trip trip) async {
    final existing = await getById(trip.id);
    if (existing == null) {
      await db.into(db.trips).insert(TripsCompanion(id:Value(trip.id),name:Value(trip.name),destination:Value(trip.destination),emoji:Value(trip.emoji),cover:Value(trip.cover),startEpochDay:Value(trip.startEpochDay),endEpochDay:Value(trip.endEpochDay),note:Value(trip.note),groupId:Value(trip.groupId),archived:Value(trip.archived),createdAt:Value(trip.createdAt),updatedAt:Value(trip.updatedAt)));
    } else {
      await updateTrip(trip);
    }
  }

  Future<void> updateTrip(Trip trip) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.trips)..where((t)=>t.id.equals(trip.id))).write(TripsCompanion(name:Value(trip.name),destination:Value(trip.destination),emoji:Value(trip.emoji),cover:Value(trip.cover),startEpochDay:Value(trip.startEpochDay),endEpochDay:Value(trip.endEpochDay),note:Value(trip.note),groupId:Value(trip.groupId),archived:Value(trip.archived),updatedAt:Value(now)));
  }

  Future<void> deleteTrip(String id) async {
    await (db.update(db.expenses)..where((e)=>e.tripId.equals(id))).write(ExpensesCompanion(tripId:Value(null),tripItemId:Value(null)));
    await (db.delete(db.tripItems)..where((t)=>t.tripId.equals(id))).go();
    await (db.delete(db.checklistItems)..where((c)=>c.tripId.equals(id))).go();
    await (db.delete(db.albumPhotos)..where((a)=>a.tripId.equals(id))).go();
    await (db.delete(db.trips)..where((t)=>t.id.equals(id))).go();
  }

  Future<void> archiveTrip(String id, bool v) => (db.update(db.trips)..where((t)=>t.id.equals(id))).write(TripsCompanion(archived:Value(v),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));

  Future<String> copyTrip(String srcId) async {
    final newId_ = newId("trip"); final now = DateTime.now().millisecondsSinceEpoch;
    final s = await (db.select(db.trips)..where((t)=>t.id.equals(srcId))).getSingle();
    await db.into(db.trips).insert(TripsCompanion(id:Value(newId_),name:Value(s.name),destination:Value(s.destination),emoji:Value(s.emoji),cover:Value(s.cover),startEpochDay:Value(s.startEpochDay),endEpochDay:Value(s.endEpochDay),note:Value(s.note),archived:Value(false),createdAt:Value(now),updatedAt:Value(now)));
    for (final i in await getItems(srcId)) {
      await db.into(db.tripItems).insert(TripItemsCompanion(id:Value(i.id+"_cp"),tripId:Value(newId_),dateEpochDay:Value(i.dateEpochDay),type:Value(i.type),name:Value(i.name),address:Value(i.address),lat:Value(i.lat),lng:Value(i.lng),photoUri:Value(i.photoUri),startTimeMin:Value(i.startTimeMin),durationMin:Value(i.durationMin),costCents:Value(i.costCents),costCurrency:Value(i.costCurrency),note:Value(i.note),sortOrder:Value(i.sortOrder),fromName:Value(i.fromName),fromAddress:Value(i.fromAddress),fromLat:Value(i.fromLat),fromLng:Value(i.fromLng),toName:Value(i.toName),toAddress:Value(i.toAddress),toLat:Value(i.toLat),toLng:Value(i.toLng),flightNo:Value(i.flightNo),createdAt:Value(now),updatedAt:Value(now)));
    }
    return newId_;
  }

  // ===== Item CRUD =====
  Future<void> insertItem(TripItemsCompanion c) => db.into(db.tripItems).insert(c);
  Future<void> updateItem(String id, TripItemsCompanion c) => (db.update(db.tripItems)..where((t)=>t.id.equals(id))).write(c.copyWith(updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
  Future<void> saveItem(TripItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.tripItems)..where((t)=>t.id.equals(item.id))).write(TripItemsCompanion(name:Value(item.name),address:Value(item.address),type:Value(item.type),lat:Value(item.lat),lng:Value(item.lng),photoUri:Value(item.photoUri),startTimeMin:Value(item.startTimeMin),durationMin:Value(item.durationMin),costCents:Value(item.costCents),costCurrency:Value(item.costCurrency),note:Value(item.note),fromName:Value(item.fromName),fromAddress:Value(item.fromAddress),fromLat:Value(item.fromLat),fromLng:Value(item.fromLng),toName:Value(item.toName),toAddress:Value(item.toAddress),toLat:Value(item.toLat),toLng:Value(item.toLng),flightNo:Value(item.flightNo),sortOrder:Value(item.sortOrder),dateEpochDay:Value(item.dateEpochDay),updatedAt:Value(now)));
  }

  Future<void> deleteItem(String id) async {
    await (db.update(db.expenses)..where((e)=>e.tripItemId.equals(id))).write(ExpensesCompanion(tripItemId:Value(null)));
    await (db.delete(db.tripItems)..where((t)=>t.id.equals(id))).go();
  }

  // ===== Date range management =====
  Future<void> updateDates(String tid, int s, int e) async {
    for (final i in await getItems(tid)) {
      int d = i.dateEpochDay;
      if (d < s) d = s;
      if (d > e) d = e;
      if (d != i.dateEpochDay) {
        await (db.update(db.tripItems)..where((t)=>t.id.equals(i.id))).write(TripItemsCompanion(dateEpochDay:Value(d)));
      }
    }
    await (db.update(db.trips)..where((t)=>t.id.equals(tid))).write(TripsCompanion(startEpochDay:Value(s),endEpochDay:Value(e),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
  }

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
}