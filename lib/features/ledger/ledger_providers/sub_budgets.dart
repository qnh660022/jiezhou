/// 账本桥接层 · 分类子预算（V2.8.1 S8）。
///
/// 由 `ledger_providers.dart` barrel 统一 export；三宿主共用同一数据面。
/// 组织方式与 `funds.dart` 同款：跟随激活团的数据流 + 薄动作封装。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/db/database.dart' show SubBudget;
import '../../../domain/models.dart';
import 'groups.dart';

SubBudgetRecord subBudgetRecordOf(SubBudget b) => SubBudgetRecord(
      id: b.id,
      groupId: b.groupId,
      categoryKey: b.categoryKey,
      amountCents: b.amount,
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
    );

/// 当前团全部分类子预算（updatedAt 升序；无激活团时为空流）。
final subBudgetsProvider = StreamProvider<List<SubBudgetRecord>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <SubBudgetRecord>[]);
  return ref.watch(ledgerRepoProvider).watchSubBudgets(gid).map(
        (l) => l.map(subBudgetRecordOf).toList(),
      );
});

// ---------------------------------------------------------------------------
// 动作
// ---------------------------------------------------------------------------

/// 新增一条子预算（上限/重复校验放 UI 层，repo 不拦）。
Future<SubBudgetRecord> addSubBudget(
  WidgetRef ref, {
  required String groupId,
  required String categoryKey,
  required int amountCents,
}) async {
  final b = await ref
      .read(ledgerRepoProvider)
      .addSubBudget(groupId, categoryKey, amountCents);
  return subBudgetRecordOf(b);
}

/// 改金额（不动 createdAt）。
Future<void> updateSubBudgetAmount(WidgetRef ref, String id, int amountCents) =>
    ref.read(ledgerRepoProvider).updateSubBudget(id, amountCents);

/// 删除子预算（发 delete 墓碑）。
Future<void> removeSubBudget(WidgetRef ref, String id) =>
    ref.read(ledgerRepoProvider).deleteSubBudget(id);
