// 「今日」智能置顶卡（V2.6.6.2 §8.1 / D1；2026-09-13 二次调整）。
//
// 位置与形态（用户反馈）：行程页列表**最底部**（攻略卡上方），与攻略卡
// 同一规格（共用 SectionCard）：扁宽单行卡 —— 左语义图标 + 两行文字
// （行程名·今日徽标 / 天数·安排·花销）+ 右箭头，不再用大卡+统计胶囊。
//
// 口径与数据全部来自地基（today_scope / today_providers），本文件只做展示：
// * 无进行中行程 → **不渲染**（`SizedBox.shrink()`，不是置灰）——§8.1 明确要求；
// * 点击进全屏驾驶舱 `/today/:tripId`。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../theme/tokens.dart';
import '../../trips/trip_widgets.dart' show SectionCard;
import '../today_providers.dart';
import '../today_scope.dart';

/// 行程页底部「今日」行卡：只在有进行中行程时出现。
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
    final hasLedger = spend?.hasLedger ?? false;
    final spendText = hasLedger ? MoneyFormat.display(spend!.totalCents) : '未关联';

    final sub = '第 ${scope.dayIndex} 天 / 共 ${scope.totalDays} 天'
        ' · 安排 $doneCount/${items.length}'
        ' · 花销 $spendText'
        '${pick.othersCount > 0 ? ' · 另有 ${pick.othersCount} 个进行中' : ''}';

    // 形态与攻略入口卡（_GuideEntryCard）完全同规格：扁宽单行 SectionCard。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md),
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : null,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/today/${trip.id}');
          },
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Spacing.md),
              ),
              child:
                  Icon(Icons.near_me_rounded, size: 19, color: scheme.primary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(trip.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppFontSizes.bodyLarge,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                      ),
                      const SizedBox(width: Spacing.sm),
                      const _TodayBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSizes.caption - 1,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

/// 「今日」小胶囊：强调这是智能置顶的时间敏感入口。
class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
