// V2.7.2 S8：Plan B 备选项仓储用例（转备胎/互换/退回/一层约束/口径）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/domain/day_shift_engine.dart';

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
  late WishlistRepository wishes;
  final spy = _NotifySpy();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = TripsRepository(db);
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

  Future<void> seedCard(String id, int day,
      {int? start, int? dur, String type = 'attraction', String? guideRef,
      int sortOrder = 10}) async {
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: id,
          tripId: 't1',
          dateEpochDay: Value(day),
          type: Value(type),
          name: Value(id),
          address: const Value('测试地址'),
          startTimeMin: Value(start),
          durationMin: Value(dur),
          guideRef: Value(guideRef),
          sortOrder: Value(sortOrder),
          createdAt: 1000,
          updatedAt: 1000,
        ));
  }

  test('1. 转为备选：当天有正式卡 → backupOf=首个正式卡 id', () async {
    await seedCard('m1', 100, start: 420, dur: 60, sortOrder: 10);
    await seedCard('m2', 100, start: 600, dur: 60, sortOrder: 20);
    await repo.convertToBackup('t1', 'm2');
    expect((await repo.getItem('m2'))!.backupOf, 'm1',
        reason: '挂到该天首个正式卡（sortOrder 最小）');
  });

  test('2. 转为备选：当天无正式卡 → backupOf=\'\'（无主）', () async {
    await seedCard('solo', 101, start: 420, dur: 60);
    await repo.convertToBackup('t1', 'solo');
    expect((await repo.getItem('solo'))!.backupOf, '');
  });

  test('3. 一层约束：备胎再转备胎 → StateError', () async {
    await seedCard('m1', 100, start: 420, dur: 60);
    await seedCard('b1', 100, start: 600, dur: 60);
    await repo.convertToBackup('t1', 'b1'); // b1 = 备胎
    expect(() => repo.convertToBackup('t1', 'b1'), throwsStateError);
  });

  test('4. 互换身份：main.backupOf=备胎id、备胎转正；时间日期字段不互换',
      () async {
    await seedCard('main', 100, start: 420, dur: 60);
    await seedCard('bk', 100, start: 960, dur: 90, sortOrder: 20);
    await repo.convertToBackup('t1', 'bk'); // bk → 备胎（backupOf='main'）
    await repo.swapBackup('main', 'bk');
    final main = (await repo.getItem('main'))!;
    final bk = (await repo.getItem('bk'))!;
    expect(main.backupOf, 'bk', reason: '原正式卡成为指向新正式卡的备胎');
    expect(bk.backupOf, isNull, reason: '备胎转正');
    expect(bk.startTimeMin, 960, reason: '时间字段不互换');
    expect(bk.durationMin, 90);
    expect(bk.dateEpochDay, 100, reason: '日期字段不互换');
    expect(main.startTimeMin, 420);
  });

  test('5. 互换身份：目标非正式卡 → StateError', () async {
    await seedCard('m1', 100);
    await seedCard('m2', 100);
    await repo.convertToBackup('t1', 'm2');
    expect(() => repo.swapBackup('m2', 'm1'), throwsStateError,
        reason: 'main 参数本身是备胎');
  });

  test('6. 互换身份：备胎 backupOf 为空（null）→ StateError', () async {
    await seedCard('m1', 100);
    await seedCard('x', 101);
    expect(() => repo.swapBackup('m1', 'x'), throwsStateError,
        reason: 'x 是正式卡（backupOf=null），不能作为备胎参与替换');
  });

  test('7. 转正（独立）：backupOf=\'\' → null', () async {
    await seedCard('bk', 102);
    await repo.convertToBackup('t1', 'bk');
    await repo.promoteBackup('t1', 'bk');
    expect((await repo.getItem('bk'))!.backupOf, isNull);
  });

  test('8. 退回想去：删卡（墓碑）+ 池行继承字段', () async {
    spy.events.clear();
    await seedCard('bk', 102, start: 960, dur: 150, guideRef: 'hz#food#3');
    await repo.convertToBackup('t1', 'bk');
    final wid = await repo.returnBackupToWishlist('t1', 'bk');
    expect(await repo.getItem('bk'), isNull, reason: '卡被物理删');
    final wish = await (db.select(db.wishlistItems)
          ..where((t) => t.id.equals(wid)))
        .getSingle();
    expect(wish.name, 'bk');
    expect(wish.address, '测试地址');
    expect(wish.type, 'attraction');
    expect(wish.durationMin, 150);
    expect(wish.guideRef, 'hz#food#3');
    expect(
      spy.events.any(
          (e) => e.$1 == 'trip_items' && e.$2 == 'bk' && e.$3 == 'delete'),
      isTrue,
    );
    expect(spy.events.any((e) => e.$1 == 'wishlist_items' && e.$2 == wid),
        isTrue);
  });

  test('9. 装配转备胎：建 backupOf=\'\' 卡 + 删池行（同事务双 notify）', () async {
    final wid = await wishes.addItem(tripId: 't1', name: '池条目', durationMin: 60);
    spy.events.clear();
    final cardId = await repo.assemblePlaceAsBackup(
        tripId: 't1', wishlistId: wid, dateEpochDay: 100);
    final card = (await repo.getItem(cardId))!;
    expect(card.backupOf, '');
    expect(card.name, '池条目');
    expect(card.durationMin, 60);
    expect(await wishes.getItem(wid), isNull, reason: '收口规则 1：删池条目');
    expect(
      spy.events.any(
          (e) => e.$1 == 'wishlist_items' && e.$2 == wid && e.$3 == 'delete'),
      isTrue,
    );
  });

  test('10. 顺延引擎平移备胎（与正式卡同规则）——insertDay 后 backupOf 保留',
      () async {
    await seedCard('m1', 100, start: 420, dur: 60);
    await seedCard('bk', 100);
    await repo.convertToBackup('t1', 'bk');
    final items = await repo.getItems('t1');
    final ops = insertDay(
        startEpochDay: 100,
        endEpochDay: 103,
        items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
        k: 0); // 最前插入：全部卡 +1
    await repo.applyDayOps('t1', ops);
    final bk = (await repo.getItem('bk'))!;
    expect(bk.dateEpochDay, 101, reason: '备胎随平移');
    expect(bk.backupOf, 'm1', reason: 'backupOf 指向关系不变');
    expect((await repo.getItem('m1'))!.dateEpochDay, 101);
  });
}
