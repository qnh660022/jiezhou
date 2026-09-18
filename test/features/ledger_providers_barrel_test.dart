// V2.7.1 S2 · G4：桥接层拆分的等价性护栏。
//
// 本文件只从**原路径** `ledger_providers.dart` 导入，并逐一引用拆分后 5 个子文件
// 导出的符号——若 barrel 漏 export 任一文件，本文件将无法编译（编译期证明
// 「屏幕零改动」成立）。同时断言 Agent 名与签名未漂移。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/features/ledger/ledger_models.dart';
import 'package:travel_assistant/features/ledger/ledger_providers.dart';

void main() {
  test('G4 barrel：bills / groups / io_csv / settle / stats 全部可达', () {
    // bills.dart
    expect(expensesProvider, isNotNull);
    expect(tripBillsProvider, isNotNull);
    expect(expenseRecordOf, isNotNull);
    expect(saveExpense, isNotNull);
    expect(todayOr(0), greaterThan(0));

    // groups.dart
    expect(activeGroupIdProvider, isNotNull);
    expect(groupsProvider, isNotNull);
    expect(activeGroupProvider, isNotNull);
    expect(membersProvider, isNotNull);
    expect(categoriesProvider, isNotNull);
    expect(activateGroup, isNotNull);
    expect(archiveMember, isNotNull);
    expect(categoryIconChoices, hasLength(18));

    // settle.dart
    expect(settlementsProvider, isNotNull);
    expect(activeSettlementProvider, isNotNull);
    expect(startSettlement, isNotNull);
    expect(netBalanceMap, isNotNull);
    expect(transferPlanOf, isNotNull);

    // stats.dart
    expect(memberBoardProvider, isNotNull);
    expect(unsettledCountProvider, isNotNull);
    expect(budgetStatusProvider, isNotNull);
    expect(categoryBreakdownProvider, isNotNull);
    expect(dailyTotalsProvider, isNotNull);
    expect(payMethodBreakdownProvider, isNotNull);

    // io_csv.dart
    expect(exportGroupBackup, isNotNull);
    expect(importFullBackupFile, isNotNull);
    expect(buildCsvText, isNotNull);
    expect(summarizeImportReport(const _FakeReport()), contains('导入成功'));
  });

  test('G4 纯重构：分摊标签映射与枚举穷尽未漂移', () {
    expect(shareModeLabel(ShareMode.equal), '平均');
    expect(shareModeLabel(ShareMode.portions), '按份数');
    expect(shareModeLabel(ShareMode.percent), '按百分比');
    expect(shareModeLabel(ShareMode.custom), '自定义');
  });
}

class _FakeReport {
  const _FakeReport();
  int get members => 1;
  int get expenses => 2;
  int get trips => 0;
  int get tripItems => 0;
}
