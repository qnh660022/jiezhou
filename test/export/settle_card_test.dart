// V2.7.1 S5 · E1：结算分享卡（版式 / 空态 / 文件名 / 隐私边界）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/export/settle_card_builder.dart';
import 'package:travel_assistant/features/ledger/ledger_models.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  final transfers = <TransferView>[
    const TransferView(from: 'm1', to: 'm2', cents: 92500, done: true),
    const TransferView(from: 'm1', to: 'm3', cents: 92500, done: true),
  ];
  final data = SettlementCardData(
    groupName: '大阪四人组',
    roundNo: 2,
    completedAtMs: DateTime(2026, 9, 18, 14, 30).millisecondsSinceEpoch,
    transfers: transfers,
    memberNames: const {'m1': '张三', 'm2': '李四', 'm3': '王五'},
    generatedAt: DateTime(2026, 9, 18, 15, 0),
  );

  test('文件名规范 settle-round<N>-<yyyyMMdd-HHmm>.png', () {
    expect(settleCardFileName(2, DateTime(2026, 9, 18, 14, 30)),
        'settle-round2-20260918-1430.png');
    expect(settleCardFileName(11, DateTime(2026, 1, 2, 3, 4)),
        'settle-round11-20260102-0304.png');
  });

  testWidgets('版式：标题 / 副标题 / 转账行 / 脚注', (tester) async {
    await tester.pumpWidget(wrap(SettleCard(data: data)));
    expect(find.text('大阪四人组 · 第 2 轮结算'), findsOneWidget);
    expect(find.text('完成于 2026-09-18'), findsOneWidget);
    expect(find.text('张三 → 李四'), findsOneWidget);
    expect(find.text('张三 → 王五'), findsOneWidget);
    expect(find.text('共 2 笔转账 · 已按最少转账方案计算'), findsOneWidget);
    expect(find.textContaining('芥舟 · 生成于 2026-09-18 15:00'), findsOneWidget);
  });

  testWidgets('金额：¥ 前缀 + 两位小数右对齐', (tester) async {
    await tester.pumpWidget(wrap(SettleCard(data: data)));
    expect(find.text('¥925.00'), findsNWidgets(2));
  });

  testWidgets('进行中（completedAtMs=null）副标题为「进行中」', (tester) async {
    final ongoing = SettlementCardData(
      groupName: '团',
      roundNo: 1,
      transfers: transfers,
      memberNames: const {'m2': '李四', 'm3': '王五'},
      generatedAt: DateTime(2026, 9, 18),
    );
    await tester.pumpWidget(wrap(SettleCard(data: ongoing)));
    expect(find.text('进行中'), findsOneWidget);
  });

  testWidgets('零转账空态卡：不崩溃且提示已平', (tester) async {
    final empty = SettlementCardData(
      groupName: '团',
      roundNo: 3,
      completedAtMs: DateTime(2026, 9, 18).millisecondsSinceEpoch,
      transfers: const [],
      memberNames: const {},
      generatedAt: DateTime(2026, 9, 18),
    );
    await tester.pumpWidget(wrap(SettleCard(data: empty)));
    expect(find.text('本轮无需转账，账目已平'), findsOneWidget);
    expect(find.text('共 0 笔转账 · 已按最少转账方案计算'), findsOneWidget);
  });

  testWidgets('策略脚注：最少人参与', (tester) async {
    final minPeople = SettlementCardData(
      groupName: '团',
      roundNo: 1,
      transfers: transfers,
      memberNames: const {'m1': '张三', 'm2': '李四', 'm3': '王五'},
      generatedAt: DateTime(2026, 9, 18),
      strategyLabel: '最少人参与',
    );
    await tester.pumpWidget(wrap(SettleCard(data: minPeople)));
    expect(find.text('共 2 笔转账 · 已按最少人参与方案计算'), findsOneWidget);
  });

  testWidgets('悬空成员 id 兜底为「已移除成员」而非裸 id', (tester) async {
    final orphan = SettlementCardData(
      groupName: '团',
      roundNo: 1,
      transfers: const [TransferView(from: 'ghost', to: 'm2', cents: 100, done: false)],
      memberNames: const {'m2': '李四'},
      generatedAt: DateTime(2026, 9, 18),
    );
    await tester.pumpWidget(wrap(SettleCard(data: orphan)));
    expect(find.text('已移除成员 → 李四'), findsOneWidget);
  });

  testWidgets('隐私：卡片不含账单标题/备注类文本（结构上只吃转账列表）', (tester) async {
    // 输入数据里根本没有账单明细字段；此处断言渲染结果不含任何非转账文本。
    await tester.pumpWidget(wrap(SettleCard(data: data)));
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(texts.any((t) => t.contains('账单')), isFalse);
    expect(texts.any((t) => t.contains('备注')), isFalse);
  });

  testWidgets('深色主题下仍可渲染（语义色不硬编码）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: Center(child: SettleCard(data: data))),
    ));
    expect(find.text('大阪四人组 · 第 2 轮结算'), findsOneWidget);
  });
}
