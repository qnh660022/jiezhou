/// 今日驾驶舱数据桥接层（D1~D3）。
///
/// 设计要点：
/// * 所有「今日」判定都走 [resolveTodayScope] 纯函数（可单测），本文件只负责
///   把 drift 流 + prefs 拼成 UI 需要的形状；
/// * 「进行中行程」= 设备今日落在行程区间内（§8.1），无则整条链路返回 null，
///   首页 TodayCard 与桌面侧栏据此**不渲染**（不是置灰）；
/// * 今日花销只读**本地账本**（`expenses` 业务表）——驾驶舱是个人视角聚合页，
///   协作账本的钱不由它统计（§1.1：驾驶舱不进空间）。
library;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../theme/theme_provider.dart';
import '../ledger/ledger_providers.dart';
import 'today_local_store.dart';
import 'today_scope.dart';

/// 今日本地状态（勾选 / 备注 / 未读游标）。
final todayLocalStoreProvider = Provider<TodayLocalStore>(
    (ref) => TodayLocalStore(ref.watch(sharedPreferencesProvider)));

/// 全部行程（含归档），映射为纯逻辑用的 [TripSpan]。
final tripSpansProvider = StreamProvider<List<TripSpan>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.trips)).watch().map((rows) => [
        for (final t in rows)
          TripSpan(
            id: t.id,
            name: t.name,
            startEpochDay: t.startEpochDay,
            endEpochDay: t.endEpochDay,
            destination: t.destination,
            archived: t.archived,
          ),
      ]);
});

/// 当前进行中的行程（无 → null）。
///
/// 用 `dateToEpochDay(DateTime.now())` 而 **不是** `todayEpochDay()`：
/// 后者是 const 语义上的"今天"，在前台跨零点时不会自动变；这里每次 provider
/// 重算都读一次时钟，配合页面可见期的刷新即可跨日更新。
final activeTripPickProvider = Provider<ActiveTripPick?>((ref) {
  final spans = ref.watch(tripSpansProvider).value;
  if (spans == null) return null;
  return pickActiveTrip(spans);
});

/// 某行程的今日口径（时区/第 N 天/进度）。
final todayScopeProvider = Provider.family<TodayScope?, String>((ref, tripId) {
  final spans = ref.watch(tripSpansProvider).value ?? const <TripSpan>[];
  for (final t in spans) {
    if (t.id == tripId) return resolveTodayScope(trip: t);
  }
  return null;
});

/// 某行程当天的行程项（业务表；本人行程）。
///
/// 驾驶舱只服务"我自己的行程"，故直接读业务表 `trip_items`，
/// 空间里别人的行程由 `/companions/space/:id` 读镜像表（两条数据源不混）。
final todayItemRecordsProvider =
    StreamProvider.family<List<TripItem>, (String tripId, int epochDay)>(
        (ref, arg) {
  final db = ref.watch(dbProvider);
  return (db.select(db.tripItems)
        ..where((t) => t.tripId.equals(arg.$1) & t.dateEpochDay.equals(arg.$2))
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
        ]))
      .watch();});

/// 当天已勾选的行程项 id（本地记忆）。
final todayDoneIdsProvider =
    Provider.family<Set<String>, (String tripId, int epochDay)>((ref, arg) {
  final store = ref.watch(todayLocalStoreProvider);
  // 依赖一个可失效的计数器，勾选后由 UI 调 ref.invalidate 触发重算
  ref.watch(todayDoneRevisionProvider);
  return store.doneIds(arg.$1, arg.$2);
});

/// 勾选态变更的版本号（每次写盘 +1，驱动 [todayDoneIdsProvider] 刷新）。
final todayDoneRevisionProvider = StateProvider<int>((_) => 0);

/// 今日备注文本。
final todayNoteProvider =
    Provider.family<String, (String tripId, int epochDay)>((ref, arg) {
  ref.watch(todayNoteRevisionProvider);
  return ref.watch(todayLocalStoreProvider).note(arg.$1, arg.$2);
});

/// 备注变更版本号。
final todayNoteRevisionProvider = StateProvider<int>((_) => 0);

