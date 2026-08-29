// 🔗 分享行程海报：RepaintBoundary 预览 + 保存 + 分享
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../export/share_helper.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

/// 分享行程海报页
class TripShareScreen extends ConsumerStatefulWidget {
  const TripShareScreen({super.key});

  @override
  ConsumerState<TripShareScreen> createState() => _TripShareScreenState();
}

class _TripShareScreenState extends ConsumerState<TripShareScreen> {
  String? _tripId;
  final GlobalKey _posterKey = GlobalKey();

  // 流与 build 解耦（防反复刷新）：tripId 固定，流只建一次
  Stream<Trip?>? _tripStream;
  Stream<List<TripItem>>? _itemsStream;

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_tripId == null) {
      final arg = GoRouterState.of(context).extra;
      _tripId = arg is String ? arg : null;
    }
    final tripId = _tripId;
    if (tripId == null) {
      return Scaffold(appBar: GlassAppBar(title: '分享行程'), body: const EmptyState(emoji: '🔗', title: '未找到行程'));
    }
    return Scaffold(
      appBar: GlassAppBar(title: '分享行程'),
      body: StreamBuilder<Trip?>(
        stream: _tripStream ??= ref.read(tripsRepoProvider).watchTrip(tripId),
        builder: (context, snap) {
          final trip = snap.data;
          if (trip == null) return const EmptyState(emoji: '🔗', title: '行程不存在');
          return StreamBuilder<List<TripItem>>(
            stream: _itemsStream ??= ref.read(tripsRepoProvider).watchItems(tripId),
            builder: (context, itemsSnap) {
              final items = itemsSnap.data ?? const <TripItem>[];
              return _buildBody(trip, items);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(Trip trip, List<TripItem> items) {
    final scheme = Theme.of(context).colorScheme;
    final totalDays = tripTotalDays(trip.startEpochDay, trip.endEpochDay);

    // 按天分组行程安排
    final byDay = <int, List<TripItem>>{};
    for (final it in items) {
      (byDay[it.dateEpochDay] ??= []).add(it);
    }
    final dayKeys = byDay.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster preview
          RepaintBoundary(
            key: _posterKey,
            child: Container(
              decoration: BoxDecoration(
                gradient: CoverGradients.gradientFor(trip.cover),
                borderRadius: AppRadius.card,
                boxShadow: [
                  BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                children: [
                  // Emoji background
                  Positioned(
                    right: -10,
                    top: 30,
                    child: Text(trip.emoji, style: TextStyle(fontSize: 120, color: Colors.white.withValues(alpha: 0.15))),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Spacing.md),
                        // 头部：名称 + 目的地 + 日期徽章
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.emoji, style: const TextStyle(fontSize: 44)),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trip.name,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                                  const SizedBox(height: 4),
                                  Text(trip.destination.isEmpty ? '说走就走' : trip.destination,
                                      style: TextStyle(fontSize: AppFontSizes.body, color: Colors.white.withValues(alpha: 0.9))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.md),
                        Wrap(
                          spacing: Spacing.sm,
                          runSpacing: Spacing.sm,
                          children: [
                            _PosterBadge(text: cnDateRange(trip.startEpochDay, trip.endEpochDay)),
                            _PosterBadge(text: '$totalDays 天'),
                            if (items.isNotEmpty) _PosterBadge(text: '${items.length} 个安排'),
                          ],
                        ),
                        const SizedBox(height: Spacing.lg),

                        // 行程摘要
                        if (dayKeys.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppRadius.card,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text('还没有安排，先在行程里添加吧 ✍️',
                                style: TextStyle(fontSize: AppFontSizes.body, color: Colors.white.withValues(alpha: 0.9))),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppRadius.card,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var di = 0; di < dayKeys.length; di++) ...[
                                  if (di > 0) const SizedBox(height: Spacing.md),
                                  _PosterDayRow(
                                    dayIndex: dayKeys[di] - trip.startEpochDay + 1,
                                    dateLabel: cnMonthDay(dayKeys[di]),
                                    items: byDay[dayKeys[di]]!,
                                  ),
                                ],
                              ],
                            ),
                          ),

                        const SizedBox(height: Spacing.lg),
                      ],
                    ),
                  ),
                  // Branding
                  Positioned(
                    bottom: Spacing.lg,
                    right: Spacing.xl,
                    child: Text('旅途助手 ✈️',
                        style: TextStyle(fontSize: AppFontSizes.caption, color: Colors.white.withValues(alpha: 0.65))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: '保存到相册',
                  icon: Icons.save_alt_rounded,
                  expanded: true,
                  onPressed: _saveToAlbum,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: PrimaryButton(
                  label: '分享',
                  icon: Icons.share_rounded,
                  expanded: true,
                  onPressed: _share,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.huge),
        ],
      ),
    );
  }

  Future<ui.Image?> _captureImage() async {
    final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return boundary.toImage(pixelRatio: 3.0);
  }

  Future<void> _saveToAlbum() async {
    HapticFeedback.mediumImpact();
    final image = await _captureImage();
    if (image == null) { _toast('截图失败'); return; }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) { _toast('截图失败'); return; }
    final bytes = byteData.buffer.asUint8List();
    final msg = await saveImageBytes(
        bytes, 'poster_${DateTime.now().millisecondsSinceEpoch}.png');
    _toast(msg);
  }

  Future<void> _share() async {
    HapticFeedback.mediumImpact();
    final image = await _captureImage();
    if (image == null) { _toast('截图失败'); return; }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) { _toast('截图失败'); return; }
    final bytes = byteData.buffer.asUint8List();
    final trip = await ref.read(tripsRepoProvider).getById(_tripId!);
    await shareFile(bytes, 'poster_share.png', 'image/png',
        text: '来看看我的行程「${trip?.name ?? ''}」');
  }
}

class _PosterBadge extends StatelessWidget {
  const _PosterBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: AppRadius.capsule,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}

class _PosterDayRow extends StatelessWidget {
  const _PosterDayRow({
    required this.dayIndex,
    required this.dateLabel,
    required this.items,
  });
  final int dayIndex;
  final String dateLabel;
  final List<TripItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.capsule,
              ),
              child: Text('Day $dayIndex',
                  style: const TextStyle(fontSize: AppFontSizes.caption - 2, fontWeight: FontWeight.w800, color: Colors.black87)),
            ),
            const SizedBox(width: Spacing.sm),
            Text(dateLabel,
                style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tripTypeVisual(it.type).icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    it.startTimeMin != null ? '${hhmm(it.startTimeMin!)} ${it.name}' : it.name,
                    style: TextStyle(fontSize: AppFontSizes.caption, color: Colors.white.withValues(alpha: 0.95)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}