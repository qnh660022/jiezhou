// V2.6.6.2 §10.2：三张新云表 payload 必含 created_ms 等 NOT NULL 列；
// `SyncTransportFake.requiredColumns` 缺列即报错（23502 回归范式）。
//
// 背景：`categories_sync` 曾漏传 created_ms → PostgREST 23502 → 该实体整批失败 →
// 8 次后退化成死信，分类同步长期卡死（测试却全绿）。fake 必须与真表同样严格，
// 否则这类 bug 在测试里会静默通过。
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

  SyncPusher newPusher() => SyncPusher(outbox, transport, SyncDbAccessor(db));

  Future<void> seedSpace(String id, {int createdMs = 1000}) =>
      db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
            id: id,
            name: '空间',
            createdBy: 'u1',
            createdMs: createdMs,
            updatedMs: createdMs,
          ));

  Future<void> seedMember(String id, String spaceId) =>
      db.into(db.spaceMembers).insert(SpaceMembersCompanion.insert(
            id: id,
            spaceId: spaceId,
            userId: 'u1',
            role: const Value('owner'),
            displayName: const Value('我'),
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
            createdMs: 1000,
            updatedMs: 1000,
          ));

  group('requiredColumns 登记完整性', () {
    test('三张新云表都登记了 NOT NULL 无默认值列', () {
      for (final t in const [
        'spaces_sync',
        'space_members_sync',
        'space_events_sync',
      ]) {
        expect(SyncTransportFake.requiredColumns.containsKey(t), isTrue,
            reason: '$t 未登记 requiredColumns（漏登记 = 测试全绿但线上 23502）');
        expect(SyncTransportFake.requiredColumns[t], contains('created_ms'),
            reason: '$t 的 created_ms 是 not null 且无默认值');
      }
      // §3.1 逐列核对：spaces 的 name/status/created_by 均 not null 无默认值
      expect(SyncTransportFake.requiredColumns['spaces_sync'],
          containsAll(<String>{'name', 'status', 'created_by', 'created_ms'}));
      expect(
          SyncTransportFake.requiredColumns['space_members_sync'],
          containsAll(<String>{
            'space_id', 'user_id', 'role', 'display_name', 'joined_ms', 'created_ms',
          }));
      expect(
          SyncTransportFake.requiredColumns['space_events_sync'],
          containsAll(<String>{
            'space_id', 'actor_user', 'action', 'entity_kind', 'summary', 'created_ms',
          }));
    });
  });

  group('上行 payload 列完整性', () {
    test('travel_spaces payload 含 created_ms（信封兜底或业务列）', () async {
      await seedSpace('s1', createdMs: 4321);
      await outbox.enqueue('travel_spaces', 's1', 'upsert', 9000);
      final rows =
          await newPusher().assemble(await outbox.selectBatch());
      final json = rows.single.toCloudJson();
      expect(json['created_ms'], 4321, reason: '业务列优先，不被信封兜底覆盖');
      expect(json['updated_ms'], 9000);
      expect(json['deleted'], isFalse);
      expect(json['name'], '空间');
      expect(json['status'], 'active');
      expect(json['created_by'], 'u1');
    });

    test('space_members payload 六列齐全且 created_ms 非空', () async {
      await seedSpace('s1');
      await seedMember('m1', 's1');
      await outbox.enqueue('space_members', 'm1', 'upsert', 9000);
      final json = (await newPusher().assemble(await outbox.selectBatch()))
          .single
          .toCloudJson();
      for (final col in SyncTransportFake.requiredColumns['space_members_sync']!) {
        expect(json[col], isNotNull, reason: '$col 不能为空（线上会 23502）');
      }
      expect(json['space_id'], 's1');
      expect(json['role'], 'owner');
      expect(json['display_name'], '我');
      expect(json['joined_ms'], 1000);
    });

    test('space_events payload：append-only 但仍带 updated_ms/created_ms', () async {
      await seedSpace('s1');
      await seedEvent('e1', 's1');
      await outbox.enqueue('space_events', 'e1', 'upsert', 9000);
      final json = (await newPusher().assemble(await outbox.selectBatch()))
          .single
          .toCloudJson();
      for (final col in SyncTransportFake.requiredColumns['space_events_sync']!) {
        expect(json[col], isNotNull, reason: '$col 不能为空（线上会 23502）');
      }
      // 补列①：事件表也必须有 updated_ms，否则增量游标无法工作
      expect(json['updated_ms'], 9000);
      expect(json['deleted'], isFalse);
      expect(json['action'], 'space_created');
      expect(json['entity_kind'], 'space');
    });

    test('信封兜底：本地无 created_ms 语义时用入队事件时点补齐', () {
      final env = SyncEnvelope(
        entity: SyncEntity.spaces,
        rowId: 's1',
        op: SyncOutboxOp.upsert,
        updatedMs: 7777,
        row: const {'name': 'x', 'status': 'active', 'created_by': 'u1'},
      );
      final json = env.toCloudJson();
      expect(json['created_ms'], 7777, reason: 'SyncEnvelope.putIfAbsent 兜底');
    });
  });

  group('fake 缺列必须报错（不能静默通过）', () {
    test('漏传 created_ms → 抛 23502 风格错误', () async {
      transport.seedRow(
          'spaces_sync', {'id': 's1', 'updated_ms': 1, 'deleted': false});
      await expectLater(
        transport.upsert('spaces_sync', [
          {'id': 's1', 'name': 'x', 'status': 'active', 'created_by': 'u1'},
        ]),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('23502'))),
      );
    });

    test('漏传 space_members 的 joined_ms → 抛 23502 风格错误', () async {
      await expectLater(
        transport.upsert('space_members_sync', [
          {
            'id': 'm1',
            'space_id': 's1',
            'user_id': 'u1',
            'role': 'owner',
            'display_name': '我',
            'created_ms': 1,
            'updated_ms': 1,
            'deleted': false,
          },
        ]),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('23502'))),
      );
    });

    test('墓碑批次不校验缺列（云端行已被物理清理的正常路径）', () async {
      await transport.upsert('spaces_sync', [
        {'id': 's1', 'updated_ms': 1, 'deleted': true},
      ]);
      expect(transport.tables['spaces_sync']?['s1']?['deleted'], isTrue);
    });
  });
}
