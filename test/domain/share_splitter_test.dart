import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/share_splitter.dart';

void main() {
  group('equal 均摊：余数按序每人 +1', () {
    test('除不尽依次补齐', () {
      expect(
        splitShares(totalCents: 100, memberIds: ['a', 'b', 'c']),
        [const ShareEntry(memberId: 'a', cents: 34),
         const ShareEntry(memberId: 'b', cents: 33),
         const ShareEntry(memberId: 'c', cents: 33)],
      );
      // 101 = 34+34+33
      expect(splitShares(totalCents: 101, memberIds: ['a', 'b', 'c']).map((e) => e.cents),
          [34, 34, 33]);
      expect(splitShares(totalCents: 10, memberIds: ['a', 'b', 'c', 'd']).map((e) => e.cents),
          [3, 3, 2, 2]);
    });

    test('整除与零额', () {
      expect(splitShares(totalCents: 90, memberIds: ['a', 'b', 'c']).map((e) => e.cents),
          [30, 30, 30]);
      expect(splitShares(totalCents: 0, memberIds: ['a', 'b']).map((e) => e.cents), [0, 0]);
    });

    test('负数（退款）镜像分摊且守恒', () {
      expect(splitShares(totalCents: -100, memberIds: ['a', 'b', 'c']).map((e) => e.cents),
          [-34, -33, -33]);
      expect(splitShares(totalCents: -101, memberIds: ['a', 'b', 'c']).map((e) => e.cents),
          [-34, -34, -33]);
    });

    test('守恒性质扫描', () {
      for (var total = -305; total <= 305; total += 17) {
        for (final n in [1, 2, 3, 5, 8]) {
          final ids = List.generate(n, (i) => 'm$i');
          final result = splitShares(totalCents: total, memberIds: ids);
          expect(result.map((e) => e.cents).reduce((x, y) => x + y), total,
              reason: 'total=$total n=$n');
        }
      }
    });
  });

  group('portions 按份数最大余数法', () {
    test('基础比例', () {
      final r = splitShares(
        totalCents: 100,
        memberIds: ['a', 'b'],
        mode: ShareMode.portions,
        portions: const {'a': 1, 'b': 2},
      );
      expect(r.map((e) => e.cents), [33, 67], reason: '余数 b(2)>a(1)，剩余 1 分给 b');
    });

    test('余数平局按成员 id 字典序', () {
      final r = splitShares(
        totalCents: 101,
        memberIds: ['b', 'a'], // 故意乱序传入，验证按 id 而非入参顺序
        mode: ShareMode.portions,
        portions: const {'a': 1, 'b': 1},
      );
      expect(r.map((e) => e.cents), [50, 51]); // a 得到多出的 1 分
    });

    test('份数缺失/全 0 回退 equal', () {
      expect(
        splitShares(totalCents: 100, memberIds: ['a', 'b'],
            mode: ShareMode.portions, portions: const {}).map((e) => e.cents),
        [50, 50],
      );
      expect(
        splitShares(totalCents: 100, memberIds: ['a', 'b'],
            mode: ShareMode.portions, portions: const {'a': 0, 'b': 0}).map((e) => e.cents),
        [50, 50],
      );
    });

    test('表中没有的成员按 0 份处理，未知成员被忽略', () {
      final r = splitShares(
        totalCents: 300,
        memberIds: ['a', 'b', 'c'],
        mode: ShareMode.portions,
        portions: const {'a': 2, 'zz': 9}, // zz 不在成员里应被忽略
      );
      expect(r.map((e) => e.cents), [200, 100, 0]);
    });

    test('负数总额镜像守恒', () {
      final r = splitShares(
        totalCents: -301,
        memberIds: ['a', 'b'],
        mode: ShareMode.portions,
        portions: const {'a': 2, 'b': 1},
      );
      expect(r.map((e) => e.cents).reduce((x, y) => x + y), -301);
      expect(r.first.cents, -201);
    });
  });

  group('custom 自定义守恒校验', () {
    const shares = [
      ShareEntry(memberId: 'a', cents: 60),
      ShareEntry(memberId: 'b', cents: 40),
    ];
    test('守恒直接通过并保持原序', () {
      expect(
        splitShares(totalCents: 100, memberIds: ['a', 'b'],
            mode: ShareMode.custom, customShares: shares),
        shares,
      );
    });

    test('不守恒抛 ArgumentError', () {
      expect(
        () => splitShares(totalCents: 99, memberIds: ['a', 'b'],
            mode: ShareMode.custom, customShares: shares),
        throwsArgumentError,
      );
    });

    test('未知成员抛 ArgumentError；缺明细抛 ArgumentError', () {
      expect(
        () => splitShares(totalCents: 100, memberIds: ['a', 'b'],
            mode: ShareMode.custom,
            customShares: const [ShareEntry(memberId: 'x', cents: 100)]),
        throwsArgumentError,
      );
      expect(
        () => splitShares(totalCents: 100, memberIds: ['a', 'b'],
            mode: ShareMode.custom),
        throwsArgumentError,
      );
    });
  });

  test('非法输入', () {
    expect(() => splitShares(totalCents: 10, memberIds: []), throwsArgumentError);
    expect(() => splitShares(totalCents: 10, memberIds: ['a', 'a']), throwsArgumentError);
  });
}
