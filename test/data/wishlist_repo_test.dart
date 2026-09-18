// V2.7.2 S1：WishlistRepository 写路径登记（notifyWrite / 墓碑 / 级联）。
// 登记 9：行程删除级联清池（含逐行 delete 墓碑）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

/// 捕获 notifyWrite 事件的假 hook（引擎未挂载时的仓库层出口）。
class _NotifySpy {
  final events = <(String, String, String)>[];
  void attach() {
    SyncOutboxService.hook = (entity, rowId, op, ms) => events.add((entity, rowId, op));
  }

  void detach() => SyncOutboxService.hook = null;
}

void main() {
  late AppDatabase db;
  late WishlistRepository repo;
  late TripsRepository tripsRepo;
  final spy = _NotifySpy();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = WishlistRepository(db);
    tripsRepo = TripsRepository(db);
    spy.attach();
  });
  tearDown(() async {
    spy.detach();
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch;

  Future<String> seedTrip(String id) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: id, name: '行程', createdAt: now, updatedAt: now));
    return id;
  }

  test('addItem：入池 + notifyWrite（localKey=wishlist_items）', () async {
    final tripId = await seedTrip('t1');
    final id = await repo.addItem(
      tripId: tripId,
      cityKey: 'hangzhou',
      name: '西湖',
      durationMin: 90,
      tag: '必去',
      guideRef: 'hangzhou#spots#0',
    );
    expect(id, isNotEmpty);
    final w = await repo.getItem(id);
    expect(w, isNotNull);
    expect(w!.name, '西湖');
    expect(w.type, 'attraction');
    expect(w.durationMin, 90);
    expect(spy.events.any((e) => e.$1 == 'wishlist_items' && e.$2 == id && e.$3 == 'upsert'),
        isTrue, reason: '写后必须上行入队');
  });

  test('deleteItem：物理删 + delete 墓碑', () async {
    final tripId = await seedTrip('t1');
    final id = await repo.addItem(tripId: tripId, name: '雷峰塔');
    spy.events.clear();
    await repo.deleteItem(id);
    expect(await repo.getItem(id), isNull);
    expect(spy.events.single, ('wishlist_items', id, 'delete'),
        reason: '删除发墓碑');
  });

  test('updateItem：改时长 + notifyWrite（updatedAt 刷新）', () async {
    final tripId = await seedTrip('t1');
    final id = await repo.addItem(tripId: tripId, name: '灵隐寺');
    spy.events.clear();
    await repo.updateItem(id, const WishlistItemsCompanion(durationMin: Value(240)));
    final w = await repo.getItem(id);
    expect(w!.durationMin, 240);
    expect(spy.events.any((e) => e.$1 == 'wishlist_items' && e.$3 == 'upsert'), isTrue);
  });

  test('登记 9：deleteTrip 级联清池（行删净 + 逐行墓碑）', () async {
    final tripId = await seedTrip('t1');
    final w1 = await repo.addItem(tripId: tripId, name: '西湖');
    final w2 = await repo.addItem(tripId: tripId, name: '河坊街');
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'i1', tripId: tripId, createdAt: now, updatedAt: now));
    spy.events.clear();
    await tripsRepo.deleteTrip(tripId);
    expect(await repo.getByTrip(tripId), isEmpty, reason: '池随行程级联清空');
    expect(await db.select(db.tripItems).get(), isEmpty);
    expect(
        spy.events.where((e) => e.$1 == 'wishlist_items' && e.$3 == 'delete').map((e) => e.$2),
        unorderedEquals(<String>[w1, w2]),
        reason: '登记 9：逐行 delete 墓碑');
    expect(
        spy.events.where((e) => e.$1 == 'trip_items' && e.$3 == 'delete').map((e) => e.$2),
        contains('i1'));
  });

  test('toRecord：drift 行 → WishlistRecord 领域镜像逐字段', () async {
    final tripId = await seedTrip('t1');
    final id = await repo.addItem(
      tripId: tripId,
      cityKey: 'suzhou',
      name: '拙政园',
      address: '东北街178号',
      type: 'attraction',
      durationMin: 150,
      tag: '经典',
      guideRef: 'suzhou#spots#1',
      note: '早去',
    );
    final row = (await repo.getByTrip(tripId)).single;
    final rec = repo.toRecord(row);
    expect(rec.id, id);
    expect(rec.tripId, tripId);
    expect(rec.cityKey, 'suzhou');
    expect(rec.name, '拙政园');
    expect(rec.address, '东北街178号');
    expect(rec.durationMin, 150);
    expect(rec.tag, '经典');
    expect(rec.guideRef, 'suzhou#spots#1');
  });

  test('TripItemRecord 映射：guideRef / backupOf 随行（引擎入参契约）', () async {
    final tripId = await seedTrip('t1');
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'i1',
          tripId: tripId,
          name: const Value('缆车'),
          guideRef: const Value('huangshan#spots#3'),
          backupOf: const Value('i0'),
          createdAt: now,
          updatedAt: now));
    final rows = await db.select(db.tripItems).get();
    final rec = TripsRepository.tripItemToRecord(rows.single);
    expect(rec.guideRef, 'huangshan#spots#3');
    expect(rec.backupOf, 'i0');
    expect(rec.name, '缆车');
  });
}
