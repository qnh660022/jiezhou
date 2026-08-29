// 📄 导出行程 PDF：说明页 + 生成 + 分享
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../export/pdf_builder.dart';
import '../../../export/share_helper.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

/// 导出行程 PDF 页
class TripExportScreen extends ConsumerStatefulWidget {
  const TripExportScreen({super.key});

  @override
  ConsumerState<TripExportScreen> createState() => _TripExportScreenState();
}

class _TripExportScreenState extends ConsumerState<TripExportScreen> {
  String? _tripId;
  bool _generating = false;

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
      return Scaffold(
        appBar: GlassAppBar(title: '导出 PDF'),
        body: const EmptyState(emoji: '📄', title: '未找到行程'),
      );
    }
    return Scaffold(
      appBar: GlassAppBar(title: '导出 PDF'),
      body: StreamBuilder<Trip?>(
        stream: _tripStream ??= ref.read(tripsRepoProvider).watchTrip(tripId),
        builder: (context, tripSnap) {
          final trip = tripSnap.data;
          if (trip == null) {
            return const EmptyState(emoji: '📄', title: '行程不存在');
          }
          return StreamBuilder<List<TripItem>>(
            stream: _itemsStream ??= ref
                .read(tripsRepoProvider)
                .watchItems(tripId),
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
    // Group items by day
    final byDay = <int, List<TripItem>>{};
    for (final it in items) {
      (byDay[it.dateEpochDay] ??= []).add(it);
    }
    final days = byDay.keys.toList()..sort();
    final totalDays = tripTotalDays(trip.startEpochDay, trip.endEpochDay);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview card
          Container(
            padding: const EdgeInsets.all(Spacing.xxl),
            decoration: BoxDecoration(
              gradient: CoverGradients.gradientFor(trip.cover),
              borderRadius: AppRadius.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: Spacing.md),
                Text(
                  trip.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${trip.destination} · $totalDays 天',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  cnDateRange(trip.startEpochDay, trip.endEpochDay),
                  style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),

          // Content summary
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF 包含内容',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: Spacing.md),
                _SummaryRow(
                  icon: Icons.photo_library_rounded,
                  label: '封面总览',
                  detail: '行程信息 + 目的地',
                ),
                for (final day in days)
                  _SummaryRow(
                    icon: Icons.calendar_today_rounded,
                    label:
                        'Day ${day - trip.startEpochDay + 1} · ${cnMonthDay(day)}',
                    detail: '${byDay[day]!.length} 个安排',
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),

          // Generate button
          PrimaryButton(
            label: '生成并分享 PDF',
            loading: _generating,
            expanded: true,
            icon: Icons.picture_as_pdf_rounded,
            onPressed: items.isEmpty
                ? null
                : () => _generateAndShare(trip, items),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                '暂无安排数据，无法生成 PDF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: Spacing.huge),
        ],
      ),
    );
  }

  Future<void> _generateAndShare(Trip trip, List<TripItem> items) async {
    if (_tripId == null) return;
    setState(() => _generating = true);
    try {
      // 将完整行程信息转换为 PDF Builder 的结构，同时保留真实 Day 编号。
      final byDay = <int, List<TripItem>>{};
      for (final it in items) {
        (byDay[it.dateEpochDay] ??= []).add(it);
      }
      final dayKeys = byDay.keys.toList()..sort();
      final totalDays = tripTotalDays(trip.startEpochDay, trip.endEpochDay);
      final pdfDays = <Map<String, dynamic>>[];
      for (final day in dayKeys) {
        final list = byDay[day]!
          ..sort((a, b) {
            final aTime = a.startTimeMin ?? 24 * 60;
            final bTime = b.startTimeMin ?? 24 * 60;
            final byTime = aTime.compareTo(bTime);
            return byTime != 0 ? byTime : a.sortOrder.compareTo(b.sortOrder);
          });
        final pdfItems = <Map<String, dynamic>>[];
        for (final it in list) {
          final visual = tripTypeVisual(it.type);
          final currency = currencyByCode(it.costCurrency);
          final cost = it.costCents == null
              ? ''
              : '${currency?.symbol ?? it.costCurrency} ${(it.costCents! / 100).toStringAsFixed(2)}';
          pdfItems.add({
            'type': it.type,
            'icon': visual.icon,
            'name': it.name,
            'address': it.address,
            'time': it.startTimeMin == null ? '' : hhmm(it.startTimeMin!),
            'duration': it.durationMin == null
                ? ''
                : formatDuration(it.durationMin!),
            'cost': cost,
            'note': it.note,
            'fromName': it.fromName,
            'toName': it.toName,
            'flightNo': it.flightNo ?? '',
          });
        }
        pdfDays.add({
          'dayIndex': day - trip.startEpochDay + 1,
          'date': cnFullDate(day),
          'items': pdfItems,
        });
      }
      final bytes = await buildTripPdf(
        trip.name,
        '${trip.destination} · $totalDays 天',
        pdfDays,
        emoji: trip.emoji,
        coverKey: trip.cover,
        totalDays: totalDays,
        dateRange: cnDateRange(trip.startEpochDay, trip.endEpochDay),
        totalItems: items.length,
      );
      await shareFile(
        bytes,
        'trip_$_tripId.pdf',
        'application/pdf',
      );
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.detail,
  });
  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              fontSize: AppFontSizes.caption,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
