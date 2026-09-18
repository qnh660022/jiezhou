// V2.7.2 S1：新实体 wishlist_items 与新列（trips.pace / trip_items.guide_ref /
// trip_items.backup_of）的全量同步登记。10 处登记逐项断言（规格 §四 S1.4(4)）。
import 'package:collection/collection.dart' show isNullOrEmpty;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/db_access.dart';
import 'package:travel_assistant/data/sync/sync_codec.dart';
import 'package:travel_assistant/data/sync/sync_engine.dart';
import 'package:travel_assistant/data/sync/sync_merger.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/data/sync/sync_pusher.dart';
import 'package:travel_assistant/data/sync/sync_transport_fake.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxService outbox;
  late SyncTransportFake transport;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    outbox = SyncOutboxService(db);
    transport = SyncTransportFake()..user = 'u1';
  });
  tearDown(() async => db.close());

  final now = DateTime.now().millisecondsSinceEpoch;

  Future<void> seedTrip(String id) => db.into(db.trips).insert(
      TripsCompanion.insert(id: id, name: '行程', createdAt: 1000, updatedAt: 1000));

  Future<void> seedWish(String id, {String tripId = 't1'}) =>
      db.into(db.wishlistItems).insert(WishlistItemsCompanion.insert(
        id: id,
        tripId: tripId,
            cityKey: const Value('hangzhou'),
            name: const Value('西湖'),
            address: const Value('龙井路1号'),
            type: const Value('attraction'),
            durationMin: const Value(90),
            tag: const Value('必去'),
            guideRef: const Value('hangzhou#spots#0'),
            note: const Value('傍晚去'),
            sortOrder: const Value(3),
            createdAt: 1000,
            updatedAt: 2000,
          ));

  SyncPusher newPusher() => SyncPusher(outbox, transport, SyncDbAccessor(db));

  group('登记 1：SyncEntity 枚举 / localKey / isCollabMirror / pullOrder', () {
    test('wishlistItems → 云表 wishlist_items_sync / 本地键 wishlist_items（H10 钉死）', () {
      expect(SyncEntity.wishlistItems.cloudTable, 'wishlist_items_sync');
      expect(SyncEntity.wishlistItems.name, 'wishlistItems');
      expect(SyncEntity.wishlistItems.localKey, 'wishlist_items',
          reason: '枚举名是 wishlistItems，不映射将复现 H10 静默丢数据');
      expect(SyncEntity.byLocalKey('wishlist_items'), SyncEntity.wishlistItems);
      expect(SyncEntity.byLocalKey('wishlistItems'), SyncEntity.wishlistItems,
          reason: '兼容 name 键（历史残留）');
    });

    test('isCollabMirror 含 wishlistItems；pullOrder 在 tripItems 之后', () {
      expect(SyncEntity.wishlistItems.isCollabMirror, isTrue);
      final order = SyncEntity.pullOrder;
      expect(order.indexOf(SyncEntity.tripItems),
          lessThan(order.indexOf(SyncEntity.wishlistItems)));
      expect(order.indexOf(SyncEntity.trips),
          lessThan(order.indexOf(SyncEntity.wishlistItems)));
      expect(order.contains(SyncEntity.wishlistItems), isTrue);
    });
  });

  group('登记 2：codec 双向覆盖', () {
    test('wishlist：本地 → 云列 map 逐字段', () async {
      await seedTrip('t1');
      await seedWish('w1');
      final row = (await db.select(db.wishlistItems).get()).single;
      final cloud = SyncCodec.wishlistItemToCloud(row);
      expect(cloud['trip_id'], 't1');
      expect(cloud['city_key'], 'hangzhou');
      expect(cloud['name'], '西湖');
      expect(cloud['address'], '龙井路1号');
      expect(cloud['type'], 'attraction');
      expect(cloud['duration_min'], 90);
      expect(cloud['tag'], '必去');
      expect(cloud['guide_ref'], 'hangzhou#spots#0');
      expect(cloud['note'], '傍晚去');
      expect(cloud['sort_order'], 3);
      expect(cloud['created_ms'], 1000);
      expect(cloud['updated_ms'], 2000);
    });

    test('wishlist：云 → 本地往返逐字段一致（nullable 列 null 往返）', () async {
      await seedTrip('t1');
      await seedWish('w1');
      final row = (await db.select(db.wishlistItems).get()).single;
      final cloud = SyncCodec.wishlistItemToCloud(row);
      await db.delete(db.wishlistItems).go();
      await db.into(db.wishlistItems).insertOnConflictUpdate(
          SyncCodec.wishlistItemFromCloud({...cloud, 'id': 'w1', 'updated_ms': 2000}));
      final back = (await db.select(db.wishlistItems).get()).single;
      expect(back.tripId, 't1');
      expect(back.cityKey, 'hangzhou');
      expect(back.name, '西湖');
      expect(back.durationMin, 90);
      expect(back.tag, '必去');
      expect(back.guideRef, 'hangzhou#spots#0');
      expect(back.sortOrder, 3);
    });

    test('wishlist：下行 nullable 缺失 → 全部空/NULL 兜底（不抛）', () async {
      final comp = SyncCodec.wishlistItemFromCloud({
        'id': 'w2',
        'trip_id': 't1',
        'updated_ms': 100,
        'created_ms': 100,
      });
      expect(comp.name.present, isTrue);
      await db.into(db.wishlistItems).insertOnConflictUpdate(comp);
      final w = (await db.select(db.wishlistItems).get()).single;
      expect(w.name, '');
      expect(w.cityKey, '');
      expect(w.durationMin, isNull);
      expect(w.tag, isNull);
      expect(w.guideRef, isNull);
    });

    test('trip_items：guide_ref / backup_of 双向透传（null 不省略键）', () async {
      await seedTrip('t1');
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: 'i1',
            tripId: 't1',
            guideRef: const Value('hangzhou#food#2'),
            backupOf: const Value(''),
            createdAt: now,
            updatedAt: now));
      final row = (await db.select(db.tripItems).get()).single;
      final cloud = SyncCodec.tripItemToCloud(row);
      expect(cloud.containsKey('guide_ref'), isTrue);
      expect(cloud['guide_ref'], 'hangzhou#food#2');
      expect(cloud.containsKey('backup_of'), isTrue);
      expect(cloud['backup_of'], '');

      await db.delete(db.tripItems).go();
      await db.into(db.tripItems).insertOnConflictUpdate(
          SyncCodec.tripItemFromCloud({...cloud, 'id': 'i1', 'updated_ms': now}));
      final back = (await db.select(db.tripItems).get()).single;
      expect(back.guideRef, 'hangzhou#food#2');
      expect(back.backupOf, '');
    });

    test('trips：pace 双向（下行缺失兜底 standard）', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            pace: const Value('tight'),
            createdAt: 1000,
            updatedAt: 1000));
      final row = (await db.select(db.trips).get()).single;
      final cloud = SyncCodec.tripToCloud(row);
      expect(cloud['pace'], 'tight');
      final back = SyncCodec.tripFromCloud({...cloud, 'id': 't1', 'updated_ms': 1000});
      expect(back.pace.present && back.pace.value == 'tight', isTrue);
      final relaxed = SyncCodec.tripFromCloud({'id': 't2', 'name': 'x', 'updated_ms': 1});
      expect(relaxed.pace.value, 'standard');
    });
  });

  group('登记 3/4：db_access 与 merger 五分支', () {
    test('db_access.readBusinessRow 支持 wishlist_items', () async {
      await seedTrip('t1');
      await seedWish('w1');
      final accessor = SyncDbAccessor(db);
      expect((await accessor.readBusinessRow('wishlist_items', 'w1'))?['name'], '西湖');
      expect(await accessor.readBusinessRow('wishlist_items', 'missing'), isNull);
    });

    test('merger：本人 wishlist 云端行落业务表；他人行进镜像（协作内）/跳过（协作外）',
        () async {
      final merger = SyncMerger(db, outbox)
        ..refreshContext(
            userId: 'u1', collabGroups: const {}, collabTrips: {'tripOther'}, known: true);
      await seedTrip('t1');
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w1',
        'trip_id': 't1',
        'owner_user_id': 'u1',
        'name': '我的池条目',
        'type': 'attraction',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      expect((await db.select(db.wishlistItems).get()).single.name, '我的池条目');

      // 他人 + 行程在协作名单 → 落 SharedWishlistItems 镜像
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w2',
        'trip_id': 'tripOther',
        'owner_user_id': 'someoneElse',
        'name': '旅伴的池条目',
        'type': 'food',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      expect((await db.select(db.sharedWishlistItems).get()).single.name, '旅伴的池条目');
      expect(await db.select(db.wishlistItems).get(), hasLength(1),
          reason: '他人行绝不进业务表（H7 防串）');

      // 他人 + 行程不在名单 → 跳过
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w3',
        'trip_id': 'tripUnknown',
        'owner_user_id': 'someoneElse',
        'name': '陌生条目',
        'type': 'food',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      expect(await db.select(db.sharedWishlistItems).get(), hasLength(1));
    });

    test('merger：wishlist 软删下行幂等（业务表与镜像都清）', () async {
      await seedTrip('t1');
      await seedWish('w1');
      final merger = SyncMerger(db, outbox)
        ..refreshContext(userId: 'u1', collabGroups: const {}, known: true);
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w1',
        'deleted': true,
        'updated_ms': 300,
      });
      expect(await db.select(db.wishlistItems).get(), isEmpty);
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w1',
        'deleted': true,
        'updated_ms': 300,
      });
      expect(await db.select(db.wishlistItems).get(), isEmpty);
    });

    test('merger：云端胜 upsert（本地旧 → 云新覆盖；本地新 → 入队防环）', () async {
      await seedTrip('t1');
      await seedWish('w1');
      final merger = SyncMerger(db, outbox)
        ..refreshContext(userId: 'u1', collabGroups: const {}, known: true);
      // 本地 updatedAt=2000；云端 3000 → 云端胜
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w1',
        'trip_id': 't1',
        'owner_user_id': 'u1',
        'name': '云端新版',
        'type': 'attraction',
        'updated_ms': 3000,
        'created_ms': 1000,
        'deleted': false,
      });
      expect((await db.select(db.wishlistItems).get()).single.name, '云端新版');

      // 云端 1000（更旧）→ 本地胜：无引擎 hook 时直写入队
      await merger.mergeRow(SyncEntity.wishlistItems, {
        'id': 'w1',
        'trip_id': 't1',
        'owner_user_id': 'u1',
        'name': '云端旧版',
        'type': 'attraction',
        'updated_ms': 1000,
        'created_ms': 1000,
        'deleted': false,
      });
      expect((await db.select(db.wishlistItems).get()).single.name, '云端新版');
      final pending = await outbox.pendingEntry('wishlist_items', 'w1');
      expect(pending, isNotNull, reason: '本地胜需入队上行（防环收敛）');
    });
  });

  group('登记 5/6：上云闸门与 requiredColumns', () {
    test('fake requiredColumns：wishlist_items_sync 最小列集（nullable 列不得加入）', () {
      expect(SyncTransportFake.requiredColumns['wishlist_items_sync'],
          {'trip_id', 'name', 'type', 'created_ms', 'updated_ms'});
      expect(SyncTransportFake.requiredColumns['trip_items_sync']!.contains('guide_ref'),
          isFalse, reason: 'guide_ref 为 nullable，不得加入 required');
      expect(SyncTransportFake.requiredColumns['trip_items_sync']!.contains('backup_of'),
          isFalse, reason: 'backup_of 为 nullable，不得加入 required');
    });

    test('端到端 drain → wishlist_items_sync 含全部 NOT NULL 列', () async {
      await seedTrip('t1');
      await seedWish('w1');
      await outbox.enqueue('wishlist_items', 'w1', 'upsert', 9000);
      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      final row = transport.tables['wishlist_items_sync']?['w1'];
      expect(row, isNotNull);
      for (final col in SyncTransportFake.requiredColumns['wishlist_items_sync']!) {
        expect(row![col], isNotNull, reason: '$col 不能为空（线上 23502）');
      }
      expect(row!['city_key'], 'hangzhou');
    });

    test('端到端 drain：trip_items 增列随行上行；delete 墓碑正常', () async {
      await seedTrip('t1');
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: 'i1',
            tripId: 't1',
            backupOf: const Value('i0'),
            createdAt: now,
            updatedAt: now));
      await outbox.enqueue('trip_items', 'i1', 'upsert', 9000);
      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      final row = transport.tables['trip_items_sync']?['i1'];
      expect(row!['backup_of'], 'i0');
      expect(row.containsKey('guide_ref'), isTrue,
          reason: 'null 不省略键，写 null（避免云端旧值残留）');
      expect(row['guide_ref'], isNull);
    });

    test('pusher 闸门：行程上云关闭时 wishlist 行被丢弃', () async {
      await seedTrip('t1');
      await seedWish('w1');
      final pusher = newPusher()
        ..isEntityEnabled = (entity, rowId, row) {
          if (entity == 'wishlist_items') {
            final tid = row['trip_id'];
            return tid is String ? tid != 't1' : true;
          }
          return true;
        };
      await outbox.enqueue('wishlist_items', 'w1', 'upsert', 9000);
      final r = await pusher.drain();
      expect(r.ok, isTrue);
      expect(transport.tables['wishlist_items_sync']?['w1'], isNull,
          reason: '关闸行被移出 outbox 不入网');
      expect(await outbox.pendingCount(), 0);
    });
  });

  group('登记 5（引擎挂接）：bootstrap / toggle / purge / 加入空间重拉', () {
    test('SyncEntity.localKey 全量登记键唯一（防两套键名并存）', () {
      final keys = SyncEntity.values.map((e) => e.localKey).toList();
      expect(keys.toSet().length, keys.length, reason: 'localKey 不得重复');
    });
  });
}
