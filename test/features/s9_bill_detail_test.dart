// V2.8.1 S9 · 账单详情抽屉（规格 §十二，4 例）：
// 结清状态胶囊切换 / 谁付了·谁分摊迷你卡 / 编辑62%+删除图标钮 / 精要插槽空态。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/features/ledger/widgets/bill_detail_sheet.dart';
import 'package:travel_assistant/shared/widgets/sheet.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

Future<void> openDetailForTest(BuildContext context, ExpenseRecord expense) {
  return showDraggableSheet<void>(
    context: context,
    builder: (_, scrollController) => BillDetailSheet(
      scrollController: scrollController,
      expense: expense,
      memberName: (id) => '张三',
      icon: '🍜',
    ),
  );
}

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String groupId;
  late String memberId;
  late ExpenseRecord expense;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
    final g = await repo.addGroup('团', '🧭');
    groupId = g.id;
    final m = await repo.addMember(g.id, '张三');
    memberId = m;
    await repo.setActiveGroup(g.id);
    await repo.addExpense(ExpensesCompanion.insert(
      id: 'e1',
      groupId: groupId,
      dateEpochDay: const Value(100),
      title: const Value('午饭'),
      categoryKey: const Value('food'),
      amountCents: const Value(2500),
      payersJson: Value('[{"memberId":"$memberId","cents":2500}]'),
      sharesJson: Value('[{"memberId":"$memberId","cents":2500}]'),
      createdAt: 100,
    ));
    expense = ExpenseRecord(
      id: 'e1',
      groupId: groupId,
      dateEpochDay: 100,
      title: '午饭',
      categoryKey: 'food',
      type: ExpenseType.normal,
      amountCents: 2500,
      currency: 'CNY',
      rate: 1.0,
      payers: [ShareEntry(memberId: memberId, cents: 2500)],
      shares: [ShareEntry(memberId: memberId, cents: 2500)],
      shareMode: ShareMode.equal,
    );
  });
  tearDown(() async => db.close());

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => openDetailForTest(context, expense),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('1. 待结清状态胶囊渲染（amber 语义）', (tester) async {
    await pumpDetail(tester);
    expect(find.text('待结清 · 点此标记两清'), findsOneWidget);
  });

  testWidgets('2. 点状态胶囊 → 标记两清落库', (tester) async {
    await pumpDetail(tester);
    await tester.tap(find.text('待结清 · 点此标记两清'));
    await tester.pumpAndSettle();
    final rows = await db.select(db.expenses).get();
    expect(rows.first.settledRoundId, isNotNull, reason: '结清标记落库');
  });

  testWidgets('3. 谁付了·谁分摊迷你卡（头像行 + 金额 + 模式标签）', (tester) async {
    await pumpDetail(tester);
    expect(find.text('谁付了 · 谁分摊'), findsOneWidget);
    expect(find.text('张三 付款'), findsOneWidget);
    expect(find.text('平均'), findsOneWidget);
  });

  testWidgets('4. 底部动作区：编辑（Filled）+ 删除图标钮；无关联不渲染行程卡',
      (tester) async {
    await pumpDetail(tester);
    expect(find.widgetWithText(FilledButton, '编辑'), findsOneWidget);
    expect(find.byTooltip('删除账单'), findsOneWidget);
    expect(find.text('所属行程'), findsNothing);
  });
}
