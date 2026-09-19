// V2.8.3.3：行程域角色解析 + 只读态（补 V2.7.2 A12 未落地的 viewer 管线）。
//
// 与 test/features/ledger_access_test.dart 同构 —— 两域的角色语义必须一致，
// 否则同一旅伴空间里会出现「行程能改、账本不能改」的自相矛盾。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_account.dart' show SpaceRole;
import 'package:travel_assistant/features/trips/trip_access.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
  });

  tearDown(() async => db.close());

  Future<void> seedTrip(String id) =>
      db.into(db.trips).insert(TripsCompanion.insert(
            id: id,
            name: '大理行',
            createdAt: 1,
            updatedAt: 1,
          ));

  Future<void> seedSpaceMember({
    required String spaceId,
    required String tripId,
    required String userId,
    required String role,
    int? deletedMs,
  }) async {
    await db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
          id: spaceId,
          name: '空间',
          createdBy: 'u-owner',
          tripId: Value(tripId),
          createdMs: 1,
          updatedMs: 1,
        ));
    await db.into(db.spaceMembers).insert(SpaceMembersCompanion.insert(
          id: 'sm-$spaceId-$userId',
          spaceId: spaceId,
          userId: userId,
          role: Value(role),
          joinedMs: 1,
          createdMs: 1,
          updatedMs: 1,
          deletedMs: Value(deletedMs),
        ));
  }

  group('resolveMyTripRole（与云端 _trip_role / ledger_access 同口径）', () {
    test('1. 本地 trips 行 = 我创建的行程 → owner', () async {
      await seedTrip('t-own');
      expect(await resolveMyTripRole(db, 't-own', null), TripRole.owner);
    });

    test('2. 空间 viewer → viewer', () async {
      await seedSpaceMember(
          spaceId: 's1', tripId: 't1', userId: 'u1', role: SpaceRole.viewer);
      expect(await resolveMyTripRole(db, 't1', 'u1'), TripRole.viewer);
    });

    test('3. 空间 editor → editor', () async {
      await seedSpaceMember(
          spaceId: 's1', tripId: 't1', userId: 'u1', role: SpaceRole.editor);
      expect(await resolveMyTripRole(db, 't1', 'u1'), TripRole.editor);
    });

    test('4. 空间 owner → owner', () async {
      await seedSpaceMember(
          spaceId: 's1', tripId: 't1', userId: 'u-owner', role: SpaceRole.owner);
      expect(await resolveMyTripRole(db, 't1', 'u-owner'), TripRole.owner);
    });

    test('5. 空间成员已软删 → 不生效', () async {
      await seedSpaceMember(
          spaceId: 's1',
          tripId: 't1',
          userId: 'u1',
          role: SpaceRole.viewer,
          deletedMs: 99);
      expect(await resolveMyTripRole(db, 't1', 'u1'), isNull);
    });

    test('6. 查不到（未登录 / 不属任何空间）→ null', () async {
      expect(await resolveMyTripRole(db, 't-x', 'u1'), isNull);
      expect(await resolveMyTripRole(db, '', 'u1'), isNull);
    });
  });

  group('TripAccess 判定', () {
    test('7. 未知角色按可写放开（RLS 兜底，与 LedgerAccess 同口径）', () {
      final a = TripAccess.of(null);
      expect(a.canWrite, isTrue);
      expect(a.readOnly, isFalse);
    });

    test('8. viewer：只读', () {
      final a = TripAccess.of(TripRole.viewer);
      expect(a.canWrite, isFalse);
      expect(a.readOnly, isTrue);
    });

    test('9. editor / owner：可写', () {
      expect(TripAccess.of(TripRole.editor).canWrite, isTrue);
      expect(TripAccess.of(TripRole.owner).canWrite, isTrue);
    });

    test('10. 角色标签与空间域一致', () {
      expect(TripRole.labelOf(TripRole.viewer), '观察者');
      expect(TripRole.labelOf(TripRole.editor), '编辑者');
      expect(TripRole.labelOf(TripRole.owner), '创建者');
    });
  });

  group('详情页接线（文件断言：A12 门控点不得回退为硬编码 true）', () {
    test('11. 三面板 canEdit 均由角色解析结果传入', () {
      final src =
          File('lib/features/trips/screens/trip_detail_screen.dart')
              .readAsStringSync();
      expect(src.contains('tripAccessProvider'), isTrue,
          reason: '详情页必须订阅行程角色');
      expect(src.contains('KitTab(tripId: id, canEdit: _canWrite)'), isTrue,
          reason: '锦囊面板须接 viewer 只读');
      expect(src.contains('AssemblePanel(tripId: tripId, canEdit: canEdit)'),
          isTrue, reason: '装配台半屏抽屉须接 viewer 只读');
      expect(src.contains('OutlineTab(tripId: tripId, canEdit: canEdit)'),
          isTrue, reason: '大纲抽屉须接 viewer 只读');
      expect(src.contains('canEdit: true'), isFalse,
          reason: 'A12：详情页不得再出现硬编码可写');
    });

    test('12. 时间线写入口全部有 _canWrite 门控', () {
      final src =
          File('lib/features/trips/screens/trip_detail_screen.dart')
              .readAsStringSync();
      // 新增/编辑安排、长按操作抽屉、批量、拖拽、装配入口
      // 宿主类（_TripDetailScreenState）内 3 处早返回门控
      // onEnterMultiSelect / onBatchMove / onBatchDelete
      expect(RegExp(r'if \(!_canWrite\) return;').allMatches(src).length,
          greaterThanOrEqualTo(3),
          reason: '批量选择 / 批量移动 / 批量删除须逐一门控');
      // 子类 _DetailBody 拿不到宿主私有字段，角色由构造参数下传后门控
      expect(RegExp(r'if \(!widget\.canWrite\) return;').allMatches(src).length,
          greaterThanOrEqualTo(1),
          reason: '拖拽重排门控在 _DetailBody 内');
      expect(src.contains('if (!_canWrite) {'), isTrue,
          reason: '新增与编辑安排、长按操作抽屉须整体拦截');
      expect(src.contains('onAssemble: widget.canWrite'), isTrue,
          reason: '观察者不渲染装配入口');
    });
  });
}
