/// 统计计算器：总览/成员排行/分类占比/每日合计/月度趋势/预算进度。
///
/// 【口径】
/// * 除预付款外的一切统计均包含已结算账单（历史金额照常计入）；
/// * type == prepay 只进 prepayTotal，不进 total/count；
/// * refund 以负数自然冲减总额。
///
/// 【G3（V2.7.1 S2）】本文件已收口为**全类型化**纯函数：一律 `List<ExpenseRecord>`
/// / `List<MemberRecord>`，不再有 `_Ex` 包装、`dynamic` 与「drift 行 / 领域记录」双形态分支。
/// 旧的 `StatsCalculator` 静态包装类已删除（其唯一调用方 stats.dart 已同步迁移）。
///
/// 本文件纯 Dart 无 IO。
library;

import '../core/date_utils.dart';
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

/// 月度合计项（S6 趋势折线用）
class MonthlyTotal {
  const MonthlyTotal({required this.monthKey, required this.cents});

  /// `year * 100 + month`（如 202609）
  final int monthKey;
  final int cents;
}

List<ExpenseRecord> _nonPrepay(List<ExpenseRecord> expenses) =>
    expenses.where((e) => e.type != ExpenseType.prepay).toList();

// ---------------------------------------------------------------------------
// 类型化标量口径（原 StatsCalculator 静态包装的直接替代）
// ---------------------------------------------------------------------------

/// 总支出（分）：normal + refund 冲减，不含 prepay。
int totalCents(List<ExpenseRecord> expenses) {
  var sum = 0;
  for (final e in expenses) {
    if (e.type == ExpenseType.prepay) continue;
    sum += e.amountCents;
  }
  return sum;
}

/// 账单笔数：不含 prepay。
int countOf(List<ExpenseRecord> expenses) => _nonPrepay(expenses).length;

/// 预付款合计（分）。
int prepayTotalCents(List<ExpenseRecord> expenses) {
  var sum = 0;
  for (final e in expenses) {
    if (e.type == ExpenseType.prepay) sum += e.amountCents;
  }
  return sum;
}

/// 每人已付合计（memberId -> 分）。[includePrepay] 为 true 时含预付款账单。
Map<String, int> paidByMember(List<ExpenseRecord> expenses,
    {bool includePrepay = false}) {
  final map = <String, int>{};
  for (final e in includePrepay ? expenses : _nonPrepay(expenses)) {
    for (final p in e.payers) {
      map[p.memberId] = (map[p.memberId] ?? 0) + p.cents;
    }
  }
  return map;
}

/// 每人应摊合计（memberId -> 分）。[includePrepay] 为 true 时含预付款账单。
Map<String, int> shareByMember(List<ExpenseRecord> expenses,
    {bool includePrepay = false}) {
  final map = <String, int>{};
  for (final e in includePrepay ? expenses : _nonPrepay(expenses)) {
    for (final s in e.shares) {
      map[s.memberId] = (map[s.memberId] ?? 0) + s.cents;
    }
  }
  return map;
}

// ---------------------------------------------------------------------------
// 既有口径（保持逐位不变）
// ---------------------------------------------------------------------------

/// 团级总览。[memberCount] 为团内成员总数。
GroupStats summarize(List<ExpenseRecord> expenses, {required int memberCount}) {
  final list = _nonPrepay(expenses);
  final total = totalCents(expenses);
  final prepay = prepayTotalCents(expenses);
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
  final spent = totalCents(expenses);
  return BudgetProgress(
    spentCents: spent,
    remainingCents: budgetCents - spent,
    percent: spent * 100 ~/ budgetCents,
  );
}

// ---------------------------------------------------------------------------
// S6 · 统计升级：月度趋势 + 时间范围筛选
//
// 【时区口径】本模块一律用 dateEpochDay（设备本地日），与「今日驾驶舱」的
// 目的地时区口径**不同**；UI 必须标注「按设备本地日期统计」。
// ---------------------------------------------------------------------------

/// 时间范围（会话级，不持久化；默认 all）
enum StatsRange { all, thisMonth, lastMonth, thisYear, custom }

/// 自定义日期的可选边界（与记账表单一致）
final int kStatsCustomMinEpochDay = dateToEpochDay(DateTime(2015, 1, 1));
final int kStatsCustomMaxEpochDay = dateToEpochDay(DateTime(2045, 12, 31));

/// 闭区间 [fromEpochDay, toEpochDay]；null 表示该侧无界。
class DayRange {
  const DayRange({this.fromEpochDay, this.toEpochDay});

  final int? fromEpochDay;
  final int? toEpochDay;

