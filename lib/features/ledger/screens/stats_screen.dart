import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/count_up_text.dart';
import '../widgets/member_avatar.dart';

/// 📊 消费统计：预算环 + 分类圆盘 + 每日趋势 + 成员排行。
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetStatusProvider);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final dailyAsync = ref.watch(dailyTotalsProvider);
    final boardAsync = ref.watch(memberBoardProvider);

    return Scaffold(
      appBar: GlassAppBar(title: '统计'),
      body: budgetAsync.isLoading || breakdownAsync.isLoading || dailyAsync.isLoading || boardAsync.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (breakdownAsync.value ?? const <CategoryShareView>[]).isEmpty
              ? const EmptyState(
                  emoji: '📊',
                  title: '还没有可统计的数据',
                  message: '记下第一笔，图表马上就有内容了',
                )
              : ListView(
                  // 底部留白统一 120：分支子页同样被悬浮胶囊底栏覆盖，32 不够
                  padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md,
                      Spacing.xl, Spacing.huge * 2 + Spacing.xxl),
                  children: [
                    StaggeredSection(
                      index: 0,
                      child: _BudgetHero(
                        budget: budgetAsync.value ??
                            const BudgetStatusView(
                                enabled: false,
                                totalCents: 0,
                                spentCents: 0,
                                remainingCents: 0,
                                percent: 0),
                      ),
                    ),
                    StaggeredSection(index: 1, child: _CategoryPie(breakdown: breakdownAsync.value!)),
                    StaggeredSection(index: 2, child: _DailyBars(daily: dailyAsync.value ?? const <DailyTotalView>[])),
                    StaggeredSection(index: 3, child: _MemberRanking(board: boardAsync.value ?? const <MemberStatView>[])),
                    StaggeredSection(index: 4, child: const _PrepayNote()),
                  ],
                ),
    );
  }
}

/// 区块入场（复用 stagger 节奏，但独立实现避免依赖屏幕私有组件）
class StaggeredSection extends StatefulWidget {
  const StaggeredSection({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggeredSection> createState() => _StaggeredSectionState();
}

class _StaggeredSectionState extends State<StaggeredSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      (widget.index * 0.06).clamp(0.0, 0.6),
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(_animation),
        child: Padding(
          padding: const EdgeInsets.only(bottom: Spacing.lg),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 预算 Hero 环
// ---------------------------------------------------------------------------

class _BudgetHero extends StatelessWidget {
  const _BudgetHero({required this.budget});

  final BudgetStatusView budget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = budget.enabled && budget.totalCents > 0;
    final over = budget.overBudget;
    final ringColor = over ? scheme.error : scheme.primary;

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: over ? 0 : 0.10),
            scheme.primary.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: enabled ? budget.percent : 0,
            size: 96,
            strokeWidth: 9,
            color: ringColor,
            child: CountUpText(
              value: enabled ? (budget.percent * 100).round() : 0,
              formatter: (v) => v.toString() + '%',
              style: AppTextStyles.money(context, fontSize: AppFontSizes.bodyLarge),
            ),
          ),
          const SizedBox(width: Spacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(enabled ? (over ? '预算已超支' : '预算还稳') : '未开启预算',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('总支出 ¥' + _yuan(budget.spentCents),
                    style: Theme.of(context).textTheme.bodySmall),
                if (enabled)
                  Text(
                    over
                        ? '超出 ¥' + _yuan(-budget.remainingCents)
                        : '剩余 ¥' + _yuan(budget.remainingCents),
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: over ? scheme.error : scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _yuan(int cents) =>
      (cents ~/ 100).toString() + '.' + (cents % 100).toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// 分类占比圆盘
// ---------------------------------------------------------------------------

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.breakdown});

  final List<CategoryShareView> breakdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sections = <PieChartSectionData>[
      for (final row in breakdown.take(8))
        PieChartSectionData(
          value: row.cents.toDouble().clamp(1, double.infinity),
          color: AvatarPalette.colorForName(row.category.key),
          radius: 46,
          showTitle: false,
        ),
    ];

    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('钱都花在哪儿', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: PieChart(PieChartData(
                      sections: sections,
                      centerSpaceRadius: 34,
                      sectionsSpace: 2,
                    )),
                  ),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final row in breakdown.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AvatarPalette.colorForName(row.category.key),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(row.category.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelMedium),
                                ),
                                Text((row.fraction * 100).toStringAsFixed(0) + '%',
                                    style: Theme.of(context).textTheme.labelSmall),
                              ],
                            ),
                          ),
                      ],
                    ),
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
// 每日趋势渐变柱
// ---------------------------------------------------------------------------

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});

  final List<DailyTotalView> daily;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = daily.length <= 14 ? daily : daily.sublist(daily.length - 14);
    final maxCents = shown.fold<int>(1, (m, d) => d.cents > m ? d.cents : m);

    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近每天花多少', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              height: 140,
              child: shown.isEmpty
                  ? Center(child: Text('暂无数据', style: Theme.of(context).textTheme.bodySmall))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxCents * 1.15,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= shown.length) return const SizedBox.shrink();
                                final d = epochDayToDate(shown[idx].epochDay);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(d.day.toString(),
                                      style: TextStyle(
                                          fontSize: 10, color: scheme.onSurfaceVariant)),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < shown.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: shown[i].cents.toDouble(),
                                  width: 10,
                                  borderRadius: BorderRadius.circular(5),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      scheme.primary.withValues(alpha: 0.45),
                                      scheme.primary,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 成员排行：paid / share / balance 三分段切换
