// 首页「今日」智能置顶卡（V2.6.6.2 §8.1 / D1）。
//
// 口径与数据全部来自地基（today_scope / today_providers），本文件只做展示：
// * 无进行中行程 → **不渲染**（`SizedBox.shrink()`，不是置灰）——§8.1 明确要求；
// * 摘要 = 行程名 + 第 N 天/共 M 天 + 今日安排（已完成/总数）+ 今日花销；
// * 多行程同时进行时补一句「另有 N 个行程进行中」；
// * 点击进全屏驾驶舱 `/today/:tripId`。
//
// 视觉：芥舟语言（tokens 大圆角 24 + 表面层色 + 主题色描边柔光），
// 不自造毛玻璃（玻璃面仅 glass_app_bar / SheetSurface 两条既有路径）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../../theme/tokens.dart';
import '../today_providers.dart';
import '../today_scope.dart';

/// 首页顶部智能置顶卡：只在有进行中行程时出现。
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pick = ref.watch(activeTripPickProvider);
    // 无进行中行程：整卡不渲染（§8.1）。
    if (pick == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final trip = pick.trip;
    // 行程今日口径：正常由 tripSpansProvider 派生；数据未就绪时用纯函数兜底，
    // 保证卡片不会因为流的第一帧为空而闪断。
    final scope =
        ref.watch(todayScopeProvider(trip.id)) ?? resolveTodayScope(trip: trip);
    final day = scope.tripTodayEpochDay;

    final rawItems =
        ref.watch(todayItemRecordsProvider((trip.id, day))).value ??
            const <TripItem>[];
    final items = todayItemsByDay<TripItem>(
      rawItems,
      day,
      (i) => i.dateEpochDay,
      (i) => i.startTimeMin,
      sortOrderOf: (i) => i.sortOrder,
    );
    final doneIds = ref.watch(todayDoneIdsProvider((trip.id, day)));
    final doneCount = items.where((i) => doneIds.contains(i.id)).length;
    final spend = ref.watch(todaySpendProvider((trip.id, day)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      child: Material(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/today/${trip.id}');
          },
          child: Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.22), width: 1),
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
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(AppRadius.inputValue),
                      ),
                      child: Icon(Icons.near_me_rounded,
                          size: 23, color: scheme.primary),
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
                                  trip.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              _TodayBadge(scheme: scheme),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '第 ${scope.dayIndex} 天 / 共 ${scope.totalDays} 天'
                            '${trip.destination.isEmpty ? '' : ' · ${trip.destination}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                // 用 Wrap 而不是 Row：窄屏（360dp）下两个 StatChip 会横向溢出
                // （golden 测试实测 RenderFlex overflow），Wrap 会自动换行。
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    StatChip(
                      emoji: '🗓️',
                      label: '今日安排',
                      value: items.isEmpty ? '无安排' : '$doneCount/${items.length}',
                    ),
                    StatChip(
                      emoji: '💰',
                      label: '今日花销',
                      value: (spend?.hasLedger ?? false)
                          ? MoneyFormat.display(spend!.totalCents)
                          : '未关联',
                      valueColor: (spend?.hasLedger ?? false)
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (pick.othersCount > 0) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '另有 ${pick.othersCount} 个行程进行中',
                    style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「今日」小胶囊：强调这是智能置顶的时间敏感入口。
class _TodayBadge extends StatelessWidget {
  const _TodayBadge({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: AppRadius.capsule,
      ),
      child: Text(
        '今日',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}
