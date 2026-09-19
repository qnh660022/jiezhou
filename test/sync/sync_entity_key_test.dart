// 回归用例：同步实体键一致性 + 上行装配健壮性。
//
// 背景（bug H10）：`SyncEntity.tripItems.name` 是 Dart 枚举名 `tripItems`，
// 而全仓库（仓储写路径 `notifyWrite` / db_access / 引擎上云闸门 / 同步中心计数）
// 用的本地键是 `trip_items`。上行装配曾按 `name` 匹配 → `trip_items` 被判为
// 未知实体、静默从 outbox 删除 → **行程安排永远上不了云**，且没有任何报错。
// 同类风险见 H9（装配丢弃行导致索引错配）、L2（墓碑命中 23502 白变死信）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/db_access.dart';
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

  Future<void> seedTrip(String id) =>
      db.into(db.trips).insert(TripsCompanion(
            id: Value(id),
            name: const Value('行程'),
            destination: const Value(''),
            emoji: const Value('✈️'),
            cover: const Value('ocean'),
            startEpochDay: const Value(0),
            endEpochDay: const Value(1),
            note: const Value(''),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ));

  Future<void> seedItem(String id, String tripId) =>
      db.into(db.tripItems).insert(TripItemsCompanion(
            id: Value(id),
            tripId: Value(tripId),
            dateEpochDay: const Value(0),
            type: const Value('attraction'),
            name: const Value('安排'),
            address: const Value(''),
            note: const Value(''),
            costCurrency: const Value('CNY'),
            fromName: const Value(''),
            fromAddress: const Value(''),
            toName: const Value(''),
            toAddress: const Value(''),
            sortOrder: const Value(0),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ));

  SyncPusher newPusher() => SyncPusher(outbox, transport, SyncDbAccessor(db));

  group('实体键一致性', () {
    test('localKey 与 name 的差异被显式建模：tripItems → trip_items', () {
      expect(SyncEntity.tripItems.name, 'tripItems');
      expect(SyncEntity.tripItems.localKey, 'trip_items');
      // V2.6.6.2 起，"枚举名 ≠ 本地表名" 的实体不止 tripItems：
      // 空间三实体的本地表名均带前缀/复数形态，见 space_entity_key_test.dart。
      const renamed = {
        SyncEntity.tripItems,
        SyncEntity.spaces,
        SyncEntity.spaceMembers,
        SyncEntity.spaceEvents,
        // V2.7.1：inboxItems 的枚举名是 `inboxItems`，本地键固定 `inbox_items`
        SyncEntity.inboxItems,
        // V2.7.2：wishlistItems → wishlist_items
        SyncEntity.wishlistItems,
        // V2.8.1：subBudgets → sub_budgets（同 H10 防线，见 sync_models localKey）
        SyncEntity.subBudgets,
      };
      for (final e in SyncEntity.values) {
        if (renamed.contains(e)) continue;
        expect(e.localKey, e.name, reason: '${e.name} 的 localKey 应等于 name');
      }
      expect(SyncEntity.byLocalKey('trip_items'), SyncEntity.tripItems);
      expect(SyncEntity.byLocalKey('tripItems'), SyncEntity.tripItems,
          reason: '兼容修复前遗留的旧键行');
      expect(SyncEntity.byLocalKey('nope'), isNull);
    });

    test('H10 回归：trip_items 入队后必须装配成 tripItems 信封（不被当脏数据丢弃）', () async {
      await seedTrip('t1');
      await seedItem('i1', 't1');
      await outbox.enqueue('trip_items', 'i1', 'upsert', 5000);

      final pairs = await newPusher().assembleEntries(await outbox.selectBatch());
      expect(pairs, hasLength(1));
      expect(pairs.first.$2.entity, SyncEntity.tripItems);
      expect(await outbox.pendingCount(), 1, reason: '不应被静默清理');
    });

    test('H10 端到端：drain 必须把 trip_items 送上 trip_items_sync', () async {
      await seedTrip('t1');
      await seedItem('i1', 't1');
      await outbox.enqueue('trip_items', 'i1', 'upsert', 5000);

      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      expect(transport.tables['trip_items_sync']?['i1']?['trip_id'], 't1');
      expect(await outbox.pendingCount(), 0);
    });

    test('键归一：历史 tripItems 行搬迁到 trip_items，取事件更新的一条', () async {
      await seedTrip('t1');
      await seedItem('i1', 't1');
      // 模拟修复前合流层写入的旧键行（事件更晚）
      await db.into(db.syncOutbox).insert(SyncOutboxCompanion.insert(
            entity: 'tripItems',
            rowId: 'i1',
            op: 'upsert',
            updatedMs: 9000,
          ));
      await outbox.enqueue('trip_items', 'i1', 'upsert', 7000);

      final moved = await outbox.normalizeEntityKeys();
      expect(moved, 1);
      final rows = await db.select(db.syncOutbox).get();
      expect(rows, hasLength(1));
      expect(rows.first.entity, 'trip_items');
      expect(rows.first.updatedMs, 9000);
      // 搬迁后仍能正常上行
      final pairs = await newPusher().assembleEntries(await outbox.selectBatch());
      expect(pairs.single.$2.entity, SyncEntity.tripItems);
    });
  });

  group('上行装配健壮性', () {
    test('H9 回归：批次含「本地已删且云端不存在」的行时不错配、drain 不抛', () async {
      await seedTrip('t1');
      await outbox.enqueue('trips', 't1', 'upsert', 1000);
      await outbox.enqueue('trips', 'ghost', 'delete', 2000); // 两端都没有 → 丢弃

      final pairs = await newPusher().assembleEntries(await outbox.selectBatch());
      expect(pairs, hasLength(1));
      expect(pairs.first.$1.rowId, 't1');
      expect(await outbox.pendingCount(), 1);

      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      expect(transport.tables['trips_sync']?['t1'], isNotNull);
    });

    test('L2 回归：全墓碑批次命中 23502 → 按成功丢弃，不退化成死信', () async {
      // 远端确实有该行，墓碑才有上行意义（否则 assemble 直接丢弃）
      transport.seedRow(
          'trips_sync', {'id': 't1', 'updated_ms': 10, 'deleted': false});
      await outbox.enqueue('trips', 't1', 'delete', 3000);
      transport.nextUpsertError = Exception(
          'PostgrestException(23502): null value in column "created_ms" of '
          'relation "trips_sync" violates not-null constraint');

      final r = await newPusher().drain();
      expect(r.ok, isTrue, reason: '远端行已被物理清理，墓碑无处可落不算失败');
      expect(await outbox.pendingCount(), 0);
    });

    test('非墓碑批次命中 23502 仍算失败并累计 attemptCount（不能静默当成功）', () async {
      await seedTrip('t1');
      await outbox.enqueue('trips', 't1', 'upsert', 1000);
      transport.nextUpsertError = Exception(
          'PostgrestException(23502): null value in column "created_ms" of '
          'relation "trips_sync" violates not-null constraint');

      final r = await newPusher().drain();
      expect(r.ok, isFalse);
      final rows = await db.select(db.syncOutbox).get();
      expect(rows.single.attemptCount, 1);
    });
  });
}
