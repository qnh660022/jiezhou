// 🔗 分享行程海报：RepaintBoundary 预览 + 保存 + 分享
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
// S5：海报渲染基建共用（行程海报与结算卡同源）。
import '../../../export/poster_exporter.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/share_link_sheet.dart';
import '../../../theme/app_icons.dart';
import '../../../shared/widgets/app_snack_bar.dart';

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
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    if (_tripId == null) {
      final arg = GoRouterState.of(context).extra;
      _tripId = arg is String ? arg : null;
    }
    final tripId = _tripId;
    if (tripId == null) {
      return Scaffold(appBar: GlassAppBar(title: '分享行程'), body: const EmptyState(icon: Icons.link_rounded, title: '未找到行程'));
    }
    return Scaffold(
      appBar: GlassAppBar(title: '分享行程'),
      body: StreamBuilder<Trip?>(
        stream: _tripStream ??= ref.read(tripsRepoProvider).watchTrip(tripId),
        builder: (context, snap) {
          final trip = snap.data;
          if (trip == null) return const EmptyState(icon: Icons.link_rounded, title: '行程不存在');
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
                    child: Text('芥舟 ✈️',
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
          // 只读链接分享（云端）：无需登录即可在浏览器查看行程时间线
          const SizedBox(height: Spacing.xl),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('只读链接分享'),
              subtitle: Text(
                '生成一个网页链接，任何人不登录也能查看此行程（只读）；可设 4 位口令，随时撤销。',
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: AppFontSizes.caption),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showShareLinkSheet(context,
                  entityType: 'trip', entityId: trip.id),
            ),
          ),
          SizedBox(
            height: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.navBarHeight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToAlbum() async {
    HapticFeedback.mediumImpact();
    // S5：海报渲染基建已抽到 export/poster_exporter.dart（与结算卡共用）。
    final msg = await savePosterPng(
        _posterKey, 'poster_${DateTime.now().millisecondsSinceEpoch}.png');
    _toast('${copy(CopyTokens.exportDone)} $msg');
  }

  Future<void> _share() async {
    HapticFeedback.mediumImpact();
    final trip = await ref.read(tripsRepoProvider).getById(_tripId!);
    final ok = await sharePosterPng(_posterKey, 'poster_share.png',
        text: '来看看我的行程「${trip?.name ?? ''}」');
    if (!ok) {
      _toast('截图失败');
      return;
    }
    _toast(copy(CopyTokens.shareDone));
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
        // V2.8.3.1：海报签条统一走 GlassTokens
        color: Colors.white.withValues(alpha: GlassTokens.coverPillFillAlpha),
        borderRadius: AppRadius.capsule,
        border: Border.all(
            color: Colors.white.withValues(alpha: GlassTokens.coverPillBorderAlpha)),
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