  bool contains(int day) =>
      (fromEpochDay == null || day >= fromEpochDay!) &&
      (toEpochDay == null || day <= toEpochDay!);
}

/// 解析时间范围的日界（本地日，闭区间）。
///
/// * all → 双端 null；
/// * thisMonth / lastMonth / thisYear → 按 [now] 计算自然月/年边界；
/// * custom → 取 [customFromEpochDay]/[customToEpochDay]，并夹到 2015-01-01~2045-12-31。
DayRange statsRangeBounds(
  StatsRange range, {
  DateTime? now,
  int? customFromEpochDay,
  int? customToEpochDay,
}) {
  final base = now ?? DateTime.now();
  switch (range) {
    case StatsRange.all:
      return const DayRange();
    case StatsRange.thisMonth:
      return _monthRange(base.year, base.month);
    case StatsRange.lastMonth:
      final y = base.month == 1 ? base.year - 1 : base.year;
      final m = base.month == 1 ? 12 : base.month - 1;
      return _monthRange(y, m);
    case StatsRange.thisYear:
      return DayRange(
        fromEpochDay: dateToEpochDay(DateTime(base.year, 1, 1)),
        toEpochDay: dateToEpochDay(DateTime(base.year, 12, 31)),
      );
    case StatsRange.custom:
      var from = customFromEpochDay ?? kStatsCustomMinEpochDay;
      var to = customToEpochDay ?? kStatsCustomMaxEpochDay;
      if (from > to) {
        final t = from;
        from = to;
        to = t;
      }
      if (from < kStatsCustomMinEpochDay) from = kStatsCustomMinEpochDay;
      if (to > kStatsCustomMaxEpochDay) to = kStatsCustomMaxEpochDay;
      return DayRange(fromEpochDay: from, toEpochDay: to);
  }
}

DayRange _monthRange(int year, int month) {
  final last = DateTime(year, month + 1, 0).day;
  return DayRange(
    fromEpochDay: dateToEpochDay(DateTime(year, month, 1)),
    toEpochDay: dateToEpochDay(DateTime(year, month, last)),
  );
}

/// 月度合计（monthKey = year*100+month）。口径同 [totalsByDay]：
/// 含已结算、不含 prepay、refund 负数冲减。
Map<int, int> totalsByMonth(
  List<ExpenseRecord> expenses, {
  int? fromEpochDay,
  int? toEpochDay,
}) {
  final map = <int, int>{};
  for (final e in _nonPrepay(expenses)) {
    if (fromEpochDay != null && e.dateEpochDay < fromEpochDay) continue;
    if (toEpochDay != null && e.dateEpochDay > toEpochDay) continue;
    final d = epochDayToDate(e.dateEpochDay);
    final key = d.year * 100 + d.month;
    map[key] = (map[key] ?? 0) + e.amountCents;
  }
  return map;
}

/// 枚举 [fromEpochDay]..[toEpochDay] 覆盖的全部年月 key（含首尾整月）。
List<int> monthKeysBetween(int fromEpochDay, int toEpochDay) {
  final from = epochDayToDate(fromEpochDay);
  final to = epochDayToDate(toEpochDay);
  final out = <int>[];
  var y = from.year;
  var m = from.month;
  while (y < to.year || (y == to.year && m <= to.month)) {
    out.add(y * 100 + m);
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return out;
}

/// 趋势序列：按范围聚合 + **空月补 0**（折线不跳点）。
///
/// * [StatsRange.all]：以数据自身的最小/最大月份为界（无数据返回空表）；
/// * 其余范围：以自然边界补齐（保证「本月」永远 1 个点、「今年」最多 12 个点）。
List<MonthlyTotal> monthlyTrend(
  List<ExpenseRecord> records, {
  required StatsRange range,
  DateTime? now,
  int? customFromEpochDay,
  int? customToEpochDay,
}) {
  final totals = totalsByMonth(records);
  if (range == StatsRange.all) {
    if (totals.isEmpty) return const [];
    final keys = totals.keys.toList()..sort();
    return [for (final k in keys) MonthlyTotal(monthKey: k, cents: totals[k]!)];
  }
  final bounds = statsRangeBounds(range,
      now: now,
      customFromEpochDay: customFromEpochDay,
      customToEpochDay: customToEpochDay);
  final keys =
      monthKeysBetween(bounds.fromEpochDay!, bounds.toEpochDay!);
  final scoped = totalsByMonth(records,
      fromEpochDay: bounds.fromEpochDay, toEpochDay: bounds.toEpochDay);
  return [
    for (final k in keys) MonthlyTotal(monthKey: k, cents: scoped[k] ?? 0),
  ];
}
