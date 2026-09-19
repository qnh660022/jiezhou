// V2.8.1 S5 · 记一笔键盘化（规格 §8.6，≥18 例）：
// 连算 6 / 键盘 2 / 折叠组 3 / 草稿 3 / 记忆 2 / 再记一笔 1 / 蒙层 1 / 校验 2。
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
import 'package:travel_assistant/domain/money_expression.dart';
import 'package:travel_assistant/features/ledger/screens/expense_edit_screen.dart';
import 'package:travel_assistant/features/ledger/widgets/amount_keypad.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

void main() {
  group('MoneyExpression 连算（纯函数 6 例）', () {
    MoneyExpression exprFrom(List<Object> keys) {
      final e = MoneyExpression();
      for (final k in keys) {
        if (k is int) {
          e.pushDigit(k);
        } else if (k == '+') {
          e.pushOp(MoneyOp.add);
        } else if (k == '-') {
          e.pushOp(MoneyOp.subtract);
        } else if (k == '.') {
          e.pushDot();
        }
      }
      return e;
    }

    test('1. 合法序 [5,8,+,3,2] → 90 分', () {
      final e = exprFrom([5, 8, '+', 3, 2]);
      expect(e.display, '58+32');
      expect(e.totalFen, 9000);
    });

    test('2. 连续运算符 → 忽略非法键（第二个及以后）', () {
      final e = exprFrom([5, '+', '-', 3]);
      expect(e.display, '5+3', reason: '连续运算符：仅首个生效，其余忽略');
      expect(e.totalFen, 800);
    });

    test('3. 开头运算符 → 忽略', () {
      final e = exprFrom(['+', 5, 8]);
      expect(e.display, '58');
      expect(e.totalFen, 5800);
    });

    test('4. 小数进位：0.1+0.02 → 12 分（分域截断 ≤2 位）', () {
      final e = exprFrom([0, '.', 1, '+', 0, '.', 0, 2]);
      expect(e.totalFen, 12);
    });

    test('5. 上限 99,999,999 分：溢出 → null / 拒绝继续输入', () {
      // 整数位最多 6 个 9：999999 元 = 99999900 分；第 7 位会被拒
      final e = exprFrom([9, 9, 9, 9, 9, 9, 9, 9]);
      expect(e.totalFen, 99999900);
      e.pushDot();
      e.pushDigit(9);
      e.pushDigit(9); // 999999.99 元 = 上限 99999999 分
      expect(e.totalFen, 99999999);
      e.pushDigit(9); // 小数第三位 → 拒绝
      expect(e.totalFen, 99999999);
      final big = exprFrom([9, 9, 9, 9, 9, 9, '.', 9, 9, '+', 1]);
      expect(big.display, '999999.99+1');
      expect(big.totalFen, isNull, reason: '合计溢出 → null');
    });

    test('6. 清空 / 退格 / 结尾运算符', () {
      final e = exprFrom([5, 8, '+']);
      expect(e.totalFen, isNull, reason: '结尾运算符 = 无有效合计');
      e.backspace(); // 删掉 +
      expect(e.display, '58');
      e.clear();
      expect(e.isEmpty, isTrue);
      expect(e.totalFen, isNull);
    });
  });

  group('记一笔键盘化（屏幕级）', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExpenseDraftStore.remove('new'); // 静态草稿仓库跨用例隔离
      db = AppDatabase();
    });
    tearDown(() async => db.close());

    Future<SharedPreferences> pumpEdit(WidgetTester tester,
        {Map<String, Object> seedPrefs = const {}, String? query}) async {
      // 高视口：键盘化页面内容 + 自定义键盘同屏（ListView 懒构建）
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(seedPrefs);
      final prefs = await SharedPreferences.getInstance();
      final repo = LedgerRepository(db, PrefsRepository());
      final g = await repo.addGroup('个人团', '🧭', kind: 'personal');
      await repo.addMember(g.id, '我');
      await repo.setActiveGroup(g.id);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
          GoRoute(
              path: '/edit',
              builder: (_, __) => const ExpenseEditScreen()),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      // push 语义：蒙层 800ms 后的 context.pop() 才有路可退（与真实进入方式一致）
      router.push('/edit${query ?? ''}');
      await tester.pumpAndSettle();
      return prefs;
    }

    Future<void> typeTitle(WidgetTester tester, String text) async {
      await tester.enterText(find.widgetWithText(TextField, '').first, text);
      await tester.pump();
    }

    testWidgets('7. 完成=保存：金额+标题即可保存（个人账本）并出成功蒙层', (tester) async {
      final prefs = await pumpEdit(tester);
      // 键盘输入 12.5
      for (final d in [1, 2]) {
        await tester.tap(find.text('$d').last);
        await tester.pump();
      }
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('5').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '午饭');
      await tester.pump();
      // 键盘「完成」→ 保存（键盘即保存：页面无第二个保存主按钮）
      await tester.tap(find.bySemanticsLabel('完成并保存'));
      // 只推进少量假时钟：pumpAndSettle 会越过 800ms 触发自动 pop，蒙层就看不到了
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('已记下这一笔'), findsOneWidget, reason: '保存成功蒙层');
      expect(find.byType(ExpenseEditScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      // 落库验证
      final expenses = await db.select(db.expenses).get();
      expect(expenses.length, 1);
      expect(expenses.first.amountCents, 1250);
      expect(expenses.first.title, '午饭');
    });

    testWidgets('8. 校验文案按序：空表单点完成 → 「请填写账单名称」', (tester) async {
      await pumpEdit(tester);
      await tester.tap(find.bySemanticsLabel('完成并保存'));
      await tester.pumpAndSettle();
      expect(find.text('请填写账单名称'), findsOneWidget);
      // 输入金额但不填标题 → 仍是名称校验先行
      await tester.tap(find.text('3').last);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('完成并保存'));
      await tester.pumpAndSettle();
      expect(find.text('请填写账单名称'), findsOneWidget, reason: '校验顺序第一位');
    });

    testWidgets('9. 摘要 chip 与折叠组联动：点 chip 展开对应组、再点收起（互斥）',
        (tester) async {
      await pumpEdit(tester);
      await tester.tap(find.text('💳 支付方式'));
      await tester.pumpAndSettle();
      expect(find.text('现金'), findsOneWidget, reason: '支付方式组展开');
      await tester.tap(find.text('🔗 关联行程'));
      await tester.pumpAndSettle();
      expect(find.text('不关联行程'), findsOneWidget, reason: '切换到行程组');
      expect(find.text('现金'), findsNothing, reason: '一次只展开一组');
      await tester.tap(find.text('🔗 关联行程'));
      await tester.pumpAndSettle();
      expect(find.text('不关联行程'), findsNothing, reason: '再点收起');
    });

    testWidgets('10. 草稿拦截：有脏数据返回 → L2 弹层；确认后草稿可回填', (tester) async {
      final prefs = await pumpEdit(tester);
      await tester.enterText(find.byType(TextField).first, '火锅');
      await tester.pump();
      for (final d in [8, 8]) {
        await tester.tap(find.text('$d').last);
        await tester.pump();
      }
      final dynamic routerState = tester.state(find.byType(Navigator).first);
      routerState.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('放弃这笔账？'), findsOneWidget, reason: 'L2 草稿拦截弹层');
      expect(find.textContaining('¥88'), findsWidgets, reason: '弹层列出当前金额');
      // 「放弃并返回」→ 清除草稿并返回
      await tester.tap(find.text('放弃并返回'));
      await tester.pumpAndSettle();
      // 重新进入 → 草稿已清除（选择的是放弃）
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(path: '/edit', builder: (_, __) => const ExpenseEditScreen()),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '火锅'), findsNothing,
          reason: '「放弃」后草稿清除');
      await tester.pump(const Duration(milliseconds: 500)); // 冲掉汇率刷新定时器
    });

    testWidgets('11. 草稿留存：弹层选「留在本页」→ 手动返回 → 再次进入自动回填',
        (tester) async {
      final prefs = await pumpEdit(tester);
      await tester.enterText(find.byType(TextField).first, '缆车票');
      await tester.pump();
      final dynamic routerState = tester.state(find.byType(Navigator).first);
      routerState.maybePop();
      await tester.pumpAndSettle();
      // 「离开并保留草稿」→ 写入会话草稿并返回
      await tester.tap(find.text('离开并保留草稿'));
      await tester.pumpAndSettle();
      // 重新进入
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(path: '/edit', builder: (_, __) => const ExpenseEditScreen()),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '缆车票'), findsOneWidget,
          reason: '草稿自动回填');
      await tester.pump(const Duration(milliseconds: 500)); // 冲掉汇率刷新定时器
    });

    testWidgets('12. 默认值记忆：新建回填 + 保存后写入 app.exp.recent', (tester) async {
      final prefs = await pumpEdit(tester, seedPrefs: {
        'app.exp.recent':
            '{"categoryKey":"transport","payMethod":"credit","currency":"CNY"}',
      });
      // 保存一笔（未改动分类/支付方式）→ 记忆应保留回填值
      await tester.enterText(find.byType(TextField).first, '地铁');
      await tester.pump();
      await tester.tap(find.text('4').last);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('完成并保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final recent = prefs.getString('app.exp.recent');
      expect(recent, isNotNull, reason: '保存后写入记忆');
      expect(recent!, contains('"payMethod":"credit"'),
          reason: '回填的 payMethod 记忆保留');
      expect(recent, contains('"categoryKey":"transport"'),
          reason: '回填的 categoryKey 记忆保留');
      await tester.pump(const Duration(milliseconds: 500)); // 冲掉汇率刷新定时器
    });

    testWidgets('13. 无激活团/无成员：引导空态防线（不产生幽灵账单）', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // 不建团、不 setActiveGroup：编辑页必须停在引导空态，无键盘可录账
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
          GoRoute(path: '/edit', builder: (_, __) => const ExpenseEditScreen()),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      router.push('/edit');
      await tester.pumpAndSettle();
      expect(find.text('先拉人再记账'), findsOneWidget,
          reason: '成员为空 → 引导空态（防幽灵账单的 UI 层防线）');
      expect(find.byType(AmountKeypad), findsNothing, reason: '空态下无键盘可录账');
      expect(await db.select(db.expenses).get(), isEmpty, reason: '零账单落库');
      await tester.pump(const Duration(milliseconds: 500)); // 冲掉汇率刷新定时器
    });
  });
}
