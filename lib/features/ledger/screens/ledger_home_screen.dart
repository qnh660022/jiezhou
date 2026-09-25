
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../domain/budget_alert_engine.dart';
import '../../../domain/models.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/swipeable_bill_tile.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_access.dart';
import '../ledger_models.dart';
import '../observability_providers.dart' show conflictEntityIdsProvider;
import '../ledger_providers.dart';
import '../widgets/bill_detail_sheet.dart';
import '../widgets/ledger_toolbox_sheet.dart';
import '../widgets/conflict_badge.dart';
import '../widgets/category_icon_box.dart';
import '../widgets/count_up_text.dart';
import '../widgets/member_avatar.dart';
import '../widgets/stagger_in.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/sync_status_capsule.dart';
import 'inbox_sheets.dart';
import '../../../theme/app_icons.dart';

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
            // S7 E2：viewer 不渲染「快照合并」写入口（导出类只读操作保留）。
            Consumer(
              builder: (context, ref, _) {
                if (ref.watch(_canWriteActiveGroupProvider) != true) {
                  return const SizedBox.shrink();
                }
                return HeaderIconButton(
                  icon: Icons.wifi_tethering_rounded,
                  tooltip: '局域网同步（同 Wi-Fi 快照合并）',
                  onTap: () => context.pushNamed('lan-sync'),
                );
              },
            ),
            HeaderIconButton(
              icon: Icons.swap_horizontal_circle_rounded,
              // V2.9.0:用语统一 ——「旅行团」改「账本」。
              tooltip: '切换账本',
              onTap: () => _openGroupSwitcher(context, ref),
            ),
            HeaderIconButton(
              icon: Icons.group_add_rounded,
              tooltip: '新建账本',
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
            // 云同步状态小点：与头部按钮同行对齐（点按进同步中心）
            const Padding(
              padding: EdgeInsets.only(left: Spacing.sm),
              child: SyncStatusCapsule(),
            ),
            // S12.3：变更记录入口（仅 owner/editor 渲染，隐藏不置灰）。
            const _HeaderOverflowMenu(),
          ],
        ),
        Expanded(
          // V2.8.2 S6：骨架→内容 300ms 淡接 morph
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: groupAsync.when(
              loading: () => const _HomeSkeleton(key: ValueKey('home-skeleton')),
              // V2.9.0:错误态收口 ErrorState —— 提供真实可点的「重试」,
              // 不再提示「下拉重试」却无任何重试入口。
              error: (e, s) => KeyedSubtree(
                key: const ValueKey('home-error'),
                child: ErrorState(
                  onRetry: () => ref.invalidate(activeGroupProvider),
                  error: e,
                  stackTrace: s,
                ),
              ),
              data: (group) {
                if (group == null) {
                  return KeyedSubtree(
                    key: const ValueKey('home-empty'),
                    child: EmptyState(
                      icon: AppIcons.coins,
                      title: copy(CopyTokens.ledgerEmpty),
                      message: copy(CopyTokens.ledgerEmptyAction),
                      // V2.9.0:用语统一 ——「新建旅行团」→「新建账本」。
                      actionLabel: '新建账本',
                      onAction: () => context.pushNamed('group-edit'),
                    ),
                  );
                }
                return _LedgerBody(groupId: group.id);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// S7 · E2：当前激活团的写权限（UI 三态的唯一判据）
// ---------------------------------------------------------------------------

/// 当前激活团是否可写。
///
/// * 未知角色（`ledgerAccessProvider` 仍在加载 / 解析不出）→ **可写**：
///   云 RLS 才是最终屏障，误藏入口比误露入口更伤体验（§S7.1.4）。
/// * 无激活团 → false（此时页面走空态，无写入口）。
final _canWriteActiveGroupProvider = Provider<bool>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value ?? '';
  if (gid.isEmpty) return false;
  return (ref.watch(ledgerAccessProvider(gid)).value ?? LedgerAccess.owner)
      .canWrite;
});

/// 头部溢出菜单：变更记录入口（viewer 不渲染，§S12.3-3）。
class _HeaderOverflowMenu extends ConsumerWidget {
  const _HeaderOverflowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(_canWriteActiveGroupProvider) != true) {
      return const SizedBox.shrink();
    }
    // V2.8.1 S7：头部溢出菜单唯一项改为「工具箱」入口（L3 抽屉收纳低频功能）。
    return HeaderIconButton(
      icon: Icons.apps_rounded,
      tooltip: '工具箱',
      onTap: () => showLedgerToolbox(context),
    );
  }
}

