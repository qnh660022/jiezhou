// 🧳 行程首页（Tab 根）：五态状态机分组 + 渐变封面大卡（Hero/视差/进度条）
// 数据访问集中区 —— 按 t2 命名假设编写，T2 落地后如签名有出入统一在此校正：
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../export/share_helper.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

/// 行程 Tab 首屏
class TripsHomeScreen extends ConsumerStatefulWidget {
  const TripsHomeScreen({super.key});

  @override
  ConsumerState<TripsHomeScreen> createState() => _TripsHomeScreenState();
}

class _TripsHomeScreenState extends ConsumerState<TripsHomeScreen> {
  final ScrollController _scroll = ScrollController();
  bool _showArchived = false;

  // 流与 build 解耦（防反复刷新）：只建一次，drift 流可安全重复订阅
  Stream<List<Trip>>? _tripsStream;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openMapSettings() {
    HapticFeedback.selectionClick();
    context.push('/trips/map-settings');
  }

  void _createTrip() {
    context.push('/trips/edit');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(
        // 首屏毛玻璃大标题展示应用品牌（widget_test 冷启动断言依据）
        largeTitle: '旅途助手',
        scrollController: _scroll,
        actions: [
          IconButton(
            tooltip: '地图服务设置',
            onPressed: _openMapSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Trip>>(
        stream: _tripsStream ??= ref.read(tripsRepoProvider).watchTrips(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _HomeSkeleton();
          }
          if (snap.hasError) {
            return EmptyState(
                emoji: '😵', title: '加载失败', message: '${snap.error}');
          }
          final trips = snap.data ?? const <Trip>[];
          if (trips.isEmpty) {
            return EmptyState(
              emoji: '🧭',
              title: '还没有行程',
              message: '创建第一段旅程，从目的地和日期开始规划吧',
              actionLabel: '新建行程',
              onAction: _createTrip,
            );
          }
          return _buildGroups(context, trips);
        },
      ),
          Positioned(
            right: Spacing.xl,
            bottom: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.actionButtonOffset,
            ),
            child: FloatingActionButton.extended(
              heroTag: 'fab-create-trip',
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
              onPressed: _createTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建行程'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroups(BuildContext context, List<Trip> trips) {
    final today = todayEpochDay();
    final ongoing = <Trip>[];
    final upcoming = <Trip>[];
    final planning = <Trip>[];
    final ended = <Trip>[];
    final archived = <Trip>[];
    for (final t in trips) {
      switch (classifyTrip(
        startEpochDay: t.startEpochDay,
        endEpochDay: t.endEpochDay,
        archived: t.archived,
        today: today,
      )) {
        case TripLifeStatus.ongoing:
          ongoing.add(t);
        case TripLifeStatus.upcoming:
          upcoming.add(t);
        case TripLifeStatus.planning:
          planning.add(t);
        case TripLifeStatus.ended:
          ended.add(t);
        case TripLifeStatus.archived:
          archived.add(t);
      }
    }
    int sortAsc(Trip a, Trip b) => a.startEpochDay.compareTo(b.startEpochDay);
    ongoing.sort(sortAsc);
    upcoming.sort(sortAsc);
    planning.sort(sortAsc);
    ended.sort((a, b) => b.endEpochDay.compareTo(a.endEpochDay));
    archived.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final children = <Widget>[];
    var stagger = 0;
    void group(String title, List<Trip> list) {
      if (list.isEmpty) return;
      children.add(SectionHeader(title: title, trailingLabel: null,
          subtitle: '${list.length} 个行程'));
      for (final t in list) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Spacing.lg),
          child: StaggerIn(index: stagger++, child: _TripCard(trip: t, scrollController: _scroll)),
        ));
      }
    }

    group('进行中', ongoing);
    group('即将出发', upcoming);
    group('规划中', planning);
    group('已结束', ended);
    if (archived.isNotEmpty) {
      children.add(SectionHeader(title: '已归档', trailingLabel: null,
          subtitle: '${archived.length} 个行程'));
      for (final t in archived) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: StaggerIn(
            index: stagger++,
            child: _ArchivedRow(
              trip: t,
              expanded: _showArchived,
              onToggle: () => setState(() => _showArchived = !_showArchived),
            ),
          ),
        ));
      }
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xs,
            Spacing.xl,
            AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.contentTail,
            ),
          ),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }
}


