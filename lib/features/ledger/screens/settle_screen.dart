import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../data/providers.dart';
import '../../../domain/models.dart';
import '../../../domain/settle_strategy.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/member_avatar.dart';
import '../widgets/stagger_in.dart';
import 'settle_card_sheet.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../theme/app_icons.dart';

/// V2.9.0:全量成员(含软删)姓名表 —— 净额榜/转账行姓名解析走它,
/// 软删成员不再显示「?」(与 settle_card_sheet 同口径:repo.getMembers 全量)。
final _allMemberNamesProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null || gid.isEmpty) return const <String, String>{};
  final members = await ref.watch(ledgerRepoProvider).getMembers(gid);
  return {for (final m in members) m.id: m.name};
});

/// ⚖️ AA 结算：净额榜 → 转账方案逐笔确认 → 完成本轮；历史可撤销。
///
/// S9：净额榜下方可选结算策略（最少笔数 / 最少人参与），**会话级状态不持久化**。
class SettleScreen extends ConsumerStatefulWidget {
  const SettleScreen({super.key});

  @override
  ConsumerState<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends ConsumerState<SettleScreen> {
  SettleStrategy _strategy = SettleStrategy.minTransfers;

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeSettlementProvider);
    final membersAsync = ref.watch(membersProvider);
    final historyAll = ref.watch(settlementsProvider);
    final groupId = ref.watch(activeGroupIdProvider).value;

