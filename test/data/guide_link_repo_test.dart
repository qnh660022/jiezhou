// V2.7.2 S5：addItemWithGuideRef / findByGuideRefPrefix 仓储层用例。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

class _NotifySpy {
  final events = <(String, String, String)>[];
  void attach() {
    SyncOutboxService.hook =
        (entity, rowId, op, ms) => events.add((entity, rowId, op));
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
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: '行',
          startEpochDay: const Value(100),
          endEpochDay: const Value(102),
          createdAt: 1000,
          updatedAt: 1000,
        ));
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't2',
          name: '行2',
          startEpochDay: const Value(100),
          endEpochDay: const Value(102),
          createdAt: 1000,
          updatedAt: 1000,
        ));
  });

  tearDown(() async {
    spy.detach();
    await db.close();
  });

  test('1. spots 映射逐字段（type/address/durationMin/guideRef）', () async {
    final id = await repo.addItemWithGuideRef(
      tripId: 't1',
      dateEpochDay: 100,
      name: '西湖',
      type: 'attraction',
      guideRef: 'hangzhou#spots#0',
      address: '龙井路1号',
      durationMin: 90,
    );
    final row = (await repo.getItem(id))!;
    expect(row.type, 'attraction');
    expect(row.name, '西湖');
    expect(row.address, '龙井路1号');
    expect(row.durationMin, 90);
    expect(row.guideRef, 'hangzhou#spots#0');
    expect(row.dateEpochDay, 100);
    expect(row.startTimeMin, isNull, reason: '未选时段 → startTimeMin 为空');
  });

  test('2. food 映射（address 存 area；type=food）', () async {
    final id = await repo.addItemWithGuideRef(
      tripId: 't1',
      dateEpochDay: 101,
      name: '知味观',
      type: 'food',
      guideRef: 'hangzhou#food#2',
      address: '湖滨银泰 in77',
      durationMin: 60,
      startTimeMin: 720,
    );
    final row = (await repo.getItem(id))!;
    expect(row.type, 'food');
    expect(row.address, '湖滨银泰 in77');
    expect(row.startTimeMin, 720, reason: '用户选了时段才写 startTimeMin');
  });

  test('3. sortOrder 追加该天末尾（步长 10），不同天互不影响', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'a', tripId: 't1', dateEpochDay: const Value(100), createdAt: now, updatedAt: now));
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'b', tripId: 't1', dateEpochDay: const Value(100), createdAt: now, updatedAt: now));
    await (db.update(db.tripItems)..where((t) => t.id.equals('a')))
        .write(const TripItemsCompanion(sortOrder: Value(10)));
    await (db.update(db.tripItems)..where((t) => t.id.equals('b')))
        .write(const TripItemsCompanion(sortOrder: Value(20)));

    final c = await repo.addItemWithGuideRef(
      tripId: 't1',
      dateEpochDay: 100,
      name: '新卡',
      type: 'attraction',
      guideRef: 'hz#spots#1',
    );
    final d = await repo.addItemWithGuideRef(
      tripId: 't1',
      dateEpochDay: 101,
      name: '另一天',
      type: 'food',
      guideRef: 'hz#food#1',
    );
    expect((await repo.getItem(c))!.sortOrder, 30);
    expect((await repo.getItem(d))!.sortOrder, 10, reason: '空天从 10 起');
  });

  test('4. 写入后 notifyWrite(trip_items, id) 逐行发出', () async {
    spy.events.clear();
    final id = await repo.addItemWithGuideRef(
      tripId: 't1',
      dateEpochDay: 100,
      name: '灵隐寺',
      type: 'attraction',
      guideRef: 'hangzhou#spots#1',
    );
    expect(
        spy.events.where((e) => e.$1 == 'trip_items').map((e) => e.$2), [id]);
  });

  test('5. 前缀反查：同城同栏全部命中，其余栏/其余行程排除', () async {
    await repo.addItemWithGuideRef(
        tripId: 't1',
        dateEpochDay: 100,
        name: 'A',
        type: 'attraction',
        guideRef: 'hz#spots#0');
    await repo.addItemWithGuideRef(
        tripId: 't1',
        dateEpochDay: 101,
        name: 'B',
        type: 'attraction',
        guideRef: 'hz#spots#1');
    await repo.addItemWithGuideRef(
        tripId: 't1',
        dateEpochDay: 101,
        name: 'C',
        type: 'food',
        guideRef: 'hz#food#0');
    await repo.addItemWithGuideRef(
        tripId: 't2',
        dateEpochDay: 100,
        name: 'D',
        type: 'attraction',
        guideRef: 'hz#spots#2');
    // 无 guideRef 的普通卡不参与
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'plain',
          tripId: 't1',
          dateEpochDay: const Value(100),
          createdAt: now,
          updatedAt: now,
        ));

    final hits = await repo.findByGuideRefPrefix('t1', 'hz#spots#');
    expect(hits.map((e) => e.name), ['A', 'B'], reason: '按天升序');
  });

  test('6. 前缀反查：无命中返回空（静默降级前提）', () async {
    final hits = await repo.findByGuideRefPrefix('t1', 'none#spots#');
    expect(hits, isEmpty);
  });
}
