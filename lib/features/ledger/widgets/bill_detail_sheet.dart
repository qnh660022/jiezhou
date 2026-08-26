import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../domain/models.dart';
import 'package:drift/drift.dart' show Value;
import '../../../shared/widgets/money_text.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import 'category_icon_box.dart';

/// 账单详情底部抽屉内容：明细一览 + 单笔手动结 / 反结开关。
///
/// 由调用方配合 showDraggableSheet 使用（传入其 scrollController）。
class BillDetailSheet extends ConsumerWidget {
  const BillDetailSheet({
    super.key,
    required this.scrollController,
    required this.expense,
    required this.memberName,
    this.icon = '🏷️',
  });

  final ScrollController scrollController;
  final ExpenseRecord expense;
  final String Function(String memberId) memberName;

  /// 分类 emoji（由调用方从分类流解析后传入）
  final String icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settled = expense.settledRoundId != null;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, Spacing.xxxl),
      children: [
        Row(
          children: [
            CategoryIconBox(categoryKey: expense.categoryKey, icon: icon),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(expense.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            MoneyText(expense.amountCents,
                fontSize: AppFontSizes.headline, semanticColor: true),
          ],
        ),
        if (expense.tripId != null)
          _LinkedTripSection(
            expenseId: expense.id,
            tripId: expense.tripId!,
            tripItemId: expense.tripItemId,
          ),
        const SizedBox(height: Spacing.lg),
        DetailLine(label: '类型', value: expenseTypeLabel(expense.type)),
        DetailLine(label: '日期', value: fmtFullDateOfEpoch(expense.dateEpochDay)),
        DetailLine(
          label: '付款人',
          value: expense.payers.isEmpty
              ? '-'
              : expense.payers
                  .map((p) => memberName(p.memberId) + ' ¥' + formatPlainYuan(p.cents))
                  .join('、'),
        ),
        DetailLine(
          label: '分摊',
          value: expense.shares.map((s) => memberName(s.memberId)).toSet().join('、') +
              '（' +
              shareModeLabel(expense.shareMode) +
              '）',
        ),
        if (expense.note != null && expense.note!.isNotEmpty)
          DetailLine(label: '备注', value: expense.note!),
        const Divider(height: Spacing.xl),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeColor: scheme.primary,
          title: const Text('标记为已结清'),
          subtitle: Text(settled ? '这笔已经两清啦' : '私下转过了？手动打个勾',
              style: Theme.of(context).textTheme.bodySmall),
          value: settled,
          onChanged: (v) async {
            HapticFeedback.lightImpact();
            await setExpenseSettled(ref, expense, v);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/expenses/edit?id=' + expense.id);
                },
                child: const Text('编辑'),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.error, foregroundColor: scheme.onError),
                onPressed: () async {
                  Navigator.of(context).pop();
                  HapticFeedback.lightImpact();
                  await deleteExpense(ref, expense.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('已删除')));
                  }
                },
                child: const Text('删除'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 所属行程/安排回链区块：chips 跳转行程详情 + 解除关联（仅置空外键，不删账单）
class _LinkedTripSection extends ConsumerStatefulWidget {
  const _LinkedTripSection({
    required this.expenseId,
    required this.tripId,
    this.tripItemId,
  });

  final String expenseId;
  final String tripId;
  final String? tripItemId;

  @override
  ConsumerState<_LinkedTripSection> createState() => _LinkedTripSectionState();
}

class _LinkedTripSectionState extends ConsumerState<_LinkedTripSection> {
  late final Future<(Trip?, TripItem?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(Trip?, TripItem?)> _load() async {
    final repo = ref.read(tripsRepoProvider);
    final trip = await repo.getById(widget.tripId);
    final item =
        widget.tripItemId == null ? null : await repo.getItem(widget.tripItemId!);
    return (trip, item);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<(Trip?, TripItem?)>(
      future: _future,
      builder: (context, snap) {
        final trip = snap.data?.$1;
        final item = snap.data?.$2;
        Widget chip({required String label, VoidCallback? onTap}) => GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.xs),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.capsule,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            );
        return Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: AppRadius.input,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('所属行程',
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                chip(
                  label: trip == null ? '🧳 行程' : '${trip.emoji} ${trip.name}',
                  onTap: trip == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          context.push('/trips/detail', extra: widget.tripId);
                        },
                ),
                if (item != null)
                  chip(
                    label: '📍 ${item.name}',
                    onTap: trip == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            context.push('/trips/detail', extra: widget.tripId);
                          },
                  ),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await ref.read(ledgerRepoProvider).updateExpense(
                        widget.expenseId,
                        ExpensesCompanion(
                            tripId: const Value(null),
                            tripItemId: const Value(null)));
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已解除行程关联')));
                    }
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_off_rounded,
                        size: 13, color: scheme.error),
                    const SizedBox(width: 3),
                    Text('解除关联',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption - 1,
                            fontWeight: FontWeight.w600,
                            color: scheme.error)),
                  ]),
                ),
              ],
            ),
          ]),
        );
      },
    );
  }
}

/// int 分 → 不带千分位的元字符串（抽屉内轻量展示用）
String formatPlainYuan(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  return (cents < 0 ? '-' : '') + yuan.toString() + '.' + fen;
}

/// 明细行
class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
