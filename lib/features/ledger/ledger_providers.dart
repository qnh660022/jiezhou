/// 记账线数据桥接层：对数据层 / 领域算法的全部 import 与调用集中在此。
///
/// 【T2 对齐说明·预热期假设清单】
/// 以下文件尚未落地，均按 T2 任务描述的命名假设接入；T2 完成广播后，
/// 若真实签名有出入，**只需校正本文件**（屏幕零改动）：
/// * data/repo/ledger_repo.dart：
///     - class LedgerRepository：watchGroups/watchActiveGroupId/watchMembers/watchExpenses/
///       watchSettlements/addExpense/updateExpense/deleteExpense/setExpenseSettled/
///       addGroup(name,icon)/updateGroup(id,name,icon)/deleteGroup/setActiveGroup/
///       addMember(groupId,name)/renameMember/deleteMember(被引用抛StateError)/
///       setBudget(groupId,{enabled,budgetCents})/createSettlement/markTransferDone(id,index,done)/
///       completeSettlement/undoLastSettlement/exportGroupJson/importGroupJson→ImportReport
///     - Group{id,name,icon,budgetEnabled,budgetCents}
///     - Settlement{id,groupId,status(SettlementStatus),transfers(List<TransferRecord{from,to,cents,done}>),roundNo,createdAt,completedAt}
///     - SettlementStatus{active,completed}
///     - ImportReport{groups,members,expenses,settlements,trips,tripItems,reusedCategories,warnings}
/// * data/repo/trips_repo.dart：watchTripsByGroup→List<Trip>/watchItemsByTrip→List<TripItem>
///     - Trip{id,name,destination,emoji,cover,startEpochDay,endEpochDay,archived,...}
///     - TripItem{id,tripId,name,dateEpochDay,costCents,costCurrency,...}
/// * data/repo/categories_repo.dart：watchCategories→List<Category{key,name,icon,builtin}>/
///     addCustomCategory/deleteCustomCategory(被引用抛StateError)/kCategoryIconChoices(18)
/// * data/repo/prefs_repo.dart：getCurrencyRates/setCurrencyRate
/// * data/seed/currencies.dart：const kCurrencies List<Currency{code,symbol,name,rate}>（13币种）
/// * domain/share_splitter.dart：splitShares({totalCents,memberIds,mode,portions})→List<ShareEntry>
/// * domain/settle_engine.dart：computeNetBalances(List<Member>,List<Expense>)→Map<String,int>/
///     minTransferPlan(balances)→List<TransferPlan{from,to,cents}>
/// * domain/stats_calculator.dart（静态）：totalCents/countOf/prepayTotalCents/paidByMember/
///     shareByMember/categoryTotals/dailyTotals
library;

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_utils.dart';
import '../../core/uid.dart';
import '../../data/providers.dart'; // all repo providers + dbProvider
import '../../data/repo/categories_repo.dart';
import '../../data/seed/currencies.dart';
import '../../data/db/database.dart' hide Settlement; // hide to avoid conflict with models.dart
import '../../domain/stats_calculator.dart';
import '../../domain/csv_builder.dart';
import '../../domain/models.dart';
import '../../domain/settle_engine.dart';
import '../../domain/share_splitter.dart';
import '../../domain/budget_alert_engine.dart';
import 'ledger_models.dart';

// ---------------------------------------------------------------------------
// 仓储单例：T2 落地后按真实构造方式接入（如需要 AppDatabase 则在此注入）
// ---------------------------------------------------------------------------



// ---------------------------------------------------------------------------
// 视图转换（原始记录 → UI 视图；字段出入只改这里）
// ---------------------------------------------------------------------------

LedgerGroupView groupViewOf(Group g) => LedgerGroupView(
      id: g.id,
      name: g.name,
      icon: g.icon,
      budgetEnabled: g.budgetEnabled,
      budgetCents: g.budgetCents,
    );

/// colorIndex 兜底：与 AvatarPalette.colorForName 同源的姓名稳定哈希
int fallbackColorIndex(String name) {
  var sum = 0;
  for (final unit in name.codeUnits) {
    sum += unit;
  }
  return sum % 8;
}

LedgerMemberView memberViewOf(Member m) =>
    LedgerMemberView(id: m.id, name: m.name, colorIndex: fallbackColorIndex(m.name));

