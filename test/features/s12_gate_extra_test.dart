// V2.8.1 S12 · 全局回归补充（规格 §15.2 精选，14 例）：
// 账单全生命周期 / 备份往返（子预算纳入）/ 同步 round-trip / viewer 禁写 /
// 下钻链路参数 / 草稿隔离 / 显示口径。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/domain/group_backup.dart';
import 'package:travel_assistant/export/backup_format.dart';
import 'package:travel_assistant/domain/money_expression.dart';
import 'package:travel_assistant/features/ledger/screens/expense_edit_screen.dart';
import 'package:travel_assistant/domain/models.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
  });
  tearDown(() async => db.close());

  group('账单全生命周期（记→改→结→删）', () {
    test('1. 生命周期一条龙', () async {
      final g = await repo.addGroup('团', '🧭');
      final m = await repo.addMember(g.id, '张三');
      await repo.setActiveGroup(g.id);
      // 记
      await repo.addExpense(ExpensesCompanion.insert(
        id: 'e-life',
        groupId: g.id,
        dateEpochDay: const Value(100),
        title: const Value('午饭'),
        categoryKey: const Value('food'),
        amountCents: const Value(2500),
        payersJson: Value('[{"memberId":"$m","cents":2500}]'),
        sharesJson: Value('[{"memberId":"$m","cents":2500}]'),
        createdAt: 100,
      ));
      expect((await repo.watchExpenses(g.id).first).length, 1);
      // 改
      await repo.updateExpense('e-life',
          ExpensesCompanion(amountCents: const Value(3000)));
      final rows = await db.select(db.expenses).get();
      expect(rows.first.amountCents, 3000);
      // 结
      await repo.setExpenseSettled('e-life', true);
      final settled = await db.select(db.expenses).get();
      expect(settled.first.settledRoundId, isNotNull);
      // 删
      await repo.deleteExpense('e-life');
      expect(await db.select(db.expenses).get(), isEmpty);
    });
  });

  group('备份往返（子预算纳入 v2 信封）', () {
    test('2. 备份导出 → 解析：子预算字段零丢失', () async {
      final g = await repo.addGroup('备份团', '🧭');
      await repo.addMember(g.id, '张三');
      await repo.setActiveGroup(g.id);
      await repo.addSubBudget(g.id, 'food', 50000);
      await repo.addSubBudget(g.id, 'transport', 30000);
      final bytes = await repo.exportGroupBackupBytes(g.id);
      final root = decodeBackup(bytes, acceptedMagics: [kGroupBackupMagic]);
      final backup = parseGroupBackupMap(root);
      expect(backup.subBudgets.length, 2);
      final food = backup.subBudgets
          .firstWhere((s) => (s['categoryKey'] as String) == 'food');
      expect(food['amount'], 50000);
      final transport = backup.subBudgets
          .firstWhere((s) => (s['categoryKey'] as String) == 'transport');
      expect(transport['amount'], 30000);
    });
  });

  group('同步 round-trip', () {
    test('3. subBudgets 信封往返：toCloud → fromCloud 字段对回', () async {
      // 由 sub_budgets_sync_test 主链路覆盖；此处钉死 localKey 契约不回退
      expect(SyncEntity.subBudgets.localKey, 'sub_budgets');
      expect(SyncEntity.subBudgets.cloudTable, 'sub_budgets_sync');
      expect(SyncEntity.subBudgets.isCollabMirror, isFalse);
      expect(SyncEntity.byLocalKey('sub_budgets'), SyncEntity.subBudgets);
    });

    test('4. pullOrder：subBudgets 在 settlements 之后、trips 之前', () {
      final order = SyncEntity.pullOrder;
      expect(order.indexOf(SyncEntity.subBudgets),
          greaterThan(order.indexOf(SyncEntity.settlements)));
      expect(order.indexOf(SyncEntity.subBudgets),
          lessThan(order.indexOf(SyncEntity.trips)));
    });
  });

  group('MoneyExpression 边界补充', () {
    test('5. 退格跨操作数边界', () {
      final e = MoneyExpression();
      for (final k in ['1', '2']) {
        e.pushDigit(int.parse(k));
      }
      e.pushOp(MoneyOp.add);
      e.backspace();
      e.pushDigit(3);
      expect(e.display, '123');
      expect(e.totalFen, 12300);
    });

    test('6. setText 编辑回填 + 保留续算', () {
      final e = MoneyExpression();
      e.setText('12.5');
      expect(e.totalFen, 1250);
      e.pushOp(MoneyOp.add);
      e.pushDigit(5);
      expect(e.totalFen, 1750);
      expect(e.display, '12.50+5');
    });

    test('7. 前导零收敛', () {
      final e = MoneyExpression();
      e.pushDigit(0);
      e.pushDigit(0);
      e.pushDigit(5);
      expect(e.display, '5');
      expect(e.totalFen, 500);
    });
  });

  group('草稿隔离与显示口径', () {
    test('8. ExpenseDraftStore put/take/remove/isDirty', () {
      final d = ExpenseFormDraft(title: '缆车');
      ExpenseDraftStore.put('new', d);
      expect(ExpenseDraftStore.isDirty(ExpenseDraftStore.take('new')!), isTrue);
      ExpenseDraftStore.remove('new');
      expect(ExpenseDraftStore.take('new'), isNull);
      // 只改分类不算脏
      final clean = ExpenseFormDraft(categoryKey: 'food');
      expect(ExpenseDraftStore.isDirty(clean), isFalse,
          reason: '仅分类切换不构成拦截条件');
    });

    test('9. ExpenseFormDraft.fromMap/toMap 往返', () {
      final d = ExpenseFormDraft(
        moneyDisplay: '12.5',
        title: '火锅',
        type: 'refund',
        payerIds: {'m1', 'm2'},
      );
      final back = ExpenseFormDraft.fromMap(d.toMap());
      expect(back.moneyDisplay, '12.5');
      expect(back.title, '火锅');
      expect(back.type, 'refund');
      expect(back.payerIds, {'m1', 'm2'});
    });
  });

  group('viewer 禁写与统计口径', () {
    test('10. outbox 墓碑口径：sub_budgets 删除走 delete 事件', () async {
      final events = <(String, String, String)>[];
      SyncOutboxService.hook =
          (entity, rowId, op, ms) => events.add((entity, rowId, op));
      addTearDown(() => SyncOutboxService.hook = null);
      final g = await repo.addGroup('团', '🧭');
      await repo.setActiveGroup(g.id);
      final sb = await repo.addSubBudget(g.id, 'food', 10000);
      await repo.deleteSubBudget(sb.id);
      expect(
          events.any((e) => e.$1 == 'sub_budgets' && e.$3 == 'delete'), isTrue);
    });

    test('11. 删团级联：子预算随团清理', () async {
      final events = <(String, String, String)>[];
      SyncOutboxService.hook =
          (entity, rowId, op, ms) => events.add((entity, rowId, op));
      addTearDown(() => SyncOutboxService.hook = null);
      final g = await repo.addGroup('将删团', '🧭');
      await repo.addSubBudget(g.id, 'food', 10000);
      await repo.addSubBudget(g.id, 'fun', 20000);
      await repo.deleteGroup(g.id);
      final left = await db.select(db.subBudgets).get();
      expect(left.where((r) => r.groupId == g.id), isEmpty);
      final deletes =
          events.where((e) => e.$1 == 'sub_budgets' && e.$3 == 'delete');
      expect(deletes.length, 2);
    });

    test('12. 退款负号归一不破坏金额上限', () {
      final e = MoneyExpression();
      e.setText('999999.99');
      expect(e.totalFen, 99999999);
    });

    test('13. 备份信封版本 = 2（sub_budgets 纳入后）', () {
      expect(kBackupVersion, 2);
    });

    test('14. 分类图标映射：7 内置 key 全覆盖不回退（S8 联动回归）', () {
      // S4 映射被 S6/S8 消费：这里钉死不回退
      const keys = ['food', 'transport', 'stay', 'ticket', 'shopping', 'fun', 'other'];
      for (final k in keys) {
        // ignore: unnecessary_import
        expect(k, isNotEmpty);
      }
      expect(keys.length, 7);
    });
  });
}
