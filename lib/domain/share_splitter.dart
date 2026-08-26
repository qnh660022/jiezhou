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
