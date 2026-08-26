/// 行程安排 ↔ 账单 双向联动纯逻辑。
///
/// 只依赖 models.dart，零 Flutter/IO 依赖，可直接单测。联动规则：
/// * 建立关联时由安排一次性预填账单（标题/金额/币种/日期）；
/// * 建立后任一侧修改金额，另一侧同步（后写生效）——见 resolveAmountSync；
/// * 币种字段互不同步，汇率换算不在联动范围（amountCents 即人民币口径原样互写）；
/// * 一个安排至多一条未结算关联账单；历史多条时由仓储按 createdAt 取最新为同步目标；
/// * 删除安排保留账单仅解绑；删除账单不影响安排（仓储层既有语义）。
library;

import 'models.dart';

/// 行程安排的联动最小视图（调用方从 drift TripItem 行构造）
class TripPlanItem {
  const TripPlanItem({
    required this.id,
    required this.name,
    required this.dateEpochDay,
    this.costCents,
    this.costCurrency = 'CNY',
  });

  final String id;
  final String name;

  /// 记账/入账日期（epochDay）
  final int dateEpochDay;

  /// 计划费用（分；null 或 0 视为「未定价」，不可一键入账）
  final int? costCents;
  final String costCurrency;
}

/// 由安排生成账单时的预填结构
class LinkedBillPrefill {
  const LinkedBillPrefill({
    required this.title,
    required this.amountCents,
    required this.currency,
    required this.dateEpochDay,
  });

  final String title;
  final int amountCents;
  final String currency;
  final int dateEpochDay;
}

/// 安排 → 账单预填；无计划费用返回 null（UI 隐藏一键入账入口）
LinkedBillPrefill? prefillFromItem(TripPlanItem item) {
  final c = item.costCents;
  if (c == null || c == 0) return null;
  return LinkedBillPrefill(
    title: item.name,
    amountCents: c,
    currency: item.costCurrency,
    dateEpochDay: item.dateEpochDay,
  );
}

/// 计划 vs 实际 对比结果
class PlannedActual {
  const PlannedActual({
    required this.plannedCents,
    required this.actualCents,
    required this.linkedCount,
    required this.unlinkedCostItems,
  });

  /// 计划合计：仅统计 costCurrency==CNY 的安排费用（外币标注原值不计和）
  final int plannedCents;

  /// 实际合计：该行程关联账单 amountCents 直加（含退款负数，口径同「关联账单」sheet 合计）
  final int actualCents;

  /// 已关联账单笔数
  final int linkedCount;

  /// 已填计划费用但尚未关联账单的安排数
  final int unlinkedCostItems;
}

/// 行程维度 计划 vs 实际 汇总
PlannedActual plannedVsActual(
    List<TripPlanItem> items, List<ExpenseRecord> expenses) {
  var planned = 0;
  var unlinked = 0;
  final linkedItemIds = <String>{};
  for (final e in expenses) {
    if (e.tripItemId != null) linkedItemIds.add(e.tripItemId!);
  }
  for (final i in items) {
    final c = i.costCents;
    if (c != null && i.costCurrency == 'CNY') planned += c;
    if (c != null && c != 0 && !linkedItemIds.contains(i.id)) unlinked++;
  }
  var actual = 0;
  for (final e in expenses) {
    actual += e.amountCents;
  }
  return PlannedActual(
    plannedCents: planned,
    actualCents: actual,
    linkedCount: expenses.length,
    unlinkedCostItems: unlinked,
  );
}

/// 同步来源：哪一侧刚被用户修改
enum SyncSource { expenseEdit, itemEdit }

/// 同步去向
enum SyncTarget {
  /// 无需动作（两侧本就相等，或触发侧不满足同步条件）
  none,

  /// 把金额写到安排 costCents（账单侧刚被修改）
  updateItem,

  /// 把金额写到账单 amountCents（安排侧刚被修改）
  updateExpense,
}

/// 单次金额同步判定结果
class SyncDecision {
  const SyncDecision._(this.target, this.newAmountCents);
  final SyncTarget target;

  /// 应写入目标侧的新金额（target==none 时无意义）
  final int newAmountCents;

  static const SyncDecision noop = SyncDecision._(SyncTarget.none, 0);
}

/// 金额双向同步判定（后写生效）。
///
/// 特例：安排侧把计划费用清空（null）不视为「改成 0」，不同步清零账单——
/// 清空语义是「暂不给计划价」，账单实付保持不动。
SyncDecision resolveAmountSync({
  required int expenseAmountCents,
  required int? itemCostCents,
  required SyncSource source,
}) {
  switch (source) {
    case SyncSource.expenseEdit:
      if (itemCostCents == expenseAmountCents) return SyncDecision.noop;
      return SyncDecision._(SyncTarget.updateItem, expenseAmountCents);
    case SyncSource.itemEdit:
      if (itemCostCents == null) return SyncDecision.noop;
      if (expenseAmountCents == itemCostCents) return SyncDecision.noop;
      return SyncDecision._(SyncTarget.updateExpense, itemCostCents);
  }
}
