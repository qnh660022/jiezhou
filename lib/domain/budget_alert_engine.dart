/// 预算预警三级阈值引擎（纯函数）。
///
/// 统计口径与 features/ledger/ledger_providers.dart 的 budgetStatusProvider
/// 保持一致：spent 不含 prepay 类型（由调用方保证）；百分比向下取整，
/// 边界含等于（恰为 50%/80%/100% 即命中对应级别）。
/// 本文件纯 Dart 无 IO。
library;

/// 预警级别（升序即严重度升序）
enum BudgetAlertLevel { info, warning, danger }

/// 三级阈值表：使用比例 -> 级别。边界含等于。
final Map<double, BudgetAlertLevel> kBudgetAlertThresholds = {
  0.5: BudgetAlertLevel.info,
  0.8: BudgetAlertLevel.warning,
  1.0: BudgetAlertLevel.danger,
};

/// 一条预算预警
class BudgetAlert {
  const BudgetAlert({
    required this.level,
    required this.percent,
    required this.spentCents,
    required this.budgetCents,
    required this.messageCn,
  });

  final BudgetAlertLevel level;

  /// 使用比例整数百分位（向下取整，可超 100）
  final int percent;
  final int spentCents;
  final int budgetCents;

  /// 中文提示文案（通知/预警中心直接展示）
  final String messageCn;
}

/// 分 -> 「x.y」元字符串（引擎内轻量格式化，展示层可再加工）
String budgetFmtYuan(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  return '${cents < 0 ? '-' : ''}$yuan.$fen';
}

/// 评估当前预算状态应触发的全部预警。
///
/// * 预算关闭或 [budgetCents] <= 0 -> 空；
/// * 多级同时命中按 info -> warning -> danger 升序返回；
/// * 文案携带实际金额与百分比。
List<BudgetAlert> evaluateAlerts({
  required bool enabled,
  required int budgetCents,
  required int spentCents,
}) {
  if (!enabled || budgetCents <= 0) return const [];
  final percent = spentCents * 100 ~/ budgetCents; // 与 stats_calculator 同口径
  final out = <BudgetAlert>[];
  void push(BudgetAlertLevel lv, String msg) => out.add(BudgetAlert(
      level: lv, percent: percent, spentCents: spentCents, budgetCents: budgetCents, messageCn: msg));

  if (percent >= 50) {
    push(BudgetAlertLevel.info,
        '预算已过半：已用 ¥${budgetFmtYuan(spentCents)} / ¥${budgetFmtYuan(budgetCents)}（$percent%）');
  }
  if (percent >= 80) {
    final remain = budgetCents - spentCents;
    push(BudgetAlertLevel.warning,
        remain >= 0 ? '预算告急：剩余 ¥${budgetFmtYuan(remain)}，注意消费节奏' : '预算告急：已用 $percent%');
  }
  if (percent >= 100) {
    final over = spentCents - budgetCents;
    push(BudgetAlertLevel.danger,
        over > 0 ? '已超支 ¥${budgetFmtYuan(over)}，建议调整预算或控制消费' : '预算刚好用完：已花满 ¥${budgetFmtYuan(budgetCents)}');
  }
  return out;
}
