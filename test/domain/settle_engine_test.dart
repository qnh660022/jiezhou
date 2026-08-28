import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/settle_engine.dart';
import 'package:travel_assistant/domain/share_splitter.dart';

MemberRecord _m(String id) => MemberRecord(id: id, name: '成员$id');

ExpenseRecord _bill(
  String id, {
  required List<ShareEntry> payers,
  List<ShareEntry>? shares,
  ExpenseType type = ExpenseType.normal,
  int? amountCents,
  String? settledRoundId,
}) =>
    ExpenseRecord(
      id: id,
      groupId: 'g1',
      dateEpochDay: 19000,
      title: '账单$id',
      categoryKey: 'other',
      type: type,
      amountCents: amountCents ?? payers.fold<int>(0, (s, p) => s + p.cents),
      currency: 'CNY',
      rate: 1,
      payers: payers,
      shares: shares ?? [],
      settledRoundId: settledRoundId,
    );

List<ShareEntry> _eq(int cents, List<String> ids) =>
    splitShares(totalCents: cents, memberIds: ids);

void main() {
  final members = [_m('a'), _m('b'), _m('c')];

  group('computeNetBalances 口径', () {
    test('三角债：一人垫付三人均摊', () {
      final bal = computeNetBalances(members, [
          _bill('e1', payers: const [ShareEntry(memberId: 'a', cents: 300)],
              shares: _eq(300, ['a', 'b', 'c'])),
        ],
      );
      expect(bal, {'a': 200, 'b': -100, 'c': -100});
    });

    test('多人付款求和', () {
      final bal = computeNetBalances(members, [
          _bill('e1',
              payers: const [ShareEntry(memberId: 'a', cents: 80),
                             ShareEntry(memberId: 'b', cents: 40)],
              shares: _eq(120, ['a', 'b', 'c'])),
        ],
      );
      expect(bal, {'a': 40, 'b': 0, 'c': -40});
    });

    test('refund 负数参与冲减', () {
      final bal = computeNetBalances(members, [
          _bill('e1',
              type: ExpenseType.refund,
              amountCents: -60,
              payers: const [ShareEntry(memberId: 'a', cents: -60)],
              shares: _eq(-60, ['a', 'b', 'c'])),
        ],
      );
      expect(bal, {'a': -40, 'b': 20, 'c': 20});
    });

    test('prepay 纳入净额，垫付方参与 AA', () {
      // c 预垫 900，四人均摊时 c 应收回 900-900/4*... 简化：a/b 各摊 300
      final bal = computeNetBalances(members, [
          _bill('p1',
              type: ExpenseType.prepay,
              payers: const [ShareEntry(memberId: 'c', cents: 900)],
              shares: const [
                ShareEntry(memberId: 'a', cents: 300),
                ShareEntry(memberId: 'b', cents: 300),
                ShareEntry(memberId: 'c', cents: 300),
              ]),
        ],
      );
      expect(bal, {'a': -300, 'b': -300, 'c': 600});
    });

    test('已结算账单不计入', () {
      final bal = computeNetBalances(members, [
          _bill('old', settledRoundId: 'r9',
              payers: const [ShareEntry(memberId: 'b', cents: 70)],
              shares: _eq(70, ['a', 'b'])),
        ],
      );
      expect(bal, {'a': 0, 'b': 0, 'c': 0});
    });

    test('综合叠加场景', () {
      final expenses = [
        _bill('e1', payers: const [ShareEntry(memberId: 'a', cents: 300)],
            shares: _eq(300, ['a', 'b', 'c'])),
        _bill('e2',
            payers: const [ShareEntry(memberId: 'a', cents: 80),
                           ShareEntry(memberId: 'b', cents: 40)],
            shares: _eq(120, ['a', 'b', 'c'])),
        _bill('e3',
            type: ExpenseType.refund,
            amountCents: -60,
            payers: const [ShareEntry(memberId: 'a', cents: -60)],
            shares: _eq(-60, ['a', 'b', 'c'])),
        _bill('p1',
            type: ExpenseType.prepay,
            payers: const [ShareEntry(memberId: 'c', cents: 900)],
            shares: const [ShareEntry(memberId: 'c', cents: 900)]),
        _bill('old', settledRoundId: 'r9',
            payers: const [ShareEntry(memberId: 'b', cents: 70)],
            shares: _eq(70, ['a', 'b'])),
      ];
      final bal = computeNetBalances(members, expenses);
      expect(bal, {'a': 200, 'b': -80, 'c': -120});
    });
  });

  group('minTransferPlan 贪心方案', () {
    test('三角债两笔清零且确定性排序', () {
      const bal = {'a': 200, 'b': -100, 'c': -100};
      final plan = minTransferPlan(bal);
      expect(plan, const [
        TransferPlan(from: 'b', to: 'a', cents: 100),
        TransferPlan(from: 'c', to: 'a', cents: 100),
      ]);
      expect(validatePlan(plan, bal), isTrue);
    });

    test('不等额抵消合并', () {
      const bal = {'a': 200, 'b': -80, 'c': -120};
      final plan = minTransferPlan(bal);
      // 应付降序：c(120) 先与 a 抵消 120，再 b(80)
      expect(plan, const [
        TransferPlan(from: 'c', to: 'a', cents: 120),
        TransferPlan(from: 'b', to: 'a', cents: 80),
      ]);
      expect(validatePlan(plan, bal), isTrue);
    });

    test('全零无方案', () {
      expect(minTransferPlan({'a': 0, 'b': 0}), isEmpty);
    });

    test('复杂多方互抵', () {
      const bal = {'a': 90, 'b': -30, 'c': -25, 'd': -35};
      final plan = minTransferPlan(bal);
      expect(plan.length, lessThanOrEqualTo(3));
      expect(validatePlan(plan, bal), isTrue);
    });
  });

  group('validatePlan 守恒校验', () {
    test('合法方案通过', () {
      const bal = {'a': 100, 'b': -60, 'c': -40};
      final plan = minTransferPlan(bal);
      expect(validatePlan(plan, bal), isTrue);
    });

    test('净额不为零直接否决', () {
      const bal = {'a': 5, 'b': 0};
      expect(validatePlan(const [], bal), isFalse);
    });

    test('抽掉一笔即失败', () {
      const bal = {'a': 200, 'b': -100, 'c': -100};
      final plan = minTransferPlan(bal)..removeLast();
      expect(validatePlan(plan, bal), isFalse);
    });

    test('金额非正/自转/未知账户失败', () {
      const bal = {'a': 100, 'b': -100};
      expect(
        validatePlan(const [TransferPlan(from: 'b', to: 'a', cents: 0)], bal),
        isFalse,
      );
      expect(
        validatePlan(const [TransferPlan(from: 'a', to: 'a', cents: 100)], bal),
        isFalse,
      );
      expect(
        validatePlan(const [TransferPlan(from: 'b', to: 'zz', cents: 100)], bal),
        isFalse,
      );
    });

    test('空方案对全零账本成立', () {
      expect(validatePlan(const [], {'a': 0, 'b': 0}), isTrue);
    });
  });
}
