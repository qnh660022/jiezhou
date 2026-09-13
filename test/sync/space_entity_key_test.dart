// V2.6.6.2 §10.1：新增 SyncEntity 的 localKey snake_case 断言（H10 回归范式）。
//
// 背景（bug H10）：`SyncEntity.tripItems.name` 是 `tripItems`，而全仓库用的本地键
// 是 `trip_items`；上行装配按 name 匹配 → 行被判为脏数据静默清理 → 永不上云。
// V2.6.6.2 新增的三个空间实体同样存在「枚举名 ≠ 本地表名」：
//   spaces       → travel_spaces
//   spaceMembers → space_members
//   spaceEvents  → space_events
// 本用例把映射钉死，任何一处改动漏改都会红。
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

  Future<void> seedSpace(String id) => db.into(db.travelSpaces).insert(
        TravelSpacesCompanion.insert(
          id: id,
          name: '京都行',
          createdBy: 'u1',
          createdMs: 1000,
          updatedMs: 1000,
        ),
      );

  Future<void> seedMember(String id, String spaceId) =>
      db.into(db.spaceMembers).insert(SpaceMembersCompanion.insert(
            id: id,
            spaceId: spaceId,
            userId: 'u1',
            role: const Value('owner'),
            joinedMs: 1000,
            createdMs: 1000,
            updatedMs: 1000,
          ));

  Future<void> seedEvent(String id, String spaceId) =>
      db.into(db.spaceEvents).insert(SpaceEventsCompanion.insert(
            id: id,
            spaceId: spaceId,
            actorUser: 'u1',
            action: 'space_created',
            entityKind: 'space',
            summary: const Value('建了空间'),
            createdMs: 1000,
            updatedMs: 1000,
          ));

  SyncPusher newPusher() => SyncPusher(outbox, transport, SyncDbAccessor(db));

  group('空间实体键一致性（H10 回归）', () {
    test('localKey 显式映射到本地表名，且全部 snake_case', () {
      expect(SyncEntity.spaces.name, 'spaces');
      expect(SyncEntity.spaces.localKey, 'travel_spaces');
      expect(SyncEntity.spaceMembers.name, 'spaceMembers');
      expect(SyncEntity.spaceMembers.localKey, 'space_members');
      expect(SyncEntity.spaceEvents.name, 'spaceEvents');
      expect(SyncEntity.spaceEvents.localKey, 'space_events');

      // 全枚举 localKey 一律 snake_case（无大写字母）
      for (final e in SyncEntity.values) {
        expect(e.localKey, matches(RegExp(r'^[a-z][a-z0-9_]*$')),
            reason: '${e.name} 的 localKey 必须是 snake_case');
        expect(SyncEntity.byLocalKey(e.localKey), e);
      }
    });

    test('byLocalKey 兼容枚举名（历史脏键行仍可识别）', () {
      expect(SyncEntity.byLocalKey('travel_spaces'), SyncEntity.spaces);
      expect(SyncEntity.byLocalKey('spaces'), SyncEntity.spaces);
      expect(SyncEntity.byLocalKey('space_members'), SyncEntity.spaceMembers);
      expect(SyncEntity.byLocalKey('space_events'), SyncEntity.spaceEvents);
      expect(SyncEntity.byLocalKey('nope'), isNull);
    });

    test('云表名与规格书 §3.1 一致', () {
      expect(SyncEntity.spaces.cloudTable, 'spaces_sync');
      expect(SyncEntity.spaceMembers.cloudTable, 'space_members_sync');
      expect(SyncEntity.spaceEvents.cloudTable, 'space_events_sync');
    });

    test('拉取顺序：空间域在账本域/行程域之前（父实体先行）', () {
      final order = SyncEntity.pullOrder;
      expect(order.indexOf(SyncEntity.spaces),
          lessThan(order.indexOf(SyncEntity.spaceMembers)));
      expect(order.indexOf(SyncEntity.spaceMembers),
          lessThan(order.indexOf(SyncEntity.spaceEvents)));
      expect(order.indexOf(SyncEntity.spaceEvents),
          lessThan(order.indexOf(SyncEntity.groups)));
      expect(order.indexOf(SyncEntity.groups),
          lessThan(order.indexOf(SyncEntity.members)));
      expect(order.indexOf(SyncEntity.spaces),
          lessThan(order.indexOf(SyncEntity.trips)));
      expect(order.indexOf(SyncEntity.trips),
          lessThan(order.indexOf(SyncEntity.tripItems)));
    });
  });

  group('空间实体上行装配（端到端）', () {
    test('travel_spaces 入队后装配成 spaces 信封，并送上 spaces_sync', () async {
      await seedSpace('s1');
      await outbox.enqueue('travel_spaces', 's1', 'upsert', 5000);

      final pairs = await newPusher().assembleEntries(await outbox.selectBatch());
      expect(pairs, hasLength(1));
      expect(pairs.first.$2.entity, SyncEntity.spaces);

      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      final row = transport.tables['spaces_sync']?['s1'];
      expect(row, isNotNull);
      expect(row!['name'], '京都行');
      expect(row['created_by'], 'u1');
      expect(row['status'], 'active');
      expect(row['created_ms'], 1000);
    });

    test('space_members / space_events 各自走上对应云表', () async {
      await seedSpace('s1');
      await seedMember('m1', 's1');
      await seedEvent('e1', 's1');
      await outbox.enqueue('space_members', 'm1', 'upsert', 5000);
      await outbox.enqueue('space_events', 'e1', 'upsert', 5000);

      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      expect(transport.tables['space_members_sync']?['m1']?['space_id'], 's1');
      expect(transport.tables['space_events_sync']?['e1']?['action'], 'space_created');
    });
  });
}
