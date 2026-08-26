import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/member_avatar.dart';
import '../widgets/stagger_in.dart';

/// ⚖️ AA 结算：净额榜 → 转账方案逐笔确认 → 完成本轮；历史可撤销。
class SettleScreen extends ConsumerWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeSettlementProvider);
    final membersAsync = ref.watch(membersProvider);
    final historyAll = ref.watch(settlementsProvider);
    final groupId = ref.watch(activeGroupIdProvider).value;

    final loading = activeAsync.isLoading || membersAsync.isLoading;
    final members = membersAsync.value ?? const <LedgerMemberView>[];
    final history = (historyAll.value ?? const <SettlementView>[]).where((s) => !s.active).toList();

    return Scaffold(
      appBar: GlassAppBar(title: 'AA 结算'),
      body: loading
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Spacing.xl),
              children: const [
                SkeletonBox(height: 120, radius: AppRadius.cardValue),
                SizedBox(height: Spacing.lg),
                SkeletonBox(height: 88, radius: AppRadius.cardValue),
                SkeletonBox(height: 88, radius: AppRadius.cardValue),
              ],
            )
          : groupId == null || members.isEmpty
              ? const EmptyState(
                  emoji: '👥',
                  title: '先有团有人才好算账',
                  message: '去账本页建团加成员，回来一键算清',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
                  children: [
                    StaggerIn(index: 0, child: _NetBoard(members: members)),
                    const SizedBox(height: Spacing.lg),
                    activeAsync.when(
                      loading: () => const SkeletonBox(height: 160, radius: AppRadius.cardValue),
                      error: (e, _) => Text('结算加载失败', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      data: (active) => active == null
                          ? StaggerIn(
                              index: 1,
                              child: _StartRoundCard(
                                onStart: () async {
                                  HapticFeedback.lightImpact();
                                  await startSettlement(ref, groupId);
                                },
                              ),
                            )
                          : _ActiveRound(
                              settlement: active,
                              members: members,
                            ),
                    ),
                    if (history.isNotEmpty)
                      StaggerIn(index: 3, child: _HistorySection(history: history)),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// 净额榜
// ---------------------------------------------------------------------------

class _NetBoard extends ConsumerWidget {
  const _NetBoard({required this.members});

  final List<LedgerMemberView> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    final balances = netBalanceMap(members, expenses);

    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.sm),
              child: Text('每人净额 · 正收负欠',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 1),
                child: Row(
                  children: [
                    MemberAvatar(member: m, size: 30),
                    const SizedBox(width: Spacing.sm),
                    Expanded(child: Text(m.name, style: Theme.of(context).textTheme.labelLarge)),
                    MoneyText(
                      balances[m.id] ?? 0,
                      fontSize: AppFontSizes.bodyLarge,
                      showSign: true,
                      color: (balances[m.id] ?? 0) >= 0
                          ? SemanticColors.income
                          : SemanticColors.expense,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 开始本轮
// ---------------------------------------------------------------------------

class _StartRoundCard extends StatelessWidget {
  const _StartRoundCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        color: scheme.primary.withValues(alpha: 0.07),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text('⚖️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: Spacing.md),
          Text('是时候把账算清了', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text('按最少转账次数生成方案，谁转谁一目了然',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Spacing.lg),
          PrimaryButton(label: '开始这一轮结算', expanded: true, onPressed: onStart),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 进行中的一轮
// ---------------------------------------------------------------------------

class _ActiveRound extends ConsumerWidget {
  const _ActiveRound({required this.settlement, required this.members});

  final SettlementView settlement;
  final List<LedgerMemberView> members;

  String nameOf(String id) =>
      members.where((m) => m.id == id).firstOrNull?.name ?? '?';

  LedgerMemberView memberOf(String id) =>
      members.firstWhere((m) => m.id == id,
          orElse: () => LedgerMemberView(id: id, name: '?', colorIndex: 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDone = settlement.allDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('第 ' + settlement.roundNo.toString() + ' 轮 · 待转 ' +
                  (settlement.transfers.length - settlement.doneCount).toString() +
                  '/' + settlement.transfers.length.toString() + ' 笔',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        for (var i = 0; i < settlement.transfers.length; i++)
          TransferRow(
            index: i,
            transfer: settlement.transfers[i],
            fromMember: memberOf(settlement.transfers[i].from),
            toMember: memberOf(settlement.transfers[i].to),
            onToggle: (done) => toggleTransfer(ref, settlement.id, i, done),
          ),
        const SizedBox(height: Spacing.lg),
        PrimaryButton(
          label: allDone ? '完成本轮 ✅' : '还差 ' + (settlement.transfers.length - settlement.doneCount).toString() + ' 笔没确认',
          expanded: true,
          backgroundColor: allDone ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: allDone ? null : Theme.of(context).colorScheme.onSurfaceVariant,
          onPressed: allDone
              ? () async {
                  HapticFeedback.lightImpact();
                  await finishSettlement(ref, settlement.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('第 ' + settlement.roundNo.toString() + ' 轮结清，干杯 🎉')));
                  }
                }
              : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 单笔转账行：付款人 → 弹簧箭头 → 收款人 + 打勾
// ---------------------------------------------------------------------------

class TransferRow extends StatefulWidget {
  const TransferRow({
    super.key,
    required this.index,
    required this.transfer,
    required this.fromMember,
    required this.toMember,
    required this.onToggle,
  });

  final int index;
  final TransferView transfer;
  final LedgerMemberView fromMember;
  final LedgerMemberView toMember;
  final ValueChanged<bool> onToggle;

  @override
  State<TransferRow> createState() => _TransferRowState();
}

class _TransferRowState extends State<TransferRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  /// 箭头入场：elasticOut 弹簧感
  late final Animation<double> _spring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 1.0, curve: ElasticOutCurve(0.9)),
  );

  bool _bouncing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_bouncing) return;
    setState(() => _bouncing = true);
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return; // 先判存活再执行副作用，避免失活后仍触发父级 onToggle
      widget.onToggle(!widget.transfer.done);
      setState(() => _bouncing = false); // 弹跳结束复位，避免卡在放大态
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = widget.transfer.done;

    return Material(
      color: done
          ? scheme.primary.withValues(alpha: 0.06)
          : (scheme.brightness == Brightness.dark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest),
      borderRadius: AppRadius.input,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: done ? 0.62 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
            child: Row(
              children: [
                // 付款人
                Column(
                  children: [
                    MemberAvatar(member: widget.fromMember, size: 34),
                    const SizedBox(height: 2),
                    SizedBox(width: 52, child: Text(widget.fromMember.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
                  ],
                ),
                Expanded(
                  child: SlideTransition(
                    position: Tween(begin: const Offset(-0.35, 0), end: Offset.zero).animate(_spring),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: _bouncing ? 1.25 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: Icon(Icons.east_rounded,
                              size: 22, color: done ? scheme.primary : scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        MoneyText(widget.transfer.cents,
                            fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                // 收款人
                Column(
                  children: [
                    MemberAvatar(member: widget.toMember, size: 34),
                    const SizedBox(height: 2),
                    SizedBox(width: 52, child: Text(widget.toMember.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
                  ],
                ),
                const SizedBox(width: Spacing.sm),
                // 打勾
                GestureDetector(
                  onTap: _toggle,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    scale: _bouncing ? 1.18 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? scheme.primary : Colors.transparent,
                        border: Border.all(color: done ? scheme.primary : scheme.outlineVariant, width: 1.6),
                      ),
                      child: done
                          ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 历史轮次折叠列表
// ---------------------------------------------------------------------------

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.history});

  final List<SettlementView> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
          child: Text('历史结算', style: Theme.of(context).textTheme.titleMedium),
        ),
        Material(
          color: scheme.brightness == Brightness.dark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest,
          borderRadius: AppRadius.card,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < history.length; i++) ...[
                if (i > 0)
                  Divider(height: 0.8, thickness: 0.8, indent: Spacing.xl, endIndent: Spacing.xl),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer,
                    child: Text('#' + history[i].roundNo.toString(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer)),
                  ),
                  title: Text('第 ' + history[i].roundNo.toString() + ' 轮 · ' +
                      history[i].transfers.length.toString() + ' 笔转账',
                      style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text(
                    fmtFullDate(DateTime.fromMillisecondsSinceEpoch(history[i].completedAtMs ?? history[i].createdAtMs)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: TextButton(
                    onPressed: () => _confirmUndo(context, ref),
                    child: Text('撤销',
                        style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.error)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUndo(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.32,
      minChildSize: 0.26,
      builder: (sheetContext, __) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('撤销最近一轮结算？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text('该轮涉及的账单会回到「未结」状态，方案作废重来。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('算了'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      final gid = ref.read(activeGroupIdProvider).value;
                      if (gid != null) {
                        await undoLastRound(ref, gid);
                      }
                    },
                    child: const Text('撤销这轮'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