// ---------------------------------------------------------------------------

class _MemberRanking extends StatefulWidget {
  const _MemberRanking({required this.board});

  final List<MemberStatView> board;

  @override
  State<_MemberRanking> createState() => _MemberRankingState();
}

class _MemberRankingState extends State<_MemberRanking> {
  int _metric = 2; // 默认按 balance

  static const _labels = ['垫付', '应摊', '结余'];

  int _valueOf(MemberStatView r) {
    switch (_metric) {
      case 0:
        return r.paidCents;
      case 1:
        return r.shareCents;
      default:
        return r.balanceCents;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = [...widget.board]..sort((a, b) => _valueOf(b) - _valueOf(a));
    final maxAbs = rows.fold<int>(1, (m, r) {
      final v = _valueOf(r).abs();
      return v > m ? v : m;
    });

    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('成员排行', style: Theme.of(context).textTheme.titleMedium)),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: [
                    for (var i = 0; i < _labels.length; i++)
                      ButtonSegment(value: i, label: Text(_labels[i])),
                  ],
                  selected: {_metric},
                  onSelectionChanged: (selection) {
                    HapticFeedback.selectionClick();
                    setState(() => _metric = selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: Row(
                  children: [
                    MemberAvatar(member: row.member, size: 30),
                    const SizedBox(width: Spacing.sm),
                    SizedBox(
                      width: 52,
                      child: Text(row.member.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: _valueOf(row).abs() / maxAbs),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => LinearProgressIndicator(
                            value: t.clamp(0.02, 1.0),
                            minHeight: 8,
                            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                            color: _valueOf(row) >= 0 ? scheme.primary : scheme.error,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    SizedBox(
                      width: 84,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: MoneyText(
                          _metric == 2 ? row.balanceCents : _valueOf(row),
                          fontSize: AppFontSizes.caption,
                          showSign: _metric == 2,
                          semanticColor: _metric == 2,
                        ),
                      ),
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

/// 预付款合计说明卡
class _PrepayNote extends ConsumerWidget {
  const _PrepayNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    var prepay = 0;
    for (final e in expenses) {
      if (e.type == ExpenseType.prepay) prepay += e.amountCents;
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.08),
        borderRadius: AppRadius.input,
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Text('🛫', style: TextStyle(fontSize: 20)),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text('预付款合计（不计入日常支出）',
                style: Theme.of(context).textTheme.labelMedium),
          ),
          MoneyText(prepay,
              fontSize: AppFontSizes.bodyLarge, color: scheme.secondary),
        ],
      ),
    );
  }
}
