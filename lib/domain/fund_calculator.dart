/// 公款池派生量（V2.7.1 S8 · N1）。
///
/// 【红线】
/// * 池余额是**展示量**，不入库、不参与净额——「谁该退多少」由结算引擎负责，
///   两套数字不得互相替代；
/// * 余额只统计**未入账**账单（`settledRoundId == null`）：含池账单的结算轮完成后，
///   已退款部分自然退出余额，关池前余额趋近 0，否则已退款金额会被重复显示。
///
/// 【建模约定（净额自洽的唯一依据）】
/// * 入金 = `prepay`：payers = 各缴款人、shares = 管理人；
/// * 出金 = `normal`：payers = 管理人、shares 按分摊模式。
/// 详见规格书 §S8.2。本文件纯 Dart 无 IO。
library;

import 'models.dart';

bool _counts(ExpenseRecord e, String fundId) =>
    e.fundId == fundId && e.settledRoundId == null;

/// 池余额（分）= Σ未入账入金 − Σ未入账出金。
int fundBalanceCents(String fundId, List<ExpenseRecord> expenses) {
  var balance = 0;
  for (final e in expenses) {
    if (!_counts(e, fundId)) continue;
    if (e.type == ExpenseType.prepay) {
      balance += e.amountCents;
    } else if (e.type == ExpenseType.normal) {
      balance -= e.amountCents;
    }
  }
  return balance;
}

/// 已入金合计（分）：未入账入金账单的 payers 逐人累加。
int fundContributedTotal(String fundId, List<ExpenseRecord> expenses) {
  var total = 0;
  for (final e in expenses) {
    if (!_counts(e, fundId) || e.type != ExpenseType.prepay) continue;
    for (final p in e.payers) {
      total += p.cents;
    }
  }
  return total;
}

/// 已支出合计（分）：未入账出金账单金额合计。
int fundSpentTotal(String fundId, List<ExpenseRecord> expenses) {
  var total = 0;
  for (final e in expenses) {
    if (!_counts(e, fundId) || e.type != ExpenseType.normal) continue;
    total += e.amountCents;
  }
  return total;
}

/// 各成员缴款额（memberId -> 分）：未入账入金账单的 payers 逐人累加。
Map<String, int> fundContributionByMember(
    String fundId, List<ExpenseRecord> expenses) {
  final map = <String, int>{};
  for (final e in expenses) {
    if (!_counts(e, fundId) || e.type != ExpenseType.prepay) continue;
    for (final p in e.payers) {
      map[p.memberId] = (map[p.memberId] ?? 0) + p.cents;
    }
  }
  return map;
}

/// 出金分类聚合（categoryKey -> 分）：仅未入账出金账单。
Map<String, int> fundSpentByCategory(
    String fundId, List<ExpenseRecord> expenses) {
  final map = <String, int>{};
  for (final e in expenses) {
    if (!_counts(e, fundId) || e.type != ExpenseType.normal) continue;
    map[e.categoryKey] = (map[e.categoryKey] ?? 0) + e.amountCents;
  }
  return map;
}

/// 参与人数（有缴款记录的不同成员数）。
int fundContributorCount(String fundId, List<ExpenseRecord> expenses) =>
    fundContributionByMember(fundId, expenses).keys.length;

/// 余额低于计划总额 20% 的提示阈值（不做通知，仅卡片文案）。
bool fundBelowThreshold(int balanceCents, int? targetCents) =>
    targetCents != null && targetCents > 0 && balanceCents < targetCents * 20 ~/ 100;
