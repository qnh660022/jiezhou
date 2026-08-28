/// 统计计算器：总览/成员排行/分类占比/每日合计/预算进度。
///
/// 【口径】
/// * 除预付款外的一切统计均包含已结算账单（历史金额照常计入）；
/// * type == prepay 只进 prepayTotal，不进 total/count；
/// * refund 以负数自然冲减总额。
/// 本文件纯 Dart 无 IO。
library;

import 'models.dart';

/// 团级总览
class GroupStats {
  const GroupStats({
    required this.totalCents,
    required this.count,
    required this.prepayTotalCents,
    required this.avgPerPersonCents,
  });

  /// 总支出（分）：normal + refund（负数冲减），不含 prepay
  final int totalCents;

  /// 账单笔数：不含 prepay
  final int count;

  /// 预付款合计（分）
  final int prepayTotalCents;

  /// 人均（分）= total ~/ 成员数；无成员时为 0
  final int avgPerPersonCents;
}

/// 单个成员的收支画像
class MemberStat {
  const MemberStat({
    required this.member,
    required this.paidCents,
    required this.shareCents,
  });

  final MemberRecord member;

  /// 已付：名下 payers 合计（不含 prepay 账单）
  final int paidCents;

  /// 应摊：名下 shares 合计（不含 prepay 账单）
  final int shareCents;

  /// 差额 = 已付 − 应摊（正数表示垫付待收）
  int get balanceCents => paidCents - shareCents;
}

/// 分类占比项
class CategoryShare {
  const CategoryShare({required this.key, required this.cents, required this.percent});

  final String key;
  final int cents;

  /// 占总支出百分比（一位小数，如 23.5）；总额为 0 时恒 0
  final double percent;
}

/// 预算进度
class BudgetProgress {
  const BudgetProgress({
    required this.spentCents,
    required this.remainingCents,
    required this.percent,
  });

  final int spentCents;

  /// 剩余 = 预算 − 已花，可为负（超支）
  final int remainingCents;

  /// 已花百分比（整数，可超 100）
  final int percent;
}

List<ExpenseRecord> _nonPrepay(List<ExpenseRecord> expenses) =>
    expenses.where((e) => e.type != ExpenseType.prepay).toList();

/// 团级总览。[memberCount] 为团内成员总数。
GroupStats summarize(List<ExpenseRecord> expenses, {required int memberCount}) {
  final list = _nonPrepay(expenses);
  var total = 0;
  for (final e in list) {
    if (e.type == ExpenseType.refund) continue; // 退款=收款收入，不计入支出总额
    total += e.amountCents;
  }
  var prepay = 0;
  for (final e in expenses) {
    if (e.type == ExpenseType.prepay) prepay += e.amountCents;
  }
  return GroupStats(
    totalCents: total,
    count: list.length,
    prepayTotalCents: prepay,
    avgPerPersonCents: memberCount > 0 ? total ~/ memberCount : 0,
  );
}

/// 成员排行（保持传入 [members] 顺序，UI 自行排序展示）
List<MemberStat> memberStatistics({
  required List<MemberRecord> members,
  required List<ExpenseRecord> expenses,
}) {
  final paid = <String, int>{};
  final share = <String, int>{};
  for (final m in members) {
    paid[m.id] = 0;
    share[m.id] = 0;
  }
  for (final e in _nonPrepay(expenses)) {
    for (final p in e.payers) {
      paid[p.memberId] = (paid[p.memberId] ?? 0) + p.cents;
    }
    for (final s in e.shares) {
      share[s.memberId] = (share[s.memberId] ?? 0) + s.cents;
    }
  }
  return [
    for (final m in members)
      MemberStat(
        member: m,
        paidCents: paid[m.id]!,
        shareCents: share[m.id]!,
      ),
  ];
}

/// 分类合计（key -> 分），含 refund 冲减、不含 prepay
Map<String, int> totalsByCategory(List<ExpenseRecord> expenses) {
  final map = <String, int>{};
  for (final e in _nonPrepay(expenses)) {
    map[e.categoryKey] = (map[e.categoryKey] ?? 0) + e.amountCents;
  }
  return map;
}

