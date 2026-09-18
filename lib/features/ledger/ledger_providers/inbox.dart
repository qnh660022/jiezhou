/// 账本桥接层 · 记账收件箱（S10 · N3）。
///
/// 红线：pending 条目**零污染**——不参与统计 / 结算 / 预算 / 导出 / 备份 / 分享。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/uid.dart';
import '../../../data/providers.dart';
import '../../../data/db/database.dart' show InboxItem;
import '../ledger_models.dart';
import 'bills.dart';
import 'groups.dart';

InboxItemView inboxViewOf(InboxItem i) => InboxItemView(
      id: i.id,
      groupId: i.groupId,
      amountCents: i.amountCents,
      note: i.note,
      capturedAtMs: i.capturedAt,
      source: i.source,
      status: i.status,
      convertedExpenseId: i.convertedExpenseId,
    );

/// 当前团全部收件箱条目（capturedAt 降序）。
final inboxItemsProvider = StreamProvider<List<InboxItemView>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <InboxItemView>[]);
  return ref.watch(ledgerRepoProvider).watchInboxItems(gid).map(
        (l) => l.map(inboxViewOf).toList(),
      );
});

/// 待归类条目（pending）。
final pendingInboxProvider = Provider<AsyncValue<List<InboxItemView>>>((ref) {
  final all = ref.watch(inboxItemsProvider);
  if (all.isLoading) return const AsyncLoading();
  return AsyncData(
      (all.value ?? const <InboxItemView>[]).where((i) => i.isPending).toList());
});

/// 待归类条数（主页入口徽章）。
final pendingInboxCountProvider = Provider<AsyncValue<int>>((ref) {
  final pending = ref.watch(pendingInboxProvider);
  if (pending.isLoading) return const AsyncLoading();
  return AsyncData((pending.value ?? const <InboxItemView>[]).length);
});

/// 已归类条目（converted，折叠区展示）。
final convertedInboxProvider = Provider<AsyncValue<List<InboxItemView>>>((ref) {
  final all = ref.watch(inboxItemsProvider);
  if (all.isLoading) return const AsyncLoading();
  return AsyncData(
      (all.value ?? const <InboxItemView>[]).where((i) => i.isConverted).toList());
});

// ---------------------------------------------------------------------------
// 动作
// ---------------------------------------------------------------------------

/// 捕捉一条（只填金额 + 可选备注）。
Future<String> captureInboxItem(
  WidgetRef ref, {
  required String groupId,
  required int amountCents,
  String? note,
  String source = 'manual',
}) =>
    ref.read(ledgerRepoProvider).captureInboxItem(
          gid: groupId,
          amountCents: amountCents,
          note: note,
          source: source,
        );

/// 单条归类：把 pending 条目转正为正式账单（幂等，重试不重复生成）。
Future<String> convertInboxItem(
  WidgetRef ref, {
  required String itemId,
  required ExpenseDraft draft,
}) {
  final eid = draft.id ?? newId('expense');
  final comp = expenseCompanionOf(draft, id: eid);
  return ref
      .read(ledgerRepoProvider)
      .convertInboxItem(itemId: itemId, expense: comp);
}

/// 批量归类：同一分类与分摊模式，逐条执行（金额不变）。
Future<int> convertInboxItems(
  WidgetRef ref, {
  required List<InboxItemView> items,
  required ExpenseDraft Function(InboxItemView item) draftOf,
}) async {
  var done = 0;
  for (final item in items) {
    await convertInboxItem(ref, itemId: item.id, draft: draftOf(item));
    done++;
  }
  return done;
}

/// 移除条目：**仅已转正条目**可删（pending 必须先归类）。
Future<void> deleteInboxItem(WidgetRef ref, String itemId) =>
    ref.read(ledgerRepoProvider).deleteInboxItem(itemId);
