/// 记账收件箱（S10）的底部弹层：快速记 + 归类（单条/批量）。
///
/// 与页面拆开，避免单文件过大；两者共同遵守「pending 零污染」红线。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../core/uid.dart';
import '../../../domain/models.dart';
import '../../../domain/share_splitter.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/member_avatar.dart';

/// 快速记一笔：**只有**金额（大号 autofocus）与可选备注（禁止加分类/分摊字段）。
Future<void> showCaptureInboxSheet(
    BuildContext context, WidgetRef ref, String groupId) async {
  final controller = TextEditingController();
  final noteController = TextEditingController();
  await showDraggableSheet<void>(
    context: context,
    initialChildSize: 0.46,
    minChildSize: 0.36,
    builder: (sheetContext, scrollController) => ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl,
          Spacing.xxl + MediaQuery.viewInsetsOf(sheetContext).bottom),
      children: [
        Text('快速记', style: Theme.of(sheetContext).textTheme.titleLarge),
        const SizedBox(height: Spacing.sm),
        Text('先记下金额，回到收件箱再慢慢归类。',
            style: Theme.of(sheetContext).textTheme.bodySmall),
        const SizedBox(height: Spacing.lg),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(prefixText: '¥ ', hintText: '0.00'),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: noteController,
          maxLength: 40,
          decoration: const InputDecoration(hintText: '备注（可选），如「打车」'),
        ),
        const SizedBox(height: Spacing.md),
        FilledButton(
          onPressed: () async {
            final cents = parseMoney(controller.text);
            if (cents == null || cents <= 0) {
              ScaffoldMessenger.of(sheetContext)
                  .showSnackBar(const SnackBar(content: Text('请填写有效金额')));
              return;
            }
            final note = noteController.text.trim();
            Navigator.of(sheetContext).pop();
            HapticFeedback.lightImpact();
            try {
              await captureInboxItem(
                ref,
                groupId: groupId,
                amountCents: cents,
                note: note.isEmpty ? null : note,
                source: 'quick_action',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已收进收件箱，记得归类')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('记录失败：${e.toString()}')));
              }
            }
          },
          child: const Text('收进收件箱'),
        ),
      ],
    ),
  );
  controller.dispose();
  noteController.dispose();
}

/// 归类表单：标题 / 分类 / 付款人 / 分摊模式 / 日期；返回 null 表示取消。
/// 个人账本自动隐藏付款人与分摊控件（付款人与分摊人固定为 owner）。
Future<ExpenseDraft?> showClassifySheet(
    BuildContext context, WidgetRef ref, InboxItemView item) async {
  final group = ref.read(activeGroupProvider).value;
  final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
  final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];
  if (group == null || members.isEmpty) return null;

  final titleController = TextEditingController(text: item.note ?? '');
  final percentCtrls = <String, TextEditingController>{};
  var categoryKey = categories.isNotEmpty ? categories.first.key : 'other';
  var payerId = members.first.id;
  var mode = ShareMode.equal;
  var dateEpochDay = _dayOf(item.capturedAtMs);

  final result = await showDraggableSheet<ExpenseDraft>(
    context: context,
    initialChildSize: 0.86,
    minChildSize: 0.5,
    builder: (sheetContext, scrollController) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final scheme = Theme.of(ctx).colorScheme;
        final participants = members.map((m) => m.id).toList();
        List<ShareEntry> shares = const [];
        Map<String, int>? portions;
        if (mode == ShareMode.percent) {
          final raw = <String, int>{};
          percentCtrls.forEach((id, c) {
            final v = double.tryParse(c.text.trim());
            if (v != null && v > 0) raw[id] = (v * 100).round();
          });
          final bp = normalizePercentToBp(raw);
          if (bp.isNotEmpty) {
            portions = bp;
            shares = splitShares(
              totalCents: item.amountCents,
              memberIds: participants,
              mode: ShareMode.percent,
              portions: bp,
            );
          }
        }
        if (shares.isEmpty) {
          shares =
              splitShares(totalCents: item.amountCents, memberIds: participants);
        }
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl,
              Spacing.xxl + MediaQuery.viewInsetsOf(sheetContext).bottom),
          children: [
            Text('归类这一笔', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Row(children: [
              MoneyText(item.amountCents, fontSize: AppFontSizes.title),
              const SizedBox(width: Spacing.sm),
              Text('（金额不可改）',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: titleController,
              maxLength: 30,
              decoration: const InputDecoration(hintText: '这一笔是什么'),
            ),
            const SizedBox(height: Spacing.sm),
            Text('分类', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final c in categories)
                  GestureDetector(
                    onTap: () => setSheetState(() => categoryKey = c.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.key == categoryKey
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: AppRadius.input,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(c.icon),
                        const SizedBox(width: 4),
                        Text(c.name, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
              ],
            ),
            if (!group.isPersonal) ...[
              const SizedBox(height: Spacing.lg),
              Text('付款人', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.sm,
                children: [
                  for (final m in members)
                    ChoiceChip(
                      label: Text(m.name),
                      selected: payerId == m.id,
                      onSelected: (_) => setSheetState(() => payerId = m.id),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              Text('分摊模式', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: Spacing.xs),
              SegmentedButton<ShareMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ShareMode.equal, label: Text('平均')),
                  ButtonSegment(value: ShareMode.percent, label: Text('按百分比')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setSheetState(() => mode = s.first),
              ),
              if (mode == ShareMode.percent) ...[
                const SizedBox(height: Spacing.sm),
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Row(children: [
                      MemberAvatar(member: m, size: 24),
                      const SizedBox(width: Spacing.sm),
                      Expanded(child: Text(m.name)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: percentCtrls.putIfAbsent(
                              m.id, () => TextEditingController()),
                          textAlign: TextAlign.right,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d{0,3}(\.\d{0,2})?')),
                          ],
                          decoration:
                              const InputDecoration(suffixText: '%', hintText: '0'),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    ]),
                  ),
              ],
            ],
            const SizedBox(height: Spacing.lg),
            Text('日期', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(fmtIsoDate(epochDayToDate(dateEpochDay))),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: epochDayToDate(dateEpochDay),
                  firstDate: DateTime(2015, 1, 1),
                  lastDate: DateTime(2045, 12, 31),
                );
                if (picked != null) {
                  setSheetState(() => dateEpochDay = dateToEpochDay(picked));
                }
              },
            ),
            const SizedBox(height: Spacing.xl),
            PrimaryButton(
              label: '归类进账本',
              expanded: true,
              onPressed: () {
                final title = titleController.text.trim();
                final draft = ExpenseDraft(
                  id: newId('expense'),
                  groupId: group.id,
                  dateEpochDay: dateEpochDay,
                  title: title.isEmpty ? '收件箱归类' : title,
                  categoryKey: categoryKey,
                  type: ExpenseType.normal,
                  amountCents: item.amountCents,
                  currency: 'CNY',
                  rate: 1,
                  payers: group.isPersonal
                      ? [ShareEntry(memberId: participants.first, cents: item.amountCents)]
                      : [ShareEntry(memberId: payerId, cents: item.amountCents)],
                  shares: shares,
                  shareMode: group.isPersonal ? ShareMode.equal : mode,
                  portions: group.isPersonal ? null : portions,
                );
                Navigator.of(sheetContext).pop(draft);
              },
            ),
          ],
        );
      },
    ),
  );
  titleController.dispose();
  for (final c in percentCtrls.values) {
    c.dispose();
  }
  return result;
}