/// 分类占比列表，按金额降序
List<CategoryShare> categoryShares(List<ExpenseRecord> expenses) {
  final totals = totalsByCategory(expenses);
  var total = 0;
  for (final v in totals.values) {
    total += v;
  }
  return [
    for (final e in totals.entries)
      CategoryShare(
        key: e.key,
        cents: e.value,
        percent: total == 0 ? 0 : ((e.value * 1000 / total).round() / 10),
      ),
  ]..sort((a, b) => b.cents.compareTo(a.cents));
}

/// 每日合计（epochDay -> 分），不含 prepay
Map<int, int> totalsByDay(List<ExpenseRecord> expenses) {
  final map = <int, int>{};
  for (final e in _nonPrepay(expenses)) {
    map[e.dateEpochDay] = (map[e.dateEpochDay] ?? 0) + e.amountCents;
  }
  return map;
}

/// 预算进度；[budgetCents] 为空或 ≤0 视为未设预算返回 null。
BudgetProgress? budgetProgress({
  required List<ExpenseRecord> expenses,
  required int? budgetCents,
}) {
  if (budgetCents == null || budgetCents <= 0) return null;
  var spent = 0;
  for (final e in _nonPrepay(expenses)) {
    spent += e.amountCents;
  }
  return BudgetProgress(
    spentCents: spent,
    remainingCents: budgetCents - spent,
    percent: spent * 100 ~/ budgetCents,
  );
}

/// 统一抽象：同时支持 ExpenseRecord 和 drift Expense
class _Ex {
  const _Ex._(this.id, this.type, this.amountCents, this.categoryKey, this.dateEpochDay, this.payersList, this.sharesList);
  final String id, type, categoryKey;
  final int amountCents, dateEpochDay;
  final List<dynamic> payersList, sharesList;
  bool get isPrepay => type == 'prepay';
}

/// 包装类：兼容 ledger_providers.dart 的静态调用风格
class StatsCalculator {
  static _Ex _wrap(dynamic e) {
    if (e is ExpenseRecord) return _Ex._(e.id, e.type.name, e.amountCents, e.categoryKey, e.dateEpochDay, e.payers, e.shares);
    // drift Expense row
    return _Ex._(e.id, e.type as String, e.amountCents as int, e.categoryKey as String, e.dateEpochDay as int, [], []);
  }
  static List<_Ex> _toEs(List<dynamic> es) => es.map(_wrap).toList();
  static int totalCents(List es) => _toEs(es).where((e)=>!e.isPrepay).fold(0,(s,e)=>s+e.amountCents);
  static int countOf(List es) => _toEs(es).where((e)=>!e.isPrepay).length;
  static int prepayTotalCents(List es) => _toEs(es).where((e)=>e.isPrepay).fold(0,(s,e)=>s+e.amountCents);
  static Map<String,int> paidByMember(List es, {bool includePrepay = false}) { final m=<String,int>{}; for(final e in _toEs(es).where((x)=>includePrepay||!x.isPrepay)) { for(final p in e.payersList) { final mid=p is Map?(p["memberId"]??""):(p.memberId??""); final c=p is Map?(p["cents"]??0) as int:(p.cents??0) as int; m[mid]=(m[mid]??0)+c; } } return m; }
  static Map<String,int> shareByMember(List es, {bool includePrepay = false}) { final m=<String,int>{}; for(final e in _toEs(es).where((x)=>includePrepay||!x.isPrepay)) { for(final s in e.sharesList) { final mid=s is Map?(s["memberId"]??""):(s.memberId??""); final c=s is Map?(s["cents"]??0) as int:(s.cents??0) as int; m[mid]=(m[mid]??0)+c; } } return m; }
  static Map<String,int> categoryTotals(List es) { final m=<String,int>{}; for(final e in _toEs(es).where((x)=>!x.isPrepay)) { m[e.categoryKey]=(m[e.categoryKey]??0)+e.amountCents; } return m; }
  static Map<int,int> dailyTotals(List es) { final m=<int,int>{}; for(final e in _toEs(es).where((x)=>!x.isPrepay)) { m[e.dateEpochDay]=(m[e.dateEpochDay]??0)+e.amountCents; } return m; }
}