    final loading = activeAsync.isLoading || membersAsync.isLoading;
    final members = membersAsync.value ?? const <LedgerMemberView>[];
    // V2.9.0:软删成员姓名走全量成员表解析。
    final allNames = ref.watch(_allMemberNamesProvider).value ?? const <String, String>{};
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
                  icon: AppIcons.members,
                  title: '先有团有人才好算账',
                  message: '去账本页建团加成员，回来一键算清',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
                  children: [
                    StaggerIn(index: 0, child: _NetBoard(members: members, allNames: allNames)),
                    const SizedBox(height: Spacing.md),
                    // S9：结算策略（切换即时生效，创建本轮时记录到 settlements.strategy）。
                    SegmentedButton<SettleStrategy>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: SettleStrategy.minTransfers, label: Text('最少笔数')),
                        ButtonSegment(
                            value: SettleStrategy.minParticipants, label: Text('最少人参与')),
                      ],
                      selected: {_strategy},
                      onSelectionChanged: (s) {
                        HapticFeedback.selectionClick();
                        setState(() => _strategy = s.first);
                      },
                    ),
                    const SizedBox(height: Spacing.lg),
                    activeAsync.when(
                      loading: () => const SkeletonBox(height: 160, radius: AppRadius.cardValue),
                      // V2.9.0:错误态收口 ErrorState,原始异常只进调试日志。
                      error: (e, s) => ErrorState(
                        onRetry: () => ref.invalidate(settlementsProvider),
                        error: e,
                        stackTrace: s,
                      ),
                      data: (active) => active == null
                          ? StaggerIn(
                              index: 1,
                              child: _StartRoundCard(
                                onStart: () async {
                                  HapticFeedback.lightImpact();
                                  final created = await startSettlement(ref, groupId,
                                      strategy: _strategy);
                                  if (!context.mounted) return;
                                  // 余额已平衡 / 无未结账单时，createSettlement 返回 null 不入库
                                  if (!created) {
                                    showAppSnackBar(context, '当前没有需要结算的账单 🎉');
                                  }
                                },
                              ),
                            )
                          : _ActiveRound(
                              settlement: active,
                              members: members,
                              allNames: allNames,
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
  const _NetBoard({required this.members, this.allNames = const {}});

  final List<LedgerMemberView> members;

  /// V2.9.0:全量成员(含软删)姓名表 —— 有未结账目的软删成员也参与净额榜。
  final Map<String, String> allNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    // V2.9.0:软删成员若仍有未结账目,补入净额榜(姓名走全量表),避免其欠收凭空消失。
    final activeIds = {for (final m in members) m.id};
    final merged = [...members];
    final touchedIds = <String>{
      for (final e in expenses)
        if (e.settledRoundId == null) ...[
          for (final p in e.payers) p.memberId,
          for (final s in e.shares) s.memberId,
        ],
    };
    for (final entry in allNames.entries) {
      if (!activeIds.contains(entry.key) && touchedIds.contains(entry.key)) {
        merged.add(LedgerMemberView(id: entry.key, name: entry.value, colorIndex: 0));
      }
    }
    final balances = netBalanceMap(merged, expenses);

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
            for (final m in merged)
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
  const _ActiveRound({
    required this.settlement,
    required this.members,
    this.allNames = const {},
  });

  final SettlementView settlement;
  final List<LedgerMemberView> members;

  /// V2.9.0:全量成员(含软删)姓名表。
  final Map<String, String> allNames;

  LedgerMemberView memberOf(String id) {
    final active = members.where((m) => m.id == id).firstOrNull;
    if (active != null) return active;
    // V2.9.0:软删成员用全量表姓名补一个视图(头像色取 0 号)。
    return LedgerMemberView(
        id: id, name: allNames[id] ?? '?', colorIndex: 0);
  }

  /// 方案中出现的不同账户数（脚注「M 人参与」）。
  Set<String> _participants() {
    final ids = <String>{};
    for (final t in settlement.transfers) {
      ids.add(t.from);
      ids.add(t.to);
    }
    return ids;
  }

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
        const SizedBox(height: Spacing.xs),
        // S9 脚注：笔数 + 参与人数 + 所用策略。
        Text(
          '${settlement.transfers.length} 笔 · ${_participants().length} 人参与 · '
          '${settlement.strategy == 'minParticipants' ? '最少人参与' : '最少笔数'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Spacing.sm),
        for (var i = 0; i < settlement.transfers.length; i++)
          // 用稳定 key 让 Element 树可重建时正确复用旧 state（round 状态切换时
          // 长度/顺序不变会被原样保留），避免 framework.dart
          // '_dependents.isEmpty: is not true' 断言（出现在 controller 在
          // 未 list 上的 forward/unmount 时序错配场景）。
          TransferRow(
            key: ValueKey('tr-${settlement.id}-$i'),
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
                    showAppSnackBar(context, '第 ' + settlement.roundNo.toString() + ' 轮结清，干杯 🎉');
                  }
                }
              : null,
        ),
        const SizedBox(height: Spacing.sm),
        // S5：把本轮方案变成可分享的图片卡 + 只读链接。
        OutlinedButton.icon(
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('生成结算卡 / 只读链接'),
          onPressed: () => showSettleCardSheet(context, ref, settlement),
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  /// 箭头入场：elasticOut 弹簧感
  late final Animation<double> _spring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 1.0, curve: ElasticOutCurve(0.9)),
  );

  bool _bouncing = false;

  @override
  void initState() {
    super.initState();
    // 把 forward 从字段初始化阶段挪到 initState：避免 widget 在 build 期间
    // 被立刻替换/卸载时 controller forward 调度撞上 unmount（会触发
    // framework.dart '_dependents.isEmpty: is not true' 断言）。
    _controller.forward();
  }

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
    // V2.9.0:引擎只支持撤销最近完成的一轮 —— 只有最新一轮渲染「撤销」,
    // 更早轮次如实不渲染(此前每行都有撤销、行为却永远撤最近一轮,行号与行为错位)。
    // settlementsProvider 已按 roundNo 降序排好,取最大轮号即为最近一轮。
    final latestRoundNo =
        history.isEmpty ? null : history.map((s) => s.roundNo).reduce((a, b) => a > b ? a : b);
    // V2.9.0:撤销影响面按「该轮入结的账单数」如实呈现(danger 弹层强确认口径)。
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    int affectedBills(SettlementView s) =>
        expenses.where((e) => e.settledRoundId == s.id).length;
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // S5：每一轮都可单独生成结算卡 / 只读链接。
                      IconButton(
                        tooltip: '生成结算卡',
                        icon: Icon(Icons.ios_share_rounded,
                            size: 18, color: scheme.onSurfaceVariant),
                        onPressed: () => showSettleCardSheet(context, ref, history[i]),
                      ),
                      if (history[i].roundNo == latestRoundNo)
                        TextButton(
                          onPressed: () =>
                              _confirmUndo(context, ref, history[i], affectedBills(history[i])),
                          child: Text('撤销',
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption, color: scheme.error)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// V2.9.0:撤销确认改走 L2 危险确认(影响账单数入文案),成功/失败给轻提示。
  Future<void> _confirmUndo(
      BuildContext context, WidgetRef ref, SettlementView round, int billCount) async {
    HapticFeedback.selectionClick();
    final ok = await showDangerConfirm(
      context: context,
      title: '撤销第 ' + round.roundNo.toString() + ' 轮结算？',
      body: '该轮 ' + billCount.toString() + ' 笔账单会回到「未结」状态，转账方案作废，此操作不可恢复。',
      confirmLabel: '确认',
      icon: Icons.undo_rounded,
    );
    if (!ok || !context.mounted) return;
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null) return;
    try {
      await undoLastRound(ref, gid);
      if (!context.mounted) return;
      showAppSnackBar(context,
          '已撤销第 ' + round.roundNo.toString() + ' 轮结算，' + billCount.toString() + ' 笔账单回到未结');
    } catch (e, s) {
      // V2.9.0:原始异常只进调试日志,不进 UI 文案。
      debugPrint('undoLastRound failed: $e\n$s');
      if (!context.mounted) return;
      showAppSnackBar(context, '撤销失败，请稍后重试', tone: SnackTone.destructive);
    }
  }
}