/// 某行程今日关联账本的支出摘要（金额分 + 类目），供花销卡与花销详情页使用。
///
/// 口径见 [todaySpendCents]：仅当日、退款负数冲减、预付不入日常合计。
class TodaySpendRow {
  const TodaySpendRow({
    required this.id,
    required this.title,
    required this.categoryKey,
    required this.amountCents,
    required this.type,
    required this.note,
    required this.dateEpochDay,
  });

  final String id;
  final String title;
  final String categoryKey;
  final int amountCents;
  final String type;
  final String note;
  final int dateEpochDay;
}

class TodaySpendSummary {
  const TodaySpendSummary({
    required this.rows,
    required this.totalCents,
    required this.groupId,
    required this.groupName,
    required this.budgetCents,
  });

  final List<TodaySpendRow> rows;
  final int totalCents;

  /// 关联账本 id（无关联 → null）。
  final String? groupId;
  final String? groupName;

  /// 账本预算（分）；未开启返回 null。
  final int? budgetCents;

  bool get hasLedger => groupId != null;

  /// 预算余量（分）；无预算返回 null。
  int? get remainingCents =>
      budgetCents == null ? null : budgetCents! - totalCents;

  double? get budgetProgress =>
      (budgetCents == null || budgetCents! <= 0) ? null : totalCents / budgetCents!;
}

/// 某行程的今日花销（含关联账本与预算）。
final todaySpendProvider =
    Provider.family<TodaySpendSummary?, (String tripId, int epochDay)>((ref, arg) {
  final tripId = arg.$1;
  final epochDay = arg.$2;

  // 行程 → 关联账本（trips.groupId）
  final trip = ref.watch(tripSpansWithGroupProvider).value?[tripId];
  final groupId = trip?.groupId;
  if (groupId == null) {
    return const TodaySpendSummary(
      rows: [],
      totalCents: 0,
      groupId: null,
      groupName: null,
      budgetCents: null,
    );
  }
  final expenses = ref.watch(groupExpensesProvider(groupId)).value ??
      const <Expense>[];
  final rows = <TodaySpendRow>[];
  for (final e in expenses) {
    if (e.dateEpochDay != epochDay) continue;
    rows.add(TodaySpendRow(
      id: e.id,
      title: e.title,
      categoryKey: e.categoryKey,
      amountCents: e.amountCents,
      type: e.type,
      note: e.note,
      dateEpochDay: e.dateEpochDay,
    ));
  }
  // 大额置顶（§8.3 花销详情页）
  rows.sort((a, b) => b.amountCents.abs().compareTo(a.amountCents.abs()));
  final total = todaySpendCents(
    expenses.map((e) => (
          dateEpochDay: e.dateEpochDay,
          amountCents: e.amountCents,
          type: e.type
        )),
    epochDay,
  );
  final groups = ref.watch(groupsProvider).value ?? const [];
  String? name;
  int? budget;
  for (final g in groups) {
    if (g.id == groupId) {
      name = g.name;
      budget = (g.budgetEnabled && (g.budgetCents ?? 0) > 0) ? g.budgetCents : null;
      break;
    }
  }
  return TodaySpendSummary(
    rows: rows,
    totalCents: total,
    groupId: groupId,
    groupName: name,
    budgetCents: budget,
  );
});

/// 行程 id → (groupId, name)，驾驶舱解析关联账本用。
class TripLedgerLink {
  const TripLedgerLink({required this.groupId, required this.name});
  final String? groupId;
  final String name;
}

final tripSpansWithGroupProvider =
    StreamProvider<Map<String, TripLedgerLink>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.trips)).watch().map((rows) => {
        for (final t in rows)
          t.id: TripLedgerLink(groupId: t.groupId, name: t.name),
      });
});

/// 某账本的全部账单（drift 原始行；驾驶舱只用当日切片）。
final groupExpensesProvider =
    StreamProvider.family<List<Expense>, String>((ref, groupId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.expenses)..where((e) => e.groupId.equals(groupId))).watch();
});
