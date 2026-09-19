// 今日花销详情页（V2.6.6.2 §8.3 / D3，路由 `/today/:tripId/spend`）。
//
// 结构：类目分布环图（中心总金额大字）+ 当日流水列表（大额置顶）+ 顶部「记一笔」。
//
// 硬约束：
// * 金额一律 int 分，只在展示层格式化；退款为负数（全局约定，见 core/money.dart）；
// * 图表配色只用当前 ColorScheme 的离散档位轮转，禁止彩虹渐变；
// * 每行点击跳账本明细 `/expenses`；无关联账本时给引导而不是空图。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../theme/tokens.dart';
import '../../ledger/ledger_models.dart';
import '../../ledger/ledger_providers.dart';
import '../../ledger/widgets/category_icon_box.dart';
import '../today_providers.dart';
import '../widgets/money_hero_text.dart';
import '../widgets/today_surface.dart';
import '../../../theme/app_icons.dart';

/// 今日花销详情：类目分布 + 流水。
class TodaySpendScreen extends ConsumerStatefulWidget {
  const TodaySpendScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TodaySpendScreen> createState() => _TodaySpendScreenState();
}

class _TodaySpendScreenState extends ConsumerState<TodaySpendScreen> {
  /// 直达记账页（带当日 epochDay），返回后兜底刷新一次花销流。
  Future<void> _addExpense(int epochDay) async {
    HapticFeedback.lightImpact();
    final groupId =
        ref.read(todaySpendProvider((widget.tripId, epochDay)))?.groupId;
    await context.push('/expenses/edit?date=$epochDay');
    // provider 是流式的，通常自动刷新；这里兜底 invalidate，避免个别情况滞后。
    if (mounted && groupId != null) {
      ref.invalidate(groupExpensesProvider(groupId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scope = ref.watch(todayScopeProvider(widget.tripId));
    final tripName =
        ref.watch(tripSpansWithGroupProvider).value?[widget.tripId]?.name ??
            '今日';

    if (scope == null) {
      return Scaffold(
        appBar: GlassAppBar(title: tripName),
        body: const EmptyState(
          icon: AppIcons.compass,
          title: '行程不存在或已删除',
          message: '回到行程列表重新看看',
        ),
      );
    }

    final epochDay = scope.tripTodayEpochDay;
    final summary =
        ref.watch(todaySpendProvider((widget.tripId, epochDay)));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: GlassAppBar(
        title: '今日花销',
        actions: [
          TextButton.icon(
            onPressed: () => _addExpense(epochDay),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('记一笔'),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: summary == null
          ? const Center(child: CircularProgressIndicator())
          : !summary.hasLedger
              ? EmptyState(
                  icon: Icons.link_rounded,
                  title: '关联账本后可用',
                  message: '把这趟行程挂到一本账本上，今日花销与预算余量自动汇总。',
                  actionLabel: '去关联账本',
                  onAction: () => context.pushNamed('group-edit'),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: Spacing.xxxl),
                  children: [
                    _SpendTotalCard(summary: summary),
                    if (summary.rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: Spacing.xl),
                        child: EmptyState(
                          icon: AppIcons.wallet,
                          title: '今天还没有记账',
                          message: '旅途中的每笔开销都记下来，回看不心虚',
                        ),
                      )
                    else ...[
                      _CategoryChartCard(summary: summary),
                      _BillListCard(
                        summary: summary,
                        onTapRow: () {
                          HapticFeedback.selectionClick();
                          context.push('/expenses');
                        },
                      ),
                    ],
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// 合计（大数字 + 预算余量）
// ---------------------------------------------------------------------------

class _SpendTotalCard extends StatelessWidget {
  const _SpendTotalCard({required this.summary});

  final TodaySpendSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remain = summary.remainingCents;
    final progress = summary.budgetProgress;
    final over = progress != null && progress > 1.0;

    return TodaySurface(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TodayCardTitle(
            title: summary.groupName == null
                ? '今日合计'
                : '今日合计 · ${summary.groupName}',
          ),
          const SizedBox(height: Spacing.sm),
          MoneyHeroText(summary.totalCents, fontSize: AppFontSizes.display),
          const SizedBox(height: Spacing.sm),
          if (remain != null)
            Text(
              over
                  ? '已超支 ${MoneyFormat.display(-remain)}'
                  : '预算余量 ${MoneyFormat.display(remain)}',
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                color: over ? scheme.error : scheme.onSurfaceVariant,
              ),
            )
          else
            Text('本账本未设预算', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 类目分布环图（中心总金额大字；配色只用 scheme 离散档位轮转）
// ---------------------------------------------------------------------------

/// 类目聚合行（图例 + 扇区共用）。
class _CategorySlice {
  const _CategorySlice({
    required this.key,
    required this.name,
    required this.cents,
    required this.color,
  });

  final String key;
  final String name;
  final int cents;
  final Color color;
}

class _CategoryChartCard extends ConsumerWidget {
  const _CategoryChartCard({required this.summary});

  final TodaySpendSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryView>[];

    // 分类轮转色板：主题 Scheme 的离散档位（禁止彩虹渐变/硬编码色值）。
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
    ];

    // 按类目聚合（退款为负，聚合成负的类目不进环图，只在流水里体现）。
    final sums = <String, int>{};
    for (final row in summary.rows) {
      sums[row.categoryKey] = (sums[row.categoryKey] ?? 0) + row.amountCents;
    }
    final entries = sums.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final slices = <_CategorySlice>[
      for (var i = 0; i < entries.length; i++)
        _CategorySlice(
          key: entries[i].key,
          name: _categoryName(categories, entries[i].key),
          cents: entries[i].value,
          color: palette[i % palette.length],
        ),
    ];
    final positiveTotal = slices.fold<int>(0, (sum, s) => sum + s.cents);

    if (slices.isEmpty) return const SizedBox.shrink();

    return TodaySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TodayCardTitle(title: '类目分布'),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: [
                          for (final s in slices)
                            PieChartSectionData(
                              value: s.cents.toDouble(),
                              color: s.color,
                              radius: 42,
                              showTitle: false,
                            ),
                        ],
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                    // 环心：今日合计大字
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '合计',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        MoneyHeroText(
                          summary.totalCents,
                          fontSize: AppFontSizes.bodyLarge,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in slices.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Text(
                              '${(s.cents / positiveTotal * 100).round()}%',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryName(List<CategoryView> categories, String key) {
    for (final c in categories) {
      if (c.key == key) return c.name;
    }
    return key;
  }
}

// ---------------------------------------------------------------------------
// 当日流水（大额置顶，provider 已按绝对值排序）
// ---------------------------------------------------------------------------

class _BillListCard extends ConsumerWidget {
  const _BillListCard({required this.summary, required this.onTapRow});

  final TodaySpendSummary summary;
  final VoidCallback onTapRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryView>[];

    return TodaySurface(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: Spacing.xs),
            child: TodayCardTitle(title: '今日流水 · 大额置顶'),
          ),
          const SizedBox(height: Spacing.sm),
          for (var i = 0; i < summary.rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0.8,
                thickness: 0.8,
                indent: 56,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            _BillRow(
              row: summary.rows[i],
              icon: _iconOf(categories, summary.rows[i].categoryKey),
              onTap: onTapRow,
            ),
          ],
        ],
      ),
    );
  }

  String _iconOf(List<CategoryView> categories, String key) {
    for (final c in categories) {
      if (c.key == key) return c.icon;
    }
    return '🏷️';
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.row,
    required this.icon,
    required this.onTap,
  });

  final TodaySpendRow row;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = row.type == 'refund';
    // 退款行显示「拿回的钱」为正数（取绝对值，兼容两种落库符号口径）；
    // 合计仍旧走 todaySpendCents 的带符号口径，不在展示层重复计算。
    final shown = isRefund ? row.amountCents.abs() : row.amountCents;

    return InkWell(
      borderRadius: AppRadius.input,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs, vertical: Spacing.md),
        child: Row(
          children: [
            CategoryIconBox(
              categoryKey: row.categoryKey,
              icon: icon,
              size: 38,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.title.isEmpty ? '未命名' : row.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (isRefund) ...[
                        const SizedBox(width: 6),
                        ExpenseTypeChip(
                          label: '退款',
                          background: scheme.errorContainer,
                          foreground: scheme.error,
                        ),
                      ] else if (row.type == 'prepay') ...[
                        const SizedBox(width: 6),
                        ExpenseTypeChip(
                          label: '预付',
                          background:
                              scheme.secondary.withValues(alpha: 0.14),
                          foreground: scheme.secondary,
                        ),
                      ],
                    ],
                  ),
                  if (row.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      row.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            MoneyText(
              shown,
              fontSize: AppFontSizes.bodyLarge,
              semanticColor: true,
            ),
          ],
        ),
      ),
    );
  }
}
