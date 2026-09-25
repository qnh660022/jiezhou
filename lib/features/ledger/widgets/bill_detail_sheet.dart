import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../domain/models.dart';
import 'package:drift/drift.dart' show Value;
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import 'category_icon_box.dart';

/// 账单详情底部抽屉内容：明细一览 + 单笔手动结 / 反结开关。
///
/// 由调用方配合 showDraggableSheet 使用（传入其 scrollController）。
/// V2.8.1 S9 重设计：头部状态胶囊 / 谁付了·谁分摊迷你卡 / 玻璃行程卡
///（解除关联收进 ⋯ 菜单）/ 精要插槽 / 编辑（62% 宽）+ 删除图标钮。
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
            // V2.8.2 S6：与账单行金额成对的 Hero（金额连续过渡终点）
            Hero(
              tag: 'bill-amount-${expense.id}',
              child: Material(
                type: MaterialType.transparency,
                child: MoneyText(
                    expense.type == ExpenseType.refund
                        ? -expense.amountCents
                        : expense.amountCents,
                    fontSize: AppFontSizes.headline,
                    semanticColor: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        // V2.8.1 S9：结清前置 —— 头部状态胶囊（amber ↔ green，点按 toggle）
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () async {
              HapticFeedback.lightImpact();
              await setExpenseSettled(ref, expense, !settled);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: settled
                    ? SemanticColors.income.withValues(alpha: 0.14)
                    : scheme.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: settled
                        ? SemanticColors.income.withValues(alpha: 0.5)
                        : SemanticColors.warning.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    settled ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    size: 15,
                    color: settled ? SemanticColors.income : SemanticColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    // V2.9.0:用语统一 ——「两清」→「已结清」。
                    settled ? '已结清 ✓' : '待结清 · 点击标记已结清',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        fontWeight: FontWeight.w700,
                        color: settled ? SemanticColors.income : scheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
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
        DetailLine(label: '支付方式', value: payMethodLabel(expense.payMethod)),
        if (expense.note != null && expense.note!.isNotEmpty)
          DetailLine(label: '备注', value: expense.note!),
        const SizedBox(height: Spacing.sm),
        // V2.8.1 S9：「谁付了 · 谁分摊」迷你卡（头像行 + 模式标签 chip + tabular 金额）
        _PayShareMiniCard(
          expense: expense,
          memberName: memberName,
        ),
        const Divider(height: Spacing.xl),
        // V2.8.1 S9：精要插槽 —— guide_essence_section 完工后自动渲染（布局槽位，空态隐藏）
        _EssenceSlot(expenseId: expense.id),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            // 编辑：Filled 62% 宽
            Expanded(
              flex: 62,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/expenses/edit?id=' + expense.id);
                },
                child: const Text('编辑'),
              ),
            ),
            const Spacer(),
            // 删除：图标钮（L2 危险确认含数量）
            IconButton.filledTonal(
              tooltip: '删除账单',
              style: IconButton.styleFrom(
                  backgroundColor: scheme.error.withValues(alpha: 0.12),
                  foregroundColor: scheme.error),
              onPressed: () async {
                final ok = await showDangerConfirm(
                  context: context,
                  title: '删除账单',
                  body: '删除「${expense.title}」？共 1 笔，不可恢复，云端共享成员都会看到删除记录。',
                  confirmLabel: '删除',
                );
                if (!ok) return;
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                await deleteExpense(ref, expense.id);
                if (context.mounted) {
                  showAppSnackBar(context, '已删除', tone: SnackTone.destructive);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

/// V2.8.1 S9：「谁付了 · 谁分摊」迷你卡。
class _PayShareMiniCard extends StatelessWidget {
  const _PayShareMiniCard({required this.expense, required this.memberName});

  final ExpenseRecord expense;
  final String Function(String memberId) memberName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = expense.type == ExpenseType.refund;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.input,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isRefund ? '谁收了 · 谁分摊' : '谁付了 · 谁分摊',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(shareModeLabel(expense.shareMode),
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 1,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          for (final p in expense.payers)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: scheme.primary.withValues(alpha: 0.18),
                    child: Text(
                      memberName(p.memberId).characters.first,
                      style: TextStyle(fontSize: 9, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        memberName(p.memberId) +
                            (isRefund ? ' 收款' : ' 付款'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  MoneyText(p.cents.abs(),
                      fontSize: AppFontSizes.caption, color: scheme.onSurface),
                ],
              ),
            ),
          if (expense.shares.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '摊 ' +
                  expense.shares.map((s) => memberName(s.memberId)).toSet().join('、'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// V2.8.1 S9：精要插槽 —— 底部虚线占位段。
/// V2.7.2 S10 `guide_essence_section` 完工后由该组件自身渲染内容；
/// 本版仅保留布局槽位，无精要数据时整段隐藏。
class _EssenceSlot extends ConsumerWidget {
  const _EssenceSlot({required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // V2.7.2 S10 未交付精要查询前的空态：整段隐藏（空态隐藏口径）。
    // 交付后此处接入 guide_essence_section 的精要流，有数据时渲染虚线卡。
    return const SizedBox.shrink();
  }
}

/// 所属行程/安排回链区块：chips 跳转行程详情；解除关联收进 ⋯ 菜单（L2 危险态）
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
        // V2.8.3.1：玻璃叠玻璃修正 —— 本卡位于玻璃 Sheet（SheetContainer）内，
        // 嵌套 GlassSurface 会导致双份 BackdropFilter + 发灰观感（iOS 26
        // Liquid Glass 层级规则：玻璃不能采样玻璃）。改实色卡 + 细描边。
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.card,
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Text('所属行程',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (v) async {
                      if (v != 'unlink') return;
                      final ok = await showDangerConfirm(
                        context: context,
                        title: '解除行程关联？',
                        body: '解除后这笔账单将不再挂在行程下。共 1 条关联会被清空，账单本身保留。',
                        confirmLabel: '解除',
                      );
                      if (!ok || !context.mounted) return;
                      HapticFeedback.lightImpact();
                      await ref.read(ledgerRepoProvider).updateExpense(
                          widget.expenseId,
                          ExpensesCompanion(
                              tripId: const Value(null),
                              tripItemId: const Value(null)));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        showAppSnackBar(context, '已解除行程关联');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'unlink',
                        child: Row(children: [
                          Icon(Icons.link_off_rounded,
                              size: 16, color: SemanticColors.expense),
                          SizedBox(width: Spacing.sm),
                          Text('解除关联'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
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
                ],
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// int 分 → 元字符串（V2.9.0:统一走 MoneyFormat 千分位口径）
String formatPlainYuan(int cents) => MoneyFormat.fenToYuan(cents);

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
