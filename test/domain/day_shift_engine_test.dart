// V2.7.2 S2：增减天数顺延引擎单测（规格 §五 S2.5 ≥12 例）。
// 纯函数，直接构造 TripItemRecord 快照断言输出动作列表。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/day_shift_engine.dart';
import 'package:travel_assistant/domain/records.dart';

TripItemRecord _card(String id, int day, {int sortOrder = 10, String? backupOf}) =>
    TripItemRecord(
      id: id,
      tripId: 't1',
      dateEpochDay: day,
      type: 'attraction',
      name: id,
      address: '',
      sortOrder: sortOrder,
      createdAt: 1000,
      updatedAt: 1000,
      backupOf: backupOf,
    );

/// start=100（第 1 天），N=3 → 100/101/102
const int start = 100;

void main() {
  group('insertDay（第 k 天后插空天）', () {
    test('1. k=0（最前插入）：全部卡 +1，end +1', () {
      final ops = insertDay(
        startEpochDay: start,
        endEpochDay: start + 2,
        items: [_card('a', start), _card('b', start + 2)],
        k: 0,
      );
      expect(
          ops,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'a', newEpochDay: start + 1, newSortOrder: 10),
            OpShiftItem(itemId: 'b', newEpochDay: start + 3, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 3),
          ]));
    });

    test('1. k=N（最后一天后插入）：无卡后移，仅 end +1', () {
      final ops = insertDay(
        startEpochDay: start,
        endEpochDay: start + 2,
        items: [_card('a', start + 2)],
        k: 3,
      );
      expect(ops, [OpSetEnd(newEndEpochDay: start + 3)]);
    });

    test('1. k=N+1 等价 k=N（尾部追加）', () {
      final items = [_card('a', start)];
      expect(
          insertDay(startEpochDay: start, endEpochDay: start + 2, items: items, k: 4),
          insertDay(startEpochDay: start, endEpochDay: start + 2, items: items, k: 3));
    });
  });

  group('removeDay（三选一承接）', () {
    test('2. 删首天 k=1：merge 抛异常（禁用），shift/discard 正确', () {
      const end = start + 2;
      expect(
        () => removeDay(
            startEpochDay: start,
            endEpochDay: end,
            items: [_card('a', start)],
            k: 1,
            mode: RemoveMode.merge),
        throwsStateError,
      );
      // 修正语义：a@100 并入原第 2 天（该天前移成新第 1 天，落在 100）；
      // b@101 → 100（承接序 20 在 b 原 10 之后）；c@102 → 101
      final shiftOps = removeDay(
          startEpochDay: start,
          endEpochDay: end,
          items: [_card('a', start), _card('b', start + 1), _card('c', start + 2)],
          k: 1,
          mode: RemoveMode.shift);
      expect(
          shiftOps,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'a', newEpochDay: start, newSortOrder: 20),
            OpShiftItem(itemId: 'b', newEpochDay: start, newSortOrder: 10),
            OpShiftItem(itemId: 'c', newEpochDay: start + 1, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 1),
          ]));
      final discardOps = removeDay(
          startEpochDay: start,
          endEpochDay: end,
          items: [_card('a', start), _card('b', start + 1), _card('c', start + 2)],
          k: 1,
          mode: RemoveMode.discard);
      expect(
          discardOps,
          orderedEquals(<DayOp>[
            OpDeleteItem(itemId: 'a'),
            // b@101 / c@102 均 > target(100) → 各 -1
            OpShiftItem(itemId: 'b', newEpochDay: start, newSortOrder: 10),
            OpShiftItem(itemId: 'c', newEpochDay: start + 1, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 1),
          ]));
    });

    test('3. 删末天 k=N：shift 抛异常（末天无后一天），discard 正确且 end -1', () {
      expect(
        () => removeDay(
            startEpochDay: start,
            endEpochDay: start + 2,
            items: [_card('a', start + 2, sortOrder: 10)],
            k: 3,
            mode: RemoveMode.shift),
        throwsStateError,
      );
      final ops = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: [_card('a', start + 2, sortOrder: 10)],
          k: 3,
          mode: RemoveMode.discard);
      expect(ops, [OpDeleteItem(itemId: 'a'), OpSetEnd(newEndEpochDay: start + 1)]);
    });

    test('4. 删中间天三种模式逐卡断言', () {
      // N=4：100/101/102/103；k=2 → target=101, target+1=102
      final items = [
        _card('a', start),
        _card('b', start + 1, sortOrder: 10),
        _card('c', start + 1, sortOrder: 20),
        _card('d', start + 2, sortOrder: 10),
        _card('e', start + 3, sortOrder: 10),
      ];
      // shift：b/c 并入原第 3 天（该天前移成新第 2 天，落在 101）；
      // 承接序在 d 原 10 之后 → 20/30；d@102 → 101；e@103 → 102
      final shiftOps = removeDay(
          startEpochDay: start,
          endEpochDay: start + 3,
          items: items,
          k: 2,
          mode: RemoveMode.shift);
      expect(
          shiftOps,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'b', newEpochDay: start + 1, newSortOrder: 20),
            OpShiftItem(itemId: 'c', newEpochDay: start + 1, newSortOrder: 30),
            OpShiftItem(itemId: 'd', newEpochDay: start + 1, newSortOrder: 10),
            OpShiftItem(itemId: 'e', newEpochDay: start + 2, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 2),
          ]));
      // merge：b/c → 100 承接（a 原 10 → 承接序 20/30）；d@102>101 → 101；e@103 → 102
      final mergeOps = removeDay(
          startEpochDay: start,
          endEpochDay: start + 3,
          items: items,
          k: 2,
          mode: RemoveMode.merge);
      expect(
          mergeOps,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'b', newEpochDay: start, newSortOrder: 20),
            OpShiftItem(itemId: 'c', newEpochDay: start, newSortOrder: 30),
            OpShiftItem(itemId: 'd', newEpochDay: start + 1, newSortOrder: 10),
            OpShiftItem(itemId: 'e', newEpochDay: start + 2, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 2),
          ]));
      // discard：b/c 删除；d@102>101 → 101；e@103 → 102
      final discardOps = removeDay(
          startEpochDay: start,
          endEpochDay: start + 3,
          items: items,
          k: 2,
          mode: RemoveMode.discard);
      expect(
          discardOps,
          orderedEquals(<DayOp>[
            OpDeleteItem(itemId: 'b'),
            OpDeleteItem(itemId: 'c'),
            OpShiftItem(itemId: 'd', newEpochDay: start + 1, newSortOrder: 10),
            OpShiftItem(itemId: 'e', newEpochDay: start + 2, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 2),
          ]));
    });

    test('5. N=1 抛 StateError（至少保留一天）', () {
      expect(
        () => removeDay(
            startEpochDay: start,
            endEpochDay: start,
            items: const [],
            k: 1,
            mode: RemoveMode.shift),
        throwsStateError,
      );
    });

    test('6. 备胎卡随平移（与正式卡同规则）', () {
      final ops = insertDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: [
            _card('x', start + 1, backupOf: 'main1'),
            _card('main1', start + 1),
          ],
          k: 1);
      expect(
          ops,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'x', newEpochDay: start + 2, newSortOrder: 10),
            OpShiftItem(itemId: 'main1', newEpochDay: start + 2, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 3),
          ]));
    });

    test('7. sortOrder 续编：承接天原 10,20 → 被删天卡追加 30,40', () {
      final ops = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: [
            _card('a1', start, sortOrder: 10),
            _card('a2', start, sortOrder: 20),
            _card('p', start + 1, sortOrder: 10),
            _card('q', start + 1, sortOrder: 20),
          ],
          k: 1,
          mode: RemoveMode.shift);
      final shifts = ops.whereType<OpShiftItem>().toList();
      // 第 1 天两张卡并入原第 2 天（前移成新第 1 天，epochDay=start）：
      // p/q 保持 10/20，a1/a2 追加 30/40
      final byId = {for (final s in shifts) s.itemId: s};
      expect(byId['a1']!.newSortOrder, 30);
      expect(byId['a2']!.newSortOrder, 40);
      expect(byId['a1']!.newEpochDay, start);
      expect(byId['p']!.newEpochDay, start);
      expect(byId['p']!.newSortOrder, 10);
      expect(byId['q']!.newSortOrder, 20);
    });

    test('8. 跨月平移（epochDay 连续性）', () {
      // start = 2026-09-30（任意 epochDay），删首天 shift：
      // 9/30 卡并入原第 2 天（新第 1 天，epochDay=sep30），10/2 卡 → 10/1
      final sep30 = 20626; // 与具体日期无关：只验证整数连续性
      final ops = removeDay(
          startEpochDay: sep30,
          endEpochDay: sep30 + 2,
          items: [_card('a', sep30), _card('b', sep30 + 2)],
          k: 1,
          mode: RemoveMode.shift);
      expect(
          ops,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'a', newEpochDay: sep30, newSortOrder: 10),
            OpShiftItem(itemId: 'b', newEpochDay: sep30 + 1, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: sep30 + 1),
          ]));
    });

    test('9. 空天删除（无卡）仅 end -1', () {
      final ops = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: [_card('a', start)],
          k: 2,
          mode: RemoveMode.discard);
      expect(ops, [OpSetEnd(newEndEpochDay: start + 1)]);
    });

    test('10. determinism：同输入两次输出 deep equal', () {
      final items = [
        _card('a', start),
        _card('b', start + 1, sortOrder: 20),
        _card('c', start + 1, sortOrder: 10),
        _card('d', start + 2),
      ];
      final o1 = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: items,
          k: 2,
          mode: RemoveMode.shift);
      final o2 = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: items,
          k: 2,
          mode: RemoveMode.shift);
      expect(o1, o2);
      final i1 = insertDay(startEpochDay: start, endEpochDay: start + 2, items: items, k: 1);
      final i2 = insertDay(startEpochDay: start, endEpochDay: start + 2, items: items, k: 1);
      expect(i1, i2);
    });

    test('越界 k 抛 StateError（k=0 / k=N+1 删除）', () {
      expect(
        () => removeDay(
            startEpochDay: start,
            endEpochDay: start + 2,
            items: const [],
            k: 0,
            mode: RemoveMode.shift),
        throwsStateError,
      );
      expect(
        () => removeDay(
            startEpochDay: start,
            endEpochDay: start + 2,
            items: const [],
            k: 4,
            mode: RemoveMode.discard),
        throwsStateError,
      );
    });

    test('13. 删倒数第二天 k=N-1 shift：卡并入末天（前移成新末天），不越界', () {
      // N=3：100/101/102；k=2 → target=101；末天 102 前移成新末天 101
      final ops = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: [
            _card('a', start),
            _card('b', start + 1, sortOrder: 10),
            _card('c', start + 2, sortOrder: 10),
          ],
          k: 2,
          mode: RemoveMode.shift);
      expect(
          ops,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'b', newEpochDay: start + 1, newSortOrder: 20),
            OpShiftItem(itemId: 'c', newEpochDay: start + 1, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 1),
          ]));
    });

    test('14. shift 承接天为空天：被删天卡按 10,20 续编，不与更晚天冲突', () {
      // N=4：101 天为空；k=2 → target=101；承接天（原 102）为空 → a/b 拿 10/20
      final ops = removeDay(
          startEpochDay: start,
          endEpochDay: start + 3,
          items: [
            _card('a', start + 1, sortOrder: 10),
            _card('b', start + 1, sortOrder: 20),
            _card('c', start + 3, sortOrder: 10),
          ],
          k: 2,
          mode: RemoveMode.shift);
      expect(
          ops,
          orderedEquals(<DayOp>[
            OpShiftItem(itemId: 'a', newEpochDay: start + 1, newSortOrder: 10),
            OpShiftItem(itemId: 'b', newEpochDay: start + 1, newSortOrder: 20),
            OpShiftItem(itemId: 'c', newEpochDay: start + 2, newSortOrder: 10),
            OpSetEnd(newEndEpochDay: start + 2),
          ]));
    });

    test('15. 备胎卡 removeDay shift 与正式卡同规则平移', () {
      final ops = removeDay(
          startEpochDay: start,
          endEpochDay: start + 2,
          items: [
            _card('x', start, backupOf: 'main1'),
            _card('main1', start),
            _card('p', start + 1),
          ],
          k: 1,
          mode: RemoveMode.shift);
      final byId = {
        for (final op in ops.whereType<OpShiftItem>()) op.itemId: op
      };
      expect(byId['x']!.newEpochDay, start);
      expect(byId['x']!.newSortOrder, 20);
      expect(byId['main1']!.newEpochDay, start);
      expect(byId['main1']!.newSortOrder, 30);
      expect(byId['p']!.newEpochDay, start);
    });
  });

  test('appendDay：仅 end +1', () {
    expect(appendDay(endEpochDay: start + 2), [OpSetEnd(newEndEpochDay: start + 3)]);
  });
}
