// L1-P0 合流判定 + 增量拉取（V2.6 §3.7 必测清单）：
// 云胜 / 本地胜（防环）/ 相等不动作 / 软删幂等 / 复合游标不重不漏 /
// 金额口径（refund -abs）/ 反身一致性（assemble→merge 幂等）。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/db_access.dart';
import 'package:travel_assistant/data/sync/sync_codec.dart';
import 'package:travel_assistant/data/sync/sync_meta_service.dart';
import 'package:travel_assistant/data/sync/sync_merger.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/data/sync/sync_puller.dart';
import 'package:travel_assistant/data/sync/sync_pusher.dart';
import 'package:travel_assistant/data/sync/sync_transport_fake.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxService outbox;
  late SyncTransportFake transport;
  late SyncMerger merger;
  late SyncPuller puller;
  late SyncMetaService meta;

  setUp(() async {
    db = AppDatabase();
    outbox = SyncOutboxService(db);
    transport = SyncTransportFake();
    merger = SyncMerger(db, outbox)
      ..refreshContext(userId: 'u1', collabGroups: {});
    meta = SyncMetaService(db);
    puller = SyncPuller(db, transport, meta, merger);
  });

  tearDown(() async => db.close());

  Map<String, dynamic> cloudTrip(String id, int updatedMs,
          {bool deleted = false, String name = '云端名'}) =>
      {
        'id': id,
        'name': name,
        'updated_ms': updatedMs,
        'created_ms': updatedMs - 100,
        'deleted': deleted,
      };

  group('mergeRow', () {
    test('L1-P0 云胜：云端 updatedMs 大 → 覆盖本地', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '本地名',
            createdAt: 100,
            updatedAt: 100,
          ));
      await merger.mergeRow(SyncEntity.trips, cloudTrip('t1', 200));
      final row = await (db.select(db.trips)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(row.name, '云端名');
      expect(row.updatedAt, 200);
    });

    test('L1-P0 本地胜：本地大 → 入队上行（计数=1）', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '本地名',
            createdAt: 100,
            updatedAt: 500,
          ));
      await merger.mergeRow(SyncEntity.trips, cloudTrip('t1', 200));
      final row = await (db.select(db.trips)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(row.name, '本地名'); // 本地未被覆盖
      final pending = await outbox.pendingUpdatedMs('trips', 't1');
      expect(pending, isNotNull); // 已排队上行
    });

    test('L1-P0 相等：不动作', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '同名',
            createdAt: 100,
            updatedAt: 200,
          ));
      await merger.mergeRow(SyncEntity.trips, cloudTrip('t1', 200, name: '同名'));
      expect(await outbox.pendingCount(), 0);
    });

    test('L1-P0 软删下行：本地行删除（幂等，重复执行不炸）', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: 'x',
            createdAt: 100,
            updatedAt: 100,
          ));
      await merger.mergeRow(SyncEntity.trips, cloudTrip('t1', 300, deleted: true));
      expect(await db.select(db.trips).get(), isEmpty);
      await merger.mergeRow(SyncEntity.trips, cloudTrip('t1', 300, deleted: true));
      expect(await db.select(db.trips).get(), isEmpty);
    });

    test('L1-P0 金额口径：下行 refund 正数 → 落库 -abs()', () async {
      transport.seedRow('expenses_sync', {
        'id': 'e1',
        'group_id': 'g1',
        'title': '退款',
        'type': 'refund',
        'amount_cents': 5000, // 上行链路若误传正数
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      await puller.pull(SyncEntity.expenses);
      final row = await (db.select(db.expenses)..where((e) => e.id.equals('e1')))
          .getSingle();
      expect(row.amountCents, -5000);
      expect(SyncCodec.normalizeAmountCents(
          SyncCodec.normalizeAmountCents(-5000, 'refund'), 'refund'),
          -5000); // 幂等
    });

    test('L1-P0 反身一致性：上行 assemble → merge(fromCloud) 幂等往返', () async {
      final now = 5000;
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '往返',
            createdAt: now - 10,
            updatedAt: now,
          ));
      await outbox.enqueue('trips', 't1', 'upsert', now);
      // 上行
      final pusher = SyncPusher(outbox, transport, SyncDbAccessor(db));
      await pusher.drain();
      final cloudRow = transport.tables['trips_sync']!['t1']!;
      // 下行（新库视角）→ 应等值合并
      await merger.mergeRow(SyncEntity.trips, cloudRow);
      final row = await (db.select(db.trips)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(row.name, '往返');
      expect(row.updatedAt, now);
      expect(await outbox.pendingCount(), 0); // 无新增 pending（收敛）
    });
  });

  group('复合游标', () {
    test('L1-P0 同 updatedMs 超 limit → 两轮拉取不重不漏', () async {
      for (var i = 0; i < 5; i++) {
        transport.seedRow('trips_sync', {
          'id': 't$i',
          'name': '行$i',
          'updated_ms': 100, // 全部同一毫秒
          'created_ms': 100,
          'deleted': false,
        });
      }
      // limit=2 → 5 行需 3 页
      final pullerSmall = SyncPuller(db, transport, meta, merger, pageLimit: 2);
      final r = await pullerSmall.pull(SyncEntity.trips);
      expect(r.ok, isTrue);
      expect(r.pulled, 5); // 不重不漏
      final rows = await db.select(db.trips).get();
      expect(rows.length, 5);
      expect(await meta.lastPulledMs('trips'), 100);
    });
  });

  group('共享镜像分流', () {
    test('L1-P0 协作团的云端行 → 落 shared_* 表，不进本地业务表', () async {
      merger.refreshContext(userId: 'u1', collabGroups: {'g1'});
      transport.seedRow('groups_sync', {
        'id': 'g1',
        'owner_user_id': 'ownerX',
        'name': '共享团',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      await puller.pull(SyncEntity.groups);
      expect((await db.select(db.sharedGroups).get()).length, 1);
      expect((await db.select(db.groups).get()).length, 0);
      // 退出共享：清镜像
      await merger.clearSharedGroup('g1');
      expect((await db.select(db.sharedGroups).get()).length, 0);
    });
  });
}