CategoryView categoryViewOf(Category c) =>
    CategoryView(key: c.key, name: c.name, icon: c.icon, builtin: c.builtin);

TripCardView tripCardViewOf(Trip t) => TripCardView(
      id: t.id,
      name: t.name,
      destination: t.destination,
      emoji: t.emoji,
      cover: t.cover,
      startEpochDay: t.startEpochDay,
      endEpochDay: t.endEpochDay,
      archived: t.archived,
    );

TripItemOption itemOptionOf(TripItem i) => TripItemOption(
      id: i.id,
      tripId: i.tripId,
      name: i.name,
      dateEpochDay: i.dateEpochDay,
      costCents: i.costCents,
      costCurrency: i.costCurrency,
    );

SettlementView settlementViewOf(Settlement s) => SettlementView(
      id: s.id,
      groupId: s.groupId,
      active: s.status == SettlementStatus.active,
      roundNo: s.roundNo,
      transfers: s.transfers
          .map((t) => TransferView(from: t.from, to: t.to, cents: t.cents, done: t.done))
          .toList(),
      createdAtMs: s.createdAt,
      completedAtMs: s.completedAt,
    );

CurrencyView currencyViewOf(CurrencyInfo c) =>
    CurrencyView(code: c.code, symbol: c.symbol, name: c.name, defaultRate: c.rate);

// ---------------------------------------------------------------------------
// 基础流
// ---------------------------------------------------------------------------

/// 当前激活团 id（SharedPreferences 持久化）
final activeGroupIdProvider =
    StreamProvider<String?>((ref) => ref.watch(ledgerRepoProvider).watchActiveGroupId());

/// 行程关联账单原始流（行程详情入账徽章 / 计划vs实际卡用；drift 行直出）
final tripBillsProvider =
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
  return ref.watch(ledgerRepoProvider).watchByTrip(tripId);
});

/// 全部团
final groupsProvider = StreamProvider<List<LedgerGroupView>>(
    (ref) => ref.watch(ledgerRepoProvider).watchGroups().map((l) => l.map(groupViewOf).toList()));

/// 当前团（无团时 data 为 null）
final activeGroupProvider = Provider<AsyncValue<LedgerGroupView?>>((ref) {
  final groups = ref.watch(groupsProvider);
  final id = ref.watch(activeGroupIdProvider).value;
  if (groups.isLoading) return const AsyncValue.loading();
  final list = groups.value ?? const <LedgerGroupView>[];
  for (final g in list) {
    if (g.id == id) return AsyncValue.data(g);
  }
  return const AsyncValue.data(null);
});

/// 当前团成员
final membersProvider = StreamProvider<List<LedgerMemberView>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <LedgerMemberView>[]);
  return ref
      .watch(ledgerRepoProvider)
      .watchMembers(gid)
      .map((l) => l.map(memberViewOf).toList());
});

/// 当前团账单（全量；屏幕侧再做筛选）。
///
/// 【健壮性修复】原始实现在 `.map()` 内对每条记录做 `ExpenseType.values.byName` /
/// `ShareMode.values.byName` / `portionsJson` 解析，且 portions 字段被错误地当成
/// JSON 数组（实际是对象）强制 `as List`，任一记录解析抛异常就会让**整条流进入
/// error 状态**，StreamProvider 的 `.value` 变 null，账单列表整体回退到「一笔都还没记」
/// 的空状态——即「记账成功却不显示」。
///
/// 现改为：逐条 try 转换，单条失败只丢弃该条（绝不拖垮整页），portions 按对象解析，
/// 枚举按名字安全兜底。这同时覆盖了按份数模式必崩、以及脏数据导致整页空白两类问题。
final expensesProvider = StreamProvider<List<ExpenseRecord>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <ExpenseRecord>[]);
  return ref.watch(ledgerRepoProvider).watchExpenses(gid).map(
    (list) => [
      for (final e in list) _tryMapExpense(e),
    ].whereType<ExpenseRecord>().toList(),
  );
});

