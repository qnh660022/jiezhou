import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/stats_calculator.dart';

MemberRecord _m(String id) => MemberRecord(id: id, name: '成员$id');

/// 固定场景：正常×2 + 退款 + 预付款
List<ExpenseRecord> fixture() {
  final d1 = dateToEpochDay(DateTime(2025, 8, 25));
  final d2 = d1 + 1;
  return [
    // e1 餐饮 100 元，a 垫付三人摊
    ExpenseRecord(
      id: 'e1', groupId: 'g', dateEpochDay: d1, title: '拉面',
      categoryKey: 'food', type: ExpenseType.normal,
      amountCents: 10000, currency: 'CNY', rate: 1,
      payers: const [ShareEntry(memberId: 'a', cents: 10000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: 4000),
        ShareEntry(memberId: 'b', cents: 3000),
        ShareEntry(memberId: 'c', cents: 3000),
      ],
    ),
    // e2 交通 50 元，仅 a/b 参与
    ExpenseRecord(
      id: 'e2', groupId: 'g', dateEpochDay: d1, title: '地铁',
      categoryKey: 'transport', type: ExpenseType.normal,
      amountCents: 5000, currency: 'CNY', rate: 1,
      payers: const [ShareEntry(memberId: 'b', cents: 5000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: 2500),
        ShareEntry(memberId: 'b', cents: 2500),
      ],
    ),
    // e3 门票退款 -30 元
    ExpenseRecord(
      id: 'e3', groupId: 'g', dateEpochDay: d2, title: '门票退',
      categoryKey: 'ticket', type: ExpenseType.refund,
      amountCents: -3000, currency: 'CNY', rate: 1,
      payers: const [ShareEntry(memberId: 'c', cents: -3000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: -1000),
        ShareEntry(memberId: 'b', cents: -1000),
        ShareEntry(memberId: 'c', cents: -1000),
      ],
    ),
    // e4 预付款 200 元（只进预付合计）
    ExpenseRecord(
      id: 'e4', groupId: 'g', dateEpochDay: d2, title: '酒店押金',
      categoryKey: 'stay', type: ExpenseType.prepay,
      amountCents: 20000, currency: 'CNY', rate: 1,
      payers: const [ShareEntry(memberId: 'a', cents: 20000)],
      shares: const [ShareEntry(memberId: 'a', cents: 20000)],
    ),
  ];
}

void main() {
  final members = [_m('a'), _m('b'), _m('c')];
  final expenses = fixture();

  group('summarize 总览口径', () {
    test('refund 冲减、prepay 单列、人均取整', () {
      final s = summarize(expenses, memberCount: 3);
      expect(s.totalCents, 12000, reason: '100+50-30');
      expect(s.count, 3);
      expect(s.prepayTotalCents, 20000);
      expect(s.avgPerPersonCents, 4000);
    });

    test('空数据与零成员不炸', () {
      final s = summarize(const [], memberCount: 0);
      expect(s.totalCents, 0);
      expect(s.count, 0);
      expect(s.prepayTotalCents, 0);
      expect(s.avgPerPersonCents, 0);
    });
  });

  group('memberStatistics 成员画像', () {
    test('paid/share/balance 且保持传入顺序', () {
      final ms = memberStatistics(members: members, expenses: expenses);
      expect(ms.map((x) => x.member.id), ['a', 'b', 'c']);
      expect(ms[0].paidCents, 10000, reason: '预付款不计入 paid');
      expect(ms[0].shareCents, 5500);
      expect(ms[0].balanceCents, 4500);
      expect(ms[1].paidCents, 5000);
      expect(ms[1].balanceCents, 500);
      expect(ms[2].paidCents, -3000, reason: '退款垫付为负');
      expect(ms[2].balanceCents, -5000);
      // Σbalance 守恒为 0
      expect(ms.fold<int>(0, (s, x) => s + x.balanceCents), 0);
    });
  });

  group('分类与每日', () {
    test('totalsByCategory 含负数冲减', () {
      expect(totalsByCategory(expenses), {'food': 10000, 'transport': 5000, 'ticket': -3000});
    });

    test('categoryShares 降序 + 一位小数百分比', () {
      final cs = categoryShares(expenses);
      expect(cs.map((c) => c.key), ['food', 'transport', 'ticket']);
      expect(cs[0].percent, 83.3);
      expect(cs[1].percent, 41.7);
      expect(cs[2].percent, -25.0);
    });

    test('总额为零时占比恒 0', () {
      final cs = categoryShares(const []);
      expect(cs, isEmpty);
    });

    test('totalsByDay 按日聚合', () {
      final byDay = totalsByDay(expenses);
      final d1 = dateToEpochDay(DateTime(2025, 8, 25));
      expect(byDay[d1], 15000);
      expect(byDay[d1 + 1], -3000);
    });
  });

  group('budgetProgress 预算进度', () {
    test('未设预算返回 null（含 0 与负数）', () {
      expect(budgetProgress(expenses: expenses, budgetCents: null), isNull);
      expect(budgetProgress(expenses: expenses, budgetCents: 0), isNull);
      expect(budgetProgress(expenses: expenses, budgetCents: -1), isNull);
    });

    test('常规区间', () {
      final p = budgetProgress(expenses: expenses, budgetCents: 15000)!;
      expect(p.spentCents, 12000);
      expect(p.remainingCents, 3000);
      expect(p.percent, 80);
    });

    test('精确花完 100%', () {
      final p = budgetProgress(expenses: expenses, budgetCents: 12000)!;
      expect(p.percent, 100);
      expect(p.remainingCents, 0);
    });

    test('超支突破 100% 且剩余为负', () {
      final p = budgetProgress(expenses: expenses, budgetCents: 10000)!;
      expect(p.percent, 120);
      expect(p.remainingCents, -2000);
    });

    test('无支出预算进度为零', () {
      final p = budgetProgress(expenses: const [], budgetCents: 5000)!;
      expect(p.spentCents, 0);
      expect(p.percent, 0);
      expect(p.remainingCents, 5000);
    });
  });
}
