/// AA 分摊核心算法：把一笔总额按三种模式拆到每个成员。
///
/// 三种模式（与 Expenses.shareMode 对应）：
/// * equal    —— 均摊，余数按成员顺序每人 +1 分配尽；
/// * portions —— 按份数最大余数法，余数平局按成员 id 字典序；
///               整体缺失或全部为 0 回退 equal；表中没有的成员按序补领
///               「成员数 − 声明总份数」的缺口（每人 1 份），缺口耗尽后按 0 份处理；
/// * custom   —— 直接采用传入明细，校验总额守恒否则抛 ArgumentError。
///
/// 所有模式保证 Σ结果 == totalCents（含负数退款场景）。
/// 本文件纯 Dart 无 IO。
library;

import 'models.dart';

/// 把 [totalCents] 拆分为每人应摊明细。
///
/// [portions] 仅在 mode==portions 时使用（memberId -> 份数）；
/// [customShares] 仅在 mode==custom 时使用。
List<ShareEntry> splitShares({
  required int totalCents,
  required List<String> memberIds,
  ShareMode mode = ShareMode.equal,
  Map<String, int> portions = const {},
  List<ShareEntry>? customShares,
}) {
  final ids = _validatedIds(memberIds);
  switch (mode) {
    case ShareMode.equal:
      return _splitEqual(totalCents, ids);
    case ShareMode.portions:
      return _splitPortions(totalCents, ids, portions);
    case ShareMode.percent:
      // 语义重载：percent 模式下 [portions] 是万分比 bp 表（10000 = 100%）。
      return _splitPercent(totalCents, ids, portions);
    case ShareMode.custom:
      return _splitCustom(totalCents, ids, customShares);
  }
}

List<String> _validatedIds(List<String> memberIds) {
  final seen = <String>{};
  for (final id in memberIds) {
    if (id.isEmpty) throw ArgumentError('成员 id 不能为空');
    if (!seen.add(id)) throw ArgumentError('成员重复: $id');
  }
  if (seen.isEmpty) throw ArgumentError('至少需要一名成员');
  return memberIds;
}

/// 均摊：绝对值均分后按符号还原，余数从第一名成员开始逐人 +1。
List<ShareEntry> _splitEqual(int totalCents, List<String> ids) {
  final n = ids.length;
  final sign = totalCents.isNegative ? -1 : 1;
  final abs = totalCents.abs();
  final base = abs ~/ n;
  var rem = abs % n;
  return [
    for (final id in ids)
      ShareEntry(memberId: id, cents: sign * (base + (rem-- > 0 ? 1 : 0))),
  ];
}

/// 按份数最大余数法。份数缺失/全 0 回退 equal；
/// 平局按成员 id 字典序（保证确定性）。
List<ShareEntry> _splitPortions(
    int totalCents, List<String> ids, Map<String, int> portions) {
  final valid = <String, int>{
    for (final id in ids)
      if ((portions[id] ?? 0) > 0) id: portions[id]!,
  };
  if (valid.isEmpty) return _splitEqual(totalCents, ids);

  // 表中没有的成员按序补领缺口：总份数预算 = 成员数 n，表内声明的总份数不足 n 时，
  // 缺失成员依 ids 顺序各认领 1 份直到预算耗尽；仍未领到的成员按 0 份处理。
  // 例：ids=[a,b,c]、表 {a:2} → 缺口 1 份由 b 认领，权重变为 a:2/b:1/c:0。
  var slack = ids.length - valid.values.fold(0, (sum, p) => sum + p);
  for (final id in ids) {
    if (slack <= 0) break;
    if (!valid.containsKey(id)) {
      valid[id] = 1;
      slack--;
    }
  }

  final sign = totalCents.isNegative ? -1 : 1;
  final abs = totalCents.abs();
  final totalP = valid.values.reduce((a, b) => a + b);

  // 先按精确比例向下取整
  final floors = <String, int>{};
  final remainders = <String, int>{};
  var assigned = 0;
  for (final e in valid.entries) {
    final exact = abs * e.value; // 分子放大避免浮点
    final f = exact ~/ totalP;
    floors[e.key] = f;
    remainders[e.key] = exact % totalP;
    assigned += f;
  }
  // 待分配的剩余分数
  var leftover = abs - assigned;
  // 余数大的优先补 1；平局按 id 字典序
  final order = valid.keys.toList()
    ..sort((a, b) {
      final r = remainders[b]!.compareTo(remainders[a]!);
      return r != 0 ? r : a.compareTo(b);
    });
  var idx = 0;
  while (leftover-- > 0) {
    floors[order[idx % order.length]] = floors[order[idx % order.length]]! + 1;
    idx++;
  }
  return [
    for (final id in ids)
      ShareEntry(
        memberId: id,
        cents: sign * (valid.containsKey(id) ? floors[id]! : 0),
      ),
  ];
}

