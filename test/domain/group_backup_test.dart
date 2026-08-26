import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/group_backup.dart';

/// 确定性 id 换发：prefix_n1 / prefix_n2 …
IdGen makeSeq() {
  var i = 0;
  return (p) => '${p}_n${++i}';
}

Map<String, dynamic> fixture() => buildGroupBackup(
      group: const {
        'id': 'g1', 'name': '关西之行', 'icon': '🗾',
        'budgetEnabled': true, 'budgetCents': 1000000,
      },
      members: const [
        {'id': 'm1', 'name': '小王', 'colorIndex': 0},
        {'id': 'm2', 'name': '小李', 'colorIndex': 1},
      ],
      expenses: [
        const {
          'id': 'e1', 'groupId': 'g1', 'dateEpochDay': 20000,
          'title': '门票', 'categoryKey': 'ticket', 'type': 'normal',
          'amountCents': 30000, 'currency': 'CNY', 'rate': 1.0,
          'payers': [
            {'memberId': 'm1', 'cents': 30000},
            {'memberId': 'ghost', 'cents': 100},
          ],
          'shares': [
            {'memberId': 'm1', 'cents': 10000},
            {'memberId': 'm2', 'cents': 10000},
            {'memberId': 'm3', 'cents': 10000},
          ],
          'shareMode': 'equal', 'settledRoundId': null,
          'tripId': 't1', 'tripItemId': 'i1',
        },
        const {
          'id': 'e2', 'groupId': 'g1', 'dateEpochDay': 20001,
          'title': '奶茶', 'categoryKey': 'custom_bubble', 'type': 'normal',
          'amountCents': 2200, 'currency': 'JPY', 'rate': 0.048,
          'payers': [
            {'memberId': 'm2', 'cents': 2200},
          ],
          'shares': [
            {'memberId': 'm2', 'cents': 2200},
          ],
          'shareMode': 'custom', 'settledRoundId': 's1',
          'tripId': 't9', // 不存在的行程 -> 应置 null
        },
      ],
      settlements: const [
        {
          'id': 's1', 'status': 'completed',
          'transfers': [
            {'from': 'm2', 'to': 'm1', 'cents': 5000, 'done': true},
            {'from': 'mX', 'to': 'm1', 'cents': 999, 'done': false},
          ],
          'expenseIds': ['e1', 'eGhost'],
          'roundNo': 1,
        },
      ],
      trips: [
        {
          'id': 't1', 'groupId': 'g1', 'name': '大阪两日', 'destination': '大阪',
          'emoji': '🏯', 'cover': 'ocean', 'startEpochDay': 20000,
          'endEpochDay': 20002, 'archived': false,
          'items': [
            {'id': 'i1', 'tripId': 't1', 'dateEpochDay': 20000,
             'type': 'attraction', 'name': '通天阁', 'sortOrder': 0},
          ],
        },
        {'id': 't2', 'groupId': 'g1', 'name': '空行程'},
      ],
      customCategories: [
        {'key': 'custom_bubble', 'name': '奶茶饮品', 'icon': '🧋'},
      ],
    );

