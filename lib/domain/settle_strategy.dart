/// 结算策略（S9 · N2）：在「最少转账笔数」外增加「最少人参与」目标。
///
/// **`settle_engine.dart` 一行不动**：本文件只做外围编排，`minTransfers` 分支
/// 直接调用既有 [minTransferPlan]，行为逐位不变。
///
/// 【「最少人参与」的口径（本仓裁定，S9.2 规格允许的实现自由度）】
/// 目标 = 让每个人「发起/接收转账的对手方最少」，即把资金流集中到一个枢纽
/// （hub = |净额| 最大的账户）：
///   1) 枢纽为应收方：所有欠款方**先**各自向枢纽转一笔；
///   2) 枢纽为应付方：枢纽**先**向所有应收方各转一笔；
///   3) 剩余余额退回既有贪心（[minTransferPlan]）收尾。
/// 这样每个欠款方最多只需「付一次」，沟通成本最低；总笔数可能略多于最少笔数
/// 方案（两者是不同目标，UI 会同时标注「N 笔 · M 人参与」）。
///
/// 两策略产出**都必须通过 [validatePlan]**，失败抛异常（不得静默降级）。
/// 本文件纯 Dart 无 IO。
library;

import 'settle_engine.dart';

enum SettleStrategy { minTransfers, minParticipants }

/// 按策略生成结算方案；余额必须守恒（Σ==0），否则 [validatePlan] 会拒。
List<TransferPlan> buildPlan({
  required Map<String, int> balances,
  required SettleStrategy strategy,
}) {
  final plan = switch (strategy) {
    SettleStrategy.minTransfers => minTransferPlan(balances),
    SettleStrategy.minParticipants => _minParticipantsPlan(balances),
  };
  if (!validatePlan(plan, balances)) {
    throw StateError('结算方案未通过守恒自检（strategy=${strategy.name}）');
  }
  return plan;
}

class _Side {
  _Side(this.id, this.amount);
  final String id;
  int amount;
}

/// 标准贪心（与 settle_engine.minTransferPlan 同口径，用于收尾 remainder）。
List<TransferPlan> _greedy(Map<String, int> balances) {
  final creditors = balances.entries
      .where((e) => e.value > 0)
      .map((e) => _Side(e.key, e.value))
      .toList()
    ..sort((a, b) {
      final c = b.amount.compareTo(a.amount);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final debtors = balances.entries
      .where((e) => e.value < 0)
      .map((e) => _Side(e.key, -e.value))
      .toList()
    ..sort((a, b) {
      final c = b.amount.compareTo(a.amount);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final plan = <TransferPlan>[];
  var i = 0, j = 0;
  while (i < creditors.length && j < debtors.length) {
    final amt = creditors[i].amount < debtors[j].amount
        ? creditors[i].amount
        : debtors[j].amount;
    if (amt > 0) {
      plan.add(TransferPlan(from: debtors[j].id, to: creditors[i].id, cents: amt));
      creditors[i].amount -= amt;
      debtors[j].amount -= amt;
    }
    if (creditors[i].amount == 0) i++;
    if (debtors[j].amount == 0) j++;
  }
  return plan;
}

List<TransferPlan> _minParticipantsPlan(Map<String, int> balances) {
  // 枢纽 = |净额| 最大者；同额按成员 id 字典序（确定性）。
  final sorted = balances.entries.where((e) => e.value != 0).toList()
    ..sort((a, b) {
      final c = b.value.abs().compareTo(a.value.abs());
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  if (sorted.isEmpty) return const [];
  final hubId = sorted.first.key;
  final hubIsCreditor = sorted.first.value > 0;

  final remaining = Map<String, int>.of(balances);
  final plan = <TransferPlan>[];

  if (hubIsCreditor) {
    // 所有欠款方先向枢纽转；枢纽收满即止。
    final debtors = sorted.where((e) => e.value < 0 && e.key != hubId).toList();
    for (final d in debtors) {
      final hubRem = remaining[hubId]!;
      if (hubRem <= 0) break;
      final owe = -remaining[d.key]!;
      if (owe <= 0) continue;
      final amt = owe < hubRem ? owe : hubRem;
      plan.add(TransferPlan(from: d.key, to: hubId, cents: amt));
      remaining[hubId] = hubRem - amt;
      remaining[d.key] = remaining[d.key]! + amt;
    }
  } else {
    // 枢纽先向所有应收方转；枢纽余额耗尽即止。
    final creditors = sorted.where((e) => e.value > 0 && e.key != hubId).toList();
    for (final c in creditors) {
      final hubRem = -remaining[hubId]!;
      if (hubRem <= 0) break;
      final due = remaining[c.key]!;
      if (due <= 0) continue;
      final amt = due < hubRem ? due : hubRem;
      plan.add(TransferPlan(from: hubId, to: c.key, cents: amt));
      remaining[hubId] = remaining[hubId]! + amt;
      remaining[c.key] = due - amt;
    }
  }

  final rest = <String, int>{
    for (final e in remaining.entries)
      if (e.value != 0) e.key: e.value,
  };
  plan.addAll(_greedy(rest));
  return plan;
}

/// 参与人数（方案中出现的不同账户数）——UI 脚注「N 笔 · M 人参与」用。
int participantCount(List<TransferPlan> plan) {
  final ids = <String>{};
  for (final t in plan) {
    ids.add(t.from);
    ids.add(t.to);
  }
  return ids.length;
}
