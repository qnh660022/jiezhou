/// V2.7.1 S12.2：冲突回执的 UI（共享组件，三宿主可用）。
///
/// 语义边界（规格 §S12.4）：
/// * 只提示、不回选：**不存也不展示被覆盖的版本体**；
/// * 记录里没有「谁改的」——合并点（`mergeRow`）只拿得到时间戳与云端行，
///   拿不到操作者身份，规格 §S12.2 的记录内容清单也未要求 actor 字段。
///   因此文案用「其他端」而非「<成员名>」，属于已知的展示降级（不影响判定）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/confirm_sheet.dart';
import '../../../theme/tokens.dart';
import '../observability_providers.dart';

/// 账单行 / 公费池记录 / 收件箱条目行上的「被覆盖」小标记。
///
/// 无未确认冲突时不占位（返回 `SizedBox.shrink()`），因此可以无条件挂在行里。
class ConflictDot extends ConsumerWidget {
  const ConflictDot({super.key, required this.entityId, this.size = 15});

  /// 业务实体 id（expenses.id / funds.id / inbox_items.id）。
  final String entityId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(conflictEntityIdsProvider).value;
    if (ids == null || !ids.contains(entityId)) return const SizedBox.shrink();
    return Semantics(
      label: '这笔记录曾被其它端的版本覆盖',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showConflictSheet(context, ref, entityId),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            Icons.sync_problem_rounded,
            size: size,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}

/// 冲突提示面板：说明「当前显示的是对方的版本」，确认后置 acknowledged。
Future<void> showConflictSheet(
  BuildContext context,
  WidgetRef ref,
  String entityId,
) async {
  final conflicts = await ref.read(entityConflictsProvider(entityId).future);
  if (!context.mounted) return;
  final count = conflicts.length;
  await showConfirmSheet(
    context: context,
    title: '这笔记录被覆盖过',
    body: count > 1
        ? '这笔记录在你之后被其它端修改过 $count 次，当前显示的是对方的版本。\n'
            '你的本地改动没有被删除，只是没有合入。'
        : '这笔记录在你之后被其它端修改过，当前显示的是对方的版本。\n'
            '你的本地改动没有被删除，只是没有合入。',
    cancelLabel: '',
    confirmLabel: '知道了',
    icon: Icons.sync_problem_rounded,
  );
  await acknowledgeEntityConflicts(ref, entityId);
}

/// 账本主页同步状态区的「N 处被覆盖」计数胶囊（本地计数，点开看明细）。
class ConflictCountChip extends ConsumerWidget {
  const ConflictCountChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unacknowledgedConflictCountProvider).value ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showSummary(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: AppRadius.input,
          ),
          child: Row(
            children: [
              Icon(Icons.sync_problem_rounded,
                  size: 16, color: scheme.onErrorContainer),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  '有 $count 处记录被其它端覆盖过',
                  style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
              Text('看看',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: FontWeight.w800,
                      color: scheme.onErrorContainer)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSummary(BuildContext context, WidgetRef ref) async {
    final ids =
        ref.read(conflictEntityIdsProvider).value ?? const <String>{};
    if (!context.mounted) return;
    await showConfirmSheet(
      context: context,
      title: '被覆盖的记录',
      body: '共 ${ids.length} 笔记录的本地改动没有合入云端（对方版本胜出）。\n\n'
          '点开对应账单上的红色标记可以逐条确认；确认后本提示会消失。',
      cancelLabel: '',
      confirmLabel: '知道了',
    );
  }
}
