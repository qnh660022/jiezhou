// V2.7.1 S9 · N2：结算策略（最少笔数 / 最少人参与）。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/settle_engine.dart';
import 'package:travel_assistant/domain/settle_strategy.dart';

void main() {
  List<TransferPlan> plan(Map<String, int> b, SettleStrategy s) =>
      buildPlan(balances: b, strategy: s);

  group('minTransfers 逐位不变（黄金样本回归）', () {
    final fixtures = <Map<String, int>>[
      {'a': 92500, 'b': 92500, 'c': 92500, 'd': -277500},
      {'a': 100, 'b': -100},
      {'a': 3000, 'b': -1000, 'c': -2000},
      {'a': 0, 'b': 500, 'c': -500},
      {'a': 1000, 'b': 1000, 'c': -1500, 'd': -500},
    ];

    test('与 settle_engine.minTransferPlan 输出完全一致', () {
      for (final f in fixtures) {
        final expected = minTransferPlan(f);
        final actual = plan(f, SettleStrategy.minTransfers);
        expect(actual.length, expected.length, reason: '$f 笔数不一致');
        for (var i = 0; i < expected.length; i++) {
          expect(actual[i].from, expected[i].from);
          expect(actual[i].to, expected[i].to);
          expect(actual[i].cents, expected[i].cents);
        }
      }
    });

    test('恒通过 validatePlan', () {
      for (final f in fixtures) {
        expect(validatePlan(plan(f, SettleStrategy.minTransfers), f), isTrue);
      }
    });
  });

  group('minParticipants 守恒与自检', () {
    final fixtures = <Map<String, int>>[
      {'a': 92500, 'b': 92500, 'c': 92500, 'd': -277500},
      {'a': 3000, 'b': -1000, 'c': -2000},
      {'a': 1000, 'b': 1000, 'c': -1500, 'd': -500},
      {'a': 7, 'b': -3, 'c': -4},
      {'a': 1, 'b': 1, 'c': 1, 'd': -3},
    ];

    test('全部通过 validatePlan', () {
      for (final f in fixtures) {
        final p = plan(f, SettleStrategy.minParticipants);
        expect(validatePlan(p, f), isTrue, reason: '$f 未通过守恒自检');
      }
    });

    test('Σ转出 == Σ转入 == Σ|净额|/2', () {
      for (final f in fixtures) {
        final p = plan(f, SettleStrategy.minParticipants);
        var out = 0;
        for (final t in p) {
          out += t.cents;
        }
        var halfAbs = 0;
        for (final v in f.values) {
          halfAbs += v.abs();
        }
        expect(out * 2, halfAbs);
      }
    });

    test('参与人数 ≤ minTransfers 方案', () {
      for (final f in fixtures) {
        final a = participantCount(plan(f, SettleStrategy.minTransfers));
        final b = participantCount(plan(f, SettleStrategy.minParticipants));
        expect(b, lessThanOrEqualTo(a), reason: '$f');
      }
    });

    test('确定性：同输入同输出', () {
      for (final f in fixtures) {
        expect(plan(f, SettleStrategy.minParticipants).map((t) => t.toString()).toList(),
            plan(f, SettleStrategy.minParticipants).map((t) => t.toString()).toList());
      }
    });

    test('枢纽集中：最大欠款方一次付清多个应收方', () {
      // 4 个应收方 + 1 个大的欠款方 → 由枢纽依次支付
      final b = {'m1': -400, 'm2': 100, 'm3': 100, 'm4': 100, 'm5': 100};
      final p = plan(b, SettleStrategy.minParticipants);
      expect(p, hasLength(4));
      for (final t in p) {
        expect(t.from, 'm1');
      }
      expect(validatePlan(p, b), isTrue);
    });

    test('枢纽为应收方时由各欠款方分别支付', () {
      final b = {'m1': 400, 'm2': -100, 'm3': -100, 'm4': -100, 'm5': -100};
      final p = plan(b, SettleStrategy.minParticipants);
      expect(p, hasLength(4));
      for (final t in p) {
        expect(t.to, 'm1');
      }
      expect(validatePlan(p, b), isTrue);
    });
  });

  group('边界', () {
    test('全零 / 空余额 → 空方案', () {
      expect(plan(const {}, SettleStrategy.minParticipants), isEmpty);
      expect(plan({'a': 0, 'b': 0}, SettleStrategy.minParticipants), isEmpty);
      expect(plan(const {}, SettleStrategy.minTransfers), isEmpty);
    });

    test('两人对平 → 一笔', () {
      final b = {'a': 100, 'b': -100};
      for (final s in SettleStrategy.values) {
        final p = plan(b, s);
        expect(p, hasLength(1));
        expect(p.single.from, 'b');
        expect(p.single.to, 'a');
        expect(p.single.cents, 100);
      }
    });

    test('余额不守恒（Σ≠0）→ validatePlan 拒 → 抛异常', () {
      expect(() => plan({'a': 100, 'b': -50}, SettleStrategy.minParticipants),
          throwsA(isA<StateError>()));
    });

    test('同额平局按成员 id 字典序（确定性破平）', () {
      final b = {'b': 100, 'a': 100, 'c': -200};
      final p = plan(b, SettleStrategy.minTransfers);
      expect(p.first.from, 'c');
      expect(p.first.to, 'a', reason: '同额按 id 升序');
    });

    test('participantCount 统计不同账户数', () {
      expect(
          participantCount(const [
            TransferPlan(from: 'a', to: 'b', cents: 1),
            TransferPlan(from: 'a', to: 'c', cents: 1),
          ]),
          3);
      expect(participantCount(const []), 0);
    });
  });
}
