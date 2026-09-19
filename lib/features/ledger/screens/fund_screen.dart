import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/conflict_badge.dart';
import 'fund_sheets.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../theme/app_icons.dart';

/// 💰 公款池详情（S8）：一池一管理人；入金 prepay / 出金 normal，
/// 余额为派生展示量（只统计未入账账单），「谁该退多少」由结算引擎产出。
class FundScreen extends ConsumerWidget {
  const FundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(fundsProvider);
    final group = ref.watch(activeGroupProvider).value;
    final members = ref.watch(membersProvider).value ?? const <LedgerMemberView>[];

    return Scaffold(
      appBar: GlassAppBar(title: '公费池'),
      body: fundsAsync.isLoading
          ? const Padding(
              padding: EdgeInsets.all(Spacing.xl),
              child: SkeletonBox(height: 160, radius: AppRadius.cardValue),
            )
          : _body(context, ref, group, members, fundsAsync.value ?? const <FundView>[]),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, LedgerGroupView? group,
      List<LedgerMemberView> members, List<FundView> funds) {
    if (group == null) {
      return const EmptyState(icon: Icons.folder_outlined, title: '还没有账本', message: '先创建一个旅行账本');
    }
    if (group.isPersonal) {
      return const EmptyState(
        icon: AppIcons.coins,
        title: '个人账本无需公费池',
        message: '公费池面向多人共同消费场景，个人账本可直接记账。',
      );
    }
    FundView? open;
    for (final f in funds) {
      if (f.isOpen) {
        open = f;
        break;
      }
    }
    if (open == null) {
      return _CreateFundForm(group: group, members: members, ref: ref);
    }
    final fund = open;
    final summaryAsync = ref.watch(fundSummaryProvider(fund.id));
    final summary = summaryAsync.value;
    final expensesAsync = ref.watch(fundExpensesProvider(fund.id));
    final expenses = expensesAsync.value ?? const <ExpenseRecord>[];
    final manager = _nameOf(members, fund.managerMemberId);
    final contributions =
        expenses.where((e) => e.type == ExpenseType.prepay).toList();
    final payouts = expenses.where((e) => e.type == ExpenseType.normal).toList();

    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.md, Spacing.xl, AppBottomLayout.withSafeArea(context, 96)),
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: AppRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fund.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('余额', style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: Spacing.sm),
                  MoneyText(summary?.balanceCents ?? 0,
                      fontSize: 30, fontWeight: FontWeight.w800),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.lg,
                runSpacing: Spacing.xs,
                children: [
                  _Meta(label: '已收', cents: summary?.contributedCents ?? 0),
                  if (fund.targetCents != null)
                    _Meta(label: '计划收', cents: fund.targetCents!),
                  _Meta(label: '已支出', cents: summary?.spentCents ?? 0),
                  _Meta(label: '参与人数', plain: '${summary?.contributorCount ?? 0} 人'),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text('管理人：$manager',
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
              if (fund.targetCents != null &&
                  (summary?.balanceCents ?? 0) < fund.targetCents! * 20 ~/ 100) ...[
                const SizedBox(height: Spacing.xs),
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: scheme.tertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('余额已低于计划总额的 20%，记得留意后续支出',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption, color: scheme.tertiary)),
                  ),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(children: [
          Expanded(
            child: PrimaryButton(
              label: '记入金',
              expanded: true,
              onPressed: () => showFundContributionSheet(context, ref, fund: fund),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: OutlinedButton(
              onPressed: () => showFundExpenseSheet(context, ref, fund: fund),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              ),
              child: const Text('记出金'),
            ),
          ),
        ]),
        const SizedBox(height: Spacing.sm),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('转移管理人'),
              onPressed: () => _transferManager(context, ref, fund, members),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('关闭公费池'),
              onPressed: () => _closeFund(context, ref, fund),
            ),
          ),
        ]),
        const SizedBox(height: Spacing.lg),
        Text('入金记录', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xs),
        if (contributions.isEmpty)
          Text('还没有入金', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final e in contributions)
            _FundBillTile(
              record: e,
              memberNames: {for (final m in members) m.id: m.name},
              showPayers: true,
            ),
        const SizedBox(height: Spacing.lg),
        Text('出金记录', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xs),
        if (payouts.isEmpty)
          Text('还没有出金', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final e in payouts)
            _FundBillTile(
              record: e,
              memberNames: {for (final m in members) m.id: m.name},
              showPayers: false,
            ),
      ],
    );
  }

  Future<void> _transferManager(BuildContext context, WidgetRef ref,
      FundView fund, List<LedgerMemberView> members) async {
    final target = await showModalBottomSheet<LedgerMemberView>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text('选择新的管理人', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final m in members)
              ListTile(
                leading: Icon(
                    m.id == fund.managerMemberId
                        ? Icons.check_circle_rounded
                        : Icons.person_outline_rounded),
                title: Text(m.name),
                enabled: m.id != fund.managerMemberId,
                onTap: () => Navigator.of(context).pop(m),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    try {
      await updateFundInfo(ref, fund.id, managerMemberId: target.id);
      if (context.mounted) {
        showAppSnackBar(context, '管理人已移交给 ${target.name}；历史账单不变');
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, '转移失败：${e.toString()}', tone: SnackTone.destructive);
      }
    }
  }

  Future<void> _closeFund(BuildContext context, WidgetRef ref, FundView fund) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: '关闭公费池？',
      body: '建议先去结算页跑一轮结算（退款由结算引擎产出），再关闭。'
          '关闭后不能再记入金或出金，池变为只读。',
      confirmLabel: '确认关闭',
      cancelLabel: '再想想',
    );
    if (!confirm) return;
    await closeFund(ref, fund.id);
    if (context.mounted) {
      showAppSnackBar(context, '公费池已关闭（只读）');
    }
  }
}

