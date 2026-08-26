import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/trip_bill_linker.dart';

ExpenseRecord _exp({String? tripItemId, int amount = 1000, int createdAt = 1}) =>
    ExpenseRecord(
      id: 'e$createdAt$tripItemId',
      groupId: 'g1',
      dateEpochDay: 20000,
      title: 't',
      categoryKey: 'other',
      type: ExpenseType.normal,
      amountCents: amount,
      currency: 'CNY',
      rate: 1.0,
      payers: const [],
      shares: const [],
      tripId: 'trip1',
      tripItemId: tripItemId,
    );

void main() {
  group('prefillFromItem 预填', () {
    test('有费用：字段逐一对齐', () {
      final p = prefillFromItem(const TripPlanItem(
          id: 'i1', name: '门票', dateEpochDay: 20100, costCents: 12000));
      expect(p, isNotNull);
      expect(p!.title, '门票');
      expect(p.amountCents, 12000);
      expect(p.currency, 'CNY');
      expect(p.dateEpochDay, 20100);
    });
    test('无费用/零费用返回 null（隐藏一键入账）', () {
      expect(
          prefillFromItem(const TripPlanItem(
              id: 'i2', name: 'x', dateEpochDay: 1)), isNull);
      expect(
          prefillFromItem(const TripPlanItem(
              id: 'i3', name: 'x', dateEpochDay: 1, costCents: 0)), isNull);
    });
  });

  group('plannedVsActual 计划 vs 实际', () {
    test('计划合计仅计 CNY，外币不计和', () {
      final r = plannedVsActual(const [
        TripPlanItem(id: 'a', name: '', dateEpochDay: 1, costCents: 10000),
        TripPlanItem(
            id: 'b',
            name: '',
            dateEpochDay: 1,
            costCents: 5000,
            costCurrency: 'JPY'),
        TripPlanItem(id: 'c', name: '', dateEpochDay: 1),
      ], const []);
      expect(r.plannedCents, 10000);
      // a 与 b 都填了计划费用且均未关联账单（外币只影响计划求和口径）
      expect(r.unlinkedCostItems, 2);
    });
    test('实际合计直加含退款负数；关联计数正确', () {
      final r = plannedVsActual(const [
        TripPlanItem(id: 'a', name: '', dateEpochDay: 1, costCents: 10000),
      ], [
        _exp(tripItemId: 'a', amount: 12000, createdAt: 1),
        _exp(amount: -2000, createdAt: 2),
      ]);
      expect(r.actualCents, 10000);
      expect(r.linkedCount, 2);
      expect(r.unlinkedCostItems, 0);
    });
  });

  group('resolveAmountSync 双向同步（后写生效）', () {
    test('账单侧改动 -> 写安排', () {
      final d = resolveAmountSync(
          expenseAmountCents: 8800,
          itemCostCents: 10000,
          source: SyncSource.expenseEdit);
      expect(d.target, SyncTarget.updateItem);
      expect(d.newAmountCents, 8800);
    });
    test('安排侧改动 -> 写账单', () {
      final d = resolveAmountSync(
          expenseAmountCents: 8800,
          itemCostCents: 6600,
          source: SyncSource.itemEdit);
      expect(d.target, SyncTarget.updateExpense);
      expect(d.newAmountCents, 6600);
    });
    test('相等为 no-op', () {
      expect(
          resolveAmountSync(
                  expenseAmountCents: 500,
                  itemCostCents: 500,
                  source: SyncSource.expenseEdit)
              .target,
          SyncTarget.none);
      expect(
          resolveAmountSync(
                  expenseAmountCents: 500,
                  itemCostCents: 500,
                  source: SyncSource.itemEdit)
              .target,
          SyncTarget.none);
    });
    test('安排侧清空计划费不同步清零账单（约定特例）', () {
      final d = resolveAmountSync(
          expenseAmountCents: 500,
          itemCostCents: null,
          source: SyncSource.itemEdit);
      expect(d.target, SyncTarget.none);
    });
  });
}
