/// V2.8.1 S8：消费洞察语引擎（纯 Dart，无 IO 无时钟直读，仅环比口径）。
///
/// 规格 §11.2：输入本月/上月各分类总额（int 分）；输出至多 2 条洞察。
/// 触发条件：prev ≥ 5000 分 且 涨幅 ≥ 0.15（多花）或 ≤ -0.15（省了）；
/// 文案模板：「{分类}比上月多花 32%」/「{分类}比上月省了 21%」；
/// 数据不足（<2 月 或 当月 <10 笔）→ 空列表。
library;

class Insight {
  const Insight({
    required this.categoryKey,
    required this.text,
    required this.changeRatio,
  });

  final String categoryKey;
  final String text;

  /// (cur - prev) / prev，正=多花，负=省。
  final double changeRatio;
}

/// 洞察语（仅环比，O4：无集中日、无 AI）。
///
/// [curCount] 为当月账单笔数；笔数 <10 或上月全空（<2 月数据）→ 空列表。
/// 输出按 |changeRatio| 降序，至多 2 条。
List<Insight> monthlyInsights({
  required Map<String, int> curMonth,
  required Map<String, int> prevMonth,
  required String Function(String categoryKey) categoryName,
  int curCount = 0,
}) {
  if (curCount < 10) return const [];
  if (prevMonth.isEmpty) return const []; // <2 月数据

  final out = <Insight>[];
  for (final e in curMonth.entries) {
    final prev = prevMonth[e.key] ?? 0;
    // 触发条件：prev ≥ 5000 分 且 |涨幅| ≥ 0.15
    if (prev < 5000) continue;
    final ratio = (e.value - prev) / prev;
    if (ratio >= 0.15) {
      out.add(Insight(
        categoryKey: e.key,
        changeRatio: ratio,
        text: '${categoryName(e.key)}比上月多花 ${(ratio * 100).round()}%',
      ));
    } else if (ratio <= -0.15) {
      out.add(Insight(
        categoryKey: e.key,
        changeRatio: ratio,
        text: '${categoryName(e.key)}比上月省了 ${(ratio.abs() * 100).round()}%',
      ));
    }
  }
  // 排除涨幅为 0 的并列（未触发），按 |ratio| 降序取前 2
  out.sort((a, b) =>
      b.changeRatio.abs().compareTo(a.changeRatio.abs()));
  return out.take(2).toList();
}
