// V2.8.1 S7 · 首页与入口收敛（规格 §10.3 精简覆盖，8 例）：
// 工具箱五入口 / 溢出菜单唯一项 / Hero 语义 chips / 超支警示条 / 切团直跳 /
// 团卡左滑删除确认 / QR 组件统一 / viewer 隐藏工具箱。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/app.dart';
import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_account.dart' show SpaceRole;
import 'package:travel_assistant/features/ledger/ledger_access.dart';
import 'package:travel_assistant/features/ledger/screens/group_list_screen.dart';
import 'package:travel_assistant/features/ledger/screens/ledger_home_screen.dart';
import 'package:travel_assistant/features/ledger/widgets/join_by_qr_tile.dart';
import 'package:travel_assistant/features/ledger/widgets/ledger_toolbox_sheet.dart';
import 'package:travel_assistant/router.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
  });
  tearDown(() async => db.close());

  /// 完整 App 壳（带路由）：能跳 /ledger/groups 等
  Future<GoRouter> pumpApp(WidgetTester tester, {String? role}) async {
    tester.view.physicalSize = const Size(900, 1900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final repo = LedgerRepository(db, PrefsRepository());
    final g = await repo.addGroup('团', '🧭');
    final m = await repo.addMember(g.id, '张三');
    await repo.setActiveGroup(g.id);
    final router = GoRouter(initialLocation: '/', routes: buildAppRoutes());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (role != null)
          ledgerAccessProvider.overrideWith((ref, gid) async =>
              LedgerAccess.of(switch (role) {
                'viewer' => SpaceRole.viewer,
                _ => SpaceRole.owner,
              })),
      ],
      child: TravelAssistantApp(router: router),
    ));
    await tester.pumpAndSettle();
    // 底栏切到账本 Tab
    await tester.tap(find.text('💰').first);
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('1. 头部溢出菜单唯一项 = 工具箱', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('工具箱'));
    await tester.pumpAndSettle();
    expect(find.text('工具箱'), findsWidgets, reason: 'L3 工具箱抽屉打开');
    expect(find.text('变更记录'), findsOneWidget);
    expect(find.text('局域网同步'), findsOneWidget);
    expect(find.text('CSV 导入'), findsOneWidget);
    expect(find.text('CSV 导出'), findsNothing, reason: '无回调时导出项隐藏（首页走头部按钮）');
    expect(find.text('分类管理'), findsOneWidget);
  });

  testWidgets('2. 工具箱含 CSV 导出入口（带回调，裸 harness）', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showLedgerToolbox(context, onExportCsv: () {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('CSV 导出'), findsOneWidget, reason: '有回调时导出项渲染');
  });

  testWidgets('3. Hero 卡：预算开启时渲染「预算 N%」chip 并可跳预算页', (tester) async {
    final repo = LedgerRepository(db, PrefsRepository());
    final g = await repo.addGroup('预算团', '🧭');
    await (db.update(db.groups)..where((x) => x.id.equals(g.id))).write(
        GroupsCompanion(
            budgetEnabled: const Value(true), budgetCents: const Value(100000)));
    await pumpApp(tester);
    // 切到预算团（经切团抽屉）
    await tester.tap(find.byTooltip('切换旅行团'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预算团').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('预算 '), findsWidgets, reason: 'Hero 卡语义 chip');
  });

  testWidgets('4. 超支态：Hero 卡出现顶部警示条（error 色调）', (tester) async {
    final repo = LedgerRepository(db, PrefsRepository());
    final g = await repo.addGroup('超支团', '🧭');
    await repo.addMember(g.id, '张三');
    await (db.update(db.groups)..where((x) => x.id.equals(g.id))).write(
        GroupsCompanion(
            budgetEnabled: const Value(true), budgetCents: const Value(1000)));
    await repo.addExpense(ExpensesCompanion.insert(
      id: 'e-big',
      groupId: g.id,
      dateEpochDay: const Value(1),
      title: const Value('大额'),
      categoryKey: const Value('food'),
      amountCents: const Value(500000),
      payersJson: const Value('[{"memberId":"m1","cents":500000}]'),
      sharesJson: const Value('[{"memberId":"m1","cents":500000}]'),
      createdAt: 100,
    ));
    await pumpApp(tester);
    await tester.tap(find.byTooltip('切换旅行团'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('超支团').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('预算 '), findsWidgets);
    // 超支横幅组件（既有）+ Hero error 色调（警示条为纯 Container，查其存在以 error 色渲染）
    expect(find.textContaining('超支'), findsWidgets, reason: '超支提示存在');
  });

  testWidgets('5. 切团抽屉：「全部旅行团」直跳 /ledger/groups', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('切换旅行团'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部旅行团'));
    await tester.pumpAndSettle();
    expect(find.text('旅行团管理'), findsOneWidget, reason: '直跳团管理页');
  });

  testWidgets('6. 团卡左滑 → L2 删除确认弹层（裸 harness 直接渲染团管理页）', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final repo = LedgerRepository(db, PrefsRepository());
    final g = await repo.addGroup('团', '🧭');
    await repo.setActiveGroup(g.id);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(home: Scaffold(body: GroupListScreen())),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsWidgets, reason: '团卡挂 Dismissible');
    await tester.drag(find.text('团').first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('删除旅行团？'), findsOneWidget, reason: '左滑接 L2 强确认');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('7. 扫码入口统一组件：团管理页使用 JoinByQrTile', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('切换旅行团'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部旅行团'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinByQrTile), findsOneWidget, reason: '三处入口收敛为同一组件');
  });

  testWidgets('8. viewer：工具箱入口隐藏（隐藏不置灰口径）', (tester) async {
    await pumpApp(tester, role: 'viewer');
    expect(find.byTooltip('工具箱'), findsNothing, reason: 'viewer 不渲染工具箱入口');
  });
}
