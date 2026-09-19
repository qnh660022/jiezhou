// 今日安排详情页（V2.6.6.2 §8.3 / D3，路由 `/today/:tripId/plan`）。
//
// 口径：
// * 当日行程项取 `todayItemsByDay` —— 有时间的按时间升序，无时间的排末尾；
// * 完成勾选**只存本地**（todayLocalStore，按 tripId+当地日期+itemId），不上云；
// * 点行 → 只读跳 `ItemDetailScreen`（MaterialPageRoute），不传任何编辑意图。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/seed/item_types.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../theme/tokens.dart';
import '../../trips/screens/item_detail_screen.dart';
import '../../trips/trip_utils.dart';
import '../today_providers.dart';
import '../today_scope.dart';
import '../widgets/today_surface.dart';
import '../../../theme/app_icons.dart';

/// 今日安排：时间线 + 本地勾选。
class TodayPlanScreen extends ConsumerStatefulWidget {
  const TodayPlanScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TodayPlanScreen> createState() => _TodayPlanScreenState();
}

class _TodayPlanScreenState extends ConsumerState<TodayPlanScreen> {
  /// 正在写盘的勾选（防连点重复提交）。
  final Set<String> _writing = <String>{};

  Future<void> _toggle(TripItem item, int epochDay, bool done) async {
    if (_writing.contains(item.id)) return;
    _writing.add(item.id);
    HapticFeedback.selectionClick();
    try {
      await ref
          .read(todayLocalStoreProvider)
          .setDone(widget.tripId, epochDay, item.id, done);
      // 写盘后让 doneIds provider 重算（地基约定的刷新方式）。
      ref.read(todayDoneRevisionProvider.notifier).state++;
    } finally {
      _writing.remove(item.id);
    }
  }

  void _openItem(TripItem item) {
    HapticFeedback.selectionClick();
    // 只读跳转：不带编辑意图，详情页自身提供编辑入口。
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          ItemDetailScreen(tripId: widget.tripId, itemId: item.id),
    ));
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
    final itemsAsync =
        ref.watch(todayItemRecordsProvider((widget.tripId, epochDay)));
    final rawItems = itemsAsync.value ?? const <TripItem>[];
    final items = todayItemsByDay<TripItem>(
      rawItems,
      epochDay,
      (i) => i.dateEpochDay,
      (i) => i.startTimeMin,
      sortOrderOf: (i) => i.sortOrder,
    );
    final doneIds =
        ref.watch(todayDoneIdsProvider((widget.tripId, epochDay)));
    final doneCount = items.where((i) => doneIds.contains(i.id)).length;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: GlassAppBar(title: '今日安排'),
      body: !itemsAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const EmptyState(
                  icon: AppIcons.calendar,
                  title: '今天还没有安排',
                  message: '去行程页给今天添两个想去的地方吧',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: Spacing.xxxl),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.xl, Spacing.lg, Spacing.xl, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '第 ${scope.dayIndex} 天 · $tripName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSizes.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '已完成 $doneCount · 共 ${items.length}',
                            style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              color: scheme.onSurfaceVariant,
                              fontFeatures: AppTextStyles.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    for (final item in items)
                      _PlanItemTile(
                        item: item,
                        done: doneIds.contains(item.id),
                        onToggle: (done) => _toggle(item, epochDay, done),
                        onOpen: () => _openItem(item),
                      ),
                  ],
                ),
    );
  }
}

/// 单条安排：勾选圈 + 时间 + 标题/地点 + 只读详情入口。
class _PlanItemTile extends StatelessWidget {
  const _PlanItemTile({
    required this.item,
    required this.done,
    required this.onToggle,
    required this.onOpen,
  });

  final TripItem item;
  final bool done;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = findTripItemType(item.type);
    final timeText =
        item.startTimeMin == null ? '全天' : hhmm(item.startTimeMin!);
    final place = item.address.isNotEmpty
        ? item.address
        : (item.toName.isNotEmpty ? item.toName : '');

    return TodaySurface(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(
          Spacing.md, Spacing.md, Spacing.lg, Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 勾选：只改本地记忆，不动行程数据。
          IconButton(
            tooltip: done ? '标记为未完成' : '标记为已完成',
            onPressed: () => onToggle(!done),
            icon: Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 24,
              color: done ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          // 时间列：无时间显示「全天」，固定列宽保证时间线对齐。
          SizedBox(
            width: 46,
            child: Text(
              timeText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
                color: item.startTimeMin == null
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
                fontFeatures: AppTextStyles.tabularFigures,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Container(width: 1, height: 30, color: scheme.outlineVariant),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(type.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.name.isEmpty ? type.name : item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSizes.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
