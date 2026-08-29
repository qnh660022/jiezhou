import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/domain/csv_builder.dart';
import 'package:travel_assistant/domain/models.dart';

void main() {
  final day0 = dateToEpochDay(DateTime(2025, 8, 25));

  final expenses = [
    // 正常账单：三人均摊 123.46
    ExpenseRecord(
      id: 'e1',
      groupId: 'g1',
      dateEpochDay: day0,
      title: '东京塔登塔',
      categoryKey: 'ticket',
      type: ExpenseType.normal,
      amountCents: 12346,
      currency: 'CNY',
      rate: 1,
      payers: const [ShareEntry(memberId: 'a', cents: 12346)],
      shares: const [
        ShareEntry(memberId: 'a', cents: 4116),
        ShareEntry(memberId: 'b', cents: 4115),
        ShareEntry(memberId: 'c', cents: 4115),
      ],
    ),
    // 退款：含逗号/引号/换行的标题与备注，外币 USD
    ExpenseRecord(
      id: 'e2',
      groupId: 'g1',
      dateEpochDay: day0 + 1,
      title: '晚餐,含"酒水"',
      categoryKey: 'food',
      type: ExpenseType.refund,
      amountCents: -5000,
      currency: 'USD',
      rate: 7.25,
      amountForeignCents: -690,
      payers: const [ShareEntry(memberId: 'a', cents: -5000)],
      shares: const [
        ShareEntry(memberId: 'a', cents: -2500),
        ShareEntry(memberId: 'b', cents: -2500),
      ],
      shareMode: ShareMode.custom,
      note: '第一行\n第二行',
      settledRoundId: 'r1',
    ),
    // 预付款：关联行程与安排，多人付款
    ExpenseRecord(
      id: 'e3',
      groupId: 'g1',
      dateEpochDay: day0 + 2,
      title: '酒店押金',
      categoryKey: 'stay',
      type: ExpenseType.prepay,
      amountCents: 90000,
      currency: 'CNY',
      rate: 1,
      payers: const [
        ShareEntry(memberId: 'b', cents: 45000),
        ShareEntry(memberId: 'a', cents: 45000),
      ],
      shares: const [
        ShareEntry(memberId: 'b', cents: 45000),
        ShareEntry(memberId: 'a', cents: 45000),
      ],
      shareMode: ShareMode.custom,
      note: '押金待退',
      tripId: 't1',
      tripItemId: 'i1',
    ),
  ];

  final csv = buildExpensesCsv(
    expenses,
    memberNames: const {'a': '小王', 'b': '小李', 'c': '小张'},
    tripNames: const {'t1': '关西之行'},
    itemTitles: const {'i1': '清水寺清晨'},
    categoryNames: const {'food': '餐饮'},
  );

  test('快照：BOM + CRLF + 转义 + 17 列逐字匹配', () {
    const expected = '\uFEFF'
        '日期,描述,分类,类型,金额元,币种,汇率,外币金额,付款人,分摊方式,分摊人数,分摊人,分摊明细,备注,状态,关联行程,关联安排\r\n'
        '2025-08-25,东京塔登塔,ticket,正常,123.46,CNY,1.0000,,小王,平均,3,小王、小李、小张,小王:41.16；小李:41.15；小张:41.15,,未结,,\r\n'
        '2025-08-26,"晚餐,含""酒水""",餐饮,退款,-50.00,USD,7.2500,-6.90,小王,自定义,2,小王、小李,小王:-25.00；小李:-25.00,"第一行\n第二行",已结,,\r\n'
        '2025-08-27,酒店押金,stay,预付,900.00,CNY,1.0000,,小李、小王,自定义,2,小李、小王,小李:450.00；小王:450.00,押金待退,未结,关西之行,清水寺清晨\r\n';
    expect(csv, expected);
  });

  test('结构断言：BOM 开头、全 CRLF、含尾随空行', () {
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv.endsWith('\r\n'), isTrue);
    final lines = csv.split('\r\n');
    expect(lines.length, 5, reason: '表头+3 行+尾随空串');
    expect(lines.last, '');
    for (final line in lines.take(4)) {
      expect(line.split(',').length, greaterThanOrEqualTo(17),
          reason: '引号内逗号除外时列数应≥17');
    }
  });

  group('csvEscape', () {
    test('普通文本不加引号', () {
      expect(csvEscape('东京塔'), '东京塔');
      expect(csvEscape('123.46'), '123.46');
      expect(csvEscape(''), '');
    });

    test('逗号/引号/换行加引号且内部翻倍', () {
      expect(csvEscape('a,b'), '"a,b"');
      expect(csvEscape('说"你好"'), '"说""你好"""');
      expect(csvEscape('L1\nL2'), '"L1\nL2"');
      expect(csvEscape('L1\rL2'), '"L1\rL2"');
    });
  });
}
