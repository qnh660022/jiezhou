// 🖼️ 行程相册：九宫格照片墙 + 相机/相册添加 + 归属日期 + 全屏预览 + 长按删除
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../features/desktop/desktop_utils.dart' show isDesktopWeb;
import '../../../platform/file_image.dart';

import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_access.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import '../../../theme/app_icons.dart';
import '../../../shared/widgets/app_snack_bar.dart';

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

  /// V2.9.0：viewer 只读判定缓存（build 期写入，回调期同步读取）。
  bool? _canWriteCache;
  bool get _canWrite => _canWriteCache ?? true;

  void _toast(String message) {
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, message);
  }

  Future<void> _addPhotoFlow() async {
    // V2.9.0：viewer 兜底拦截（添加入口已按 canWrite 隐藏）。
    if (!_canWrite) {
      _toast('你是观察者，只能查看行程');
      return;
    }
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
            // 桌面浏览器多无摄像头/体验不一致：仅保留「选择图片」。
            if (!isDesktopWeb(context))
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
                child: fileImage(uri, fit: BoxFit.contain),
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
    // V2.9.0：viewer 兜底拦截（长按删除入口已按 canWrite 隐藏）。
    if (!_canWrite) {
      _toast('你是观察者，只能查看行程');
      return;
    }
    HapticFeedback.mediumImpact();
    // V2.8.2 S6：并入统一 L2 危险确认（showDangerConfirm）
    final ok = await showDangerConfirm(
      context: context,
      title: '删除这张照片？',
      body: '删除 1 张照片，此操作不可恢复。',
    );
    if (!ok) return;
    await ref.read(tripsRepoProvider).deletePhoto(id);
    _toast('已删除');
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
        body: const EmptyState(icon: Icons.image_outlined, title: '未找到行程'),
      );
    }
    // V2.9.0：viewer 只读 —— 隐藏一切添加/删除入口（隐藏不置灰）。
    _canWriteCache = ref.watch(tripAccessProvider(tripId)).valueOrNull?.canWrite;
    return Scaffold(
      appBar: GlassAppBar(
        title: '相册',
        // V2.9.0：viewer 不渲染添加入口
        actions: _canWrite
            ? [
                IconButton(
                  onPressed: _addPhotoFlow,
                  icon: const Icon(Icons.add_a_photo_rounded),
                ),
              ]
            : const [],
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
              icon: AppIcons.camera,
              title: '还没有照片',
              message: '旅途中的精彩瞬间等你记录',
              // V2.9.0：viewer 无添加动作
              actionLabel: _canWrite ? '添加第一张' : null,
              onAction: _canWrite ? _addPhotoFlow : null,
            );
          }
          // Collect unique days
          final days = <int, List<AlbumPhoto>>{};
          for (final p in photos) {
            final d = p.dayEpochDay ?? p.createdAt ~/ 86400000;
            (days[d] ??= []).add(p);
          }
          final sortedDays = days.keys.toList()..sort();
          // V2.9.0：日期筛选真正作用于网格（此前只改 _filterDay，Grid 未过滤）。
          final visiblePhotos = _filterDay == null
              ? photos
              : photos
                  .where((p) =>
                      (p.dayEpochDay ?? p.createdAt ~/ 86400000) == _filterDay)
                  .toList();
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
                child: visiblePhotos.isEmpty
                    ? const EmptyState(
                        icon: Icons.image_outlined,
                        title: '该日期暂无照片',
                        message: '换一天看看，或切回「全部」',
                      )
                    : GridView.builder(
                  padding: const EdgeInsets.all(Spacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: visiblePhotos.length,
                  itemBuilder: (context, i) {
                    final p = visiblePhotos[i];
                    return GestureDetector(
                      onTap: () => _previewPhoto(p.uri),
                      // V2.9.0：viewer 不挂长按删除
                      onLongPress: _canWrite ? () => _deletePhoto(p.id) : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: fileImage(p.uri, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
          // V2.9.0：viewer 不渲染添加 FAB
          if (_canWrite)
            Positioned(
              right: Spacing.xl,
              bottom: AppBottomLayout.withSafeArea(
                context,
                AppBottomLayout.actionButtonOffset,
              ),
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