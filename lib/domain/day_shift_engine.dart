/// 增减天数顺延引擎（V2.7.2 S2，纯函数）。
///
/// 全部函数为纯函数：输入行程天数与卡列表快照，输出【变更动作列表】，
/// 由 repo 层在同一事务内执行（先改行，后改 Trips，提交后逐行 notifyWrite）。
/// 无 IO、无时钟直读——本引擎只用 epochDay 整数。
///
/// 记 `dayIndex = dateEpochDay − startEpochDay + 1`，`target = startEpochDay + k − 1`（第 k 天）。
///
/// 规则细节（逐条验收，规格 §五 S2.3）：
/// 1. 备胎卡（backupOf 非空/非''）与正式卡同规则平移，不区分处理；
/// 2. shift/merge 的被承接卡 sortOrder = 目标天当前最大 sortOrder + 10 起按原相对顺序续编；
/// 3. discard 产生的 [OpDeleteItem] 必须逐行写墓碑（repo 层负责）；
/// 4. N=1 时 [removeDay] 直接抛 `StateError('至少保留一天')`（UI 禁用入口）；
/// 5. 引擎不改 startEpochDay（起点固定，只有 end 平移）。
library;

import 'records.dart';

/// 单日变更动作。
sealed class DayOp {}

/// 平移/承接：把卡移到新的一天（[newSortOrder] 由引擎按承接规则算好）。
class OpShiftItem extends DayOp {
  OpShiftItem({required this.itemId, required this.newEpochDay, required this.newSortOrder});

  final String itemId;
  final int newEpochDay;
  final int newSortOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpShiftItem &&
          other.itemId == itemId &&
          other.newEpochDay == newEpochDay &&
          other.newSortOrder == newSortOrder;

  @override
  int get hashCode => Object.hash(itemId, newEpochDay, newSortOrder);

  @override
  String toString() => 'OpShiftItem($itemId → day$newEpochDay ord$newSortOrder)';
}

/// 物理删除（repo 层补墓碑 notifyWrite(op:'delete')）。
class OpDeleteItem extends DayOp {
  OpDeleteItem({required this.itemId});

  final String itemId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OpDeleteItem && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}

/// 行程 endEpochDay 调整（引擎不改 startEpochDay）。
class OpSetEnd extends DayOp {
  OpSetEnd({required this.newEndEpochDay});

  final int newEndEpochDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpSetEnd && other.newEndEpochDay == newEndEpochDay;

  @override
  int get hashCode => newEndEpochDay.hashCode;
}

/// 删除第 k 天的承接模式（三选一）。
enum RemoveMode {
  /// 被删天卡并入「原第 k+1 天」：该天随整体前移成为新第 k 天
  /// （epochDay=target），被删天卡在其末尾按步长 10 续编；更晚的卡各 -1。
  /// k==N（末天无后一天）禁用，引擎抛 StateError。
  shift,

  /// 被删天卡并入前一天（target-1），随后更晚的卡各 -1；k==1 禁用。
  merge,

  /// 被删天卡物理删除（逐行墓碑），随后更晚的卡各 -1。
  discard,
}

List<TripItemRecord> _sortedByDayOrder(List<TripItemRecord> items) {
  final list = List<TripItemRecord>.of(items);
  list.sort((a, b) {
    final byDay = a.dateEpochDay.compareTo(b.dateEpochDay);
    if (byDay != 0) return byDay;
    return a.sortOrder.compareTo(b.sortOrder);
  });
  return list;
}

int _maxSortOrderOfDay(List<TripItemRecord> sorted, int day) {
  var max = 0;
  for (final it in sorted) {
    if (it.dateEpochDay == day && it.sortOrder > max) max = it.sortOrder;
  }
  return max;
}

