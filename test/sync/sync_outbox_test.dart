// L1-P0 同步引擎核心用例（V2.6 §3.16.2 必测清单）：
// outbox 合并 / push 拆批 / 失败重试 / 引导闸 / 开关关。
// 依赖内存 drift（FLUTTER_TEST 自动内存库）+ fake transport，无真实时钟/网络。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_engine.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/data/sync/sync_pusher.dart';
import 'package:travel_assistant/data/sync/sync_transport_fake.dart';
import 'package:travel_assistant/data/sync/db_access.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxService outbox;
  late SyncTransportFake transport;
  late SyncDbAccessor accessor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    outbox = SyncOutboxService(db);
    transport = SyncTransportFake();
    transport.user = 'u1';
    accessor = SyncDbAccessor(db);
  });

  tearDown(() async => db.close());

  Trip tripRow(String id, int updatedAt, {String name = '北京行'}) => Trip(
        id: id,
        name: name,
        destination: '',
        emoji: '✈️',
        cover: 'ocean',
        startEpochDay: 0,
        endEpochDay: 1,
        note: '',
        groupId: null,
        archived: false,
        createdAt: updatedAt - 100,
        updatedAt: updatedAt,
      );

  group('outbox', () {
    test('L1-P0 同 (entity,rowId) 连续变更仅一条，updatedMs 取最新（覆盖合并）', () async {
      await outbox.enqueue('trips', 't1', 'upsert', 1000);
      await outbox.enqueue('trips', 't1', 'upsert', 2000);
      final batch = await outbox.selectBatch();
      expect(batch.length, 1);
      expect(batch.first.updatedMs, 2000);
    });

    test('L1-P0 selectBatch 按 updatedMs 升序', () async {
      await outbox.enqueue('trips', 'a', 'upsert', 3000);
      await outbox.enqueue('trips', 'b', 'upsert', 1000);
      final batch = await outbox.selectBatch();
      expect([batch[0].rowId, batch[1].rowId], ['b', 'a']);
    });
  });

  group('push', () {
    test('L1-P0 60 行 → 两次 upsert（50+10），outbox 清空', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 60; i++) {
        await db.into(db.trips).insert(TripsCompanion.insert(
              id: 't$i',
              name: '行$i',
              createdAt: now,
              updatedAt: now + i,
            ));
        await outbox.enqueue('trips', 't$i', 'upsert', now + i);
      }
      final pusher = SyncPusher(outbox, transport, accessor);
      final r = await pusher.drain();
      expect(r.ok, isTrue);
      expect(transport.upsertCalls, 2); // 50 + 10 两批（单实体每批 ≤50）
      expect(await outbox.pendingCount(), 0);
      expect(transport.tables['trips_sync']!.length, 60);
    });

    test('L1-P0 push 失败 → attemptCount+1 → 重试成功 → outbox 清空', () async {
      final now = 1000;
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            createdAt: now,
            updatedAt: now,
          ));
      await outbox.enqueue('trips', 't1', 'upsert', now);
      transport.nextUpsertError = Exception('网络不可达');
      final pusher = SyncPusher(outbox, transport, accessor);
      final r1 = await pusher.drain();
      expect(r1.ok, isFalse);
      final batch = await outbox.selectBatch();
      expect(batch.first.attemptCount, 1);
      // 重试成功
      final r2 = await pusher.drain();
      expect(r2.ok, isTrue);
      expect(await outbox.pendingCount(), 0);
    });

    test('L1-P0 死信（attemptCount ≥ 8）停止自动重试', () async {
      final now = 1000;
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            createdAt: now,
            updatedAt: now,
          ));
      await outbox.enqueue('trips', 't1', 'upsert', now);
      final pusher = SyncPusher(outbox, transport, accessor);
      for (var i = 0; i < 8; i++) {
        transport.nextUpsertError = Exception('挂'); // 每次 drain 都失败
        await pusher.drain();
      }
      expect(await outbox.deadLetterCount(), 1);
      final callsBefore = transport.upsertCalls;
      final r = await pusher.drain(); // 死信不再发起 upsert
      expect(transport.upsertCalls, callsBefore);
      expect(r.pushed, 0);
      // 一键重置
      final reset = await outbox.resetDeadLetters();
      expect(reset, 1);
    });
  });

  group('assemble 与引导闸', () {
    test('L1-P0 本地行已删 → assemble 产出 delete 信封', () async {
      await outbox.enqueue('trips', 'gone', 'delete', 5000);
      final pusher = SyncPusher(outbox, transport, accessor);
      final envelopes = await pusher.assemble(await outbox.selectBatch());
      expect(envelopes.single.op.name, 'delete');
      envelopes.single.toCloudJson().forEach((k, v) {
        if (k == 'deleted') expect(v, isTrue);
      });
    });

    test('L1-P0 引导闸未置 true → drain 前拦截（bootstrapUploadAll 之外不出网）',
        () async {
      // SyncEngine.init 挂 hook；bootstrap 未完成时 syncNow(push:true) 不上行
      final engine = SyncEngine.init(db, transport,
          (await SharedPreferences.getInstance()));
      await engine.syncNow(); // 手动同步（含 push），但闸门关 → 不 push
      expect(transport.upsertCalls, 0);
      SyncEngine.detach();
    });

    test('L1-P0 开关关：trip 关闭后其行被移出 outbox，不推云', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = 1000;
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            createdAt: now,
            updatedAt: now,
          ));
      await outbox.enqueue('trips', 't1', 'upsert', now);
      prefs.setBool('sync_enabled_trip_t1', false); // 关闸
      final pusher = SyncPusher(outbox, transport, accessor,
          isEntityEnabled: (entity, rowId, row) {
        if (entity == 'trips') return prefs.getBool('sync_enabled_trip_$rowId') ?? true;
        return true;
      });
      final r = await pusher.drain();
      expect(r.pushed, 0);
      expect(await outbox.pendingCount(), 0); // 移出 outbox
      expect(transport.upsertCalls, 0);
      // 重开 → 全量入队（toggle 路径语义由 engine 层测试覆盖，这里验证 enqueueEntityAll）
      final n = await outbox.enqueueEntityAll('trips', now + 10);
      expect(n, 1);
    });
  });
}
