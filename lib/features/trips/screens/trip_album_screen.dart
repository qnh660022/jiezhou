// 🖼️ 行程相册：九宫格照片墙 + 相机/相册添加 + 归属日期 + 全屏预览 + 长按删除
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

/// 行程相册页（路由 extra 传行程 id）
class TripAlbumScreen extends ConsumerStatefulWidget {
  const TripAlbumScreen({super.key});

  @override
  ConsumerState<TripAlbumScreen> createState() => _TripAlbumScreenState();
}

class _TripAlbumScreenState extends ConsumerState<TripAlbumScreen> {
  String? _tripId;
  int? _filterDay; // null=全部

  // 流与 build 解耦（防反复刷新）：tripId 固定，流只建一次
  Stream<List<AlbumPhoto>>? _photosStream;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhotoFlow() async {
    HapticFeedback.selectionClick();
    final source = await showDraggableSheet<ImageSource>(
      context: context,
      initialChildSize: 0.34,
      minChildSize: 0.26,
      builder: (sheetContext, _) => Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetActionTile(
              icon: Icons.photo_camera_rounded,
              label: '拍摄一张',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            SheetActionTile(
              icon: Icons.photo_rounded,
              label: '从相册选择',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
        source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null || !mounted) return;
    final uri = picked.path;
    final repo = ref.read(tripsRepoProvider);
    final trip = await repo.watchTrip(_tripId!).first;
    if (!mounted) return;
    final today = todayEpochDay();
    int defaultDay = today;
    if (trip != null) {
      if (today < trip.startEpochDay) defaultDay = trip.startEpochDay;
      if (today > trip.endEpochDay) defaultDay = trip.endEpochDay;
    }
    final day = await showDraggableSheet<int>(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.36,
      builder: (dayContext, scrollController) => _DayChooseSheet(
        trip: trip,
        defaultDay: defaultDay,
        onPicked: (d) => Navigator.of(dayContext).pop(d),
      ),
    );
    if (day == null || !mounted) return;
    await repo.addPhotoToTrip(_tripId!, uri, day);
    HapticFeedback.lightImpact();
    _toast("已保存到 ${cnFullDate(day)}");
  }

  Future<void> _previewPhoto(String uri) async {
    HapticFeedback.lightImpact();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Image.file(File(uri), fit: BoxFit.contain),
              ),
              Positioned(
                top: MediaQuery.paddingOf(ctx).top + 8,
                right: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePhoto(String id) async {
    HapticFeedback.mediumImpact();
    await showDangerConfirmSheet(
      context,
      title: '删除这张照片？',
      message: '此操作不可恢复',
      onConfirm: () async {
        await ref.read(tripsRepoProvider).deletePhoto(id);
        _toast('已删除');
      },
    );
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
        appBar: GlassAppBar(title: '相册'),
        body: const EmptyState(emoji: '🖼️', title: '未找到行程'),
      );
    }
    return Scaffold(
      appBar: GlassAppBar(
        title: '相册',
        actions: [
          IconButton(
            onPressed: _addPhotoFlow,
            icon: const Icon(Icons.add_a_photo_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<AlbumPhoto>>(
        stream: _photosStream ??= ref.read(tripsRepoProvider).watchPhotos(tripId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snap.data ?? const <AlbumPhoto>[];
          if (photos.isEmpty) {
            return EmptyState(
              emoji: '📷',
              title: '还没有照片',
              message: '旅途中的精彩瞬间等你记录',
              actionLabel: '添加第一张',
              onAction: _addPhotoFlow,
            );
          }
          // Collect unique days
          final days = <int, List<AlbumPhoto>>{};
          for (final p in photos) {
            final d = p.dayEpochDay ?? p.createdAt ~/ 86400000;
            (days[d] ??= []).add(p);
          }
          final sortedDays = days.keys.toList()..sort();
          return Column(
            children: [
              // Day filter chips
              if (sortedDays.length > 1)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                    children: [
                      FilterChip(
                        label: const Text('全部'),
                        selected: _filterDay == null,
                        onSelected: (_) => setState(() => _filterDay = null),
                      ),
                      for (final d in sortedDays)
                        Padding(
                          padding: const EdgeInsets.only(left: Spacing.sm),
                          child: FilterChip(
                            label: Text(cnMonthDay(d)),
                            selected: _filterDay == d,
                            onSelected: (_) => setState(() => _filterDay = d),
                          ),
                        ),
                    ],
                  ),
                ),
              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(Spacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, i) {
                    final p = photos[i];
                    return GestureDetector(
                      onTap: () => _previewPhoto(p.uri),
                      onLongPress: () => _deletePhoto(p.id),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(p.uri), fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
          Positioned(
            right: Spacing.xl,
            bottom: 88 + MediaQuery.paddingOf(context).bottom,
            child: FloatingActionButton.small(
              heroTag: 'fab-album-add',
              onPressed: _addPhotoFlow,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// 日期选择抽屉
class _DayChooseSheet extends StatelessWidget {
  const _DayChooseSheet({
    required this.trip,
    required this.defaultDay,
    required this.onPicked,
  });

  final Trip? trip;
  final int defaultDay;
  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) {
    if (trip == null) return const SizedBox.shrink();
    final days = trip!.endEpochDay - trip!.startEpochDay + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('选择归属日期',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.md),
          Flexible(
            child: ListView.builder(
              itemCount: days,
              itemBuilder: (context, i) {
                final day = trip!.startEpochDay + i;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
                  title: Text('Day ${i + 1} · ${cnFullDate(day)}'),
                  trailing: day == defaultDay
                      ? Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPicked(day);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}