/// 单条账单记录 → 视图模型；解析失败返回 null（由上层 .whereType 丢弃）。
ExpenseRecord? _tryMapExpense(Expense e) {
  try {
    return ExpenseRecord(
      id: e.id,
      groupId: e.groupId,
      dateEpochDay: e.dateEpochDay,
      title: e.title,
      categoryKey: e.categoryKey,
      type: _safeExpenseType(e.type),
      amountCents: e.amountCents,
      currency: e.currency,
      rate: e.rate,
      amountForeignCents: e.amountForeignCents,
      payers: _parseShareList(e.payersJson),
      shares: _parseShareList(e.sharesJson),
      shareMode: _safeShareMode(e.shareMode),
      // portions 是 JSON 对象（memberId->份数），不是数组；修正解析避免 TypeError
      portions: e.portionsJson == null ? null : _decodePortions(e.portionsJson!),
      note: e.note,
      settledRoundId: e.settledRoundId,
      tripId: e.tripId,
      tripItemId: e.tripItemId,
    );
  } catch (_) {
    return null;
  }
}

/// 安全解析按份数表：JSON 对象 -> {memberId: 份数}；格式异常返回 null 而非抛错。
Map<String, int>? _decodePortions(String json) {
  if (json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return null;
    final out = <String, int>{};
    decoded.forEach((k, v) {
      if (k is String) out[k] = v is num ? v.toInt() : 0;
    });
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

/// 账单类型枚举安全解析：未知字符串兜底 normal（避免 .byName 抛错拖垮整页）
ExpenseType _safeExpenseType(String s) {
  for (final t in ExpenseType.values) {
    if (t.name == s) return t;
  }
  return ExpenseType.normal;
}

/// 分摊方式枚举安全解析：未知字符串兜底 equal
ShareMode _safeShareMode(String s) {
  for (final m in ShareMode.values) {
    if (m.name == s) return m;
  }
  return ShareMode.equal;
}

List<ShareEntry> _parseShareList(String json) {
  if (json.isEmpty || json == '[]') return const [];
  try {
    final list = _jsonDecode(json);
    return list.map((e) => ShareEntry(
      memberId: e['memberId'] as String,
      cents: (e['cents'] as num).toInt(),
    )).toList();
  } catch (_) {
    return const [];
  }
}

List<dynamic> _jsonDecode(String s) => jsonDecode(s) as List<dynamic>;


/// 当前团结算轮（进行中在前 + 历史轮次降序）
final settlementsProvider = StreamProvider<List<SettlementView>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <SettlementView>[]);
  return ref.watch(ledgerRepoProvider).watchSettlements(gid).map((l) {
    final views = l.map<SettlementView>(settlementViewOf).toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return b.roundNo - a.roundNo;
      });
    return views;
  });
});

/// 进行中的结算轮
final activeSettlementProvider = Provider<AsyncValue<SettlementView?>>((ref) {
  final all = ref.watch(settlementsProvider);
  if (all.isLoading) return const AsyncValue.loading();
  SettlementView? found;
  for (final s in all.value ?? const <SettlementView>[]) {
    if (s.active) found = s;
  }
  return AsyncValue.data(found);
});

/// 绑定当前团的行程（横滑小卡 / 关联下拉）
final tripsInGroupProvider = StreamProvider<List<TripCardView>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <TripCardView>[]);
  return ref.watch(tripsRepoProvider).watchTripsByGroup(gid).map(
        (l) => l.map(tripCardViewOf).toList()
          ..sort((a, b) => a.startEpochDay - b.startEpochDay),
      );
});

/// 某行程下的安排（expense_edit 二级联动下拉）
final tripItemsProvider =
    StreamProvider.family<List<TripItemOption>, String>((ref, tripId) {
  return ref.watch(tripsRepoProvider).watchItemsByTrip(tripId).map(
        (l) => l.map(itemOptionOf).toList()
          ..sort((a, b) => a.dateEpochDay - b.dateEpochDay),
      );
});

/// 全部分类（内置 7 锁定 + 自定义）
final categoriesProvider = StreamProvider<List<CategoryView>>(
    (ref) => ref
        .watch(categoriesRepoProvider)
        .watchCategories()
        .map((l) => l.map(categoryViewOf).toList()));

/// 13 币种种子表
final currenciesProvider = FutureProvider<List<CurrencyView>>(
    (ref) async => kCurrencies.map<CurrencyView>(currencyViewOf).toList());

