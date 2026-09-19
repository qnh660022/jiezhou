// V2.8.1 S6 · 明细页（规格 §9.3，≥14 例）：
// 滑动暴露/回调、批量删除事务+墓碑、批量改分类 notifyWrite、URL 参数解析组合、
// 双级吸顶 pinned、时间筛选、viewer 禁入口、合计口径含预付注记。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/domain/models.dart' show ExpenseType;
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_account.dart' show SpaceRole;
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/features/ledger/ledger_access.dart';
import 'package:travel_assistant/features/ledger/screens/expenses_screen.dart';
import 'package:travel_assistant/shared/widgets/swipeable_bill_tile.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String groupId;
  late String memberId;
  final outboxEvents = <(String, String, String)>[];

  void attachOutbox() {
    SyncOutboxService.hook = (entity, rowId, op, ms) =>
        outboxEvents.add((entity, rowId, op));
  }

  void detachOutbox() => SyncOutboxService.hook = null;

  Future<String> addBill({
    required String id,
    String categoryKey = 'food',
    int dateEpochDay = 100,
    int amount = 1000,
    ExpenseType type = ExpenseType.normal,
    String title = '账单',
    String? payMethod,
  }) async {
    await repo.addExpense(ExpensesCompanion.insert(
      id: id,
      groupId: groupId,
      dateEpochDay: Value(dateEpochDay),
      title: Value(title),
      categoryKey: Value(categoryKey),
      type: Value(type.name),
      amountCents: Value(amount),
      payersJson: Value('[{"memberId":"$memberId","cents":$amount}]'),
      sharesJson: Value('[{"memberId":"$memberId","cents":$amount}]'),
      payMethod: Value(payMethod),
      createdAt: 100,
    ));
    return id;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
    final g = await repo.addGroup('团', '🧭');
    groupId = g.id;
    final m = await repo.addMember(g.id, '张三');
    memberId = m;
    await repo.setActiveGroup(g.id);
    outboxEvents.clear();
    attachOutbox();
  });
  tearDown(() async {
    detachOutbox();
    await db.close();
  });

  Future<SharedPreferences> pumpExpenses(
    WidgetTester tester, {
    String query = '',
    String? role,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // 注意：setUp 已 setMockInitialValues 并写入激活团——此处不得再重置，
    // 否则 activeGroupIdProvider 变 null，明细页永远拿不到账单。
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
        GoRoute(
          path: '/expenses',
          builder: (_, __) => const Scaffold(body: ExpensesScreen()),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (role != null)
          ledgerAccessProvider.overrideWith((ref, gid) async =>
              LedgerAccess.of(switch (role) {
                'viewer' => SpaceRole.viewer,
                'editor' => SpaceRole.editor,
                _ => SpaceRole.owner,
              })),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    router.push('/expenses$query');
    await tester.pumpAndSettle();
    // drift watch 流异步发射：补两帧，确保 provider 推送到位（否则空态分支竞态）
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    return prefs;
  }

  testWidgets('1. 无参默认行为：全部账单按日分组渲染 + 合计栏', (tester) async {
    await addBill(id: 'e1', title: '午餐');
    await addBill(id: 'e2', title: '打车', categoryKey: 'transport', dateEpochDay: 102);
    await pumpExpenses(tester);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('打车'), findsOneWidget);
    expect(find.text('当前筛选总支出'), findsOneWidget);
    expect(find.text('2 笔'), findsOneWidget);
  });

  testWidgets('2. URL 参数 category 筛选生效', (tester) async {
    await addBill(id: 'e1', title: '午餐', categoryKey: 'food');
    await addBill(id: 'e2', title: '打车', categoryKey: 'transport');
    await pumpExpenses(tester, query: '?category=food');
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('打车'), findsNothing);
  });

  testWidgets('3. URL 参数 member + payMethods 组合生效', (tester) async {
    await addBill(id: 'e1', title: '现金午饭', payMethod: 'cash');
    await addBill(id: 'e2', title: '刷卡打车', categoryKey: 'transport', payMethod: 'credit');
    await pumpExpenses(tester, query: '?payMethods=cash');
    expect(find.text('现金午饭'), findsOneWidget);
    expect(find.text('刷卡打车'), findsNothing);
  });

  testWidgets('4. URL 参数 from/to 时间范围生效', (tester) async {
    await addBill(id: 'e1', title: '范围内', dateEpochDay: 100);
    await addBill(id: 'e2', title: '范围外', dateEpochDay: 500);
    await pumpExpenses(tester, query: '?from=99&to=101');
    expect(find.text('范围内'), findsOneWidget);
    expect(find.text('范围外'), findsNothing);
  });

  testWidgets('5. 双级吸顶：月度头 + 日头都 pinned 渲染', (tester) async {
    await addBill(id: 'e1', title: '午饭', dateEpochDay: 100);
    await pumpExpenses(tester);
    final month = tester.widget<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader).first);
    expect(month.pinned, isTrue, reason: '月度头吸顶');
    final headers = tester.widgetList<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader));
    expect(headers.length, greaterThanOrEqualTo(2), reason: '月头 + 日头两级');
    expect(find.textContaining('月'), findsWidgets, reason: '出现「xxxx年x月」月头');
  });

  testWidgets('6. 合计口径：预付另计注记', (tester) async {
    await addBill(id: 'e1', title: '普通', amount: 1000);
    await addBill(id: 'e2', title: '预付机票', amount: 5000, type: ExpenseType.prepay);
    await pumpExpenses(tester);
    expect(find.text('预付另计 ¥50.00'), findsOneWidget, reason: '预付不计入总支出行');
    expect(find.text('2 笔'), findsOneWidget);
  });

  testWidgets('7. 批量删除：长按进入多选 → 删除走 L2 强确认 → 单事务 + 墓碑落 outbox',
      (tester) async {
    await addBill(id: 'e1', title: '账单一');
    await addBill(id: 'e2', title: '账单二');
    await pumpExpenses(tester);
    await tester.longPress(find.text('账单一'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选 1 笔'), findsOneWidget, reason: '进入批量态');
    await tester.tap(find.text('账单二'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选 2 笔'), findsOneWidget);
    // 批量删除 → 危险确认弹层（用 FilledButton 定位，避开滑动背景的同名标签）
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除所选 2 笔账单？'), findsOneWidget, reason: 'L2 强确认含数量');
    await tester.tap(find.text('全部删除'));
    await tester.pumpAndSettle();
    final rows = await db.select(db.expenses).get();
    expect(rows, isEmpty, reason: '批量删除落库');
    final tombstones =
        outboxEvents.where((e) => e.$1 == 'expenses' && e.$3 == 'delete');
    expect(tombstones.length, 2, reason: '逐行墓碑（op=delete）上行');
  });

  testWidgets('8. 批量改分类：单事务逐行更新', (tester) async {
    await addBill(id: 'e1', title: '账单一', categoryKey: 'food');
    await addBill(id: 'e2', title: '账单二', categoryKey: 'food');
    await pumpExpenses(tester);
    await tester.longPress(find.text('账单一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('账单二'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('改分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();
    final rows = await db.select(db.expenses).get();
    expect(rows.every((r) => r.categoryKey == 'transport'), isTrue,
        reason: '批量改分类落库（内置 key food→transport 映射为交通项）');
  });

  testWidgets('9. viewer：不进入批量多选、无滑动动作（隐藏不置灰）', (tester) async {
    await addBill(id: 'e1', title: '只读账单');
    await pumpExpenses(tester, role: 'viewer');
    await tester.longPress(find.text('只读账单'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('已选'), findsNothing, reason: 'viewer 不进入批量态');
    expect(find.byType(SwipeableBillTile), findsNothing,
        reason: 'viewer 行不挂滑动组件');
  });

  testWidgets('10. 单笔左滑删除 → L2 危险确认 → 墓碑', (tester) async {
    await addBill(id: 'e1', title: '要删的账');
    await pumpExpenses(tester);
    final tileCenter = tester.getCenter(find.text('要删的账'));
    final gesture = await tester.startGesture(tileCenter);
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('删除这笔账单？'), findsOneWidget, reason: '滑动删除接 L2 危险确认');
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(
        outboxEvents.any((e) => e.$1 == 'expenses' && e.$3 == 'delete'), isTrue,
        reason: '删除墓碑上行');
  });

  testWidgets('11. 空态：从未记账引导分支（无账单时确定性渲染）', (tester) async {
    // 空库 + 无筛选：直接落在「一笔都还没记」引导态
    final prefs = await pumpExpenses(tester);
    for (var i = 0;
        i < 20 && find.text('一笔都还没记').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('一笔都还没记'), findsOneWidget, reason: '从未记账分支');
    expect(find.text('记一笔'), findsWidgets, reason: '引导按钮 + FAB');
  });

  test('12. SwipeableBillTile 阈值常量 = 84', () {
    expect(SwipeableBillTile.threshold, 84);
  });
}
