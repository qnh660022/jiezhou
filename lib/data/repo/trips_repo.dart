/// 行程仓储。
library;
import "dart:typed_data";
import "package:drift/drift.dart";
import "../db/database.dart";
import "../../core/uid.dart";
import "../../domain/trip_backup.dart";
import "../../export/backup_format.dart";

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

  // === 专有格式备份（.tat） ===
  /// 导出单行程完整备份（行程+安排+相册uri+清单）为二进制 .tat。
  Future<Uint8List> exportTripBackupBytes(String tid) async {
    final t = await getById(tid);
    if (t == null) throw StateError('行程不存在');
    final items = await getItems(tid);
    final photos = await (db.select(db.albumPhotos)..where((a) => a.tripId.equals(tid))).get();
    final checklist = await (db.select(db.checklistItems)..where((c) => c.tripId.equals(tid))).get();
    final backup = buildTripBackup(
      trip: t.toJson(),
      items: [for (final i in items) i.toJson()],
      photos: [for (final p in photos) p.toJson()],
      checklist: [for (final c in checklist) c.toJson()],
    );
    return encodeBackup(kTripBackupMagic, backup);
  }

  /// 导入专有 .tat 行程备份（独立副本，groupId 置空）。
  Future<TripImportReport> importTripBackupBytes(Uint8List bytes) async {
    Map<String, dynamic> root;
    if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kTripBackupMagic])) {
      root = decodeBackup(bytes, acceptedMagics: [kTripBackupMagic]);
    } else {
      throw const FormatException('不是「旅途助手」的行程备份文件');
    }
    return importTripBackupMap(root);
  }

  /// 从已解码的行程备份根节点导入（同步码/二维码复用）。
  Future<TripImportReport> importTripBackupMap(Map<String, dynamic> root) async {
    final backup = parseTripBackupMap(root);
    final result = applyTripImport(backup);
    return db.transaction<TripImportReport>(() async {
      await _insertTripBackup(result);
      final name = (result.trip['name'] as String? ?? '').trim();
      return TripImportReport(
        trip: name.isEmpty ? '导入的行程' : name,
        items: result.stats.items,
        photos: result.stats.photos,
        checklist: result.stats.checklist,
      );
    });
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