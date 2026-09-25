/// 公款池（S8）的专用底部弹层：记入金 / 记出金。
///
/// **不**走通用 ExpenseEditScreen，避免表单膨胀；并保证 UI 不暴露
/// 「入金 payers」「入金 shares」这两个红字段（repo 侧二次强制校验）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../domain/models.dart';
import '../../../domain/share_splitter.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/member_avatar.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 记入金：选缴款人与各自金额（默认按计划金额全员均分）。
/// 返回 true 表示已写入。
Future<bool> showFundContributionSheet(
  BuildContext context,
  WidgetRef ref, {
  required FundView fund,
}) async {
  final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
  if (members.isEmpty) return false;
  final ctrls = <String, TextEditingController>{};
  for (final m in members) {
    ctrls[m.id] = TextEditingController();
  }
  // 计划金额存在时按「参与人数」默认均分，减少手工输入。
  final target = fund.targetCents;
  if (target != null && target > 0) {
    final each = target ~/ members.length;
    var remainder = target - each * members.length;
    for (final m in members) {
      final cents = each + (remainder-- > 0 ? 1 : 0);
      ctrls[m.id]!.text = _yuanText(cents);
    }
  }

  final ok = await showDraggableSheet<bool>(
    context: context,
    initialChildSize: 0.78,
    minChildSize: 0.5,
    builder: (sheetContext, scrollController) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        var total = 0;
        for (final m in members) {
          total += parseMoney(ctrls[m.id]!.text) ?? 0;
        }
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl,
              Spacing.xxl + MediaQuery.viewInsetsOf(sheetContext).bottom),
          children: [
            Text('记入金', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text('这笔钱会成为公费，由管理人统一保管；统计口径不算作消费。',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: Spacing.lg),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(children: [
                  MemberAvatar(member: m, size: 28),
                  const SizedBox(width: Spacing.sm),
                  Expanded(child: Text(m.name)),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: ctrls[m.id],
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(prefixText: '¥ ', hintText: '0'),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: Spacing.sm),
            Row(children: [
              Text('合计', style: Theme.of(ctx).textTheme.bodySmall),
              const Spacer(),
              MoneyText(total, fontSize: AppFontSizes.bodyLarge),
            ]),
            const SizedBox(height: Spacing.lg),
            PrimaryButton(
              label: '记入金',
              expanded: true,
              onPressed: total <= 0
                  ? null
                  : () async {
                      final contributions = <String, int>{};
                      for (final m in members) {
                        final c = parseMoney(ctrls[m.id]!.text) ?? 0;
                        if (c > 0) contributions[m.id] = c;
                      }
                      Navigator.of(sheetContext).pop(true);
                      HapticFeedback.lightImpact();
                      try {
                        await addFundContribution(ref,
                            fundId: fund.id, contributions: contributions);
                        if (context.mounted) {
                          showAppSnackBar(context, '已记入金 ✅');
                        }
                      } catch (e, s) {
                        // V2.9.0:原始异常只进调试日志,不进 UI 文案。
                        debugPrint('addFundContribution failed: $e\n$s');
                        if (context.mounted) {
                          showAppSnackBar(context, '记入金失败，请稍后重试', tone: SnackTone.destructive);
                        }
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
  for (final c in ctrls.values) {
    c.dispose();
  }
  return ok ?? false;
}

/// 记出金：金额 / 分类 / 参与人 / 分摊模式（平均 · 按份数 · 按百分比；不含 custom）。
Future<bool> showFundExpenseSheet(
  BuildContext context,
  WidgetRef ref, {
  required FundView fund,
}) async {
  final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
  final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];
  if (members.isEmpty) return false;

  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final portionCtrls = <String, TextEditingController>{};
  final percentCtrls = <String, TextEditingController>{};
  var categoryKey = categories.isNotEmpty ? categories.first.key : 'other';
  var mode = ShareMode.equal;

  final ok = await showDraggableSheet<bool>(
    context: context,
    initialChildSize: 0.88,
    minChildSize: 0.5,
    builder: (sheetContext, scrollController) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final scheme = Theme.of(ctx).colorScheme;
        final total = parseMoney(amountController.text) ?? 0;
        final ids = members.map((m) => m.id).toList();
        List<ShareEntry> shares = const [];
        Map<String, int>? portions;
        if (total > 0) {
          if (mode == ShareMode.percent) {
            final raw = <String, int>{};
            for (final m in members) {
              final v = double.tryParse(percentCtrls[m.id]?.text.trim() ?? '');
              if (v != null && v > 0) raw[m.id] = (v * 100).round();
            }
            final bp = normalizePercentToBp(raw);
            portions = bp.isEmpty ? null : bp;
            shares = splitShares(
              totalCents: total,
              memberIds: ids,
              mode: ShareMode.percent,
              portions: bp,
            );
          } else if (mode == ShareMode.portions) {
            final p = <String, int>{
              for (final m in members)
                m.id: int.tryParse(portionCtrls[m.id]?.text ?? '') ?? 1,
            };
            portions = p;
            shares = splitShares(
                totalCents: total, memberIds: ids, mode: ShareMode.portions, portions: p);
          } else {
            shares = splitShares(totalCents: total, memberIds: ids);
          }
        }
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl,
              Spacing.xxl + MediaQuery.viewInsetsOf(sheetContext).bottom),
          children: [
            Text('记出金', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text('从公费里支出，付款人固定为管理人。',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(prefixText: '¥ ', hintText: '0.00'),
              onChanged: (_) => setSheetState(() {}),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: titleController,
              maxLength: 30,
              decoration: const InputDecoration(hintText: '这笔钱花在哪'),
            ),
            Text('分类', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
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
            const SizedBox(height: Spacing.lg),
            Text('分摊模式', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            SegmentedButton<ShareMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ShareMode.equal, label: Text('平均')),
                ButtonSegment(value: ShareMode.portions, label: Text('按份数')),
                ButtonSegment(value: ShareMode.percent, label: Text('按百分比')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setSheetState(() => mode = s.first),
            ),
            const SizedBox(height: Spacing.sm),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(children: [
                  MemberAvatar(member: m, size: 24),
                  const SizedBox(width: Spacing.sm),
                  Expanded(child: Text(m.name)),
                  if (mode == ShareMode.portions)
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: portionCtrls.putIfAbsent(
                            m.id, () => TextEditingController(text: '1')),
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(suffixText: '份'),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  if (mode == ShareMode.percent)
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
                        decoration: const InputDecoration(suffixText: '%', hintText: '0'),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  if (mode == ShareMode.equal && shares.isNotEmpty)
                    MoneyText(
                      shares.firstWhere((s) => s.memberId == m.id,
                          orElse: () => const ShareEntry(memberId: '', cents: 0)).cents,
                      fontSize: AppFontSizes.caption,
                    ),
                ]),
              ),
            const SizedBox(height: Spacing.sm),
            // V2.9.0:收紧 error 判据 —— percent 归一场景 shares 为空/自动归一时
            // 不再短暂误报红色;仅在实际出现「有分摊但与总额不一致」时告警。
            Text('合计分摊 ${formatMoney(shares.fold<int>(0, (s, e) => s + e.cents))} / 支出 ${formatMoney(total)}',
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: shares.isNotEmpty &&
                            shares.fold<int>(0, (s, e) => s + e.cents) != total
                        ? scheme.error
                        : scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.lg),
            PrimaryButton(
              label: '记出金',
              expanded: true,
              onPressed: total <= 0
                  ? null
                  : () async {
                      // V2.9.0:出金标题显式校验 —— 不再静默落默认名「公费支出」。
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        showAppSnackBar(ctx, '请先填写这笔钱的用途', tone: SnackTone.destructive);
                        return;
                      }
                      Navigator.of(sheetContext).pop(true);
                      HapticFeedback.lightImpact();
                      try {
                        await addFundExpense(
                          ref,
                          fundId: fund.id,
                          title: title,
                          categoryKey: categoryKey,
                          amountCents: total,
                          shareMemberIds: ids,
                          shareMode: mode,
                          portions: portions,
                        );
                        if (context.mounted) {
                          showAppSnackBar(context, '已记出金 ✅');
                        }
                      } catch (e, s) {
                        // V2.9.0:原始异常只进调试日志,不进 UI 文案。
                        debugPrint('addFundExpense failed: $e\n$s');
                        if (context.mounted) {
                          showAppSnackBar(context, '记出金失败，请稍后重试', tone: SnackTone.destructive);
                        }
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
  titleController.dispose();
  amountController.dispose();
  for (final c in portionCtrls.values) {
    c.dispose();
  }
  for (final c in percentCtrls.values) {
    c.dispose();
  }
  return ok ?? false;
}

String _yuanText(int cents) =>
    // V2.9.0:金额统一走 MoneyFormat 千分位口径(此前丢分位/千分位)。
    MoneyFormat.fenToYuan(cents);
