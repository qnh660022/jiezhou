/// 账本桥接层 · 公款池（S8 · N1）。
///
/// 由 `ledger_providers.dart` barrel 统一 export；三宿主共用同一数据面。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/db/database.dart' show Fund;
import '../../../domain/fund_calculator.dart';
import '../../../domain/models.dart';
import '../ledger_models.dart';
import 'bills.dart';
import 'groups.dart';

FundView fundViewOf(Fund f) => FundView(
      id: f.id,
      groupId: f.groupId,
      name: f.name,
      managerMemberId: f.managerMemberId,
      targetCents: f.targetCents,
      status: f.status,
      createdAtMs: f.createdAt,
    );

/// 当前团全部公款池（createdAt 降序）。
final fundsProvider = StreamProvider<List<FundView>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <FundView>[]);
  return ref.watch(ledgerRepoProvider).watchFunds(gid).map(
        (l) => l.map(fundViewOf).toList(),
      );
});

/// 当前团未关闭的池（一池一管理人；无则为 null）。
final openFundProvider = Provider<AsyncValue<FundView?>>((ref) {
  final all = ref.watch(fundsProvider);
  if (all.isLoading) return const AsyncLoading();
  for (final f in all.value ?? const <FundView>[]) {
    if (f.isOpen) return AsyncData(f);
  }
  return const AsyncData(null);
});

/// 指定池的账单（含已入账），供详情页列表。
final fundExpensesProvider =
    Provider.family<AsyncValue<List<ExpenseRecord>>, String>((ref, fundId) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  final list = (expenses.value ?? const <ExpenseRecord>[])
      .where((e) => e.fundId == fundId)
      .toList();
  return AsyncData(list);
});

/// 池余额（分）：只统计未入账账单（派生展示量，不入库）。
final fundBalanceProvider =
    Provider.family<AsyncValue<int>, String>((ref, fundId) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  return AsyncData(
      fundBalanceCents(fundId, expenses.value ?? const <ExpenseRecord>[]));
});

/// 各成员缴款额（未入账入金）。
final fundContributorsProvider =
    Provider.family<AsyncValue<Map<String, int>>, String>((ref, fundId) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  return AsyncData(fundContributionByMember(
      fundId, expenses.value ?? const <ExpenseRecord>[]));
});

/// 池派生汇总（余额 / 已入金 / 已支出 / 参与人数）。
class FundSummary {
  const FundSummary({
    required this.balanceCents,
    required this.contributedCents,
    required this.spentCents,
    required this.contributorCount,
  });

  final int balanceCents;
  final int contributedCents;
  final int spentCents;
  final int contributorCount;
}

final fundSummaryProvider =
    Provider.family<AsyncValue<FundSummary>, String>((ref, fundId) {
  final expenses = ref.watch(expensesProvider);
  if (expenses.isLoading) return const AsyncLoading();
  final list = expenses.value ?? const <ExpenseRecord>[];
  return AsyncData(FundSummary(
    balanceCents: fundBalanceCents(fundId, list),
    contributedCents: fundContributedTotal(fundId, list),
    spentCents: fundSpentTotal(fundId, list),
    contributorCount: fundContributorCount(fundId, list),
  ));
});

// ---------------------------------------------------------------------------
// 动作
// ---------------------------------------------------------------------------

/// 新建池（管理人为必填）。
Future<FundView> createFund(
  WidgetRef ref, {
  required String groupId,
  required String name,
  required String managerMemberId,
  int? targetCents,
}) async {
  final f = await ref.read(ledgerRepoProvider).addFund(
        gid: groupId,
        name: name,
        managerMemberId: managerMemberId,
        targetCents: targetCents,
      );
  return fundViewOf(f);
}

/// 改名 / 转移管理人 / 改计划金额。
Future<void> updateFundInfo(
  WidgetRef ref,
  String fundId, {
  String? name,
  String? managerMemberId,
  int? targetCents,
  bool updateTarget = false,
}) =>
    ref.read(ledgerRepoProvider).updateFund(
          fundId,
          name: name,
          managerMemberId: managerMemberId,
          targetCents: targetCents,
          updateTarget: updateTarget,
        );

/// 关闭池（只读化）。
Future<void> closeFund(WidgetRef ref, String fundId) =>
    ref.read(ledgerRepoProvider).closeFund(fundId);

/// 记入金（payers=缴款人 / shares=管理人）。
Future<String> addFundContribution(
  WidgetRef ref, {
  required String fundId,
  required Map<String, int> contributions,
  int? dateEpochDay,
  String? note,
}) =>
    ref.read(ledgerRepoProvider).addFundContribution(
          fundId: fundId,
          contributions: contributions,
          dateEpochDay: dateEpochDay,
          note: note,
        );

/// 记出金（payers=管理人 / shares 按分摊模式）。
Future<String> addFundExpense(
  WidgetRef ref, {
  required String fundId,
  required String title,
  required String categoryKey,
  required int amountCents,
  required List<String> shareMemberIds,
  ShareMode shareMode = ShareMode.equal,
  Map<String, int>? portions,
  int? dateEpochDay,
  String? note,
}) =>
    ref.read(ledgerRepoProvider).addFundExpense(
          fundId: fundId,
          title: title,
          categoryKey: categoryKey,
          amountCents: amountCents,
          shareMemberIds: shareMemberIds,
          shareMode: shareMode,
          portions: portions,
          dateEpochDay: dateEpochDay,
          note: note,
        );
