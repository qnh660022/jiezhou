// V2.7.1 S7 · E2：账本内角色解析 + 只读态隐藏清单（viewer 不渲染写入口）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_account.dart' show SpaceRole;
import 'package:travel_assistant/features/ledger/ledger_access.dart';
import 'package:travel_assistant/features/ledger/screens/ledger_home_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
  });

  tearDown(() async => db.close());

  Future<void> seedSpaceMember({
    required String spaceId,
    required String groupId,
    required String userId,
    required String role,
    int? deletedMs,
  }) async {
    await db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
          id: spaceId,
          name: '空间',
          createdBy: 'u-owner',
          groupId: Value(groupId),
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

  Future<void> seedOwnGroup(String id) => db.into(db.groups).insert(
      GroupsCompanion.insert(id: id, name: '我的团', createdAt: 1, updatedAt: 1));

  group('resolveMyGroupRole（云端 _group_role 同口径映射）', () {
    test('1. 本地 groups 行 = 我创建的账本 → owner', () async {
      await seedOwnGroup('g-own');
      expect(await resolveMyGroupRole(db, 'g-own', null), LedgerRole.owner);
    });

    test('2. 空间 viewer → viewer', () async {
      await seedSpaceMember(
          spaceId: 's1', groupId: 'g1', userId: 'u1', role: SpaceRole.viewer);
      expect(await resolveMyGroupRole(db, 'g1', 'u1'), LedgerRole.viewer);
    });

    test('3. 空间 editor → editor（可记账，不可管成员）', () async {
      await seedSpaceMember(
          spaceId: 's1', groupId: 'g1', userId: 'u1', role: SpaceRole.editor);
      expect(await resolveMyGroupRole(db, 'g1', 'u1'), LedgerRole.editor);
    });

    test('4. 空间 owner → owner', () async {
      await seedSpaceMember(
          spaceId: 's1', groupId: 'g1', userId: 'u-owner', role: SpaceRole.owner);
      expect(await resolveMyGroupRole(db, 'g1', 'u-owner'), LedgerRole.owner);
    });

    test('5. 空间成员已软删 → 不生效', () async {
      await seedSpaceMember(
          spaceId: 's1',
          groupId: 'g1',
          userId: 'u1',
          role: SpaceRole.viewer,
          deletedMs: 99);
      expect(await resolveMyGroupRole(db, 'g1', 'u1'), isNull);
    });

    test('6. 查不到（未登录 / 不属任何空间）→ null', () async {
      expect(await resolveMyGroupRole(db, 'g-x', 'u1'), isNull);
      expect(await resolveMyGroupRole(db, '', 'u1'), isNull);
    });
  });

  group('LedgerAccess 三态判定', () {
    test('7. 未知角色按可写放开（RLS 兜底，§S7.1.4）', () {
      final a = LedgerAccess.of(null);
      expect(a.canWrite, isTrue);
      expect(a.canManage, isTrue);
      expect(a.readOnly, isFalse);
    });

    test('8. viewer：只读、不可管成员', () {
      final a = LedgerAccess.of(LedgerRole.viewer);
      expect(a.canWrite, isFalse);
      expect(a.canManage, isFalse);
      expect(a.readOnly, isTrue);
    });

    test('9. editor：可写、不可管成员；owner：全权', () {
      final e = LedgerAccess.of(LedgerRole.editor);
      expect(e.canWrite, isTrue);
      expect(e.canManage, isFalse);
      final o = LedgerAccess.of(LedgerRole.owner);
      expect(o.canWrite, isTrue);
      expect(o.canManage, isTrue);
    });
  });

  group('宿主 A（移动账本主页）只读态', () {
    Future<void> pumpHome(WidgetTester tester, String groupId,
        {required String? role}) async {
      final repo = LedgerRepository(db, PrefsRepository());
      await repo.setActiveGroup(groupId);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          ledgerAccessProvider
              .overrideWith((ref, gid) async => LedgerAccess.of(role)),
        ],
        child: const MaterialApp(home: Scaffold(body: LedgerHomeScreen())),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('10. viewer：不渲染「记一笔」FAB、无「管理成员」「快速记」入口',
        (tester) async {
      final repo = LedgerRepository(db, PrefsRepository());
      final g = await repo.addGroup('共享团', '🧭');
      final m = await repo.addMember(g.id, '张三');
      await repo.addExpense(ExpensesCompanion.insert(
        id: 'e1',
        groupId: g.id,
        dateEpochDay: const Value(1),
        title: const Value('午饭'),
        categoryKey: const Value('food'),
        amountCents: const Value(1000),
        payersJson: Value('[{"memberId":"$m","cents":1000}]'),
        sharesJson: Value('[{"memberId":"$m","cents":1000}]'),
        createdAt: 100,
      ));

      await pumpHome(tester, g.id, role: LedgerRole.viewer);

      expect(find.text('记一笔'), findsNothing, reason: 'S7.1.3：隐藏记一笔 FAB');
      expect(find.text('快速记'), findsNothing);
      expect(find.text('AA 结算'), findsNothing);
      expect(find.text('管理成员'), findsNothing);
      // 只读入口保留
      expect(find.text('全部账单'), findsOneWidget);
      expect(find.text('统计图表'), findsOneWidget);
      // 数值照常可查看
      expect(find.text('预算进度'), findsNothing);
      expect(find.text('还没设置预算'), findsOneWidget);
    });

    testWidgets('11. owner：写入口齐全（无回归）', (tester) async {
      final repo = LedgerRepository(db, PrefsRepository());
      final g = await repo.addGroup('我的团', '🧭');
      await repo.addMember(g.id, '张三');

      await pumpHome(tester, g.id, role: LedgerRole.owner);

      expect(find.text('记一笔'), findsOneWidget);
      expect(find.text('快速记'), findsOneWidget);
      expect(find.text('管理成员'), findsOneWidget);
    });

    testWidgets('12. 角色未知（解析不出）按可写处理，不误藏入口', (tester) async {
      final repo = LedgerRepository(db, PrefsRepository());
      final g = await repo.addGroup('我的团', '🧭');
      await repo.addMember(g.id, '张三');

      await pumpHome(tester, g.id, role: null);

      expect(find.text('记一笔'), findsOneWidget);
    });
  });
}