/// 用户记忆汇率（code -> rate）
final currencyRatesProvider = FutureProvider<Map<String, double>>(
    (ref) => ref.read(prefsRepoProvider).getCurrencyRates());

// ---------------------------------------------------------------------------
// 派生统计（组合多个流的同步计算，屏幕用 .when 直接消费）
// ---------------------------------------------------------------------------

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
    final es = expenses.value ?? const <ExpenseRecord>[];
    final paid = StatsCalculator.paidByMember(es);
    final share = StatsCalculator.shareByMember(es);
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
  final spent = StatsCalculator.totalCents(es);
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
  final spent = StatsCalculator.totalCents(es);
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
    final totals = StatsCalculator.categoryTotals(es);
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
    ]..sort((a, b) => b.cents - a.cents);
  });
});

/// 每日合计（epochDay 升序）
final dailyTotalsProvider = Provider<AsyncValue<List<DailyTotalView>>>((ref) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  final es = expenses.value ?? const <ExpenseRecord>[];
  final totals = StatsCalculator.dailyTotals(es);
  return AsyncData([
    for (final e in totals.entries) DailyTotalView(epochDay: e.key, cents: e.value),
  ]..sort((a, b) => a.epochDay - b.epochDay));
});

// ---------------------------------------------------------------------------
// 领域引擎包装（分摊 / 结算）
// ---------------------------------------------------------------------------

/// 三种分摊模式的统一入口（custom 由屏内先校验守恒再传入 shares）
List<ShareEntry> computeSplit({
  required int totalCents,
  required List<String> memberIds,
  required ShareMode mode,
  Map<String, int>? portions,
}) =>
    splitShares(
      totalCents: totalCents,
      memberIds: memberIds,
      mode: mode,
      portions: portions ?? {},
    );

/// 净额表（正=应收，负=应付）
Map<String, int> netBalanceMap(List<LedgerMemberView> members, List<ExpenseRecord> expenses) =>
    computeNetBalances([for(final m in members) MemberRecord(id:m.id,name:m.name,colorIndex:m.colorIndex)], expenses);

/// 最少转账计划
List<TransferPlan> transferPlanOf(Map<String, int> balances) => minTransferPlan(balances);

// ---------------------------------------------------------------------------
// 动作封装（屏幕统一走这里，不直接摸 repo 方法名）
// ---------------------------------------------------------------------------