/// 自定义：直接取传入明细并校验守恒。
List<ShareEntry> _splitCustom(
    int totalCents, List<String> ids, List<ShareEntry>? customShares) {
  if (customShares == null || customShares.isEmpty) {
    throw ArgumentError('custom 模式必须提供分摊明细');
  }
  var sum = 0;
  final known = ids.toSet();
  for (final s in customShares) {
    if (!known.contains(s.memberId)) {
      throw ArgumentError('分摊包含未知成员: ${s.memberId}');
    }
    sum += s.cents;
  }
  if (sum != totalCents) {
    throw ArgumentError('分摊总额($sum)与账单总额($totalCents)不一致');
  }
  return List.of(customShares);
}

// ===========================================================================
// 百分比分摊（S3）：bp = 万分比基点，10000 = 100%。
//
// 【语义重载】percent 模式下 `portionsJson` 存的是 bp 整数表（不是份数）：
//   {"<memberId>": <bp>}，归一后 Σbp 恒等于 10000。全流程只用整数运算。
// ===========================================================================

/// 归一化百分比到 bp：剔除 bp<=0，按比例缩放到 Σ==10000（自动归一，不报错）。
///
/// 结果为空集时返回空 Map（调用方回退 equal，与 portions「全 0 回退 equal」同口径）。
Map<String, int> normalizePercentToBp(Map<String, int> raw) {
  final valid = <String, int>{
    for (final e in raw.entries)
      if (e.value > 0) e.key: e.value,
  };
  if (valid.isEmpty) return const {};
  final total = valid.values.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return const {};
  final base = <String, int>{};
  final rem = <String, int>{};
  var assigned = 0;
  for (final e in valid.entries) {
    final exact = e.value * 10000;
    final b = exact ~/ total;
    base[e.key] = b;
    rem[e.key] = exact % total;
    assigned += b;
  }
  var deficit = 10000 - assigned;
  final order = valid.keys.toList()
    ..sort((a, b) {
      final r = rem[b]!.compareTo(rem[a]!);
      return r != 0 ? r : a.compareTo(b);
    });
  var i = 0;
  while (deficit > 0) {
    final id = order[i % order.length];
    base[id] = base[id]! + 1;
    deficit--;
    i++;
  }
  return base;
}

/// 按 bp 表分摊 [totalCents]，断言 Σ结果 == totalCents（含负数场景）。
///
/// 要求 [percents] 已归一（Σ==10000）；未归一请先调 [normalizePercentToBp]。
List<ShareEntry> splitByPercent(int totalCents, Map<String, int> percents) {
  final active = <String, int>{
    for (final e in percents.entries)
      if (e.value > 0) e.key: e.value,
  };
  if (active.isEmpty) return const [];
  final sign = totalCents.isNegative ? -1 : 1;
  final abs = totalCents.abs();
  final base = <String, int>{};
  final rem = <String, int>{};
  var assigned = 0;
  for (final e in active.entries) {
    final exact = abs * e.value;
    final b = exact ~/ 10000;
    base[e.key] = b;
    rem[e.key] = exact % 10000;
    assigned += b;
  }
  var deficit = abs - assigned;
  final order = active.keys.toList()
    ..sort((a, b) {
      final r = rem[b]!.compareTo(rem[a]!);
      return r != 0 ? r : a.compareTo(b);
    });
  var i = 0;
  while (deficit > 0) {
    final id = order[i % order.length];
    base[id] = base[id]! + 1;
    deficit--;
    i++;
  }
  return [
    for (final id in active.keys) ShareEntry(memberId: id, cents: sign * base[id]!),
  ];
}

/// percent 模式内部分摊：先按 [ids] 过滤有效成员 → 归一 → 分摊 →
/// 未参与成员按 0 补齐（保证返回顺序与 [ids] 一致）。
List<ShareEntry> _splitPercent(
    int totalCents, List<String> ids, Map<String, int> percents) {
  final valid = <String, int>{
    for (final id in ids)
      if ((percents[id] ?? 0) > 0) id: percents[id]!,
  };
  if (valid.isEmpty) return _splitEqual(totalCents, ids); // 全 0/全空 → equal
  final bp = normalizePercentToBp(valid);
  final amounts = {for (final e in splitByPercent(totalCents, bp)) e.memberId: e.cents};
  return [
    for (final id in ids) ShareEntry(memberId: id, cents: amounts[id] ?? 0),
  ];
}

/// 按份额数据结构的稳定性校验（供测试与保存前自检）：Σ 必须恰为 [totalCents]。
bool percentSplitBalanced(List<ShareEntry> shares, int totalCents) =>
    shares.fold<int>(0, (a, e) => a + e.cents) == totalCents;