/// V2.8.1 S7：Hero 卡语义 chip（12% 底 + 语义色）。
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 消费入口快捷行（原「消费」Tab 并入账本后的门面）
// ---------------------------------------------------------------------------

class _QuickActions extends ConsumerWidget {
  const _QuickActions({
    required this.unsettled,
    this.personal = false,
    this.inboxCount = 0,
    this.hasFund = false,
    this.canWrite = true,
  });

  final int unsettled;

  /// S4：个人账本隐藏 AA 结算与公费池入口。
  final bool personal;

  /// S10：待归类条数（快速记入口徽章）。
  final int inboxCount;

  /// S8：存在未关闭公款池时才显示入口（仅旅行账本）。
  final bool hasFund;

  /// S7 E2：viewer 隐藏全部写入口（AA 结算 / 公费池 / 快速记），
  /// 「全部账单」「统计图表」属只读操作，保留。
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <Widget>[
      _ActionTile(
        icon: Icons.receipt_long_rounded,
        label: '全部账单',
        onTap: () => context.push('/expenses'),
      ),
      _ActionTile(
        icon: Icons.donut_small_rounded,
        label: '统计图表',
        onTap: () => context.push('/expenses/stats'),
      ),
      if (canWrite && !personal)
        _ActionTile(
          icon: Icons.balance_rounded,
          label: 'AA 结算',
          badgeCount: unsettled > 0 ? unsettled : null,
          onTap: () => context.push('/expenses/settle'),
        ),
      if (canWrite && !personal && hasFund)
        _ActionTile(
          icon: Icons.savings_rounded,
          label: '公费池',
          onTap: () => context.push('/expenses/fund'),
        ),
      if (canWrite)
        _ActionTile(
          icon: Icons.bolt_rounded,
          label: '快速记',
          badgeCount: inboxCount > 0 ? inboxCount : null,
          onTap: () => context.push('/expenses/inbox'),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - Spacing.sm) / 2;
          return Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [for (final t in tiles) SizedBox(width: w, child: t)],
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // V2.8.1 S11：首页瓦片接 PressableScale（按压缩放微交互）
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        child: InkWell(
          borderRadius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badgeCount != null,
                  label: Text('$badgeCount'),
                  child: Icon(icon, size: 26, color: scheme.primary),
                ),
                const SizedBox(height: Spacing.xs),
                Text(label, style: TextStyle(fontSize: AppFontSizes.caption)),
              ],
            ),
          ),
        ),
      ),
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
    // S4：个人账本分流渲染（隐藏余额板 / AA 结算 / 公费池，保留预算与账单）。
    final isPersonal = ref.watch(activeGroupProvider).value?.isPersonal ?? false;
    // S10：待归类徽章；S8：存在未关闭公款池时才显示入口。
    final inboxCount = ref.watch(pendingInboxCountProvider).value ?? 0;
    final hasFund = ref.watch(openFundProvider).value != null;
    // S7 E2：权限三态（viewer=只读）。未知角色按可写处理，RLS 兜底。
    final access =
        ref.watch(ledgerAccessProvider(groupId)).value ?? LedgerAccess.owner;

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
            padding: EdgeInsets.only(
              bottom: AppBottomLayout.withSafeArea(
                context,
                AppBottomLayout.contentTail,
              ),
            ),
            children: [
              if (showOverBudgetBanner)
                StaggerIn(index: 0, child: _OverBudgetBanner(budget: budget)),
              StaggerIn(index: showOverBudgetBanner ? 1 : 0, child: _GlassGroupCard(group: _currentGroup(ref, groupId), members: members, unsettled: unsettled, budgetPercent: budget.enabled ? budget.percent.toInt() : null, overBudget: showOverBudgetBanner, conflictCount: ref.watch(conflictEntityIdsProvider).value?.length ?? 0)),
              // S12.2：未确认冲突总数（本地计数；无冲突时不占位）。
              const ConflictCountChip(),
              StaggerIn(index: showOverBudgetBanner ? 2 : 1, child: _BudgetCard(budget: budget, canEdit: access.canWrite)),
              StaggerIn(
                index: 2,
                child: _QuickActions(
                  unsettled: unsettled,
                  personal: isPersonal,
                  inboxCount: inboxCount,
                  hasFund: hasFund,
                  canWrite: access.canWrite,
                ),
              ),
              if (!isPersonal)
                StaggerIn(
                  index: 3,
                  child: _BalanceBoard(
                    board: board,
                    // S7.1.3：viewer 不渲染成员管理写入口。
                    onManageMembers: access.canManage
                        ? () => context.pushNamed('members')
                        : null,
                  ),
                ),
              if (isPersonal && expenses.isEmpty)
                const StaggerIn(
                  index: 3,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
                    child: EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: '记下自己的每一笔',
                      message: '个人账本不用选付款人与分摊，点下面按钮直接开记。',
                    ),
                  ),
                ),
              StaggerIn(index: 4, child: _RecentBills(expenses: recentExpenses.take(5).toList(), members: members, canEdit: access.canWrite)),
              if (trips.isNotEmpty)
                StaggerIn(index: 5, child: _LinkedTrips(trips: trips.where((t) => !t.archived).toList())),
            ],
          ),
        ),
        // S7.1.3：viewer 不渲染「记一笔」FAB（隐藏不置灰）。
        if (access.canWrite)
          Positioned(
            right: Spacing.xl,
            bottom: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.actionButtonOffset,
            ),
            child: GestureDetector(
              // S10 双入口保底：FAB 长按 → 快速记（只填金额）；点按 → 常规记一笔。
              onLongPress: () {
                HapticFeedback.mediumImpact();
                showCaptureInboxSheet(context, ref, groupId);
              },
              child: FloatingActionButton.extended(
                heroTag: 'fab-ledger-add',
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/expenses/edit');
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('记一笔'),
              ),
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
    // V2.9.0:用语统一 —— 兜底名「旅行团」→「账本」。
    return LedgerGroupView(id: groupId, name: '账本', icon: '🧭', budgetEnabled: false);
  }
}

