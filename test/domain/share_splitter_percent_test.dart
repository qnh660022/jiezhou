// V2.7.1 S3 · B1：百分比分摊（自动归一，万分比 bp）。
// 红线：全流程整数运算；Σbp 恒 10000；分摊结果 Σ 恒等于 totalCents。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/settle_engine.dart';
import 'package:travel_assistant/domain/share_splitter.dart';

void main() {
  group('normalizePercentToBp', () {
    test('已守恒输入（33.33/33.33/33.34）保持逐位不变且 Σ==10000', () {
      final bp = normalizePercentToBp({'a': 3333, 'b': 3333, 'c': 3334});
      expect(bp['a'], 3333);
      expect(bp['b'], 3333);
      expect(bp['c'], 3334);
      expect(bp.values.fold<int>(0, (s, v) => s + v), 10000);
    });

    test('三人各 1 → 归一为 3334/3333/3333（平局按 id 字典序补 1）', () {
      final bp = normalizePercentToBp({'a': 1, 'b': 1, 'c': 1});
      expect(bp['a'], 3334, reason: '余数平局 → id 字典序最小者 +1');
      expect(bp['b'], 3333);
      expect(bp['c'], 3333);
      expect(bp.values.fold<int>(0, (s, v) => s + v), 10000);
    });

    test('Σ≠100% 自动按比例归一（不报错）', () {
      final bp = normalizePercentToBp({'a': 10, 'b': 30});
      expect(bp, {'a': 2500, 'b': 7500});
    });

    test('剔除 bp<=0 成员', () {
      final bp = normalizePercentToBp({'a': 0, 'b': 5, 'c': -3});
      expect(bp, {'b': 10000});
    });

    test('全 0 / 全负 / 空表 → 空 Map（调用方回退 equal）', () {
      expect(normalizePercentToBp({'a': 0, 'b': 0}), isEmpty);
      expect(normalizePercentToBp({'a': -1}), isEmpty);
      expect(normalizePercentToBp(const {}), isEmpty);
    });
  });

  group('splitByPercent', () {
    test('33.33/33.33/33.34 分摊 100.00 元：Σ == 总额', () {
      final shares = splitByPercent(10000, {'a': 3333, 'b': 3333, 'c': 3334});
      expect(shares.map((s) => s.cents).fold<int>(0, (s, v) => s + v), 10000);
      expect(shares.firstWhere((s) => s.memberId == 'c').cents, 3334);
    });

    test('两人 70/30，金额 ¥0.01 → 0.01 / 0（余数归首位）', () {
      final shares = splitByPercent(1, {'a': 7000, 'b': 3000});
      expect(shares.firstWhere((s) => s.memberId == 'a').cents, 1);
      expect(shares.firstWhere((s) => s.memberId == 'b').cents, 0);
    });

    test('负数退款：符号正确，Σ == totalCents', () {
      final shares = splitByPercent(-7, {'a': 5000, 'b': 5000});
      final sum = shares.fold<int>(0, (s, e) => s + e.cents);
      expect(sum, -7);
      expect(shares.every((s) => s.cents <= 0), isTrue);
    });

    test('大额 + 除不尽：Σ 严格守恒', () {
      const total = 999999;
      final shares = splitByPercent(total, {'a': 3333, 'b': 3333, 'c': 3334});
      expect(shares.fold<int>(0, (s, e) => s + e.cents), total);
    });

    test('空表返回空结果', () {
      expect(splitByPercent(100, const {}), isEmpty);
    });
  });

  group('splitShares(percent) 端到端', () {
    test('未归一输入自动归一：1/1/1 → 3334/3333/3333 且守恒', () {
      final shares = splitShares(
        totalCents: 10000,
        memberIds: const ['a', 'b', 'c'],
        mode: ShareMode.percent,
        portions: const {'a': 1, 'b': 1, 'c': 1},
      );
      expect(shares.map((s) => s.cents).toList(), [3334, 3333, 3333]);
      expect(shares.fold<int>(0, (s, e) => s + e.cents), 10000);
    });

    test('Σ≠100% 不报错且正常分摊', () {
      final shares = splitShares(
        totalCents: 10000,
        memberIds: const ['a', 'b'],
        mode: ShareMode.percent,
        portions: const {'a': 10, 'b': 30},
      );
      expect(shares.map((s) => s.cents).toList(), [2500, 7500]);
    });

    test('全 0 / 全空 → 回退 equal', () {
      final zero = splitShares(
        totalCents: 900,
        memberIds: const ['a', 'b', 'c'],
        mode: ShareMode.percent,
        portions: const {'a': 0, 'b': 0, 'c': 0},
      );
      expect(zero.map((s) => s.cents).toList(), [300, 300, 300]);
      final empty = splitShares(
        totalCents: 900,
        memberIds: const ['a', 'b', 'c'],
        mode: ShareMode.percent,
      );
      expect(empty.map((s) => s.cents).toList(), [300, 300, 300]);
    });

    test('未参与成员按 0 补齐且顺序与 memberIds 一致', () {
      final shares = splitShares(
        totalCents: 10000,
        memberIds: const ['a', 'b', 'c'],
        mode: ShareMode.percent,
        portions: const {'a': 4000, 'c': 6000},
      );
      expect(shares.map((s) => s.memberId).toList(), ['a', 'b', 'c']);
      expect(shares.map((s) => s.cents).toList(), [4000, 0, 6000]);
    });

    test('负数退款：符号正确且守恒', () {
      final shares = splitShares(
        totalCents: -100,
        memberIds: const ['a', 'b'],
        mode: ShareMode.percent,
        portions: const {'a': 3333, 'b': 6667},
      );
      expect(shares.fold<int>(0, (s, e) => s + e.cents), -100);
    });

    test('percentSplitBalanced 自检', () {
      final shares = splitByPercent(10000, {'a': 3333, 'b': 6667});
      expect(percentSplitBalanced(shares, 10000), isTrue);
      expect(percentSplitBalanced(shares, 9999), isFalse);
    });
  });

  group('含百分比分摊的账单参与结算', () {
    test('净额正确且最少转账方案通过 validatePlan', () {
      // a 垫付 100.00，三人按 50%/30%/20% 分摊
      final expense = ExpenseRecord(
        id: 'e1',
        groupId: 'g',
        dateEpochDay: 0,
        title: '百分比账单',
        categoryKey: 'food',
        type: ExpenseType.normal,
        amountCents: 10000,
        currency: 'CNY',
        rate: 1,
        payers: const [ShareEntry(memberId: 'a', cents: 10000)],
        shares: splitShares(
          totalCents: 10000,
          memberIds: const ['a', 'b', 'c'],
          mode: ShareMode.percent,
          portions: const {'a': 5000, 'b': 3000, 'c': 2000},
        ),
        shareMode: ShareMode.percent,
        portions: const {'a': 5000, 'b': 3000, 'c': 2000},
      );
      final balances = computeNetBalances(
        const [
          MemberRecord(id: 'a', name: 'A'),
          MemberRecord(id: 'b', name: 'B'),
          MemberRecord(id: 'c', name: 'C'),
        ],
        [expense],
      );
      expect(balances, {'a': 5000, 'b': -3000, 'c': -2000});
      final plan = minTransferPlan(balances);
      expect(validatePlan(plan, balances), isTrue);
      final moved = plan.fold<int>(0, (s, t) => s + t.cents);
      expect(moved, 5000);
    });
  });
}
