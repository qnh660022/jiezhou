/// 结算引擎：净额计算 + 最少转账贪心方案 + 方案校验。
///
/// 【口径】balance = 已付 − 应摊：
/// * 只统计 settledRoundId == null（未随任何完成结算入账）的账单；
/// * prepay 预付款参与：payer 余额 +、share 余额 −，让垫付方在 AA 中拿到应收回款；
/// * refund 以负数自然冲减；
/// * 多人付款逐人累加。
///
/// 转账方向约定：balance < 0 是欠款方(from)，balance > 0 是收款方(to)。
/// 本文件纯 Dart 无 IO。
library;

import 'models.dart';

/// 一笔建议转账（from 打给 to）
class TransferPlan {
  const TransferPlan({required this.from, required this.to, required this.cents});

  final String from;
  final String to;

  /// 金额（分，恒为正）
  final int cents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferPlan && from == other.from && to == other.to && cents == other.cents;

  @override
  int get hashCode => Object.hash(from, to, cents);

  @override
  String toString() => 'TransferPlan($from -> $to: $cents)';
}

class _Side {
  _Side(this.id, this.amount);
  final String id;
  int amount;
}

/// 计算每个成员的净额（已付−应摊），返回 memberId -> balance。
/// 传入 [members] 保证无账单成员也出现在结果里（值为 0）。
Map<String, int> computeNetBalances(
    List<MemberRecord> members,
    List<ExpenseRecord> expenses,
) {
  final bal = <String, int>{for (final m in members) m.id: 0};
  for (final e in expenses) {
    if (e.settledRoundId != null) continue; // 已入账的历史轮次不再参与
    // refund 为负数、prepay 亦正常参与，均在 payers/shares 中带符号累加
    for (final p in e.payers) {
      bal[p.memberId] = (bal[p.memberId] ?? 0) + p.cents;
    }
    for (final s in e.shares) {
      bal[s.memberId] = (bal[s.memberId] ?? 0) - s.cents;
    }
  }
  return bal;
}

/// 贪心求最少转账方案：应收降序 × 应付降序逐对抵消，
/// 结果笔数 ≤ n−1 且顺序确定（同额按成员 id 字典序破平局）。
List<TransferPlan> minTransferPlan(Map<String, int> balances) {
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

/// 校验转账方案是否守恒：
/// * 净额总和必须为 0（否则不存在可行方案）；
/// * Σ转出 == Σ转入 == Σ|净额| / 2；
/// * 每个账户经方案轧差后归零；金额恒正、不自转、账户必须已知。
bool validatePlan(List<TransferPlan> plan, Map<String, int> balances) {
  var netSum = 0;
  var halfAbs = 0;
  for (final v in balances.values) {
    netSum += v;
    halfAbs += v.abs();
  }
  if (netSum != 0) return false;

  final delta = <String, int>{for (final k in balances.keys) k: 0};
  var moved = 0;
  for (final t in plan) {
    if (t.cents <= 0) return false;
    if (t.from == t.to) return false;
    if (!delta.containsKey(t.from) || !delta.containsKey(t.to)) return false;
    delta[t.from] = delta[t.from]! - t.cents;
    delta[t.to] = delta[t.to]! + t.cents;
    moved += t.cents;
  }
  if (moved * 2 != halfAbs) return false;
  for (final e in balances.entries) {
    // delta 即净流入（收−支），与待收正余额对消后归零
    if (e.value - delta[e.key]! != 0) return false;
  }
  return true;
}
