// V2.7.2 S2：applyDayOps 事务集成（引擎 → repo 落库 → notifyWrite）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/domain/day_shift_engine.dart';

class _NotifySpy {
  final events = <(String, String, String)>[];
  void attach() {
    SyncOutboxService.hook = (entity, rowId, op, ms) => events.add((entity, rowId, op));
  }

  void detach() => SyncOutboxService.hook = null;
}

void main() {
  late AppDatabase db;
  late TripsRepository repo;
  final spy = _NotifySpy();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = TripsRepository(db);
    spy.attach();
  });
  tearDown(() async {
    spy.detach();
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch;
  const start = 100; // 3 天：100/101/102

  Future<void> seed() async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: '行',
          startEpochDay: const Value(start),
          endEpochDay: const Value(start + 2),
          createdAt: now,
          updatedAt: now));
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'a', tripId: 't1', dateEpochDay: const Value(start), createdAt: now, updatedAt: now));
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'b',
          tripId: 't1',
          dateEpochDay: const Value(start + 1),
          createdAt: now,
          updatedAt: now));
  }

  test('11. repo 事务集成：插入一天全量平移落库一致', () async {
    await seed();
    final items = await repo.getItems('t1');
    final ops = insertDay(
        startEpochDay: start,
        endEpochDay: start + 2,
        items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
        k: 0);
    await repo.applyDayOps('t1', ops);
    final after = await repo.getItems('t1');
    final a = after.singleWhere((e) => e.id == 'a');
    final b = after.singleWhere((e) => e.id == 'b');
    expect(a.dateEpochDay, start + 1);
    expect(b.dateEpochDay, start + 2, reason: 'b@101 ≥ start+0 → +1');
    final trip = (await repo.getById('t1'))!;
    expect(trip.endEpochDay, start + 3, reason: 'end += 1');
    expect(trip.startEpochDay, start, reason: '引擎不改 start');
  });

  test('12. discard 墓碑逐行发出；shift/upsert 逐行发出', () async {
    await seed();
    final items = await repo.getItems('t1');
    // 删第 2 天（b 所在天），discard：b 物理删 + 墓碑；b 后无卡；end -1
    final ops = removeDay(
        startEpochDay: start,
        endEpochDay: start + 2,
        items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
        k: 2,
        mode: RemoveMode.discard);
    spy.events.clear();
    await repo.applyDayOps('t1', ops);
    expect(await (db.select(db.tripItems)..where((t) => t.id.equals('b'))).get(), isEmpty);
    final trip = (await repo.getById('t1'))!;
    expect(trip.endEpochDay, start + 1);
    expect(
        spy.events.where((e) => e.$1 == 'trip_items' && e.$3 == 'delete').map((e) => e.$2),
        ['b'],
        reason: 'discard 墓碑逐行发出');
    expect(spy.events.any((e) => e.$1 == 'trips' && e.$2 == 't1'), isTrue,
        reason: 'end 变更上行 trips 行');
  });
}
