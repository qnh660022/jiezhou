// V2.8.1 S1 · P0 止血包（规格 §4，≥4 例）：
// 1) 预算预警 tile 整体可点 toggle；2) 统计时间范围持久化往返；
// 3) ai_cards 硬编码色值消除；4) 预警关闭时点铃铛 → L3 空态抽屉。
import 'dart:io';

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
import 'package:travel_assistant/domain/stats_calculator.dart';
import 'package:travel_assistant/features/ledger/screens/ledger_home_screen.dart';
import 'package:travel_assistant/features/ledger/screens/stats_screen.dart';
import 'package:travel_assistant/router.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

void main() {
  group('S1-1 预算预警 tile 整体可点 toggle', () {
    Future<SharedPreferences> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(initialLocation: '/', routes: buildAppRoutes());
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: TravelAssistantApp(router: router),
      ));
      await tester.pumpAndSettle();
      return prefs;
    }

    Future<void> gotoProfile(WidgetTester tester) async {
      await tester.tap(find.text('我的').first);
      await tester.pumpAndSettle();
    }

    testWidgets('点 tile 文字（非开关）也能切换并持久化', (tester) async {
      final prefs = await pumpApp(tester);
      await gotoProfile(tester);
      expect(await prefs.getBool('budget_alerts_enabled'), isNull);
      await tester.tap(find.text('预算预警'));
      await tester.pumpAndSettle();
      expect(await prefs.getBool('budget_alerts_enabled'), isFalse,
          reason: '原实现 onTap 为空函数，点 tile 文字无效果');
      await tester.tap(find.text('预算预警'));
      await tester.pumpAndSettle();
      expect(await prefs.getBool('budget_alerts_enabled'), isTrue);
    });
  });

  group('S1-2 统计时间范围持久化', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
    });
    tearDown(() async => db.close());

    Future<SharedPreferences> pumpStats(WidgetTester tester,
        {Map<String, Object> seedPrefs = const {}}) async {
      SharedPreferences.setMockInitialValues(seedPrefs);
      final prefs = await SharedPreferences.getInstance();
      final repo = LedgerRepository(db, PrefsRepository());
      final g = await repo.addGroup('团', '🧭');
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
      await repo.setActiveGroup(g.id);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ));
      await tester.pumpAndSettle();
      return prefs;
    }

    testWidgets('进入时恢复上次范围（冷启动断言）', (tester) async {
      await pumpStats(tester, seedPrefs: {'app.stats.range': 'month'});
      final seg = tester.widget<SegmentedButton<StatsRange>>(
          find.byType(SegmentedButton<StatsRange>));
      expect(seg.selected, {StatsRange.thisMonth},
          reason: 'prefs 存 month → 恢复本月');
    });

    testWidgets('切换范围即持久化（往返）', (tester) async {
      final prefs = await pumpStats(tester);
      expect(prefs.getString('app.stats.range'), isNull);
      await tester.tap(find.text('今年'));
      await tester.pumpAndSettle();
      expect(prefs.getString('app.stats.range'), 'year');
      await tester.tap(find.text('本月'));
      await tester.pumpAndSettle();
      expect(prefs.getString('app.stats.range'), 'month');
    });
  });

  group('S1-3 ai_cards 硬编码色值消除', () {
    test('travel pack 卡不再含 0xFF2E7D5B 字面量', () {
      final src = File('lib/features/ai/widgets/ai_cards.dart').readAsStringSync();
      expect(src.contains('0xFF2E7D5B'), isFalse,
          reason: '架构基线：业务代码禁硬编码色值，一律 ColorScheme 语义色');
    });
  });

  group('S1-4 预警关闭时点铃铛 → L3 空态抽屉', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
    });
    tearDown(() async => db.close());

    testWidgets('预警关闭：铃铛弹「预警已关闭」抽屉而非 SnackBar', (tester) async {
      SharedPreferences.setMockInitialValues({'budget_alerts_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final repo = LedgerRepository(db, PrefsRepository());
      final g = await repo.addGroup('团', '🧭');
      await repo.setActiveGroup(g.id);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: Scaffold(body: LedgerHomeScreen())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('预算预警'));
      await tester.pumpAndSettle();

      expect(find.text('预警已关闭'), findsOneWidget, reason: 'L3 空态抽屉替代 SnackBar');
      expect(find.text('去开启'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