/// 首页加载骨架
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.huge),
      children: [
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(height: 176, radius: AppRadius.cardValue),
          const SizedBox(height: Spacing.lg),
          const SkeletonListTile(),
          const SizedBox(height: Spacing.xl),
        ],
      ],
    );
  }
}

/// 渐变封面大卡：Hero(tag=trip.id) + 滚动视差 emoji + 状态徽章 + 天数进度
class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip, required this.scrollController});

  final Trip trip;
  final ScrollController scrollController;

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push('/trips/detail', extra: trip.id);
  }

  void _showOps(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showDraggableSheet(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.36,
      builder: (sheetContext, scrollController) => _TripOpsSheet(
        trip: trip,
        pageContext: context,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final today = todayEpochDay();
    final status = classifyTrip(
      startEpochDay: trip.startEpochDay,
      endEpochDay: trip.endEpochDay,
      archived: trip.archived,
      today: today,
    );
    final progress =
        tripProgress(status, trip.startEpochDay, trip.endEpochDay, today);
    // 不再做 Hero 转场：详情页已移除对应 Hero；保留 GlobalKey 子树只会
    // 增加路由过渡期框架断言风险（_elements.contains / duplicate hero）。
    return Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () => _open(context),
          onLongPress: () => _showOps(context, ref),
          child: Container(
            height: 176,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: CoverGradients.gradientFor(trip.cover),
              borderRadius: AppRadius.card,
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: ParallaxBox(
                      scrollController: scrollController,
                      child: Text(trip.emoji,
                          style: const TextStyle(fontSize: 86, height: 1)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusPill(text: statusBadgeText(status, trip.startEpochDay, today)),
                      const Spacer(),
                      Text(trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSizes.title,
                              fontWeight: FontWeight.w800,
                              color: CoverGradients.onCover,
                              letterSpacing: -0.3)),
                      const SizedBox(height: Spacing.xs),
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              size: 13, color: CoverGradients.onCover.withValues(alpha: 0.85)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                                '${trip.destination.isEmpty ? '目的地待定' : trip.destination} · ${cnDateRange(trip.startEpochDay, trip.endEpochDay)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppFontSizes.caption,
                                    color: CoverGradients.onCover.withValues(alpha: 0.9))),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.sm),
                      Row(
                        children: [
                          _GlassChip(label: '共 ${tripTotalDays(trip.startEpochDay, trip.endEpochDay)} 天'),
                          const SizedBox(width: Spacing.sm),
                          if (progress != null)
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  height: 4,
                                  color: Colors.white.withValues(alpha: 0.28),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}



/// 封面状态徽章（毛玻璃白）
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: AppRadius.capsule,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  fontWeight: FontWeight.w600,
                  color: CoverGradients.onCover)),
        ],
      ),
    );
  }
}

/// 封面玻璃小签（天数等）
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: AppRadius.capsule,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTextStyles.tabularFigures,
              color: CoverGradients.onCover.withValues(alpha: 0.95))),
    );
  }
}

/// 已归档折叠行：收起为一根细条，展开后可进入详情/长按操作
class _ArchivedRow extends ConsumerWidget {
  const _ArchivedRow({
    required this.trip,
    required this.expanded,
    required this.onToggle,
  });

