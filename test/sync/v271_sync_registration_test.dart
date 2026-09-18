// V2.7.1 S1：新增实体（funds / inbox_items）与新增列（kind / archived /
// fund_id / pay_method / strategy）的全量同步登记。9 处登记逐项断言。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/db_access.dart';
import 'package:travel_assistant/data/sync/sync_codec.dart';
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

  Future<void> seedGroup(String id) => db.into(db.groups).insert(
      GroupsCompanion.insert(id: id, name: '团', createdAt: 1000, updatedAt: 1000));

  Future<void> seedFund(String id) => db.into(db.funds).insert(FundsCompanion.insert(
        id: id,
        groupId: 'g1',
        name: '旅行基金',
        managerMemberId: 'm1',
        targetCents: const Value(400000),
        createdAt: 1000,
        updatedAt: 1000,
      ));

  Future<void> seedInbox(String id) => db.into(db.inboxItems).insert(
      InboxItemsCompanion.insert(
        id: id,
        groupId: 'g1',
        amountCents: const Value(2500),
        note: const Value('打车'),
        capturedAt: 1000,
        createdAt: 1000,
        updatedAt: 1000,
      ));

  SyncPusher newPusher() => SyncPusher(outbox, transport, SyncDbAccessor(db));

  group('登记 1/2：SyncEntity 枚举与 localKey 显式映射', () {
    test('funds → 云表 funds_sync / 本地键 funds（显式写出）', () {
      expect(SyncEntity.funds.cloudTable, 'funds_sync');
      expect(SyncEntity.funds.localKey, 'funds');
    });

    test('inboxItems → 云表 inbox_items_sync / 本地键 inbox_items（H10 同款风险钉死）', () {
      expect(SyncEntity.inboxItems.cloudTable, 'inbox_items_sync');
      expect(SyncEntity.inboxItems.name, 'inboxItems');
      expect(SyncEntity.inboxItems.localKey, 'inbox_items',
          reason: '不映射会复现 H10：上行装配按 name 匹配失败 → 静默丢数据');
      expect(SyncEntity.byLocalKey('inbox_items'), SyncEntity.inboxItems);
      expect(SyncEntity.byLocalKey('funds'), SyncEntity.funds);
    });
  });

  group('登记 3：pullOrder 父实体先行', () {
    test('groups → members → funds → inboxItems → expenses', () {
      final order = SyncEntity.pullOrder;
      int idx(SyncEntity e) => order.indexOf(e);
      expect(idx(SyncEntity.groups), lessThan(idx(SyncEntity.funds)));
      expect(idx(SyncEntity.members), lessThan(idx(SyncEntity.funds)));
      expect(idx(SyncEntity.funds), lessThan(idx(SyncEntity.expenses)));
      expect(idx(SyncEntity.inboxItems), lessThan(idx(SyncEntity.expenses)));
    });
  });

  group('登记 4：codec 双向覆盖', () {
    test('groupToCloud 增 kind；memberToCloud 增 archived', () async {
      await seedGroup('g1');
      await db.into(db.members).insert(MembersCompanion.insert(
          id: 'm1',
          groupId: 'g1',
          name: '甲',
          archived: const Value(true),
          createdAt: 1000));
      final g = (await db.select(db.groups).get()).single;
      final m = (await db.select(db.members).get()).single;
      expect(SyncCodec.groupToCloud(g)['kind'], 'travel');
      expect(SyncCodec.memberToCloud(m)['archived'], isTrue);
    });

    test('expenseToCloud 增 fund_id / pay_method；settlementToCloud 增 strategy', () async {
      await seedGroup('g1');
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: 'e1',
            groupId: 'g1',
            fundId: const Value('f1'),
            payMethod: const Value('ewallet'),
            createdAt: 1000));
      await db.into(db.settlements).insert(SettlementsCompanion.insert(
            id: 's1',
            groupId: 'g1',
            strategy: const Value('minParticipants'),
            createdAt: 1000));
      final e = (await db.select(db.expenses).get()).single;
      final s = (await db.select(db.settlements).get()).single;
      expect(SyncCodec.expenseToCloud(e)['fund_id'], 'f1');
      expect(SyncCodec.expenseToCloud(e)['pay_method'], 'ewallet');
      expect(SyncCodec.settlementToCloud(s)['strategy'], 'minParticipants');
    });

    test('fund：本地 → 云 → 本地 往返逐字段一致', () async {
      await seedGroup('g1');
      await seedFund('f1');
      final row = (await db.select(db.funds).get()).single;
      final cloud = SyncCodec.fundToCloud(row);
      expect(cloud['group_id'], 'g1');
      expect(cloud['manager_member_id'], 'm1');
      expect(cloud['target_cents'], 400000);
      expect(cloud['status'], 'open');
      expect(cloud['created_ms'], 1000);
      expect(cloud['updated_ms'], 1000);

      await db.delete(db.funds).go();
      await db.into(db.funds).insertOnConflictUpdate(
          SyncCodec.fundFromCloud({...cloud, 'id': 'f1', 'updated_ms': 1000}));
      final back = (await db.select(db.funds).get()).single;
      expect(back.name, row.name);
      expect(back.managerMemberId, row.managerMemberId);
      expect(back.targetCents, row.targetCents);
      expect(back.status, row.status);
    });

    test('inbox_item：本地 → 云 → 本地 往返逐字段一致', () async {
      await seedGroup('g1');
      await seedInbox('i1');
      final row = (await db.select(db.inboxItems).get()).single;
      final cloud = SyncCodec.inboxItemToCloud(row);
      expect(cloud['amount_cents'], 2500);
      expect(cloud['captured_ms'], 1000);
      expect(cloud['source'], 'manual');
      expect(cloud['status'], 'pending');
      expect(cloud['converted_expense_id'], isNull);

      await db.delete(db.inboxItems).go();
      await db.into(db.inboxItems).insertOnConflictUpdate(
          SyncCodec.inboxItemFromCloud({...cloud, 'id': 'i1', 'updated_ms': 1000}));
      final back = (await db.select(db.inboxItems).get()).single;
      expect(back.amountCents, 2500);
      expect(back.note, '打车');
      expect(back.status, 'pending');
    });
  });

  group('登记 5/6：db_access 与 merger 分支', () {
    test('db_access.readBusinessRow 支持 funds / inbox_items', () async {
      await seedGroup('g1');
      await seedFund('f1');
      await seedInbox('i1');
      final accessor = SyncDbAccessor(db);
      expect((await accessor.readBusinessRow('funds', 'f1'))?['name'], '旅行基金');
      expect((await accessor.readBusinessRow('inbox_items', 'i1'))?['amount_cents'], 2500);
    });

    test('merger：本人 funds 云端行落业务表；他人行跳过（无协作镜像表）', () async {
      final merger = SyncMerger(db, outbox)
        ..refreshContext(userId: 'u1', collabGroups: {'g1'}, known: true);
      await merger.mergeRow(SyncEntity.funds, {
        'id': 'f1',
        'group_id': 'g1',
        'owner_user_id': 'u1',
        'name': '我的池',
        'manager_member_id': 'm1',
        'status': 'open',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      expect((await db.select(db.funds).get()).single.name, '我的池');

      await merger.mergeRow(SyncEntity.funds, {
        'id': 'f2',
        'group_id': 'g1',
        'owner_user_id': 'someoneElse',
        'name': '别人的池',
        'manager_member_id': 'm9',
        'status': 'open',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });
      expect(await db.select(db.funds).get(), hasLength(1),
          reason: '他人行不落本地业务表（无镜像表，防 H7 串数据）');
    });

    test('merger：inbox_items 软删下行幂等', () async {
      final merger = SyncMerger(db, outbox)
        ..refreshContext(userId: 'u1', collabGroups: const {});
      await db.into(db.groups).insert(
          GroupsCompanion.insert(id: 'g1', name: '团', createdAt: 1, updatedAt: 1));
      await seedInbox('i1');
      await merger.mergeRow(SyncEntity.inboxItems, {
        'id': 'i1',
        'deleted': true,
        'updated_ms': 300,
      });
      expect(await db.select(db.inboxItems).get(), isEmpty);
      await merger.mergeRow(SyncEntity.inboxItems, {
        'id': 'i1',
        'deleted': true,
        'updated_ms': 300,
      });
      expect(await db.select(db.inboxItems).get(), isEmpty);
    });
  });

  group('登记 8：SyncTransportFake.requiredColumns', () {
    test('funds_sync / inbox_items_sync 已登记且列齐全', () {
      expect(SyncTransportFake.requiredColumns['funds_sync'],
          containsAll(<String>{'group_id', 'name', 'manager_member_id', 'created_ms', 'updated_ms'}));
      expect(
          SyncTransportFake.requiredColumns['inbox_items_sync'],
          containsAll(<String>{
            'group_id', 'amount_cents', 'captured_ms', 'source', 'status',
            'created_ms', 'updated_ms',
          }));
    });
  });

  group('登记 7：pusher 闸门 + 端到端上行', () {
    test('fund 端到端 drain → funds_sync 含全部 NOT NULL 列', () async {
      await seedGroup('g1');
      await seedFund('f1');
      await outbox.enqueue('funds', 'f1', 'upsert', 9000);
      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      final row = transport.tables['funds_sync']?['f1'];
      expect(row, isNotNull);
      for (final col in SyncTransportFake.requiredColumns['funds_sync']!) {
        expect(row![col], isNotNull, reason: '$col 不能为空（线上 23502）');
      }
      expect(row!['group_id'], 'g1');
    });

    test('inbox_item 端到端 drain → inbox_items_sync 含全部 NOT NULL 列', () async {
      await seedGroup('g1');
      await seedInbox('i1');
      await outbox.enqueue('inbox_items', 'i1', 'upsert', 9000);
      final r = await newPusher().drain();
      expect(r.ok, isTrue);
      final row = transport.tables['inbox_items_sync']?['i1'];
      expect(row, isNotNull);
      for (final col in SyncTransportFake.requiredColumns['inbox_items_sync']!) {
        expect(row![col], isNotNull, reason: '$col 不能为空（线上 23502）');
      }
    });
  });
}
