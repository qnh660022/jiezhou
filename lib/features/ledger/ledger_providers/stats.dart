/// 账本桥接层 · 统计与预算域。
///
/// G4 拆分（V2.7.1 S2）：由 `ledger_providers.dart` barrel 统一 export。
/// G3：统计口径全部走 `domain/stats_calculator.dart` 的类型化纯函数。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/models.dart';
import '../../../domain/stats_calculator.dart';
import '../../../domain/budget_alert_engine.dart';
import '../ledger_models.dart';
import 'bills.dart';
import 'groups.dart';

AsyncValue<List<T>> _combine2<T>(
    AsyncValue<dynamic> a, AsyncValue<dynamic> b, List<T> Function() compute) {
  if (a.isLoading || b.isLoading) return const AsyncLoading();
  return AsyncData(compute());
}

/// 成员收支榜（paid/share/balance），balance 降序
final memberBoardProvider = Provider<AsyncValue<List<MemberStatView>>>((ref) {
  final members = ref.watch(membersProvider);
  final expenses = ref.watch(expensesProvider);
  return _combine2(members, expenses, () {
    final ms = members.value ?? const <LedgerMemberView>[];
    // “谁付了多少”表达当前仍待 AA 结算的应收/应付，必须与结算页
    // 使用同一口径；已完成结算的账单不再重复计入当前净额。
    final es = (expenses.value ?? const <ExpenseRecord>[])
        .where((e) => e.settledRoundId == null)
        .toList();
    final paid = paidByMember(es, includePrepay: true);
    final share = shareByMember(es, includePrepay: true);
    return [
      for (final m in ms)
        MemberStatView(
          member: m,
          paidCents: paid[m.id] ?? 0,
          shareCents: share[m.id] ?? 0,
          balanceCents: (paid[m.id] ?? 0) - (share[m.id] ?? 0),
        ),
    ]..sort((a, b) => b.balanceCents - a.balanceCents);
  });
});

/// 未结账单数（徽章）：未参与结算轮且非预付
final unsettledCountProvider = Provider<AsyncValue<int>>((ref) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  final es = expenses.value ?? const <ExpenseRecord>[];
  return AsyncData(es
      .where((e) => e.type != ExpenseType.prepay && e.settledRoundId == null)
      .length);
});

/// 当前预算预警列表（异步派生，与 budgetStatusProvider 口径一致）
final budgetAlertsProvider = Provider<List<BudgetAlert>>((ref) {
  final group = ref.watch(activeGroupProvider);
  final expenses = ref.watch(expensesProvider);
  if (group.isLoading || expenses.isLoading) return const [];
  final g = group.value;
  final es = expenses.value ?? const <ExpenseRecord>[];
  if (g == null || !g.budgetEnabled || (g.budgetCents ?? 0) <= 0) return const [];
  final spent = totalCents(es);
  return evaluateAlerts(enabled: true, budgetCents: g.budgetCents!, spentCents: spent);
});

/// 预算预警总开关（我的页设置）：关闭后红点与预警中心均不提示。
final budgetAlertsEnabledProvider = FutureProvider<bool>(
    (ref) => ref.watch(prefsRepoProvider).getBudgetAlertsEnabled());

/// 是否存在未读预算预警（红点依据）——异步 Provider
final budgetAlertUnreadProvider = FutureProvider<bool>((ref) async {
  if (!(await ref.watch(budgetAlertsEnabledProvider.future))) return false;
  final alerts = ref.watch(budgetAlertsProvider);
  final active = ref.watch(activeGroupProvider);
  final gid = active.value?.id;
  if (gid == null || alerts.isEmpty) return false;
  final prefs = ref.watch(prefsRepoProvider);
  final seen = await prefs.getBudgetAlertSeenLevels(gid);
  final maxSeen = seen.isEmpty ? -1 : seen.reduce((a, b) => a > b ? a : b);
  return alerts.any((a) => a.level.index > maxSeen);
});

/// 预算状态（本地纯算术）
final budgetStatusProvider = Provider<AsyncValue<BudgetStatusView>>((ref) {
  final group = ref.watch(activeGroupProvider);
  final expenses = ref.watch(expensesProvider);
  if (group.isLoading || expenses.isLoading) return const AsyncLoading();
  final g = group.value;
  final es = expenses.value ?? const <ExpenseRecord>[];
  final enabled = g?.budgetEnabled ?? false;
  final total = g?.budgetCents ?? 0;
  final spent = totalCents(es);
  final percent = total > 0 ? spent / total : 0.0;
  return AsyncData(BudgetStatusView(
    enabled: enabled,
    totalCents: total,
    spentCents: spent,
    remainingCents: total - spent,
    percent: percent,
  ));
});

/// 分类占比（cents 降序）
final categoryBreakdownProvider = Provider<AsyncValue<List<CategoryShareView>>>((ref) {
  final categories = ref.watch(categoriesProvider);
  final expenses = ref.watch(expensesProvider);
  return _combine2(categories, expenses, () {
    final cs = categories.value ?? const <CategoryView>[];
    final es = expenses.value ?? const <ExpenseRecord>[];
    final totals = totalsByCategory(es);
    var grand = 0;
    for (final v in totals.values) {
      grand += v;
    }
    final byKey = {for (final c in cs) c.key: c};
    return [
      for (final entry in totals.entries)
        CategoryShareView(
          category: byKey[entry.key] ??
              CategoryView(key: entry.key, name: entry.key, icon: '🏷️', builtin: false),
          cents: entry.value,
          fraction: grand > 0 ? entry.value / grand : 0,
        ),
    ]..sort((a, b) => b.cents.compareTo(a.cents));
  });
});

/// 每日合计（epochDay 升序）
final dailyTotalsProvider = Provider<AsyncValue<List<DailyTotalView>>>((ref) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  final es = expenses.value ?? const <ExpenseRecord>[];
  final totals = totalsByDay(es);
  return AsyncData([
    for (final e in totals.entries) DailyTotalView(epochDay: e.key, cents: e.value),
  ]..sort((a, b) => a.epochDay - b.epochDay));
});

/// 支付方式分组合计（S11）：口径同 totalsByCategory（normal+refund，不含 prepay）。
/// key 为 null 表示「未标记」。
final payMethodBreakdownProvider =
    Provider<AsyncValue<List<PayMethodTotalView>>>((ref) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  final es = expenses.value ?? const <ExpenseRecord>[];
  final totals = <String?, int>{};
  for (final e in es) {
    if (e.type == ExpenseType.prepay) continue;
    totals[e.payMethod] = (totals[e.payMethod] ?? 0) + e.amountCents;
  }
  return AsyncData([
    for (final e in totals.entries)
      PayMethodTotalView(payMethod: e.key, cents: e.value),
  ]..sort((a, b) => b.cents.compareTo(a.cents)));
});
