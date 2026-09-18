// V2.7.1 S2 · G3：StatsCalculator 去 dynamic 后的「黄金样本」对比测试。
// 同一固定账单集，全部指标写死预期值，逐项等值（口径逐位不变的回归护栏）。
// 同时覆盖 S6：月度趋势 + 时间范围筛选 + 空月补 0。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/stats_calculator.dart';

MemberRecord _m(String id) => MemberRecord(id: id, name: '成员$id');

ExpenseRecord _e({
  required String id,
  required int day,
  required String cat,
  required int cents,
  ExpenseType type = ExpenseType.normal,
  List<ShareEntry>? payers,
  List<ShareEntry>? shares,
}) =>
    ExpenseRecord(
      id: id,
      groupId: 'g',
      dateEpochDay: day,
      title: id,
      categoryKey: cat,
      type: type,
      amountCents: cents,
      currency: 'CNY',
      rate: 1,
      payers: payers ?? [ShareEntry(memberId: 'a', cents: cents)],
      shares: shares ?? [ShareEntry(memberId: 'a', cents: cents)],
    );

void main() {
  final aug1 = dateToEpochDay(DateTime(2025, 8, 1));
  final aug10 = dateToEpochDay(DateTime(2025, 8, 10));
  final oct5 = dateToEpochDay(DateTime(2025, 10, 5));

  // 黄金样本：8 月两笔 + 10 月一笔 + 一笔预付（跨月，9 月无数据）
  final expenses = <ExpenseRecord>[
    _e(
      id: 'a',
      day: aug1,
      cat: 'food',
      cents: 10000,
      payers: const [ShareEntry(memberId: 'a', cents: 10000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: 5000),
        ShareEntry(memberId: 'b', cents: 5000),
      ],
    ),
    _e(
      id: 'b',
      day: aug10,
      cat: 'ticket',
      cents: -3000,
      type: ExpenseType.refund,
      payers: const [ShareEntry(memberId: 'b', cents: -3000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: -1500),
        ShareEntry(memberId: 'b', cents: -1500),
      ],
    ),
    _e(
      id: 'c',
      day: oct5,
      cat: 'food',
      cents: 5000,
      payers: const [ShareEntry(memberId: 'a', cents: 5000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: 2500),
        ShareEntry(memberId: 'b', cents: 2500),
      ],
    ),
    _e(
      id: 'p',
      day: aug1,
      cat: 'stay',
      cents: 20000,
      type: ExpenseType.prepay,
      payers: const [ShareEntry(memberId: 'a', cents: 20000)],
      shares: const [ShareEntry(memberId: 'a', cents: 20000)],
    ),
  ];

  final members = [_m('a'), _m('b')];

  group('G3 黄金样本：逐项等值', () {
    test('summarize 总览', () {
      final s = summarize(expenses, memberCount: 2);
      expect(s.totalCents, 12000); // 10000 - 3000 + 5000
      expect(s.count, 3); // prepay 不计
      expect(s.prepayTotalCents, 20000);
      expect(s.avgPerPersonCents, 6000);
    });

    test('标量口径：totalCents / countOf / prepayTotalCents', () {
      expect(totalCents(expenses), 12000);
      expect(countOf(expenses), 3);
      expect(prepayTotalCents(expenses), 20000);
    });

    test('memberStatistics：paid/share/balance', () {
      final ms = memberStatistics(members: members, expenses: expenses);
      expect(ms.map((x) => x.member.id), ['a', 'b']);
      // a: 付 10000+5000 = 15000；摊 5000-1500+2500 = 6000
      expect(ms[0].paidCents, 15000);
      expect(ms[0].shareCents, 6000);
      expect(ms[0].balanceCents, 9000);
      // b: 付 -3000；摊 5000-1500+2500 = 6000
      expect(ms[1].paidCents, -3000);
      expect(ms[1].shareCents, 6000);
      expect(ms[1].balanceCents, -9000);
      expect(ms.fold<int>(0, (s, x) => s + x.balanceCents), 0, reason: 'Σbalance 守恒');
    });

    test('paidByMember / shareByMember（includePrepay 开关）', () {
      expect(paidByMember(expenses), {'a': 15000, 'b': -3000});
      expect(paidByMember(expenses, includePrepay: true), {'a': 35000, 'b': -3000});
      expect(shareByMember(expenses), {'a': 6000, 'b': 6000});
      expect(shareByMember(expenses, includePrepay: true), {'a': 26000, 'b': 6000});
    });

    test('totalsByCategory / categoryShares', () {
      expect(totalsByCategory(expenses), {'food': 15000, 'ticket': -3000});
      final cs = categoryShares(expenses);
      expect(cs.map((c) => c.key), ['food', 'ticket']);
      expect(cs[0].percent, 125.0);
      expect(cs[1].percent, -25.0);
    });

    test('totalsByDay', () {
      final byDay = totalsByDay(expenses);
      expect(byDay[aug1], 10000);
      expect(byDay[aug10], -3000);
      expect(byDay[oct5], 5000);
    });

    test('budgetProgress', () {
      final p = budgetProgress(expenses: expenses, budgetCents: 15000)!;
      expect(p.spentCents, 12000);
      expect(p.remainingCents, 3000);
      expect(p.percent, 80);
      expect(budgetProgress(expenses: expenses, budgetCents: null), isNull);
    });
  });

  group('S6 月度趋势与范围筛选', () {
    final now = DateTime(2025, 10, 15);

    test('totalsByMonth：含已结算、不含 prepay、refund 冲减', () {
      final m = totalsByMonth(expenses);
      expect(m, {202508: 7000, 202510: 5000});
    });

    test('totalsByMonth 与 totalsByDay 分层面自洽', () {
      final byDay = totalsByDay(expenses);
      final byMonth = totalsByMonth(expenses);
      var monthSum = 0;
      for (final v in byMonth.values) {
        monthSum += v;
      }
      var daySum = 0;
      for (final v in byDay.values) {
        daySum += v;
      }
      expect(monthSum, daySum);
    });

    test('monthKeysBetween 跨年连续', () {
      final keys = monthKeysBetween(
          dateToEpochDay(DateTime(2025, 11, 3)), dateToEpochDay(DateTime(2026, 2, 9)));
      expect(keys, [202511, 202512, 202601, 202602]);
    });

    test('monthlyTrend(all)：以数据首末月为界', () {
      final t = monthlyTrend(expenses, range: StatsRange.all);
      expect(t.map((e) => e.monthKey), [202508, 202510]);
      expect(t.map((e) => e.cents), [7000, 5000]);
    });

    test('monthlyTrend(thisMonth / lastMonth 空月补 0)', () {
      final thisMonth =
          monthlyTrend(expenses, range: StatsRange.thisMonth, now: now);
      expect(thisMonth, hasLength(1));
      expect(thisMonth.single.monthKey, 202510);
      expect(thisMonth.single.cents, 5000);

      // 9 月无数据 → 折线补 0（不跳点）
      final lastMonth =
          monthlyTrend(expenses, range: StatsRange.lastMonth, now: now);
      expect(lastMonth, hasLength(1));
      expect(lastMonth.single.monthKey, 202509);
      expect(lastMonth.single.cents, 0);
    });

    test('monthlyTrend(thisYear)：12 个月补齐', () {
      final t = monthlyTrend(expenses, range: StatsRange.thisYear, now: now);
      expect(t, hasLength(12));
      expect(t.first.monthKey, 202501);
      expect(t.last.monthKey, 202512);
      expect(t.firstWhere((e) => e.monthKey == 202508).cents, 7000);
      expect(t.firstWhere((e) => e.monthKey == 202509).cents, 0);
      expect(t.firstWhere((e) => e.monthKey == 202510).cents, 5000);
    });

    test('monthlyTrend(custom)：闭区间 + 越界夹取', () {
      final t = monthlyTrend(expenses,
          range: StatsRange.custom,
          customFromEpochDay: aug1,
          customToEpochDay: aug10);
      expect(t.map((e) => e.monthKey), [202508]);
      expect(t.single.cents, 7000);

      // 越界夹到 2015-01-01 ~ 2045-12-31
      final clamped = statsRangeBounds(StatsRange.custom,
          customFromEpochDay: dateToEpochDay(DateTime(1990, 1, 1)),
          customToEpochDay: dateToEpochDay(DateTime(2099, 1, 1)));
      expect(clamped.fromEpochDay, kStatsCustomMinEpochDay);
      expect(clamped.toEpochDay, kStatsCustomMaxEpochDay);
    });

    test('无数据时 all 返回空表', () {
      expect(monthlyTrend(const [], range: StatsRange.all), isEmpty);
    });
  });
}
