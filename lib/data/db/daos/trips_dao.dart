/// 行程 DAO：Trip+TripItem CRUD，复制行程，日期夹紧。
library;
import 'package:drift/drift.dart';
import '../tables.dart';
import '../database.dart';
part 'trips_dao.g.dart';
@DriftAccessor(tables: [Trips, TripItems, ChecklistItems, AlbumPhotos, Expenses])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(AppDatabase db) : super(db);
  Stream<List<Trip>> watchAll() => (select(trips)..orderBy([(t)=>OrderingTerm.desc(t.createdAt)])).watch();
  Stream<List<TripItem>> watchItems(String tripId) => (select(tripItems)..where((t)=>t.tripId.equals(tripId))..orderBy([(t)=>OrderingTerm.asc(t.dateEpochDay),(t)=>OrderingTerm.asc(t.sortOrder)])).watch();
  Stream<List<TripItem>> watchItemsForDay(String tripId, int day) => (select(tripItems)..where((t)=>t.tripId.equals(tripId)&t.dateEpochDay.equals(day))..orderBy([(t)=>OrderingTerm.asc(t.sortOrder)])).watch();
  Future<List<TripItem>> getItems(String tripId) => (select(tripItems)..where((t)=>t.tripId.equals(tripId))).get();
  Future<TripItem?> getItem(String id) => (select(tripItems)..where((t)=>t.id.equals(id))).getSingleOrNull();
  Future<void> insertTrip(TripsCompanion t) => into(trips).insert(t);
  Future<void> updateTrip(TripsCompanion t) => update(trips).replace(t);
  Future<void> deleteTrip(String id) async {
    await (update(expenses)..where((e)=>e.tripId.equals(id))).write(const ExpensesCompanion(tripId:Value(null),tripItemId:Value(null)));
    await (delete(tripItems)..where((t)=>t.tripId.equals(id))).go();
    await (delete(checklistItems)..where((c)=>c.tripId.equals(id))).go();
    await (delete(albumPhotos)..where((a)=>a.tripId.equals(id))).go();
    await (delete(trips)..where((t)=>t.id.equals(id))).go();
  }
  Future<void> insertItem(TripItemsCompanion i) => into(tripItems).insert(i);
  Future<void> updateItem(TripItemsCompanion i) => update(tripItems).replace(i);
  Future<void> deleteItem(String id) async {
    await (update(expenses)..where((e)=>e.tripItemId.equals(id))).write(const ExpensesCompanion(tripItemId:Value(null)));
    await (delete(tripItems)..where((t)=>t.id.equals(id))).go();
  }
  Future<String> copyTrip(String srcId, String newId) async {
    final s = await (select(trips)..where((t)=>t.id.equals(srcId))).getSingle();
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(trips).insert(TripsCompanion(id:Value(newId),name:Value(s.name),destination:Value(s.destination),emoji:Value(s.emoji),cover:Value(s.cover),startEpochDay:Value(s.startEpochDay),endEpochDay:Value(s.endEpochDay),note:Value(s.note),archived:const Value(false),createdAt:Value(now),updatedAt:Value(now)));
    for (final i in await getItems(srcId)) {
      await into(tripItems).insert(TripItemsCompanion(id:Value(i.id+'_cp'),tripId:Value(newId),dateEpochDay:Value(i.dateEpochDay),type:Value(i.type),name:Value(i.name),address:Value(i.address),lat:Value(i.lat),lng:Value(i.lng),photoUri:Value(i.photoUri),startTimeMin:Value(i.startTimeMin),durationMin:Value(i.durationMin),costCents:Value(i.costCents),costCurrency:Value(i.costCurrency),note:Value(i.note),sortOrder:Value(i.sortOrder),fromName:Value(i.fromName),fromAddress:Value(i.fromAddress),fromLat:Value(i.fromLat),fromLng:Value(i.fromLng),toName:Value(i.toName),toAddress:Value(i.toAddress),toLat:Value(i.toLat),toLng:Value(i.toLng),flightNo:Value(i.flightNo),createdAt:Value(now),updatedAt:Value(now)));
    }
    return newId;
  }
  Future<void> clampDates(String tripId, int s, int e) async {
    for (final i in await getItems(tripId)) {
      int d = i.dateEpochDay;
      if (d < s) d = s; if (d > e) d = e;
      if (d != i.dateEpochDay) await (update(tripItems)..where((t)=>t.id.equals(i.id))).write(TripItemsCompanion(dateEpochDay:Value(d)));
    }
    await (update(trips)..where((t)=>t.id.equals(tripId))).write(TripsCompanion(startEpochDay:Value(s),endEpochDay:Value(e)));
  }
  Future<void> moveItem(String itemId, bool up) async {
    final item = await getItem(itemId); if (item==null) return;
    final sibs = await (select(tripItems)..where((t)=>t.tripId.equals(item.tripId)&t.dateEpochDay.equals(item.dateEpochDay))..orderBy([(t)=>OrderingTerm.asc(t.sortOrder)])).get();
    final idx = sibs.indexWhere((x)=>x.id==itemId); if (idx<0) return;
    final ti = up?idx-1:idx+1; if (ti<0||ti>=sibs.length) return;
    final a=sibs[idx],b=sibs[ti];
    await (update(tripItems)..where((t)=>t.id.equals(a.id))).write(TripItemsCompanion(sortOrder:Value(b.sortOrder)));
    await (update(tripItems)..where((t)=>t.id.equals(b.id))).write(TripItemsCompanion(sortOrder:Value(a.sortOrder)));
  }
}