void main() {
  test('完整导入：四级换发且内部自洽', () {
    final backup = encodeGroupBackup(fixture());
    final r = applyImport(parseGroupBackup(backup), gen: makeSeq());

    // id 全部换新
    expect(r.group['id'], 'group_n1');
    expect(r.members.map((m) => m['id']), ['member_n2', 'member_n3']);
    expect(r.trips.map((t) => t['id']), ['trip_n4', 'trip_n6']);
    expect(r.expenses.map((e) => e['id']), everyElement(startsWith('expense_')));

    // 成员引用全部指向新成员集
    final ids = r.members.map((m) => m['id']).toSet();
    for (final e in r.expenses) {
      for (final p in (e['payers'] as List)) {
        expect(ids.contains(p['memberId']), isTrue);
      }
      for (final s in (e['shares'] as List)) {
        expect(ids.contains(s['memberId']), isTrue);
      }
    }

    // 行程/安排关联与归属
    expect(r.expenses[0]['tripId'], r.trips[0]['id']);
    expect(r.expenses[0]['tripItemId'], (r.trips[0]['items'] as List).first['id']);
    expect(r.trips[0]['groupId'], r.group['id']);
    expect((r.trips[0]['items'] as List).first['tripId'], r.trips[0]['id']);

    // 结算轮重映射 + 账单回链
    expect(r.expenses[1]['settledRoundId'], r.settlements[0]['id']);
    expect(r.settlements[0]['expenseIds'], [r.expenses[0]['id']]);
  });

  test('悬空引用清理计数', () {
    final backup = encodeGroupBackup(fixture());
    final r = applyImport(parseGroupBackup(backup), gen: makeSeq());

    // e1 的 ghost 付款者被剔除；m3 分摊者被剔除
    expect(r.stats.droppedShareEntries, 2);
    expect((r.expenses[0]['shares'] as List).length, 2);
    // e2 引用不存在的 t9 -> tripId 置 null
    expect(r.expenses[1]['tripId'], isNull);
    expect(r.stats.nulledTripLinks, 1);
    // s1 的 mX 转账被剔除；eGhost 引用被剔除
    expect(r.stats.droppedTransfers, 1);
    expect((r.settlements[0]['transfers'] as List).length, 1);
    expect(r.stats.droppedExpenseRefs, 1);
  });

  test('同名自定义分类复用库内 key；内置分类原样保留', () {
    final backup = encodeGroupBackup(fixture());
    final r = applyImport(
      parseGroupBackup(backup),
      gen: makeSeq(),
      existingCategoryByName: const {'奶茶饮品': 'kept_key'},
    );
    // 复用：不再新建，账单 categoryKey 指向 kept_key
    expect(r.customCategories, isEmpty);
    expect(r.stats.reusedCategories, 1);
    expect(r.stats.createdCategories, 0);
    expect(r.expenses[1]['categoryKey'], 'kept_key');
    // 内置分类 ticket 未受影响
    expect(r.expenses[0]['categoryKey'], 'ticket');
  });

  test('无既有分类时新建且批次内同名去重', () {
    final src = fixture();
    // 追加一个同名分类，应复用本批次刚换发的 key
    src['customCategories'] = [
      ...src['customCategories'],
      {'key': 'custom_bubble2', 'name': '奶茶饮品', 'icon': '🍵'},
    ];
    final backup = encodeGroupBackup(src);
    final r = applyImport(parseGroupBackup(backup), gen: makeSeq());
    expect(r.customCategories.length, 1, reason: '同名合并为一条');
    expect(r.stats.createdCategories, 1);
    expect(r.stats.reusedCategories, 1);
    expect(r.expenses[1]['categoryKey'], r.customCategories.first['key']);
  });

  test('buildGroupBackup 不修改入参', () {
    final trips = [
      {'id': 't1', 'items': [
        {'id': 'i1'},
      ]},
    ];
    buildGroupBackup(
      group: {'id': 'g'},
      members: [],
      expenses: [],
      settlements: [],
      trips: trips,
      customCategories: [],
    );
    expect(trips[0].containsKey('items'), isTrue);
  });

  test('非法输入抛 FormatException', () {
    expect(() => parseGroupBackup('not json'), throwsFormatException);
    expect(() => parseGroupBackup('{"app":"other","version":1}'),
        throwsFormatException);
    expect(() => parseGroupBackup('{"app":"travel-assistant-v2","version":99}'),
        throwsFormatException);
    expect(
      () => parseGroupBackup('{"app":"travel-assistant-v2","version":1}'),
      throwsFormatException,
      reason: '缺少 group 节点',
    );
  });

  test('统计摘要可读（含中文冒号分隔）', () {
    final backup = encodeGroupBackup(fixture());
    final r = applyImport(parseGroupBackup(backup), gen: makeSeq());
    expect(r.stats.toString(), contains('成员2'));
    expect(r.stats.toString(), contains('账单2'));
    expect(r.stats.toString(), contains('安排1'));
  });
}