/// 在第 k 天后插入一个空天（k 允许 0..N，0=最前）：
/// `dateEpochDay >= start+k` 的卡全部 +1；endEpochDay += 1。
///
/// k==N 与 k==N+1 等价（尾部追加，无卡后移）。
List<DayOp> insertDay({
  required int startEpochDay,
  required int endEpochDay,
  required List<TripItemRecord> items,
  required int k,
}) {
  final n = endEpochDay - startEpochDay + 1;
  assert(n >= 1, '行程至少一天');
  final kk = k.clamp(0, n).toInt();
  final threshold = startEpochDay + kk; // dateEpochDay >= threshold → +1
  final ops = <DayOp>[];
  for (final it in _sortedByDayOrder(items)) {
    if (it.dateEpochDay >= threshold) {
      ops.add(OpShiftItem(
          itemId: it.id, newEpochDay: it.dateEpochDay + 1, newSortOrder: it.sortOrder));
    }
  }
  ops.add(OpSetEnd(newEndEpochDay: endEpochDay + 1));
  return ops;
}

/// 尾部追加一天：仅 endEpochDay += 1。
List<DayOp> appendDay({required int endEpochDay}) =>
    [OpSetEnd(newEndEpochDay: endEpochDay + 1)];

/// 删除第 k 天（1..N，N>=2），mode 三选一：
/// - [RemoveMode.shift]：被删天卡并入原第 k+1 天（该天前移成新第 k 天，
///   epochDay=target），被删天卡在承接天末尾按步长 10 续编；
///   `dateEpochDay > target` 的卡各 -1。k==N 禁用（抛 StateError，UI 隐藏入口）。
/// - [RemoveMode.merge]：target 当天卡 → target-1（追加 sortOrder）；
///   `dateEpochDay > target` 的卡各 -1。k==1 禁用（抛 StateError）。
/// - [RemoveMode.discard]：target 当天卡物理删除（OpDeleteItem）；
///   `dateEpochDay > target` 的卡各 -1。
///
/// 三种模式最终都 `OpSetEnd(endEpochDay - 1)`。
List<DayOp> removeDay({
  required int startEpochDay,
  required int endEpochDay,
  required List<TripItemRecord> items,
  required int k,
  required RemoveMode mode,
}) {
  final n = endEpochDay - startEpochDay + 1;
  if (n <= 1) throw StateError('至少保留一天');
  if (k < 1 || k > n) throw StateError('删除日序号越界：k=$k, N=$n');
  final target = startEpochDay + k - 1;

  final sorted = _sortedByDayOrder(items);
  final ops = <DayOp>[];

  switch (mode) {
    case RemoveMode.shift:
      // 末天无后一天可承接（UI 对 k=N 隐藏该选项，此处兜底拒绝）
      if (k == n) throw StateError('末天无后一天可承接');
      // 承接天 = 原第 k+1 天（前移后落在 target）；被删天卡追加其末尾
      var next = _maxSortOrderOfDay(
            sorted.where((it) => it.dateEpochDay == target + 1).toList(),
            target + 1,
          );
      for (final it in sorted) {
        if (it.dateEpochDay == target) {
          next += 10;
          ops.add(OpShiftItem(
              itemId: it.id, newEpochDay: target, newSortOrder: next));
        } else if (it.dateEpochDay > target) {
          ops.add(OpShiftItem(
              itemId: it.id,
              newEpochDay: it.dateEpochDay - 1,
              newSortOrder: it.sortOrder));
        }
      }
    case RemoveMode.merge:
      if (k == 1) throw StateError('首日无前一天可合并');
      var next = _maxSortOrderOfDay(
            sorted.where((it) => it.dateEpochDay == target - 1).toList(),
            target - 1,
          );
      for (final it in sorted) {
        if (it.dateEpochDay == target) {
          next += 10;
          ops.add(OpShiftItem(
              itemId: it.id, newEpochDay: target - 1, newSortOrder: next));
        } else if (it.dateEpochDay > target) {
          ops.add(OpShiftItem(
              itemId: it.id,
              newEpochDay: it.dateEpochDay - 1,
              newSortOrder: it.sortOrder));
        }
      }
    case RemoveMode.discard:
      for (final it in sorted) {
        if (it.dateEpochDay == target) {
          ops.add(OpDeleteItem(itemId: it.id));
        } else if (it.dateEpochDay > target) {
          ops.add(OpShiftItem(
              itemId: it.id,
              newEpochDay: it.dateEpochDay - 1,
              newSortOrder: it.sortOrder));
        }
      }
  }
  ops.add(OpSetEnd(newEndEpochDay: endEpochDay - 1));
  return ops;
}
