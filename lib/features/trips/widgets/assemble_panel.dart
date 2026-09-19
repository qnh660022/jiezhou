/// 想去装配台面板（V2.7.2 S7，三宿主共用）。
///
/// - 顶部当天选择；容量条（`已排 X h / 容量 Y h`，备胎不计）；
/// - 左栏想去池（复用 WishlistPanel，rankCandidates 排序、窗口无交集置灰）；
///   右栏当天正式卡时间轴缩略（只读，最近落点高亮）；
/// - 点击即落点：findSlot → Placed → 同事务建卡 + 删池行 → toast「已排入 · 撤销」；
/// - 单步撤销 30s：删卡 + 恢复池行（id 不变）；NeedDuration 补时长；
///   CapacityFull/NoSlot → 候选标红 + 换天建议（≤3）/ 转为备胎（S8）。
/// - `pace` 为行程级设置（trip_edit_screen 设置一次），不在装配时询问。
library;
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/repo/trips_repo.dart';
import '../../../data/guide/guide_providers.dart'
    show guideCityKeyByNameProvider, guideCityNameByKeyProvider;
import '../../../domain/assemble_engine.dart';
import '../../../domain/guide_match.dart';
import '../../../domain/models.dart';
import '../../../domain/records.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import 'wishlist_panel.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class AssemblePanel extends ConsumerStatefulWidget {
  const AssemblePanel({
    super.key,
    required this.tripId,
    required this.canEdit,
  });

  final String tripId;

  /// viewer 只读：池列表可见、候选不可点（隐藏不置灰——由 canEdit 控制）。
  final bool canEdit;

  @override
  ConsumerState<AssemblePanel> createState() => _AssemblePanelState();
}

class _AssemblePanelState extends ConsumerState<AssemblePanel> {
  int? _day;

  /// 最近一次落点（单步撤销，30 秒失效；再次落点覆盖）。
  (String cardId, WishlistRecord wish)? _lastPlacement;
  Timer? _undoTimer;

  /// CapacityFull/NoSlot 的候选（标红 + 出动作面板）。
  String? _failedCandidateId;

