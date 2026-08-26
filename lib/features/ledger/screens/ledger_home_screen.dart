import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../domain/budget_alert_engine.dart';
import '../../../domain/models.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/bill_detail_sheet.dart';
import '../widgets/category_icon_box.dart';
import '../widgets/count_up_text.dart';
import '../widgets/member_avatar.dart';
import '../widgets/stagger_in.dart';

/// 💰 记账 Tab 主页：当前团总览 + 余额榜 + 预算 + 最近账单流。
class LedgerHomeScreen extends ConsumerWidget {
  const LedgerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(activeGroupProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerLargeHeader(
          title: '账本',
          actions: [
            HeaderIconButton(
              icon: Icons.swap_horizontal_circle_rounded,
              tooltip: '切换旅行团',
              onTap: () => _openGroupSwitcher(context, ref),
            ),
            HeaderIconButton(
              icon: Icons.group_add_rounded,
              tooltip: '新建旅行团',
              onTap: () => context.pushNamed('group-edit'),
            ),
            Consumer(
              builder: (context, ref, _) {
                final hasUnread = ref
                        .watch(budgetAlertUnreadProvider)
                        .value ??
                    false;
                return HeaderIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: '预算预警',
                  badgeCount: hasUnread ? 1 : null,
                  onTap: () => _showAlertCenter(context, ref),
                );
              },
            ),
          ],
        ),
        Expanded(
          child: groupAsync.when(
            loading: () => const _HomeSkeleton(),
            error: (e, _) => const EmptyState(emoji: '😵', title: '加载失败了', message: '下拉重试或稍后再来看看'),
            data: (group) {
              if (group == null) {
                return EmptyState(
                  emoji: '💰',
                  title: '还没有旅行团',
                  message: '建一个团，拉上同行伙伴，AA 记账从此不糊涂',
                  actionLabel: '新建旅行团',
                  onAction: () => context.pushNamed('group-edit'),
                );
              }
              return _LedgerBody(groupId: group.id);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 有团状态主体
// ---------------------------------------------------------------------------

class _LedgerBody extends ConsumerWidget {
  const _LedgerBody({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final boardAsync = ref.watch(memberBoardProvider);
    final budgetAsync = ref.watch(budgetStatusProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final tripsAsync = ref.watch(tripsInGroupProvider);
    final unsettledAsync = ref.watch(unsettledCountProvider);

    if (membersAsync.isLoading || boardAsync.isLoading || budgetAsync.isLoading) {
      return const _HomeSkeleton();
    }

    final members = membersAsync.value ?? const <LedgerMemberView>[];
    final board = boardAsync.value ?? const <MemberStatView>[];
    final budget = budgetAsync.value ?? const BudgetStatusView(
      enabled: false, totalCents: 0, spentCents: 0, remainingCents: 0, percent: 0);
    final expenses = expensesAsync.value ?? const <ExpenseRecord>[];
    final trips = tripsAsync.value ?? const <TripCardView>[];
    final unsettled = unsettledAsync.value ?? 0;

    // 超支横幅（插在最顶，StaggerIn index=0 后移）
    final showOverBudgetBanner = budget.enabled && budget.overBudget;

    final recentExpenses = [...expenses]
      ..sort((a, b) {
        final byDate = b.dateEpochDay - a.dateEpochDay;
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    return Stack(
      children: [
        RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(expensesProvider);
            ref.invalidate(settlementsProvider);
          },
          child: ListView(
            padding: EdgeInsets.only(bottom: 140 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (showOverBudgetBanner)
                StaggerIn(index: 0, child: _OverBudgetBanner(budget: budget)),
              StaggerIn(index: showOverBudgetBanner ? 1 : 0, child: _GlassGroupCard(group: _currentGroup(ref, groupId), members: members, unsettled: unsettled)),
              StaggerIn(index: showOverBudgetBanner ? 2 : 1, child: _BudgetCard(budget: budget)),
              StaggerIn(index: 2, child: _BalanceBoard(board: board)),
              StaggerIn(index: 3, child: _RecentBills(expenses: recentExpenses.take(5).toList(), members: members)),
              if (trips.isNotEmpty)
                StaggerIn(index: 4, child: _LinkedTrips(trips: trips.where((t) => !t.archived).toList())),
            ],
          ),
        ),
        Positioned(
          right: Spacing.xl,
          bottom: 76 + MediaQuery.paddingOf(context).bottom,
          child: FloatingActionButton.extended(
            heroTag: 'fab-ledger-add',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go('/expenses/edit');
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('记一笔'),
          ),
        ),
      ],
    );
  }

  LedgerGroupView _currentGroup(WidgetRef ref, String groupId) {
    final groups = ref.watch(groupsProvider).value ?? const <LedgerGroupView>[];
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    return LedgerGroupView(id: groupId, name: '旅行团', icon: '🧭', budgetEnabled: false);
  }
}

// ---------------------------------------------------------------------------
// 顶部玻璃当前团卡
// ---------------------------------------------------------------------------

class _GlassGroupCard extends StatelessWidget {
  const _GlassGroupCard({required this.group, required this.members, required this.unsettled});

  final LedgerGroupView group;
  final List<LedgerMemberView> members;
  final int unsettled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              // 玻璃质感：表面低容器色叠一层主题主色的柔光
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surfaceContainerLow.withValues(alpha: 0.82),
                  scheme.primary.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.inputValue),
                      ),
                      child: Text(group.icon, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            members.isEmpty ? '还没有成员' : members.length.toString() + ' 位同行伙伴',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (unsettled > 0)
                      _UnsettledBadge(count: unsettled),
                  ],
                ),
                if (members.isNotEmpty) ...[
                  const SizedBox(height: Spacing.lg),
                  MemberAvatarStack(members: members, size: 32),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 未结算徽章：直达 AA 结算页
class _UnsettledBadge extends StatelessWidget {
  const _UnsettledBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        context.go('/expenses/settle');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance_rounded, size: 13, color: scheme.onErrorContainer),
            const SizedBox(width: 4),
            Text(
              count.toString() + ' 笔未结',
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w600,
                color: scheme.onErrorContainer,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.transparent),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 预算环形进度卡
// ---------------------------------------------------------------------------

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});

  final BudgetStatusView budget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = budget.overBudget;
    final ringColor = over ? scheme.error : scheme.primary;
    // 预算尚未开启或未填金额：显示“添加预算”引导，而不是空进度。
    final configured = budget.enabled && budget.totalCents > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
      child: Material(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () {
            HapticFeedback.selectionClick();
            context.go('/expenses/budget');
          },
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Row(
              children: [
                if (configured)
                  ProgressRing(
                    value: budget.percent,
                    size: 76,
                    strokeWidth: 8,
                    color: ringColor,
                    child: CountUpText(
                      value: (budget.percent * 100).round(),
                      formatter: (v) => v.toString() + '%',
                      style: AppTextStyles.money(context,
                          fontSize: AppFontSizes.body, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Icon(Icons.savings_outlined,
                        size: 36, color: scheme.primary),
                  ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: configured
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(over ? '已超支，收着点花 🥲' : '预算进度', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                CountUpText(
                                  value: budget.spentCents,
                                  formatter: (v) => formatMoneyForDisplay(v),
                                  style: AppTextStyles.money(context,
                                      fontSize: AppFontSizes.title,
                                      color: over ? scheme.error : scheme.onSurface),
                                ),
                                const SizedBox(width: 4),
                                Text('/ ' + formatMoneyForDisplay(budget.totalCents),
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              over ? '超支 ' + formatMoneyForDisplay(-budget.remainingCents)
                                   : '还剩 ' + formatMoneyForDisplay(budget.remainingCents),
                              style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: over ? scheme.error : scheme.onSurfaceVariant,
                                fontFeatures: AppTextStyles.tabularFigures,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('还没设置预算', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text('给这趟旅程定个总预算，超支自动提醒',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline_rounded,
                                    size: 16, color: scheme.primary),
                                const SizedBox(width: 4),
                                Text('添加预算',
                                    style: TextStyle(
                                        fontSize: AppFontSizes.caption,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary)),
                              ],
                            ),
                          ],
                        ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatMoneyForDisplay(int cents) =>
    (cents < 0 ? '-' : '') + '¥' + _fmtAbs(cents);

String _fmtAbs(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  return yuan.toString() + '.' + fen;
}

// ---------------------------------------------------------------------------
// 成员余额榜
// ---------------------------------------------------------------------------

class _BalanceBoard extends StatelessWidget {
  const _BalanceBoard({required this.board});

  final List<MemberStatView> board;

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerSectionTitle(
          title: '谁付了多少',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              context.pushNamed('members');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('管理成员',
                    style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.primary)),
                Icon(Icons.chevron_right_rounded, size: 16, color: scheme.primary),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Material(
            color: scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLowest,
            borderRadius: AppRadius.card,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < board.length; i++) ...[
                  if (i > 0)
                    Divider(height: 0.8, thickness: 0.8, indent: Spacing.xxxl + 30, color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  _BalanceRow(row: board[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.row});

  final MemberStatView row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md + 2),
      child: Row(
        children: [
          MemberAvatar(member: row.member, size: 38),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.member.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text('垫付 ',
                        style: Theme.of(context).textTheme.labelSmall),
                    MoneyText(row.paidCents,
                        fontSize: AppFontSizes.caption, showSign: false),
                    const SizedBox(width: Spacing.sm),
                    Text('应摊 ',
                        style: Theme.of(context).textTheme.labelSmall),
                    MoneyText(row.shareCents, fontSize: AppFontSizes.caption),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(row.balanceCents >= 0 ? '应收' : '应还',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 1),
              MoneyText(
                row.balanceCents,
                fontSize: AppFontSizes.bodyLarge,
                showSign: true,
                color: row.balanceCents >= 0
                    ? SemanticColors.income
                    : SemanticColors.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 最近账单流（右滑编辑 / 左滑删除 / 点开详情）
// ---------------------------------------------------------------------------

class _RecentBills extends ConsumerWidget {
  const _RecentBills({required this.expenses, required this.members});

  final List<ExpenseRecord> expenses;
  final List<LedgerMemberView> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenses.isEmpty) {
      return const _NoBillsHint();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerSectionTitle(title: '最近记了啥'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Material(
            color: Theme.of(context).colorScheme.brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: AppRadius.card,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < expenses.length; i++) ...[
                  if (i > 0)
                    Divider(height: 0.8, thickness: 0.8, indent: 74, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
                  StaggerIn(index: i, child: _BillTile(expense: expenses[i], members: members)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoBillsHint extends StatelessWidget {
  const _NoBillsHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.huge),
      child: EmptyState(
        emoji: '🧾',
        title: '还没记过账',
        message: '点右下角「记一笔」，旅途中的每笔开销都算得明明白白',
      ),
    );
  }
}

class _BillTile extends ConsumerStatefulWidget {
  const _BillTile({required this.expense, required this.members});

  final ExpenseRecord expense;
  final List<LedgerMemberView> members;

  @override
  ConsumerState<_BillTile> createState() => _BillTileState();
}

class _BillTileState extends ConsumerState<_BillTile> {
  bool _closing = false;

  String _memberName(String id) {
    for (final m in widget.members) {
      if (m.id == id) return m.name;
    }
    return '已移除成员';
  }

  void _openEdit() {
    HapticFeedback.selectionClick();
    context.go('/expenses/edit?id=' + widget.expense.id);
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.lightImpact();
    final scheme = Theme.of(context).colorScheme;
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.34,
      minChildSize: 0.28,
      builder: (sheetContext, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('删掉这笔账？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.xs),
            Text(widget.expense.title + ' · ' + formatMoneyForDisplay(widget.expense.amountCents) + ' 元',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.xl),
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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      setState(() => _closing = true);
                      await deleteExpense(ref, widget.expense.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已删除')));
                      }
                    },
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _closing = false);
  }

  void _openDetail() {
    HapticFeedback.selectionClick();
    showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.62,
      builder: (sheetContext, scrollController) {
        var detailIcon = '🏷️';
        for (final c in ref.read(categoriesProvider).value ?? const <CategoryView>[]) {
          if (c.key == widget.expense.categoryKey) {
            detailIcon = c.icon;
            break;
          }
        }
        return BillDetailSheet(
          scrollController: scrollController,
          expense: widget.expense,
          memberName: _memberName,
          icon: detailIcon,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.expense;
    final isRefund = e.type == ExpenseType.refund;
    final isPrepay = e.type == ExpenseType.prepay;

    // 分类图标：从分类流实时解析（内置 + 自定义一致处理），缺失兜底 🏷️
    var categoryIcon = '🏷️';
    for (final c in ref.watch(categoriesProvider).value ?? const <CategoryView>[]) {
      if (c.key == e.categoryKey) {
        categoryIcon = c.icon;
        break;
      }
    }

    final tile = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: _closing ? 0 : 1,
      child: InkWell(
        onTap: _openDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md + 2),
          child: Row(
            children: [
              CategoryIconBox(categoryKey: e.categoryKey, icon: categoryIcon),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        if (isPrepay) ...[
                          const SizedBox(width: 6),
                          ExpenseTypeChip(
                            label: '预付',
                            background: scheme.secondary.withValues(alpha: 0.14),
                            foreground: scheme.secondary,
                          ),
                        ] else if (isRefund) ...[
                          const SizedBox(width: 6),
                          ExpenseTypeChip(
                            label: '退款',
                            background: scheme.errorContainer,
                            foreground: scheme.error,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _memberName(_firstPayerId(e)) +
                          (e.settledRoundId != null ? ' · 已结清' : ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              MoneyText(
                e.amountCents,
                fontSize: AppFontSizes.bodyLarge,
                semanticColor: true,
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('bill-' + e.id),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: scheme.primary.withValues(alpha: 0.14),
        iconColor: scheme.primary,
        icon: Icons.edit_rounded,
        label: '编辑',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: scheme.error.withValues(alpha: 0.12),
        iconColor: scheme.error,
        icon: Icons.delete_outline_rounded,
        label: '删除',
      ),
      onDismissed: (_) {}, // 由 confirmDismiss 接管，不真正滑除
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _openEdit();
        } else {
          await _confirmDelete();
        }
        return false; // 保持行存在，动作由抽屉/页面完成
      },
      child: tile,
    );
  }

  String _firstPayerId(ExpenseRecord e) => e.payers.isEmpty ? '' : e.payers.first.memberId;
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      decoration: BoxDecoration(color: color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w600, color: iconColor)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 关联行程横滑小卡（Hero tag = trip.id）
// ---------------------------------------------------------------------------

class _LinkedTrips extends StatelessWidget {
  const _LinkedTrips({required this.trips});

  final List<TripCardView> trips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerSectionTitle(title: '这些团的账也在这本里'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            scrollDirection: Axis.horizontal,
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.md),
            itemBuilder: (context, i) {
              final trip = trips[i];
              return StaggerIn(
                index: i,
                // 与行程页一致：不做无目标 Hero 转场，降低路由过渡框架断言风险。
                child: Material(
                    borderRadius: AppRadius.card,
                    child: Ink(
                      width: 190,
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.card,
                        gradient: CoverGradients.gradientFor(trip.cover),
                      ),
                      child: InkWell(
                        borderRadius: AppRadius.card,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.pushNamed('trip-detail', extra: trip.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(trip.emoji, style: const TextStyle(fontSize: 22)),
                                  const Spacer(),
                                  Icon(Icons.open_in_new_rounded,
                                      size: 15, color: CoverGradients.onCover.withValues(alpha: 0.85)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trip.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: AppFontSizes.bodyLarge,
                                          fontWeight: FontWeight.w700,
                                          color: CoverGradients.onCover)),
                                  const SizedBox(height: 2),
                                  Text(
                                    fmtMonthDayOfEpoch(trip.startEpochDay) +
                                        ' - ' +
                                        fmtMonthDayOfEpoch(trip.endEpochDay),
                                    style: TextStyle(
                                        fontSize: AppFontSizes.caption,
                                        color: CoverGradients.onCover.withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 团切换抽屉（右上角入口）：横滑团卡 + 管理入口
// ---------------------------------------------------------------------------

Future<void> _openGroupSwitcher(BuildContext context, WidgetRef ref) async {
  HapticFeedback.selectionClick();
  await showDraggableSheet<void>(
    context: context,
    initialChildSize: 0.58,
    builder: (sheetContext, scrollController) {
      final groups = ref.watch(groupsProvider).value ?? const <LedgerGroupView>[];
      final activeId = ref.watch(activeGroupIdProvider).value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('换个团记账', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text('选择要开始记账的旅行团',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Flexible(
            child: groups.isEmpty
                ? Center(
                    child: Text('还没有团，先新建一个吧', style: Theme.of(context).textTheme.bodySmall))
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, Spacing.xs),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
                    itemBuilder: (context, i) {
                      final g = groups[i];
                      final selected = g.id == activeId;
                      final scheme = Theme.of(context).colorScheme;
                      return Material(
                        color: selected
                            ? scheme.primaryContainer
                            : (scheme.brightness == Brightness.dark
                                ? scheme.surfaceContainerHigh
                                : scheme.surfaceContainerLowest),
                        borderRadius: AppRadius.input,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await activateGroup(ref, g.id);
                            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.input,
                              border: Border.all(
                                color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? scheme.primary.withValues(alpha: 0.18)
                                        : scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(AppRadius.buttonValue),
                                  ),
                                  child: Text(g.icon, style: const TextStyle(fontSize: 22)),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleSmall),
                                      const SizedBox(height: 2),
                                      Text(selected ? '当前使用中' : '轻点切换',
                                          style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xl + 84),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushNamed('group-list');
                    },
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: const Text('全部团'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushNamed('members');
                    },
                    icon: const Icon(Icons.people_alt_rounded, size: 18),
                    label: const Text('成员'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushNamed('group-edit');
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text('新建团'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 加载骨架
// ---------------------------------------------------------------------------

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      children: [
        SkeletonBox(height: 132, radius: AppRadius.cardValue),
        const SizedBox(height: Spacing.lg),
        SkeletonBox(height: 96, radius: AppRadius.cardValue),
        const SizedBox(height: Spacing.xl),
        SkeletonListTile(),
        SkeletonListTile(),
        SkeletonListTile(),
      ],
    );
  }
}
/// 超支横幅：error 色全宽卡片，点击跳预算页
class _OverBudgetBanner extends StatelessWidget {
  const _OverBudgetBanner({required this.budget});
  final BudgetStatusView budget;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      child: InkWell(
        onTap: () => context.pushNamed('budget'),
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onError, size: 22),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('预算已超支',
                        style: TextStyle(
                            color: scheme.onError,
                            fontWeight: FontWeight.w700,
                            fontSize: AppFontSizes.body)),
                    Text('已用 ¥${(budget.spentCents / 100).toStringAsFixed(2)} / 预算 ¥${(budget.totalCents / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                            color: scheme.onError.withValues(alpha: 0.9),
                            fontSize: AppFontSizes.caption)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onError),
            ],
          ),
        ),
      ),
    );
  }
}

/// 预算预警中心抽屉：列出当前激活团各级预警，支持全部标记已读。
void _showAlertCenter(BuildContext context, WidgetRef ref) {
  final active = ref.read(activeGroupProvider).value;
  final gid = active?.id;
  if (gid == null) return;
  if (ref.read(budgetAlertsEnabledProvider).value == false) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('预算预警已在“我的”里关闭，可在设置中重新开启')));
    return;
  }
  final alerts = ref.read(budgetAlertsProvider);
  if (alerts.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('暂无预警')));
    return;
  }
  HapticFeedback.selectionClick();
  showDraggableSheet(
    context: context,
    initialChildSize: 0.65,
    minChildSize: 0.4,
    builder: (ctx, scrollCtrl) => StatefulBuilder(builder: (sCtx, setSheet) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text('预算预警中心',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(prefsRepoProvider)
                      .setBudgetAlertSeenLevels(gid, {0, 1, 2});
                  if (sCtx.mounted) Navigator.of(sCtx).pop();
                },
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('全部已读'),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: ListView.builder(
                itemCount: alerts.length,
                itemBuilder: (_, i) {
                  final a = alerts[i];
                  final levelColors = {
                    BudgetAlertLevel.info: Theme.of(context).colorScheme.primary,
                    BudgetAlertLevel.warning: Theme.of(context).colorScheme.secondary,
                    BudgetAlertLevel.danger: Theme.of(context).colorScheme.error,
                  };
                  return Card(
                    margin: const EdgeInsets.only(bottom: Spacing.sm),
                    color: levelColors[a.level]!.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: Icon(
                        a.level == BudgetAlertLevel.info
                            ? Icons.info_outline_rounded
                            : a.level == BudgetAlertLevel.warning
                                ? Icons.warning_amber_rounded
                                : Icons.dangerous_rounded,
                        color: levelColors[a.level],
                      ),
                      title: Text(a.messageCn,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('使用 ${a.percent}%',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }),
  );
}