/// 批量归类结果（统一分类）。
class BatchClassifyResult {
  const BatchClassifyResult({required this.categoryKey});
  final String categoryKey;
}

Future<BatchClassifyResult?> showBatchClassifySheet(
    BuildContext context, WidgetRef ref, List<InboxItemView> items) async {
  final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];
  var categoryKey = categories.isNotEmpty ? categories.first.key : 'other';
  return showDraggableSheet<BatchClassifyResult>(
    context: context,
    initialChildSize: 0.5,
    minChildSize: 0.4,
    builder: (sheetContext, scrollController) => StatefulBuilder(
      builder: (ctx, setSheetState) => ListView(
        controller: scrollController,
        padding:
            const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
        children: [
          Text('批量归类 ${items.length} 笔', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: Spacing.sm),
          Text('统一指定分类，金额保持不变；分摊按平均处理。',
              style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final c in categories)
                ChoiceChip(
                  label: Text('${c.icon} ${c.name}'),
                  selected: categoryKey == c.key,
                  onSelected: (_) => setSheetState(() => categoryKey = c.key),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          PrimaryButton(
            label: '全部归类',
            expanded: true,
            onPressed: () => Navigator.of(sheetContext)
                .pop(BatchClassifyResult(categoryKey: categoryKey)),
          ),
        ],
      ),
    ),
  );
}

/// 由条目构造归类草稿（批量路径复用；金额不变、按指定分摊模式）。
ExpenseDraft buildClassifyDraft({
  required WidgetRef ref,
  required InboxItemView item,
  required String groupId,
  required String categoryKey,
  required ShareMode shareMode,
}) {
  final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
  final ids = members.map((m) => m.id).toList();
  final shares = ids.isEmpty
      ? const <ShareEntry>[]
      : splitShares(totalCents: item.amountCents, memberIds: ids, mode: shareMode);
  return ExpenseDraft(
    id: newId('expense'),
    groupId: groupId,
    dateEpochDay: _dayOf(item.capturedAtMs),
    title: (item.note ?? '').trim().isEmpty ? '收件箱归类' : item.note!.trim(),
    categoryKey: categoryKey,
    type: ExpenseType.normal,
    amountCents: item.amountCents,
    currency: 'CNY',
    rate: 1,
    payers: ids.isEmpty
        ? const <ShareEntry>[]
        : [ShareEntry(memberId: ids.first, cents: item.amountCents)],
    shares: shares,
    shareMode: shareMode,
  );
}

int _dayOf(int ms) => dateToEpochDay(DateTime.fromMillisecondsSinceEpoch(ms));
