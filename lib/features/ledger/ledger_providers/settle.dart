/// 账本桥接层 · 结算域（净额 / 结算轮 / 转账确认 / 撤销）。
///
/// G4 拆分（V2.7.1 S2）：由 `ledger_providers.dart` barrel 统一 export。
/// S9：结算策略可选（最少笔数 / 最少人参与）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/models.dart';
import '../../../domain/settle_engine.dart';
import '../../../domain/settle_strategy.dart';
import '../ledger_models.dart';
import 'groups.dart';

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
      strategy: s.strategy,
    );

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

/// 净额表（正=应收，负=应付）
Map<String, int> netBalanceMap(List<LedgerMemberView> members, List<ExpenseRecord> expenses) =>
    computeNetBalances([for(final m in members) MemberRecord(id:m.id,name:m.name,colorIndex:m.colorIndex)], expenses);

/// 最少转账计划（minTransfers，行为与历史逐位一致）
List<TransferPlan> transferPlanOf(Map<String, int> balances) => minTransferPlan(balances);

/// 按策略生成结算方案（S9）：默认最少笔数；两策略都必须通过 validatePlan。
List<TransferPlan> transferPlanByStrategy(
        Map<String, int> balances, SettleStrategy strategy) =>
    buildPlan(balances: balances, strategy: strategy);

/// 新建一轮结算（替换旧进行中），记录所用策略（S9）。
/// 返回是否真的创建了新轮：false 表示余额已平衡无需结算（也帮助 UI 给提示）。
Future<bool> startSettlement(WidgetRef ref, String groupId,
    {SettleStrategy strategy = SettleStrategy.minTransfers}) async {
  final created = await ref
      .read(ledgerRepoProvider)
      .createSettlement(groupId, strategy: strategy);
  return created != null;
}

/// 逐笔确认 / 反悔
Future<void> toggleTransfer(WidgetRef ref, String settlementId, int index, bool done) =>
    ref.read(ledgerRepoProvider).markTransferDone(settlementId, index, done);

/// 全部确认后完成本轮
Future<void> finishSettlement(WidgetRef ref, String settlementId) =>
    ref.read(ledgerRepoProvider).completeSettlement(settlementId);

/// 撤销最近完成的一轮
Future<void> undoLastRound(WidgetRef ref, String groupId) =>
    ref.read(ledgerRepoProvider).undoLastSettlement(groupId);
