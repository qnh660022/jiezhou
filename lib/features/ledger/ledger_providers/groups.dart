/// 账本桥接层 · 团 / 成员 / 分类 域。
///
/// G4 拆分（V2.7.1 S2）：本文件是原 `ledger_providers.dart` 的子集，
/// 由 `ledger_providers.dart` barrel 统一 export，所有屏幕零改动。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/repo/categories_repo.dart';
import '../../../data/seed/currencies.dart';
import '../../../data/db/database.dart'; // Group / Member / Category / Trip / TripItem 行类
import '../ledger_models.dart';

// ---------------------------------------------------------------------------
// 视图转换（原始记录 → UI 视图）
// ---------------------------------------------------------------------------

LedgerGroupView groupViewOf(Group g) => LedgerGroupView(
      id: g.id,
      name: g.name,
      icon: g.icon,
      budgetEnabled: g.budgetEnabled,
      archived: g.archived,
      budgetCents: g.budgetCents,
      kind: g.kind,
    );

/// colorIndex 兜底：与 AvatarPalette.colorForName 同源的姓名稳定哈希
int fallbackColorIndex(String name) {
  var sum = 0;
  for (final unit in name.codeUnits) {
    sum += unit;
  }
  return sum % 8;
}

LedgerMemberView memberViewOf(Member m) => LedgerMemberView(
    id: m.id, name: m.name, colorIndex: fallbackColorIndex(m.name), archived: m.archived);

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

CurrencyView currencyViewOf(CurrencyInfo c) =>
    CurrencyView(code: c.code, symbol: c.symbol, name: c.name, defaultRate: c.rate);

// ---------------------------------------------------------------------------
// 基础流
// ---------------------------------------------------------------------------

/// 当前激活团 id（SharedPreferences 持久化）
final activeGroupIdProvider =
    StreamProvider<String?>((ref) => ref.watch(ledgerRepoProvider).watchActiveGroupId());

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

/// 当前团成员（**默认过滤 archived**，S2 G1）。
///
/// 全仓成员选择点（成员页、成员榜、付款人/分摊人选择器、结算页）统一消费本
/// Provider；软删成员不进这里。历史账单仍持有其 memberId，因此结算净额照常
/// 计入（computeNetBalances 会从账单明细里补出这些账户）。
final membersProvider = StreamProvider<List<LedgerMemberView>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <LedgerMemberView>[]);
  return ref
      .watch(ledgerRepoProvider)
      .watchMembers(gid)
      .map((l) => l.map(memberViewOf).where((m) => !m.archived).toList());
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

/// 全部行程（不区分是否关联旅行团）——AI 行程工具用，便于处理独立行程。
final allTripsProvider = StreamProvider<List<TripCardView>>((ref) {
  return ref.watch(tripsRepoProvider).watchAll().map(
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
// 动作封装：团 / 成员 / 分类
// ---------------------------------------------------------------------------

/// 新建团（返回落库记录以便拿到 id）
Future<Group> createGroup(WidgetRef ref,
        {required String name, required String icon, String kind = 'travel'}) =>
    ref.read(ledgerRepoProvider).addGroup(name, icon, kind: kind);

/// 更新团名与图标
Future<void> updateGroupInfo(
        WidgetRef ref, String id, String name, String icon) =>
    ref.read(ledgerRepoProvider).updateGroup(id, name, icon);

Future<void> deleteGroup(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).deleteGroup(groupId);

/// 结束团 / 恢复团（软归档，数据保留）
Future<void> archiveGroup(WidgetRef ref, String groupId, bool archived) =>
    ref.read(ledgerRepoProvider).archiveGroup(groupId, archived);

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

/// 移除成员（保留历史，S2 G1）：软删除，历史账单净额不变。
Future<void> archiveMember(WidgetRef ref, String memberId) =>
    ref.read(ledgerRepoProvider).archiveMember(memberId);

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

/// 自定义分类的 18 个备选图标（categories_repo.kCategoryIconChoices）
List<String> get categoryIconChoices => kCategoryIconChoices;
