import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/budget_alert_engine.dart';

void main() {
  group('evaluateAlerts 三级阈值', () {
    test('预算关闭或额度 <=0 一律空', () {
      expect(evaluateAlerts(enabled: false, budgetCents: 10000, spentCents: 9999), isEmpty);
      expect(evaluateAlerts(enabled: true, budgetCents: 0, spentCents: 5), isEmpty);
      expect(evaluateAlerts(enabled: true, budgetCents: -1, spentCents: 5), isEmpty);
    });

    test('未过半不触发', () {
      // 49%
      expect(evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 4999), isEmpty);
    });

    test('恰 50% 命中 info（边界含等于）且仅 info', () {
      final a = evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 5000);
      expect(a.map((e) => e.level), [BudgetAlertLevel.info]);
      expect(a.first.percent, 50);
      expect(a.first.messageCn, contains('50'));
    });

    test('79% 仅 info；恰 80% info+warning', () {
      expect(evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 7900)
          .map((e) => e.level), [BudgetAlertLevel.info]);
      final a = evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 8000);
      expect(a.map((e) => e.level),
          [BudgetAlertLevel.info, BudgetAlertLevel.warning]);
      expect(a.last.messageCn, contains('剩余'));
    });

    test('99% 不超支；恰 100% 三级全中按升序', () {
      expect(evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 9999)
          .map((e) => e.level), [BudgetAlertLevel.info, BudgetAlertLevel.warning]);
      final a = evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 10000);
      expect(a.map((e) => e.level),
          [BudgetAlertLevel.info, BudgetAlertLevel.warning, BudgetAlertLevel.danger]);
      expect(a.last.messageCn, contains('刚好用完'));
    });

    test('超支场景文案带超支额与百分比可超 100', () {
      final a = evaluateAlerts(enabled: true, budgetCents: 10000, spentCents: 20000);
      final danger = a.last;
      expect(danger.level, BudgetAlertLevel.danger);
      expect(danger.percent, 200);
      expect(danger.messageCn, contains('超支'));
      expect(danger.messageCn, contains('100.00')); // 超支 ¥100.00
    });

    test('向下取整口径：spent*100/budget 截断后判定', () {
      // 7999.9/10000 = 79.999% -> floor 79，不触发 warning
      expect(evaluateAlerts(enabled: true, budgetCents: 100000, spentCents: 79999)
          .map((e) => e.level), [BudgetAlertLevel.info]);
    });
  });
}