/// 新增或更新账单
Future<void> saveExpense(WidgetRef ref, ExpenseDraft draft) async {
  final repo = ref.read(ledgerRepoProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  final comp = ExpensesCompanion(
    id: Value(draft.id ?? newId('expense')),
    groupId: Value(draft.groupId),
    dateEpochDay: Value(draft.dateEpochDay),
    title: Value(draft.title),
    categoryKey: Value(draft.categoryKey),
    type: Value(draft.type.name),
    amountCents: Value(draft.amountCents),
    currency: Value(draft.currency),
    rate: Value(draft.rate),
    // ShareEntry 不是 JSON encodable 对象，必须先转换成数据库约定的 Map。
    payersJson: Value(jsonEncode([
      for (final e in draft.payers) {'memberId': e.memberId, 'cents': e.cents},
    ])),
    sharesJson: Value(jsonEncode([
      for (final e in draft.shares) {'memberId': e.memberId, 'cents': e.cents},
    ])),
    shareMode: Value(draft.shareMode.name),
    portionsJson: Value(draft.portions == null ? null : jsonEncode(draft.portions)),
    note: Value(draft.note ?? ''),
    tripId: Value(draft.tripId),
    tripItemId: Value(draft.tripItemId),
    createdAt: Value(draft.id == null ? now : now),
  );
  if (draft.id == null) {
    await repo.addExpense(comp);
  } else {
    await repo.updateExpense(draft.id!, comp);
  }
}

Future<void> deleteExpense(WidgetRef ref, String expenseId) =>
    ref.read(ledgerRepoProvider).deleteExpense(expenseId);

/// 单笔手动结 / 反结（账单详情开关）
Future<void> setExpenseSettled(WidgetRef ref, ExpenseRecord expense, bool settled) =>
    ref.read(ledgerRepoProvider).setExpenseSettled(expense.id, settled);

/// 新建一轮结算（替换旧进行中）
Future<void> startSettlement(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).createSettlement(groupId);

/// 逐笔确认 / 反悔
Future<void> toggleTransfer(WidgetRef ref, String settlementId, int index, bool done) =>
    ref.read(ledgerRepoProvider).markTransferDone(settlementId, index, done);

/// 全部确认后完成本轮
Future<void> finishSettlement(WidgetRef ref, String settlementId) =>
    ref.read(ledgerRepoProvider).completeSettlement(settlementId);

/// 撤销最近完成的一轮
Future<void> undoLastRound(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).undoLastSettlement(groupId);

/// 新建团（返回落库记录以便拿到 id）
Future<Group> createGroup(WidgetRef ref,
    {required String name, required String icon}) =>
    ref.read(ledgerRepoProvider).addGroup(name, icon);

/// 更新团名与图标
Future<void> updateGroupInfo(
        WidgetRef ref, String id, String name, String icon) =>
    ref.read(ledgerRepoProvider).updateGroup(id, name, icon);

Future<void> deleteGroup(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).deleteGroup(groupId);

/// 切换当前团并落盘
Future<void> activateGroup(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).setActiveGroup(groupId);

/// 开启 / 关闭预算并设置金额
Future<void> saveBudget(WidgetRef ref, String groupId, bool enabled, int? budgetCents) =>
    ref.read(ledgerRepoProvider).setBudget(groupId, enabled: enabled, budgetCents: budgetCents);

/// 新增成员（colorIndex 仓储侧轮换分配）
Future<void> addMember(WidgetRef ref, String groupId, String name) =>
    ref.read(ledgerRepoProvider).addMember(groupId, name);

Future<void> renameMember(WidgetRef ref, String memberId, String newName) =>
    ref.read(ledgerRepoProvider).renameMember(memberId, newName);

/// 删除成员；被引用时仓储抛 StateError，由屏幕捕获提示
Future<void> removeMember(WidgetRef ref, String memberId) =>
    ref.read(ledgerRepoProvider).deleteMember(memberId);

/// 自定义分类增删（被引用拒删抛 StateError）
Future<void> createCategory(WidgetRef ref, String name, String icon) =>
    ref.read(categoriesRepoProvider).addCustomCategory(name, icon);

Future<void> removeCategory(WidgetRef ref, String key) =>
    ref.read(categoriesRepoProvider).deleteCustomCategory(key);

/// 汇率记忆
Future<void> rememberRate(WidgetRef ref, String code, double rate) async {
  await ref.read(prefsRepoProvider).setCurrencyRate(code, rate);
  ref.invalidate(currencyRatesProvider);
}

/// 导入团 JSON（粘贴文本 / 文件），返回人类可读的重映射统计摘要
Future<String> importGroupFromText(WidgetRef ref, String jsonText) async {
  final report = await ref.read(ledgerRepoProvider).importGroupJson(jsonText);
  return summarizeImportReport(report);
}

/// 导出团 JSON 文本（分享 / 剪贴板）
Future<String> exportGroupToText(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).exportGroupJson(groupId);

/// CSV 导出文本
String buildCsvText({
  required List<ExpenseRecord> expenses,
  required Map<String, String> memberNames,
  Map<String, String> tripNames = const {},
  Map<String, String> itemTitles = const {},
  Map<String, String> categoryNames = const {},
}) =>
    buildExpensesCsv(
      expenses,
      memberNames: memberNames,
      tripNames: tripNames,
      itemTitles: itemTitles,
      categoryNames: categoryNames,
    );

/// 导入报告 → 摘要文案（字段缺失时优雅降级）
String summarizeImportReport(dynamic report) {
  try {
    return '导入成功：成员 ' + _n(report?.members).toString() +
        ' · 账单 ' + _n(report?.expenses).toString() +
        ' · 行程 ' + _n(report?.trips).toString() +
        ' · 安排 ' + _n(report?.tripItems).toString();
  } catch (_) {
    return '导入完成';
  }
}

int _n(dynamic v) => v is int ? v : 0;

/// 记账默认日期兜底
int todayOr(int epochDay) => epochDay <= 0 ? todayEpochDay() : epochDay;

/// 自定义分类的 18 个备选图标（T2 假设：categories_repo.kCategoryIconChoices）
List<String> get categoryIconChoices => kCategoryIconChoices;