// ---------------------------------------------------------------------------
// 顶部玻璃当前团卡
// ---------------------------------------------------------------------------

class _GlassGroupCard extends StatelessWidget {
  const _GlassGroupCard({
    required this.group,
    required this.members,
    required this.unsettled,
    this.budgetPercent,
    this.overBudget = false,
    this.conflictCount = 0,
  });

  final LedgerGroupView group;
  final List<LedgerMemberView> members;
  final int unsettled;

  /// V2.8.1 S7：语义 chip 数据（预算 68% / 冲突 N / 超支态）。
  final int? budgetPercent;
  final bool overBudget;
  final int conflictCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      // V2.8.1 S2：手写 σ18 毛玻璃收编为 GlassSurface(floatingCard)。
      child: GlassSurface(
        level: GlassLevel.floatingCard,
        child: Container(
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            // V2.8.3.1：去双层 tint —— 移除 surfaceContainerLow 半透明层
            //（与玻璃 tint 同源叠加导致发灰），仅保留语义色柔光
            //（超支=error / 正常=primary，Apple「策略性 tint」用法）。
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: overBudget
                  ? [
                      scheme.error.withValues(alpha: 0.10),
                      scheme.error.withValues(alpha: 0.04),
                    ]
                  : [
                      scheme.primary.withValues(alpha: 0.10),
                      scheme.primary.withValues(alpha: 0.03),
                    ],
            ),
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // V2.8.1 S7：超支态顶部 4px 警示条
                if (overBudget)
                  Container(
                    height: 4,
                    margin: const EdgeInsets.only(bottom: Spacing.md),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                // V2.8.1 S7：三枚语义 chip（未结 N 笔→结算 / 冲突 N→审计 / 预算 68%→预算页）
                if (unsettled > 0 || conflictCount > 0 || budgetPercent != null) ...[
                  const SizedBox(height: Spacing.md),
                  Row(
                    children: [
                      if (unsettled > 0)
                        _HeroChip(
                          label: '未结 $unsettled 笔',
                          color: scheme.secondary,
                          onTap: () => context.push('/expenses/settle'),
                        ),
                      if (conflictCount > 0) ...[
                        const SizedBox(width: Spacing.sm),
                        _HeroChip(
                          label: '冲突 $conflictCount',
                          color: scheme.error,
                          onTap: () => context.pushNamed('audit-log'),
                        ),
                      ],
                      if (budgetPercent != null) ...[
                        const SizedBox(width: Spacing.sm),
                        _HeroChip(
                          label: '预算 $budgetPercent%',
                          color: (budgetPercent ?? 0) >= 80 ? scheme.error : scheme.primary,
                          // V2.9.0:修复未注册路径 /ledger/budget —— 改按路由名跳转。
                          onTap: () => context.pushNamed('budget'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
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
        context.push('/expenses/settle');
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
            // V2.9.0:清理透明 chevron 占位 hack —— 用定宽间距替代。
            const SizedBox(width: 10),
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
  const _BudgetCard({required this.budget, this.canEdit = true});

  final BudgetStatusView budget;

  /// S7.1.3：viewer 隐藏预算设置编辑入口（数值照常可查看，不做灰化）。
  final bool canEdit;

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
          onTap: canEdit
              ? () {
                  HapticFeedback.selectionClick();
                  context.push('/expenses/budget');
                }
              : null,
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
                                  // V2.9.0:金额展示收敛 MoneyFormat。
                                  formatter: (v) => MoneyFormat.display(v),
                                  style: AppTextStyles.money(context,
                                      fontSize: AppFontSizes.title,
                                      color: over ? scheme.error : scheme.onSurface),
                                ),
                                const SizedBox(width: 4),
                                Text('/ ' + MoneyFormat.display(budget.totalCents),
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              over ? '超支 ' + MoneyFormat.display(-budget.remainingCents)
                                   : '还剩 ' + MoneyFormat.display(budget.remainingCents),
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

// V2.9.0:本地 formatMoneyForDisplay/_fmtAbs 退役,金额展示统一走 MoneyFormat。

// ---------------------------------------------------------------------------
// 成员余额榜
// ---------------------------------------------------------------------------

class _BalanceBoard extends StatelessWidget {
  const _BalanceBoard({required this.board, this.onManageMembers});

  final List<MemberStatView> board;

  /// S7.1.3：viewer 传 null → 「管理成员」写入口整块不渲染。
  final VoidCallback? onManageMembers;

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final manage = onManageMembers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerSectionTitle(
          title: '谁付了多少',
          trailing: manage == null
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    manage();
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
  const _RecentBills({
    required this.expenses,
    required this.members,
    this.canEdit = true,
  });

  final List<ExpenseRecord> expenses;
  final List<LedgerMemberView> members;

  /// S7.1.3：viewer 时不给行挂 Dismissible（滑动编辑/删除入口整体不挂载）。
  final bool canEdit;

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
                  StaggerIn(
                      index: i,
                      child: _BillTile(
                        expense: expenses[i],
                        members: members,
                        canEdit: canEdit,
                      )),
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
        icon: AppIcons.wallet,
        title: '还没记过账',
        message: '点右下角「记一笔」，旅途中的每笔开销都算得明明白白',
      ),
    );
  }
}

class _BillTile extends ConsumerStatefulWidget {
  const _BillTile({
    required this.expense,
    required this.members,
    this.canEdit = true,
  });

  final ExpenseRecord expense;
  final List<LedgerMemberView> members;

  /// S7.1.3：viewer 不挂 Dismissible（无滑动编辑/删除）。
  final bool canEdit;

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
    context.push('/expenses/edit?id=' + widget.expense.id);
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.lightImpact();
    final e = widget.expense;
    // V2.8.1 S6：删除确认统一走 L2 危险确认（含数量行）
    final ok = await showDangerConfirm(
      context: context,
      title: '删除这笔账单？',
      body: '删除「${e.title}」？共 1 笔，不可恢复，云端共享成员都会看到删除记录。',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    setState(() => _closing = true);
    await deleteExpense(ref, widget.expense.id);
    if (mounted) showAppSnackBar(context, '已删除');
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
                        // S12.2：该行存在未确认冲突时显示小标记（仅提示，不回选）。
                        ConflictDot(entityId: e.id),
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
              // 退款显示为正（拿回的钱），逻辑层统一按负数参与统计/结算
              MoneyText(
                isRefund ? -e.amountCents : e.amountCents,
                fontSize: AppFontSizes.bodyLarge,
                semanticColor: true,
              ),
            ],
          ),
        ),
      ),
    );

    // S7.1.3：viewer 只读态 —— 整块滑动动作（编辑/删除）不挂载。
    // V2.8.1 S6：手势语言统一 —— 首页最近账单与明细页共用 SwipeableBillTile。
    if (!widget.canEdit) return tile;

    return SwipeableBillTile(
      onEdit: _openEdit,
      onDelete: _confirmDelete,
      child: tile,
    );
  }

  String _firstPayerId(ExpenseRecord e) => e.payers.isEmpty ? '' : e.payers.first.memberId;
}

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
                Text('换个账本记账', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                // V2.9.0:用语统一 ——「旅行团」改「账本」。
                Text('选择要开始记账的账本',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          // V2.9.0:去重 —— 移除「全部旅行团」按钮(与抽屉底部「全部」同目标,
          // 双入口同目标,按工单保留底部入口)。
          Flexible(
            child: groups.isEmpty
                ? Center(
                    child: Text('还没有账本，先新建一个吧', style: Theme.of(context).textTheme.bodySmall))
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
            // V2.9.0:底部硬编码 Spacing.xl+84 让位改用 AppBottomLayout.navBarHeight
            // (悬浮胶囊底栏自身高度,不含安全区)。
            padding: EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xl + AppBottomLayout.navBarHeight),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushNamed('group-list');
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.list_alt_rounded, size: 17),
                        SizedBox(width: 4),
                        Flexible(child: Text('全部', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushNamed('members');
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_rounded, size: 17),
                        SizedBox(width: 4),
                        Flexible(child: Text('成员', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushNamed('group-edit');
                    },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 17),
                        SizedBox(width: 4),
                        Flexible(child: Text('新建', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
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
  const _HomeSkeleton({super.key});

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
                    Text('已用 ' + MoneyFormat.display(budget.spentCents) + ' / 预算 ' + MoneyFormat.display(budget.totalCents),
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
    // V2.8.1 S1：预警关闭时点铃铛 → L3 抽屉空态卡（替代 SnackBar），
    // 「去开启」跳「我的」页——预算预警开关实际位于该页（偏差登记：规格书原文为跳预算页）。
    HapticFeedback.selectionClick();
    showDraggableSheet(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.3,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.card,
              ),
              child: Column(
                children: [
                  Icon(Icons.notifications_off_rounded,
                      size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: Spacing.md),
                  Text('预警已关闭',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: Spacing.xs),
                  Text('打开后在超支或接近预算上限时，账本页会提醒你',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: Spacing.lg),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/profile');
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('去开启'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return;
  }
  final alerts = ref.read(budgetAlertsProvider);
  if (alerts.isEmpty) {
    showAppSnackBar(context, '暂无预警');
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
