// V2.7.2 S1 登记 8：备份信封扩展往返。
// - 行程备份（.tat 结构）携带 wishlist 行集，version 1→2；
// - 旧包（version 1，无 wishlist 节点）恢复 → 池为空、行程/卡片完好、不报错；
// - applyTripImport 对 wishlist 做 id 重映射（tripId 指向新行程）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/domain/trip_backup.dart';

void main() {
  Map<String, dynamic> sampleWish(String id, {String tripId = 't0'}) => {
        'id': id,
        'tripId': tripId,
        'cityKey': 'hangzhou',
        'name': '西湖',
        'address': '龙井路1号',
        'type': 'attraction',
        'durationMin': 90,
        'tag': '必去',
        'guideRef': 'hangzhou#spots#0',
        'note': '',
        'sortOrder': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      };

  Map<String, dynamic> sampleTripRoot({List<Map<String, dynamic>>? wishlist}) => {
        'app': kTripBackupApp,
        'version': kTripBackupVersion,
        'trip': {
          'id': 't0',
          'name': '杭州三日',
          'destination': '杭州',
          'emoji': '✈️',
          'cover': 'ocean',
          'startEpochDay': 100,
          'endEpochDay': 102,
          'note': '',
          'groupId': 'g0',
          'archived': false,
          'createdAt': 1000,
          'updatedAt': 1000,
        },
        'items': [
          {
            'id': 'i0',
            'tripId': 't0',
            'dateEpochDay': 100,
            'type': 'attraction',
            'name': '断桥',
            'address': '',
            'note': '',
            'sortOrder': 10,
            'createdAt': 1000,
            'updatedAt': 1000,
          }
        ],
        'photos': <Map<String, dynamic>>[],
        'checklist': <Map<String, dynamic>>[],
        if (wishlist != null) 'wishlist': wishlist,
      };

  test('v2 备份：wishlist 行集写入且 round-trip 逐字段一致', () {
    final root = buildTripBackup(
      trip: (sampleTripRoot()['trip'] as Map<String, dynamic>),
      items: const [],
      photos: const [],
      checklist: const [],
      wishlist: [sampleWish('w1')],
    );
    expect(root['version'], kTripBackupVersion);
    expect(root['version'], 2);
    expect(root['wishlist'], hasLength(1));

    final parsed = parseTripBackupMap(root);
    expect(parsed.wishlist, hasLength(1));
    expect(parsed.wishlist.first['name'], '西湖');
    expect(parsed.wishlist.first['durationMin'], 90);
    expect(parsed.wishlist.first['guideRef'], 'hangzhou#spots#0');
  });

  test('导入重映射：wishlist 换发新 id、tripId 指向新行程', () {
    final backup = parseTripBackupMap(
        sampleTripRoot(wishlist: [sampleWish('w1'), sampleWish('w2')]));
    var n = 0;
    final result = applyTripImport(backup,
        gen: (prefix) => '${prefix}_new_${n++}');
    expect(result.wishlist, hasLength(2));
    final newTripId = result.trip['id'] as String;
    expect(result.wishlist.every((w) => w['tripId'] == newTripId), isTrue,
        reason: 'tripId 全部指向换发后的新行程');
    final ids = result.wishlist.map((w) => w['id']).toSet();
    expect(ids.contains('w1'), isFalse, reason: 'id 已换发');
    expect(ids.length, 2, reason: '两条各自换发');
    expect(ids.every((id) => (id as String).startsWith('wish_new_')), isTrue);
    expect(result.stats.wishlist, 2);
  });

  test('旧包兼容：version 1（无 wishlist 节点）解析成功、池为空、行程/卡片完好', () {
    final legacyRoot = sampleTripRoot()..['version'] = 1;
    final parsed = parseTripBackupMap(legacyRoot);
    expect(parsed.version, 1);
    expect(parsed.wishlist, isEmpty, reason: '旧包池为空，不报错');
    expect(parsed.trip['name'], '杭州三日');
    expect(parsed.items, hasLength(1), reason: '行程/卡片完好');
    final result = applyTripImport(parsed, gen: (p) => '${p}_n');
    expect(result.wishlist, isEmpty);
    expect(result.items, hasLength(1));
  });

  test('repository 级 .tat 导出导入：wishlist 随包往返（内存库）', () async {
    final db = AppDatabase();
    final repo = TripsRepository(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't0', name: '杭州三日', createdAt: now, updatedAt: now));
    await db.into(db.wishlistItems).insert(WishlistItemsCompanion.insert(
          id: 'w0',
          tripId: 't0',
          name: const Value('西湖'),
          durationMin: const Value(90),
          createdAt: now,
          updatedAt: now,
        ));
    final bytes = await repo.exportTripBackupBytes('t0');
    // 导入为独立副本（id 换发）
    final report = await repo.importTripBackupBytes(bytes);
    expect(report.trip, '杭州三日');
    final imported = (await db.select(db.trips).get())
        .where((t) => t.id != 't0')
        .toList();
    expect(imported, hasLength(1));
    final newTripId = imported.single.id;
    final wishes = await (db.select(db.wishlistItems)
          ..where((w) => w.tripId.equals(newTripId)))
        .get();
    expect(wishes, hasLength(1), reason: '想去池随 .tat 往返');
    expect(wishes.single.name, '西湖');
    expect(wishes.single.id, isNot('w0'), reason: '副本换发新 id');
    await db.close();
  });
}
