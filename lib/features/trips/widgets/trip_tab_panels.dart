/// 行程详情页签的共用胶水层（V2.7.2 总纲 §2.7 组件下沉）。
///
/// OutlineTab / KitTab 把「数据流 + 面板装配」从宿主（移动详情页 /
/// 桌面 Workbench）中剥离，宿主只负责决定 canEdit 与摆位。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/guide/guide_providers.dart'
    show guideCityKeyByNameProvider, guideCityNameByKeyProvider;
import '../../../data/providers.dart';
import '../../../domain/guide_match.dart';
import '../../../domain/outline_parser.dart';
import '../../../theme/tokens.dart';
import 'kit_panel.dart';
import 'outline_panel.dart';
import 'wishlist_panel.dart';
import '../outline_apply.dart';
import '../wishlist_providers.dart';

/// 「大纲」页签：OutlinePanel（初值=当前行程导出，往返式导入导出）+
/// 想去池迷你侧栏（S6 接线：无天头行入池 / 落卡即移出）。
class OutlineTab extends ConsumerStatefulWidget {
  const OutlineTab({super.key, required this.tripId, this.canEdit = true});

  final String tripId;
  final bool canEdit;

  @override
  ConsumerState<OutlineTab> createState() => _OutlineTabState();
}

class _OutlineTabState extends ConsumerState<OutlineTab> {
  /// 城过滤（V2.7.2 S11）：false = 仅默认命中城，true = 全部
  bool _showAllCities = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(tripsRepoProvider);
    return StreamBuilder<Trip?>(
      stream: repo.watchTrip(widget.tripId),
      builder: (context, tripSnap) {
        final trip = tripSnap.data;
        if (trip == null) return const SizedBox.shrink();
        return StreamBuilder<List<TripItem>>(
          stream: repo.watchItems(widget.tripId),
          builder: (context, itemsSnap) {
            final items = itemsSnap.data ?? const <TripItem>[];
            final n = trip.endEpochDay < trip.startEpochDay
                ? 0
                : trip.endEpochDay - trip.startEpochDay + 1;
            final existingNamesByDay = <int, Set<String>>{
              for (var d = 1; d <= n; d++) d: <String>{},
            };
            for (final it in items) {
              final idx = it.dateEpochDay - trip.startEpochDay + 1;
              (existingNamesByDay[idx] ??= {}).add(it.name.trim());
            }
            // 导出按天分组（天内调用方保证按 sortOrder；备胎不进导出）
            final sorted = [...items]..sort((a, b) {
                final byDay =
                    a.dateEpochDay.compareTo(b.dateEpochDay);
                if (byDay != 0) return byDay;
                return a.sortOrder.compareTo(b.sortOrder);
              });
            final cardsByDay = <int, List<OutlineExportCard>>{};
            for (final it in sorted) {
              if (it.backupOf != null) continue;
              final idx = it.dateEpochDay - trip.startEpochDay + 1;
              (cardsByDay[idx] ??= []).add(OutlineExportCard(
                startTimeMin: it.startTimeMin,
                durationMin: it.durationMin,
                name: it.name,
              ));
            }
            // S11：城过滤默认 = matchCityKey(目的地) 命中城；null → 全部
            final nameMap = ref.watch(guideCityKeyByNameProvider).valueOrNull ??
                const <String, String>{};
            final nameByKey = ref.watch(guideCityNameByKeyProvider).valueOrNull ??
                const <String, String>{};
            final matchedCity = matchCityKey(trip.destination, nameMap);
            final visibleCityKeys = (matchedCity == null || _showAllCities)
                ? null
                : <String>{matchedCity};
            return OutlinePanel(
              initialText: exportOutline(
                startEpochDay: trip.startEpochDay,
                endEpochDay: trip.endEpochDay,
                cardsByDay: cardsByDay,
              ),
              existingNamesByDay: existingNamesByDay,
              currentCardCount: items.where((e) => e.backupOf == null).length,
              canWrite: widget.canEdit,
              wishlistSlot: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (matchedCity != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.lg, Spacing.sm, Spacing.lg, 0),
                      child: Wrap(
                        spacing: Spacing.sm,
                        children: [
                          FilterChip(
                            label: Text(nameByKey[matchedCity] ?? matchedCity),
                            selected: !_showAllCities,
                            onSelected: (_) =>
                                setState(() => _showAllCities = false),
                          ),
                          FilterChip(
                            label: const Text('全部'),
                            selected: _showAllCities,
                            onSelected: (_) =>
                                setState(() => _showAllCities = true),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 300,
                    child: WishlistPanel(
                      tripId: trip.id,
                      canEdit: widget.canEdit,
                      compact: true,
                      visibleCityKeys: visibleCityKeys,
                      cityNameOf: (key) => nameByKey[key] ?? key,
                    ),
                  ),
                ],
              ),
              onApply: (text, {required bool overwrite}) => applyOutlineImport(
                tripsRepo: repo,
                wishlistRepo: ref.read(wishlistRepoProvider),
                trip: trip,
                items: items,
                text: text,
                overwrite: overwrite,
              ),
            );
          },
        );
      },
    );
  }
}

/// 「锦囊」页签（S9）：按行程目的地 matchCityKey 命中城渲染四栏。
class KitTab extends ConsumerWidget {
  const KitTab({
    super.key,
    required this.tripId,
    this.canEdit = true,
    this.bottomInset,
  });

  final String tripId;
  final bool canEdit;

  /// 列表末尾留白（V2.8.3.4）：移动详情页传底栏避让值，桌面留 null。
  final double? bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tripsRepoProvider);
    return StreamBuilder<Trip?>(
      stream: repo.watchTrip(tripId),
      builder: (context, snap) {
        final trip = snap.data;
        if (trip == null) return const SizedBox.shrink();
        return KitPanel(
          tripId: trip.id,
          destination: trip.destination,
          canEdit: canEdit,
          bottomInset: bottomInset,
        );
      },
    );
  }
}
