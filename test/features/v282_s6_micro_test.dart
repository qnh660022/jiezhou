// V2.8.2 S6 微交互包 B（配额 ≥12）：
// Hero（账单行↔详情金额、团卡↔团编辑名称）/ 图表生长（柱状 0→值、扇区扫过）/
// 骨架 morph（账本首页 300ms）/ PressableScale 行程域接线 / 统一确认抽屉回归。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/features/ledger/screens/expenses_screen.dart';
import 'package:travel_assistant/features/ledger/screens/ledger_home_screen.dart';
import 'package:travel_assistant/features/ledger/screens/stats_screen.dart';
import 'package:travel_assistant/features/trips/screens/trips_home_screen.dart';
import 'package:travel_assistant/shared/widgets/confirm_sheet.dart';
import 'package:travel_assistant/shared/widgets/pressable_scale.dart';
import 'package:travel_assistant/shared/widgets/skeleton_box.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // ===========================================================================
  // 图表生长：扇区扫过插值（纯函数）
  // ===========================================================================
  group('S6-1 pieSweepValues 扇区扫过插值', () {
    test('t=1 返回原值（终态）', () {
      final v = pieSweepValues([30, 20, 10], 1.0);
      expect(v, [30, 20, 10]);
    });

    test('t=0 全部为 0（扫过起点）', () {
      final v = pieSweepValues([30, 20, 10], 0.0);
      expect(v, [0, 0, 0]);
    });

    test('t 时刻按角度比例逐段可见（clamp 语义）', () {
      // 总量 60；t=0.5 → swept=30：第 1 段全见(30)，其后为 0
      final half = pieSweepValues([30, 20, 10], 0.5);
      expect(half[0], 30);
      expect(half[1], 0);
      expect(half[2], 0);
      // t=0.75 → swept=45：第 2 段可见 15
      final threeQ = pieSweepValues([30, 20, 10], 0.75);
      expect(threeQ[0], 30);
      expect(threeQ[1], 15);
      expect(threeQ[2], 0);
    });

    test('总量为 0 直接返回原值（空数据不扫）', () {
      expect(pieSweepValues([0, 0], 0.3), [0, 0]);
    });
  });

  // ===========================================================================
  // Hero：账单行 ↔ BillDetailSheet 金额连续过渡
  // ===========================================================================
  group('S6-2 金额 Hero', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase());
    tearDown(() async => db.close());

    Future<SharedPreferences> pumpExpenses(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
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
      final router = GoRouter(initialLocation: '/expenses', routes: [
        GoRoute(
            path: '/expenses',
            builder: (_, _) => const Scaffold(body: ExpensesScreen())),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return prefs;
    }

    testWidgets('账单行金额包 Hero（tag = bill-amount-<id>）', (tester) async {
      await pumpExpenses(tester);
      final heroes = tester.widgetList<Hero>(find.byWidgetPredicate(
          (w) => w is Hero && w.tag == 'bill-amount-e1'));
      expect(heroes.length, 1, reason: '账单行金额 Hero 就位（S6 Hero 扩展）');
    });

    test('BillDetailSheet 头部金额使用同 tag（成对飞行终点）', () {
      final src =
          File('lib/features/ledger/widgets/bill_detail_sheet.dart')
              .readAsStringSync();
      expect(src.contains("tag: 'bill-amount-\${expense.id}'"), isTrue);
    });
  });

  // ===========================================================================
  // Hero：团卡 ↔ 团编辑名称
  // ===========================================================================
  group('S6-3 团名 Hero（文件断言）', () {
    test('团卡名称 tag = group-name-<id>', () {
      final src = File('lib/features/ledger/screens/group_list_screen.dart')
          .readAsStringSync();
      expect(src.contains("tag: 'group-name-\${g.id}'"), isTrue);
    });

    test('团编辑名称输入框成对同 tag（编辑态）', () {
      final src = File('lib/features/ledger/screens/group_edit_screen.dart')
          .readAsStringSync();
      expect(src.contains("'group-name-\${GoRouterState.of(context)"), isTrue);
      expect(src.contains("'group-name-new'"), isTrue);
    });
  });

  // ===========================================================================
  // 骨架 morph：账本首页 300ms 淡接
  // ===========================================================================
  group('S6-4 骨架屏 morph', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
    });
    tearDown(() async => db.close());

    testWidgets('账本首页：首帧骨架 → 300ms 后内容淡接（AnimatedSwitcher）',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final prefs = await SharedPreferences.getInstance();
      final repo = LedgerRepository(db, PrefsRepository());
      await repo.setActiveGroup(
          (await repo.addGroup('团', '🧭')).id);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: Scaffold(body: LedgerHomeScreen())),
      ));
      await tester.pump();
      expect(find.byType(SkeletonBox), findsWidgets,
          reason: '首帧渲染骨架点位');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBox), findsNothing,
          reason: 'morph 完成后骨架退场');
    });

    test('行程域三处点位接入 AnimatedSwitcher（文件断言）', () {
      final trips = File('lib/features/trips/screens/trips_home_screen.dart')
          .readAsStringSync();
      final detail =
          File('lib/features/trips/screens/trip_detail_screen.dart')
              .readAsStringSync();
      expect(trips.contains('AnimatedSwitcher('), isTrue);
      expect(detail.contains('AnimatedSwitcher('), isTrue);
      expect(detail.contains('detail-skeleton'), isTrue);
      final expenses =
          File('lib/features/ledger/screens/expenses_screen.dart')
              .readAsStringSync();
      expect(expenses.contains('expenses-skeleton'), isTrue);
    });
  });

  // ===========================================================================
  // 统计页图表生长（终态回归）+ PressableScale 接线
  // ===========================================================================
  group('S6-5 统计图表与行程域按压缩放', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
    });
    tearDown(() async => db.close());

    testWidgets('统计页：扇区图与每日柱状在生长动画后正常呈现', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
      expect(find.text('钱都花在哪儿'), findsOneWidget);
      expect(find.text('最近每天花多少'), findsOneWidget);
    });

    testWidgets('行程首页：行程卡包 PressableScale（S6 行程域接线）', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final prefs = await SharedPreferences.getInstance();
      await TripsRepository(db)
          .createTrip(name: '大理行', dest: '大理', start: 10, end: 12);
      final router = GoRouter(initialLocation: '/trips', routes: [
        GoRoute(
            path: '/trips',
            builder: (_, _) => const TripsHomeScreen()),
        GoRoute(
            path: '/trips/detail',
            builder: (_, _) => const SizedBox.shrink()),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(PressableScale), findsWidgets,
          reason: '行程卡已接按压缩放');
    });

    test('快捷卡 PressableScale 接线（文件断言）', () {
      final src = File('lib/features/trips/screens/trip_detail_screen.dart')
          .readAsStringSync();
      expect(src.contains('child: PressableScale('), isTrue,
          reason: '详情页快捷卡 action() 已包 PressableScale');
    });
  });

  // ===========================================================================
  // 统一确认抽屉回归（弹层收尾的组件面）
  // ===========================================================================
  group('S6-6 showConfirmSheet / showDangerConfirm', () {
    testWidgets('确认抽屉：点确认返回 true', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late Future<bool> future;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        return Center(
          child: TextButton(
            onPressed: () =>
                future = showConfirmSheet(context: context, title: '确认吗', body: '影响 1 项'),
            child: const Text('OPEN'),
          ),
        );
      })));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('确认吗'), findsOneWidget);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('确认抽屉：点取消返回 false', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late Future<bool> future;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        return Center(
          child: TextButton(
            onPressed: () =>
                future = showConfirmSheet(context: context, title: '确认吗', body: 'b'),
            child: const Text('OPEN'),
          ),
        );
      })));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
    });

    testWidgets('危险确认强断言：body 不含影响数量 → AssertionError（debug 拦截）',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        }),
      ));
      expect(
        () => showDangerConfirm(
            context: captured, title: '删', body: '没有数字的后果行'),
        throwsA(isA<AssertionError>()),
        reason: 'L2 强确认口径：danger 弹层 body 必须含影响数量',
      );
    });
  });

  // ===========================================================================
  // 弹层收尾门禁（文件扫描）
  // ===========================================================================
  group('S6-7 AlertDialog 清零（B7 门禁）', () {
    List<File> dartFiles(String dir) {
      final out = <File>[];
      final d = Directory(dir);
      if (!d.existsSync()) return out;
      for (final e in d.listSync(recursive: true)) {
        if (e is File && e.path.endsWith('.dart')) out.add(e);
      }
      return out;
    }

    test('grep AlertDialog( in lib/features = 0', () {
      final offenders = <String>[];
      for (final f in dartFiles('lib/features')) {
        if (f.readAsStringSync().contains('AlertDialog(')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty, reason: 'B7：全 App 模态唯一形态 = 抽屉');
    });

    test('showDangerConfirmSheet 旧函数已删除（并入 confirm_sheet）', () {
      for (final f in dartFiles('lib')) {
        expect(f.readAsStringSync().contains('showDangerConfirmSheet'), isFalse,
            reason: '${f.path} 仍引用旧函数');
      }
    });

    test('trips 域桌面弹窗迁移（day_ops / outline / workbench / sync / checklist）',
        () {
      final files = [
        'lib/features/trips/widgets/day_ops_sheet.dart',
        'lib/features/trips/widgets/outline_panel.dart',
        'lib/features/trips/desktop_trips_workbench.dart',
        'lib/features/desktop/sync/desktop_sync_center.dart',
        'lib/features/checklist/desktop_checklist_workbench.dart',
        'lib/features/companions/screens/space_detail_screen.dart',
      ];
      for (final path in files) {
        final src = File(path).readAsStringSync();
        expect(src.contains('AlertDialog('), isFalse, reason: path);
        expect(
            src.contains('showDraggableSheet') ||
                src.contains('showConfirmSheet') ||
                src.contains('showDangerConfirm'),
            isTrue,
            reason: '$path 应走统一抽屉');
      }
    });
  });
}
