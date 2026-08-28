/// 结束团总结卡：本地纯计算的团总结（总支出/人均/成员榜首/分类大头/建议转账），
/// 底部提供「结束并归档」。归档为软标记——数据保留可改，可随时恢复。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';

/// 展示团总结抽屉；[onConfirmed] 在用户点「结束并归档」后触发（此时抽屉已关闭）。
Future<void> showGroupSummarySheet(
  BuildContext context,
  WidgetRef ref,
  LedgerGroupView group, {
  Future<void> Function()? onConfirmed,
}) async {
  final board = (ref.read(memberBoardProvider).value ?? const <MemberStatView>[])
      .where((b) => b.paidCents != 0 || b.shareCents != 0)
      .toList();
  final breakdown =
      ref.read(categoryBreakdownProvider).value ?? const <CategoryShareView>[];
  final expenses = ref.read(expensesProvider).value ?? const <ExpenseRecord>[];
  final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];

  var total = 0;
  var prepay = 0;
  var refund = 0;
  int? firstDay;
  int? lastDay;
  for (final e in expenses) {
    if (e.type == ExpenseType.prepay) {
      prepay += e.amountCents;
      continue;
    }
    total += e.amountCents; // 退款为负，自然冲减总支出
    if (e.type == ExpenseType.refund) {
      // 归正后另列展示「退回多少钱」
      refund += -e.amountCents;
    }
    if (firstDay == null || e.dateEpochDay < firstDay) firstDay = e.dateEpochDay;
    if (lastDay == null || e.dateEpochDay > lastDay) lastDay = e.dateEpochDay;
  }
  final payerCount = board.where((b) => b.paidCents > 0).length;
  final perHead = members.isEmpty ? 0 : total ~/ members.length;
  final topPayer = board.isEmpty
      ? null
      : board.reduce((a, b) => a.paidCents > b.paidCents ? a : b);
  final topCats = breakdown.take(3).toList();

  await showDraggableSheet<void>(
    context: context,
    initialChildSize: 0.62,
    minChildSize: 0.5,
    builder: (sheetContext, _) => Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(group.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('「${group.name}」行程总结',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppFontSizes.title)),
                  if (firstDay != null && lastDay != null)
                    Text('首笔 ${fmtDateShort(firstDay)} · 末笔 ${fmtDateShort(lastDay)}',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: Spacing.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryRow('总支出', _yuan(total) + ' 元', emphasize: true),
  if (prepay > 0) _SummaryRow('预付另计', _yuan(prepay) + ' 元'),
  if (refund > 0) _SummaryRow('退款另计', _yuan(refund) + ' 元'),
                  _SummaryRow('账单笔数', '${expenses.length} 笔'),
                  _SummaryRow('人均', _yuan(perHead) + ' 元（$payerCount 人付款）'),
                  if (topPayer != null && topPayer.paidCents > 0)
                    _SummaryRow('付出最多', '${topPayer.member.name}（${_yuan(topPayer.paidCents)} 元）'),
                  if (topCats.isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    Text('分类大头',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppFontSizes.body)),
                    const SizedBox(height: Spacing.xs),
                    for (final c in topCats)
                      _SummaryRow('${c.category.icon} ${c.category.name}',
                          '${_yuan(c.cents)} 元 · ${(c.fraction * 100).toStringAsFixed(0)}%'),
                  ],
                  const SizedBox(height: Spacing.sm),
                  Text('结束后：数据全部保留，随时可以继续修改或恢复成进行中的团。',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('再想想'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    if (onConfirmed != null) await onConfirmed();
                  },
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('结束并归档'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _yuan(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

String fmtDateShort(int epochDay) {
  final d = DateTime(1970, 1, 1).add(Duration(days: epochDay));
  return '${d.month}/${d.day}';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: emphasize ? AppFontSizes.body : AppFontSizes.caption,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: emphasize ? AppFontSizes.bodyLarge : AppFontSizes.caption,
                  fontWeight: FontWeight.w700,
                  color: emphasize ? scheme.primary : scheme.onSurface)),
        ],
      ),
    );
  }
}
