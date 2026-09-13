// V2.6.6.2 §10.3：spaces / spaceMembers / spaceEvents 的 mergeRow 判定
// （新者胜、软删语义）+ 协作行程镜像分流。
//
// 合流口径（与既有实体完全一致，§6.3：不引入新的合流规则）：
//   * 云端 updated_ms > 本地有效 ms → 云端胜（覆盖本地）；
//   * 云端 < 本地 → 本地胜，排队上行（防环收敛）；
//   * 相等 → 不动作；
//   * cloud.deleted == true → 删本地行（幂等）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_merger.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxService outbox;
  late SyncMerger merger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    outbox = SyncOutboxService(db);
    merger = SyncMerger(db, outbox);
    merger.refreshContext(
        userId: 'me', collabGroups: const {}, collabTrips: const {}, known: true);
  });

  tearDown(() async => db.close());

  Map<String, dynamic> spaceJson({
    String id = 's1',
    String name = '京都行',
    int updatedMs = 2000,
    bool deleted = false,
  }) =>
      {
        'id': id,
        'name': name,
        'trip_id': null,
        'group_id': null,
        'created_by': 'u1',
        'note': null,
        'status': 'active',
        'created_ms': 1000,
        'updated_ms': updatedMs,
        'deleted': deleted,
      };

  Map<String, dynamic> memberJson({
    String id = 'm1',
    String role = 'viewer',
    int updatedMs = 2000,
    bool deleted = false,
  }) =>
      {
        'id': id,
        'space_id': 's1',
        'user_id': 'u9',
        'role': role,
        'display_name': '小明',
        'joined_ms': 1000,
        'created_ms': 1000,
        'updated_ms': updatedMs,
        'deleted': deleted,
      };

  Map<String, dynamic> eventJson({
    String id = 'e1',
    String action = 'expense_added',
    int createdMs = 2000,
  }) =>
      {
        'id': id,
        'space_id': 's1',
        'actor_user': 'u9',
        'action': action,
        'entity_kind': 'expense',
        'entity_id': 'x1',
        'summary': '午餐 ¥38.00',
        'created_ms': createdMs,
        'updated_ms': createdMs,
        'deleted': false,
      };

  group('spaces 合流', () {
    test('本地无该行 → 云端直接落库', () async {
      await merger.mergeRow(SyncEntity.spaces, spaceJson());
      final rows = await db.select(db.travelSpaces).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, '京都行');
      expect(rows.single.createdBy, 'u1');
    });

    test('云端更新（updated_ms 更大）→ 云端胜', () async {
      await merger.mergeRow(SyncEntity.spaces, spaceJson(updatedMs: 2000));
      await merger.mergeRow(
          SyncEntity.spaces, spaceJson(name: '大阪行', updatedMs: 3000));
      final row = (await db.select(db.travelSpaces).get()).single;
      expect(row.name, '大阪行');
      expect(row.updatedMs, 3000);
    });

    test('本地更新（updated_ms 更大）→ 本地胜，且排队上行防环', () async {
      await db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
            id: 's1',
            name: '我改的',
            createdBy: 'u1',
            createdMs: 1000,
            updatedMs: 5000,
          ));
      await merger.mergeRow(SyncEntity.spaces, spaceJson(updatedMs: 2000));
      final row = (await db.select(db.travelSpaces).get()).single;
      expect(row.name, '我改的', reason: '本地较新不能被云端旧值吃掉');
      expect(await outbox.pendingEntry('travel_spaces', 's1'), isNotNull,
          reason: '本地胜必须排队上行（防环收敛）');
    });

    test('时间戳相等 → 不动作（防抖）', () async {
      await merger.mergeRow(SyncEntity.spaces, spaceJson(updatedMs: 2000));
      await merger.mergeRow(SyncEntity.spaces, spaceJson(updatedMs: 2000));
      expect(await outbox.pendingCount(), 0);
    });

    test('软删墓碑 → 本地行删除，并级联清理成员与动态', () async {
      await merger.mergeRow(SyncEntity.spaces, spaceJson());
      await merger.mergeRow(SyncEntity.spaceMembers, memberJson());
      await merger.mergeRow(SyncEntity.spaceEvents, eventJson());
      expect(await db.select(db.spaceMembers).get(), hasLength(1));
      expect(await db.select(db.spaceEvents).get(), hasLength(1));

      await merger.mergeRow(
          SyncEntity.spaces, spaceJson(updatedMs: 5000, deleted: true));
      expect(await db.select(db.travelSpaces).get(), isEmpty);
      expect(await db.select(db.spaceMembers).get(), isEmpty,
          reason: '空间没了，成员行不应留成孤儿');
      expect(await db.select(db.spaceEvents).get(), isEmpty);
    });

    test('本地已删但 outbox 压着删除意图 → 不复活（H1 同源）', () async {
      await outbox.enqueue('travel_spaces', 's1', 'delete', 6000);
      await merger.mergeRow(SyncEntity.spaces, spaceJson(updatedMs: 7000));
      expect(await db.select(db.travelSpaces).get(), isEmpty,
          reason: '本地删除意图未上行前，云端行不能插回来');
    });
  });

  group('spaceMembers 合流', () {
    test('角色变更（新者胜）落地', () async {
      await merger.mergeRow(SyncEntity.spaceMembers, memberJson(role: 'viewer'));
      await merger.mergeRow(
          SyncEntity.spaceMembers, memberJson(role: 'editor', updatedMs: 4000));
      final row = (await db.select(db.spaceMembers).get()).single;
      expect(row.role, 'editor');
    });

    test('软删墓碑 → 本地成员行删除（被移出 / 主动退出）', () async {
      await merger.mergeRow(SyncEntity.spaceMembers, memberJson());
      await merger.mergeRow(SyncEntity.spaceMembers,
          memberJson(updatedMs: 9000, deleted: true));
      expect(await db.select(db.spaceMembers).get(), isEmpty);
    });

    test('deleted_ms 随云端下行落库（业务软删字段）', () async {
      final json = memberJson(updatedMs: 9000);
      json['deleted_ms'] = 9000;
      await merger.mergeRow(SyncEntity.spaceMembers, json);
      final row = (await db.select(db.spaceMembers).get()).single;
      expect(row.deletedMs, 9000);
    });
  });

  group('spaceEvents 合流（append-only）', () {
    test('按 id 幂等插入，不因时间戳相同而丢失', () async {
      await merger.mergeRow(SyncEntity.spaceEvents, eventJson(id: 'e1'));
      await merger.mergeRow(SyncEntity.spaceEvents, eventJson(id: 'e2'));
      final rows = await db.select(db.spaceEvents).get();
      expect(rows.map((e) => e.id).toSet(), {'e1', 'e2'});
    });

    test('同一事件重复下行 → 幂等覆盖，不产生重复行', () async {
      await merger.mergeRow(SyncEntity.spaceEvents, eventJson(id: 'e1'));
      await merger.mergeRow(SyncEntity.spaceEvents, eventJson(id: 'e1'));
      expect(await db.select(db.spaceEvents).get(), hasLength(1));
    });
  });

  group('协作行程镜像分流（§3.3 读权限放宽后的落库位置）', () {
    Map<String, dynamic> tripJson(String id, {String owner = 'other'}) => {
          'id': id,
          'owner_user_id': owner,
          'name': '别人的行程',
          'destination': '京都',
          'emoji': '✈️',
          'cover': 'ocean',
          'start_epoch_day': 100,
          'end_epoch_day': 105,
          'note': '',
          'group_id': null,
          'archived': false,
          'created_ms': 1000,
          'updated_ms': 2000,
          'deleted': false,
        };

    test('自己的行程 → 业务表 trips', () async {
      await merger.mergeRow(SyncEntity.trips, tripJson('t1', owner: 'me'));
      expect(await db.select(db.trips).get(), hasLength(1));
      expect(await db.select(db.sharedTrips).get(), isEmpty);
    });

    test('空间关联的他人行程 → 共享镜像表，不污染「我的行程」', () async {
      merger.refreshContext(
          userId: 'me',
          collabGroups: const {},
          collabTrips: const {'t1'},
          known: true);
      await merger.mergeRow(SyncEntity.trips, tripJson('t1'));
      expect(await db.select(db.trips).get(), isEmpty,
          reason: '他人行程绝不能落业务表（H7 同源风险）');
      expect((await db.select(db.sharedTrips).get()).single.name, '别人的行程');
    });

    test('协作名单未知 → 他人行程一律跳过（fail-safe）', () async {
      merger.refreshContext(
          userId: 'me', collabGroups: const {}, collabTrips: const {'t1'}, known: false);
      await merger.mergeRow(SyncEntity.trips, tripJson('t1'));
      expect(await db.select(db.trips).get(), isEmpty);
      expect(await db.select(db.sharedTrips).get(), isEmpty);
    });

    test('不在协作名单里的他人行程 → 跳过', () async {
      merger.refreshContext(
          userId: 'me', collabGroups: const {}, collabTrips: const {'other'}, known: true);
      await merger.mergeRow(SyncEntity.trips, tripJson('t1'));
      expect(await db.select(db.sharedTrips).get(), isEmpty);
    });

    test('协作行程项按 trip_id 分流到 shared_trip_items', () async {
      merger.refreshContext(
          userId: 'me',
          collabGroups: const {},
          collabTrips: const {'t1'},
          known: true);
      await merger.mergeRow(SyncEntity.tripItems, {
        'id': 'i1',
        'owner_user_id': 'other',
        'trip_id': 't1',
        'date_epoch_day': 101,
        'type': 'attraction',
        'name': '清水寺',
        'address': '',
        'cost_currency': 'CNY',
        'note': '',
        'from_name': '',
        'from_address': '',
        'to_name': '',
        'to_address': '',
        'sort_order': 0,
        'created_ms': 1000,
        'updated_ms': 2000,
        'deleted': false,
      });
      expect(await db.select(db.tripItems).get(), isEmpty);
      expect((await db.select(db.sharedTripItems).get()).single.name, '清水寺');
    });

    test('他人行程项的软删墓碑 → 镜像行删除', () async {
      merger.refreshContext(
          userId: 'me',
          collabGroups: const {},
          collabTrips: const {'t1'},
          known: true);
      final base = {
        'id': 'i1',
        'owner_user_id': 'other',
        'trip_id': 't1',
        'date_epoch_day': 101,
        'type': 'attraction',
        'name': '清水寺',
        'address': '',
        'cost_currency': 'CNY',
        'note': '',
        'from_name': '',
        'from_address': '',
        'to_name': '',
        'to_address': '',
        'sort_order': 0,
        'created_ms': 1000,
        'updated_ms': 2000,
        'deleted': false,
      };
      await merger.mergeRow(SyncEntity.tripItems, base);
      expect(await db.select(db.sharedTripItems).get(), hasLength(1));
      await merger.mergeRow(SyncEntity.tripItems,
          {...base, 'updated_ms': 3000, 'deleted': true});
      expect(await db.select(db.sharedTripItems).get(), isEmpty);
    });
  });

  group('镜像表 updatedMs 判定（rowUpdatedMs 运行期类型分派修复）', () {
    test('已存在的共享镜像行收到更新云值 → 云端胜且不抛 TypeError', () async {
      merger.refreshContext(
          userId: 'me',
          collabGroups: const {'g1'},
          collabTrips: const {},
          known: true);
      await merger.mergeRow(SyncEntity.groups, {
        'id': 'g1',
        'owner_user_id': 'other',
        'name': '共享团',
        'icon': '📁',
        'budget_enabled': false,
        'budget_cents': null,
        'archived': false,
        'archived_at_ms': null,
        'created_ms': 1000,
        'updated_ms': 2000,
        'deleted': false,
      });
      await merger.mergeRow(SyncEntity.groups, {
        'id': 'g1',
        'owner_user_id': 'other',
        'name': '改名了',
        'icon': '📁',
        'budget_enabled': false,
        'budget_cents': null,
        'archived': false,
        'archived_at_ms': null,
        'created_ms': 1000,
        'updated_ms': 5000,
        'deleted': false,
      });
      final row = (await db.select(db.sharedGroups).get()).single;
      expect(row.name, '改名了');
    });
  });
}