String _nameOf(List<LedgerMemberView> members, String id) {
  for (final m in members) {
    if (m.id == id) return m.name;
  }
  return '已移除成员';
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, this.cents, this.plain});
  final String label;
  final int? cents;
  final String? plain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label ', style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
      if (plain != null)
        Text(plain!, style: const TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w700))
      else
        MoneyText(cents ?? 0, fontSize: AppFontSizes.caption, fontWeight: FontWeight.w700),
    ]);
  }
}

class _FundBillTile extends StatelessWidget {
  const _FundBillTile({
    required this.record,
    required this.memberNames,
    required this.showPayers,
  });

  final ExpenseRecord record;
  final Map<String, String> memberNames;
  final bool showPayers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final people = (showPayers ? record.payers : record.shares)
        .map((s) => memberNames[s.memberId] ?? '已移除成员')
        .toSet()
        .join('、');
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(children: [
        Icon(
          showPayers ? Icons.south_west_rounded : Icons.north_east_rounded,
          size: 15,
          color: showPayers ? scheme.primary : scheme.tertiary,
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text('${record.title} · $people',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: AppFontSizes.caption)),
        ),
        // V2.7.1 S12.2：该记录存在未确认冲突时显示小标记（仅提示）。
        ConflictDot(entityId: record.id, size: 13),
        MoneyText(record.amountCents, fontSize: AppFontSizes.caption),
        if (record.settledRoundId != null) ...[
          const SizedBox(width: Spacing.xs),
          Text('已结', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// 未开池时的创建表单。
class _CreateFundForm extends ConsumerStatefulWidget {
  const _CreateFundForm({required this.group, required this.members, required this.ref});
  final LedgerGroupView group;
  final List<LedgerMemberView> members;
  final WidgetRef ref;

  @override
  ConsumerState<_CreateFundForm> createState() => _CreateFundFormState();
}

class _CreateFundFormState extends ConsumerState<_CreateFundForm> {
  final _nameController = TextEditingController(text: '旅行基金');
  final _targetController = TextEditingController();
  String? _managerId;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    if (members.isEmpty) {
      return const EmptyState(
        icon: AppIcons.members,
        title: '还没有成员',
        message: '先添加同行成员，再设立旅行基金。',
      );
    }
    final managerId = _managerId ?? members.first.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
      children: [
        Text('设立旅行基金', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Spacing.sm),
        Text('出发前每人交一笔公费，途中统一支出，结束由结算引擎算出退还方案。',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Spacing.lg),
        TextField(
          controller: _nameController,
          maxLength: 20,
          decoration: const InputDecoration(labelText: '池名称'),
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _targetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: const InputDecoration(
            labelText: '计划收款总额（可空）',
            prefixText: '¥ ',
            helperText: '填了会在记入金时默认按人数均分',
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Text('管理人', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final m in members)
              ChoiceChip(
                label: Text(m.name),
                selected: managerId == m.id,
                onSelected: (_) => setState(() => _managerId = m.id),
              ),
          ],
        ),
        const SizedBox(height: Spacing.xxl),
        PrimaryButton(
          label: '创建公费池',
          expanded: true,
          onPressed: () async {
            HapticFeedback.lightImpact();
            try {
              await createFund(
                ref,
                groupId: widget.group.id,
                name: _nameController.text.trim(),
                managerMemberId: managerId,
                targetCents: parseMoney(_targetController.text),
              );
              if (context.mounted) {
                showAppSnackBar(context, '公费池已创建 ✅');
              }
            } catch (e) {
              if (context.mounted) {
                showAppSnackBar(context, '创建失败：${e.toString()}', tone: SnackTone.destructive);
              }
            }
          },
        ),
      ],
    );
  }
}
