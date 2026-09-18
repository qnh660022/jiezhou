// V2.7.2 S6：placeToDay（落卡即移出）/ reorder / 补时长 相关仓储用例。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
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
  late TripsRepository trips;
  late WishlistRepository wishes;
  final spy = _NotifySpy();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    trips = TripsRepository(db);
    wishes = WishlistRepository(db);
    spy.attach();
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: '行',
          startEpochDay: const Value(100),
          endEpochDay: const Value(103),
          createdAt: 1000,
          updatedAt: 1000,
        ));
  });

  tearDown(() async {
    spy.detach();
    await db.close();
  });

  Future<String> seedWish({
    String name = '西湖',
    String type = 'attraction',
    String address = '龙井路',
    int? durationMin,
    String? guideRef,
    String cityKey = 'hangzhou',
  }) =>
      wishes.addItem(
        tripId: 't1',
        name: name,
        type: type,
        address: address,
        durationMin: durationMin,
        guideRef: guideRef,
        cityKey: cityKey,
      );

  test('1. placeToDay：同事务建卡 + 删池行（收口规则 1）', () async {
    final wid = await seedWish();
    final cardId = await wishes.placeToDay(
        tripId: 't1', wishlistId: wid, dateEpochDay: 101);
    // 卡出现
    final card = (await trips.getItem(cardId))!;
    expect(card.name, '西湖');
    expect(card.dateEpochDay, 101);
    // 池行消失
    expect(await wishes.getItem(wid), isNull);
    expect(await wishes.getByTrip('t1'), isEmpty);
  });

  test('2. placeToDay：字段继承 + durationMin 覆盖 + guideRef 保留', () async {
    final wid = await seedWish(
        name: '灵隐寺',
        type: 'attraction',
        address: '法云弄1号',
        durationMin: 120,
        guideRef: 'hangzhou#spots#1');
    final cardId = await wishes.placeToDay(
        tripId: 't1', wishlistId: wid, dateEpochDay: 100, durationMin: 150);
    final card = (await trips.getItem(cardId))!;
    expect(card.type, 'attraction');
    expect(card.address, '法云弄1号');
    expect(card.durationMin, 150, reason: '补时长后覆盖池条目估时');
    expect(card.guideRef, 'hangzhou#spots#1');
  });

  test('3. placeToDay：sortOrder 追加该天末尾；notifyWrite 双行（upsert+墓碑）',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'a',
          tripId: 't1',
          dateEpochDay: const Value(102),
          createdAt: now,
          updatedAt: now,
        ));
    await (db.update(db.tripItems)..where((t) => t.id.equals('a')))
        .write(const TripItemsCompanion(sortOrder: Value(20)));
    final wid = await seedWish(name: '新条目');
    spy.events.clear();
    final cardId =
        await wishes.placeToDay(tripId: 't1', wishlistId: wid, dateEpochDay: 102);
    expect((await trips.getItem(cardId))!.sortOrder, 30);
    final tripEvents =
        spy.events.where((e) => e.$1 == 'trip_items' && e.$2 == cardId);
    expect(tripEvents, isNotEmpty);
    expect(tripEvents.first.$3, 'upsert');
    expect(
        spy.events
            .where((e) => e.$1 == 'wishlist_items' && e.$2 == wid)
            .first
            .$3,
        'delete',
        reason: '删池行发墓碑');
  });

  test('4. placeToDay：池行不存在抛 StateError 且不建卡', () async {
    expect(
      () => wishes.placeToDay(tripId: 't1', wishlistId: 'ghost', dateEpochDay: 100),
      throwsStateError,
    );
    expect(await trips.getItems('t1'), isEmpty);
  });

  test('5. reorder：全池 10 步长重编号持久化', () async {
    final a = await seedWish(name: 'A');
    final b = await seedWish(name: 'B');
    final c = await seedWish(name: 'C');
    await wishes.reorder('t1', [c, a, b]);
    final rows = await wishes.getByTrip('t1');
    final byId = {for (final r in rows) r.id: r};
    expect(byId[c]!.sortOrder, 10);
    expect(byId[a]!.sortOrder, 20);
    expect(byId[b]!.sortOrder, 30);
  });

  test('6. 补时长：updateItem 写 durationMin 并上行', () async {
    final wid = await seedWish(name: '未估时条目');
    expect((await wishes.getItem(wid))!.durationMin, isNull);
    spy.events.clear();
    await wishes.updateItem(
        wid, const WishlistItemsCompanion(durationMin: Value(240)));
    expect((await wishes.getItem(wid))!.durationMin, 240);
    expect(
        spy.events.any((e) => e.$1 == 'wishlist_items' && e.$2 == wid), isTrue);
  });
}