  final Trip trip;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (!expanded) {
      return InkWell(
        borderRadius: AppRadius.input,
        onTap: onToggle,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadius.input,
          ),
          child: Row(
            children: [
              Text(trip.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text('${trip.name} · ${cnDateRange(trip.startEpochDay, trip.endEpochDay)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppFontSizes.body,
                        color: scheme.onSurfaceVariant)),
              ),
              Icon(Icons.expand_more_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: AppRadius.card,
      onTap: () => context.push('/trips/detail', extra: trip.id),
      onLongPress: () => showDraggableSheet(
        context: context,
        initialChildSize: 0.5,
        minChildSize: 0.36,
        builder: (sheetContext, scrollController) => _TripOpsSheet(
          trip: trip,
          pageContext: context,
          scrollController: scrollController,
        ),
      ),
      child: SectionCard(
        color: scheme.surfaceContainerLow,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: CoverGradients.gradientFor(trip.cover),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(trip.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(cnDateRange(trip.startEpochDay, trip.endEpochDay),
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggle,
              icon: const Icon(Icons.expand_less_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// 行程长按操作抽屉：编辑 / 复制 / 专有备份 / 归档 / 删除（删除二次确认）
class _TripOpsSheet extends ConsumerWidget {
  const _TripOpsSheet({
    required this.trip,
    required this.pageContext,
    required this.scrollController,
  });

  final Trip trip;
  final BuildContext pageContext;
  final ScrollController scrollController;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(tripsRepoProvider);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
      children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: CoverGradients.gradientFor(trip.cover),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(trip.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(cnDateRange(trip.startEpochDay, trip.endEpochDay),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          SheetActionTile(
            icon: Icons.edit_rounded,
            label: '编辑行程',
            subtitle: '修改名称、封面与日期',
            onTap: () {
              Navigator.of(context).pop();
              pageContext.push('/trips/edit', extra: trip.id);
            },
          ),
          SheetActionTile(
            icon: Icons.copy_rounded,
            label: '复制为副本',
            subtitle: '生成全新行程，不关联账本',
            onTap: () async {
              Navigator.of(context).pop();
              HapticFeedback.lightImpact();
              await repo.copyTrip(trip.id);
              if (pageContext.mounted) _toast(pageContext, '已创建副本');
            },
          ),
          SheetActionTile(
            icon: Icons.save_alt_rounded,
            label: '导出行程备份（.tat）',
            subtitle: '行程、安排、照片记录与清单一并保存',
            onTap: () async {
              Navigator.of(context).pop();
              try {
                final bytes = await repo.exportTripBackupBytes(trip.id);
                final base = trip.name
                    .replaceAll(RegExp(r'[\\/:*?"<>|\\r\\n\\t]'), '_')
                    .trim();
                await shareFile(
                  bytes,
                  '${base.isEmpty ? '行程' : base}_backup.tat',
                  'application/x-travel-assistant-trip',
                );
              } catch (_) {
                if (pageContext.mounted) _toast(pageContext, '备份失败，稍后再试');
              }
            },
          ),
          SheetActionTile(
            icon: Icons.file_open_rounded,
            label: '导入行程备份（.tat）',
            subtitle: '恢复为一个新的独立行程，不覆盖当前行程',
            onTap: () async {
              Navigator.of(context).pop();
              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['tat'],
                  withData: true,
                );
                if (result.isEmpty) return;
                final picked = result.single;
                final path = picked.path;
                if (path == null) throw const FormatException();
                final bytes = await File(path).readAsBytes();
                if (bytes.isEmpty) throw const FormatException();
                final imported = await repo.importTripBackupBytes(bytes);
                if (pageContext.mounted) {
                  _toast(pageContext, '已导入「${imported.trip}」：安排${imported.items} · 清单${imported.checklist}');
                }
              } catch (_) {
                if (pageContext.mounted) _toast(pageContext, '行程备份读取失败');
              }
            },
          ),
          SheetActionTile(
            icon: trip.archived
                ? Icons.unarchive_rounded
                : Icons.archive_rounded,
            label: trip.archived ? '取消归档' : '归档行程',
            subtitle: '归档后折叠到列表尾部',
            onTap: () async {
              Navigator.of(context).pop();
              HapticFeedback.lightImpact();
              await repo.updateTrip(trip.copyWith(archived: !trip.archived)); // ASSUMED(t2): updateTrip(Trip)+copyWith
              if (pageContext.mounted) {
                _toast(pageContext, trip.archived ? '已恢复到列表' : '已归档');
              }
            },
          ),
          SheetActionTile(
            icon: Icons.delete_outline_rounded,
            label: '删除行程',
            subtitle: '安排、相册将一并删除，账单自动解绑',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              showDangerConfirmSheet(
                pageContext,
                title: '删除「${trip.name}」？',
                message: '此操作不可恢复，关联账单会保留但解除绑定。',
                onConfirm: () async {
                  HapticFeedback.mediumImpact();
                  await repo.deleteTrip(trip.id); // ASSUMED(t2): 同时置空 expenses.tripId/tripItemId
                  if (pageContext.mounted) _toast(pageContext, '行程已删除');
                },
              );
            },
          ),
        ],
    );
  }
}