  /// 城过滤（S11）：false = 仅默认命中城，true = 全部
  bool _showAllCities = false;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _armUndo() {
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _lastPlacement = null);
    });
  }

  void _toast(String msg, {SnackBarAction? action}) {
    if (!mounted) return;
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1，保留 action 透传）。
    showAppSnackBar(context, msg, action: action);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tripStream = ref.watch(tripsRepoProvider).watchTrip(widget.tripId);
    final itemStream = ref.watch(tripsRepoProvider).watchItems(widget.tripId);
    return StreamBuilder<Trip?>(
      stream: tripStream,
      builder: (context, tripSnap) {
        final trip = tripSnap.data;
        if (trip == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final pace = parseTripPace(trip.pace);
        // S11：城过滤默认 = matchCityKey(目的地) 命中城；null → 全部
        final nameMap = ref.watch(guideCityKeyByNameProvider).valueOrNull ??
            const <String, String>{};
        final nameByKey = ref.watch(guideCityNameByKeyProvider).valueOrNull ??
            const <String, String>{};
        final matchedCity = matchCityKey(trip.destination, nameMap);
        final visibleCityKeys = (matchedCity == null || _showAllCities)
            ? null
            : <String>{matchedCity};
        final n = trip.endEpochDay - trip.startEpochDay + 1;
        if (n < 1) {
          return const Center(child: Text('该行程还没有日期，先去编辑行程设置日期'));
        }
        _day ??= trip.startEpochDay;
        final day = (_day! < trip.startEpochDay || _day! > trip.endEpochDay)
            ? trip.startEpochDay
            : _day!;
        return StreamBuilder<List<TripItem>>(
          stream: itemStream,
          builder: (context, itemSnap) {
            final formalRecords = <TripItemRecord>[
              for (final it in (itemSnap.data ?? const <TripItem>[]))
                if (it.backupOf == null) // S8 口径：备胎不参与装配台/容量
                  TripsRepository.tripItemToRecord(it)
            ];
            final dayRecords = [
              for (final r in formalRecords)
                if (r.dateEpochDay == day) r
            ];
            final used = usedCapacityOf(dayRecords);
            final capacity = kDayCapacity[pace]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDayPicker(context, trip, day),
                _buildCapacityBar(context, scheme, used, capacity, pace),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final pool = Column(
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
                                  label: Text(
                                      nameByKey[matchedCity] ?? matchedCity),
                                  selected: !_showAllCities,
                                  onSelected: widget.canEdit
                                      ? (_) => setState(
                                          () => _showAllCities = false)
                                      : null,
                                ),
                                FilterChip(
                                  label: const Text('全部'),
                                  selected: _showAllCities,
                                  onSelected: widget.canEdit
                                      ? (_) =>
                                          setState(() => _showAllCities = true)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: WishlistPanel(
                            tripId: widget.tripId,
                            canEdit: widget.canEdit,
                            compact: true,
                            visibleCityKeys: visibleCityKeys,
                            cityNameOf: (key) => nameByKey[key] ?? key,
                            compare: (a, b) =>
                                compareCandidates(a, b, rem: capacity - used),
                            isEntryDisabled: (r) => !windowIntersectsDay(
                                r.type, r.durationMin ?? kDefaultOccupancyMin),
                            onEntryTap: (r) => _onCandidateTap(
                                trip: trip,
                                day: day,
                                dayRecords: dayRecords,
                                pace: pace,
                                record: r),
                            padding:
                                const EdgeInsets.only(right: Spacing.xs),
                          ),
                        ),
                      ],
                    );
                    final outline = _DayOutline(
                      records: dayRecords,
                      highlightId: _lastPlacement?.$1,
                      failedId: _failedCandidateId,
                    );
                    if (box.maxWidth >= 700) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: pool),
                          const VerticalDivider(width: 1),
                          Expanded(flex: 4, child: outline),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(flex: 5, child: pool),
                        const Divider(height: 1),
                        Expanded(flex: 4, child: outline),
                      ],
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDayPicker(BuildContext context, Trip trip, int day) {
    final n = trip.endEpochDay - trip.startEpochDay + 1;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: n,
        itemBuilder: (context, i) {
          final d = trip.startEpochDay + i;
          final selected = d == day;
          return Padding(
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: ChoiceChip(
              label: Text('第 ${i + 1} 天'),
              selected: selected,
              onSelected: widget.canEdit
                  ? (_) => setState(() {
                        _day = d;
                        _failedCandidateId = null;
                      })
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCapacityBar(BuildContext context, ColorScheme scheme, int used,
      int capacity, TripPace pace) {
    final over = used > capacity;
    final ratio = capacity <= 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0);
    String h(int m) {
      final full = m / 60;
      return full == full.roundToDouble()
          ? '${full.round()} h'
          : '${full.toStringAsFixed(1)} h';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('容量 · ${tripPaceLabel(pace)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                '已排 ${h(used)} / 容量 ${h(capacity)}${over ? '（已超）' : ''}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  color: over ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.xs),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            color: over ? scheme.error : scheme.primary,
            backgroundColor: scheme.surfaceContainerHigh,
          ),
        ],
      ),
    );
  }

  /// 装配台「点击即落点」。返回 true 表示事件已消费。
  Future<bool> _onCandidateTap({
    required Trip trip,
    required int day,
    required List<TripItemRecord> dayRecords,
    required TripPace pace,
    required WishlistRecord record,
  }) async {
    if (!widget.canEdit) return true;
    var candidate = record;
    if (!windowIntersectsDay(
        candidate.type, candidate.durationMin ?? kDefaultOccupancyMin)) {
      return true; // 置灰候选不可落点
    }
    var result = findSlot(
        dayItems: dayRecords, candidate: candidate, pace: pace);
    // NeedDuration → 补时长后重算
    if (result is NeedDuration) {
      final d = await showWishlistDurationSheet(context);
      if (d == null || !mounted) return true;
      await ref
          .read(wishlistRepoProvider)
          .updateItem(candidate.id, WishlistItemsCompanion(durationMin: Value(d)));
      candidate = _withDuration(candidate, d);
      result = findSlot(
          dayItems: dayRecords, candidate: candidate, pace: pace);
    }
    if (!mounted) return true;

    if (result is Placed) {
      setState(() => _failedCandidateId = null);
      final cardId = await ref.read(tripsRepoProvider).assemblePlace(
            tripId: trip.id,
            wishlistId: candidate.id,
            dateEpochDay: day,
            startTimeMin: result.startMin,
          );
      setState(() => _lastPlacement = (cardId, candidate));
      _armUndo();
      _toast('已排入 ${hhmm(result.startMin)}',
          action: SnackBarAction(
            label: '撤销',
            onPressed: _undoLastPlacement,
          ));
      return true;
    }

    if (result is CapacityFull) {
      setState(() => _failedCandidateId = candidate.id);
      await _showNoRoomActions(
          trip: trip,
          day: day,
          dayRecords: dayRecords,
          pace: pace,
          candidate: candidate,
          rem: result.rem);
      return true;
    }

    // NoSlot（防御分支）：同容量不足动作，建议由换天接口填充
    setState(() => _failedCandidateId = candidate.id);
    await _showNoRoomActions(
        trip: trip,
        day: day,
        dayRecords: dayRecords,
        pace: pace,
        candidate: candidate,
        rem: kDayCapacity[pace]! - usedCapacityOf(dayRecords));
    return true;
  }

  WishlistRecord _withDuration(WishlistRecord r, int durationMin) =>
      WishlistRecord(
        id: r.id,
        tripId: r.tripId,
        cityKey: r.cityKey,
        name: r.name,
        address: r.address,
        type: r.type,
        durationMin: durationMin,
        tag: r.tag,
        guideRef: r.guideRef,
        note: r.note,
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  /// 单步撤销：删卡（墓碑）+ 恢复池行（原 id）。
  Future<void> _undoLastPlacement() async {
    final placement = _lastPlacement;
    if (placement == null) return;
    final (cardId, wish) = placement;
    await ref.read(wishlistRepoProvider).restoreRow(wish);
    await ref.read(tripsRepoProvider).deleteItem(cardId);
    if (!mounted) return;
    setState(() => _lastPlacement = null);
    _toast('已撤销，条目回到想去池');
  }

  /// CapacityFull/NoSlot 动作面板：换天建议（≤3，点击切换当天并重算）+ 转为备胎。
  Future<void> _showNoRoomActions({
    required Trip trip,
    required int day,
    required List<TripItemRecord> dayRecords,
    required TripPace pace,
    required WishlistRecord candidate,
    required int rem,
  }) async {
    // 换天建议：排除当前天
    final allDays = <int, List<TripItemRecord>>{
      for (var d = trip.startEpochDay; d <= trip.endEpochDay; d++)
        if (d != day)
          d: [for (final r in dayRecords) if (r.dateEpochDay == d) r],
    };
    final suggestions = rankAlternativeDays(
      daysByEpochDay: allDays,
      candidate: candidate,
      pace: pace,
    );
    String h(int m) {
      final full = m / 60;
      return full == full.roundToDouble()
          ? '${full.round()} h'
          : '${full.toStringAsFixed(1)} h';
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(
                '当天装不下「${candidate.name}」（还剩 $rem 分钟）',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final d in suggestions)
              ListTile(
                leading: const Icon(Icons.event_rounded, size: 20),
                title: Text(
                    '换到第 ${d - trip.startEpochDay + 1} 天（还剩 ${h(rankAlternativeRem(allDays[d] ?? const [], pace))}）'),
                onTap: () => Navigator.pop(ctx, 'day:$d'),
              ),
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded, size: 20),
              title: const Text('转为备胎（挂当天）'),
              onTap: () => Navigator.pop(ctx, 'backup'),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, size: 20),
              title: const Text('取消'),
              onTap: () => Navigator.pop(ctx, 'cancel'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'backup') {
      final cardId = await ref.read(tripsRepoProvider).assemblePlaceAsBackup(
            tripId: trip.id,
            wishlistId: candidate.id,
            dateEpochDay: day,
          );
      if (!mounted) return;
      setState(() {
        _lastPlacement = null;
        _failedCandidateId = null;
      });
      _toast('已转为备胎（第 ${day - trip.startEpochDay + 1} 天）');
      assert(cardId.isNotEmpty);
      return;
    }
    if (action.startsWith('day:')) {
      final d = int.tryParse(action.substring(4));
      if (d != null) {
        setState(() => _day = d);
      }
    }
  }

  int rankAlternativeRem(List<TripItemRecord> items, TripPace pace) =>
      kDayCapacity[pace]! - usedCapacityOf(items);
}

/// 当天正式卡时间轴缩略（只读）。
class _DayOutline extends StatelessWidget {
  const _DayOutline({
    required this.records,
    required this.highlightId,
    required this.failedId,
  });

  final List<TripItemRecord> records;
  final String? highlightId;
  final String? failedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = List<TripItemRecord>.of(records)
      ..sort((a, b) {
        final at = a.startTimeMin;
        final bt = b.startTimeMin;
        if (at == null && bt == null) return a.sortOrder.compareTo(b.sortOrder);
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
    if (sorted.isEmpty) {
      return Center(
        child: Text('当天还没有安排——点击左侧候选自动落点',
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(Spacing.lg),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final r = sorted[i];
        final highlighted = r.id == highlightId;
        return Container(
          margin: const EdgeInsets.only(bottom: Spacing.sm),
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: AppRadius.input,
            border: Border.all(
              color: highlighted
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              width: highlighted ? 1.6 : 1,
            ),
          ),
          child: Row(children: [
            SizedBox(
              width: 52,
              child: Builder(builder: (__) {
                final st = r.startTimeMin;
                return Text(
                  st == null ? '全天' : hhmm(st),
                  style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [],
                    color: st == null
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                );
              }),
            ),
            Expanded(
              child: Text(r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (r.durationMin != null)
              Text('${r.durationMin} 分钟',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant)),
          ]),
        );
      },
    );
  }
}
