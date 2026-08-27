// 🗺️ 行程详情：渐变延伸头 + 玻璃吸顶 + 按天时间轴 + 天气条 + 头部快捷操作卡
// 数据访问集中区 —— 按 t2 命名假设编写：
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/services/weather_service.dart';
import '../../../domain/models.dart';
import '../../../domain/trip_bill_linker.dart';
import '../../ledger/ledger_providers.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import 'item_detail_screen.dart';
import 'item_edit_screen.dart';

/// 行程详情页（路由 extra 传行程 id）
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final ScrollController _scroll = ScrollController();
  String? _tripId;
  Future<List<WeatherDay>?>? _weatherFuture;
  int? _cachedWeatherTripKey;

  // 流与 build 解耦（防反复刷新）：tripId 固定，流只建一次
  Stream<Trip?>? _tripStream;
  Stream<List<TripItem>>? _itemsStream;

  /// 当前行程缓存：长按操作单/一键入账需要 groupId 等上下文（仅引用赋值）
  Trip? _currentTrip;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 天气 Future 按「行程id+起止日+首个坐标」缓存；失败静默降级
  Future<List<WeatherDay>?> _ensureWeather(Trip trip, List<TripItem> items) {
    double? aLat;
    double? aLng;
    for (final it in items) {
      if (it.lat != null && it.lng != null) {
        aLat = it.lat;
        aLng = it.lng;
        break;
      }
    }
    final key = Object.hash(
        trip.id, trip.startEpochDay, trip.endEpochDay, aLat, aLng);
    if (_weatherFuture == null || _cachedWeatherTripKey != key) {
      _cachedWeatherTripKey = key;
      _weatherFuture = ref.read(weatherServiceProvider).daily(WeatherQuery(
            destination: trip.destination,
            startEpochDay: trip.startEpochDay,
            endEpochDay: trip.endEpochDay,
            anchorLat: aLat,
            anchorLng: aLng,
            tripId: trip.id,
          ));
    }
    return _weatherFuture!;
  }

  @override
  Widget build(BuildContext context) {
    if (_tripId == null) {
      final arg = GoRouterState.of(context).extra;
      _tripId = arg is String ? arg : null;
    }
    final id = _tripId;
    if (id == null) {
      return Scaffold(
        appBar: GlassAppBar(title: '行程详情'),
        body: const EmptyState(emoji: '🧳', title: '未找到行程', message: '返回重新进入试试'),
      );
    }
    return Scaffold(
      appBar: GlassAppBar(title: '行程详情', scrollController: _scroll),
      body: StreamBuilder<Trip?>(
        stream: _tripStream ??= ref.read(tripsRepoProvider).watchTrip(id),
        builder: (context, tripSnap) {
          if (tripSnap.connectionState == ConnectionState.waiting) {
            return const _DetailSkeleton();
          }
          final trip = tripSnap.data;
          if (trip == null) {
            return const EmptyState(
                emoji: '🧳', title: '行程不存在或已被删除', message: '回到列表看看其他旅程吧');
          }
          _currentTrip = trip;
          return StreamBuilder<List<TripItem>>(
            stream: _itemsStream ??= ref.read(tripsRepoProvider).watchItems(id),
            builder: (context, itemsSnap) {
              final items = itemsSnap.data ?? const <TripItem>[];
              return _DetailBody(
                trip: trip,
                items: items,
                scrollController: _scroll,
                onItemLongPress: _showItemOps,
                onAddItem: _addItem,
                ensureWeather: _ensureWeather,
                onBind: () => _bindLedgerSheet(context, trip),
                onShowExpenses: () => _showExpensesSheet(context, trip),
                onQuickBill: (ctx, it) => _quickBillSheet(ctx, trip, it),
              );
            },
          );
        },
      ),
    );
  }
  // ============ 条目操作 ============

  void _addItem(BuildContext context, TripItem? item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => ItemEditScreen(tripId: _tripId!, item: item),
    ));
  }

  void _showItemOps(
      BuildContext context, TripItem item, List<TripItem> dayList) {
    HapticFeedback.mediumImpact();
    final repo = ref.read(tripsRepoProvider);
    final idx = dayList.indexWhere((e) => e.id == item.id);
    showDraggableSheet(
      context: context,
      initialChildSize: 0.52,
      minChildSize: 0.38,
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        padding:
            const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        children: [
            Text('「${item.name}」',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.sm),
            SheetActionTile(
              icon: Icons.arrow_upward_rounded,
              label: '上移',
              subtitle: idx <= 0 ? '已经在最前了' : '与上一条交换顺序',
              onTap: idx <= 0
                  ? null
                  : () async {
                      Navigator.of(sheetContext).pop();
                      final other = dayList[idx - 1];
                      await repo.saveItem(item.copyWith(sortOrder: other.sortOrder));
                      await repo.saveItem(other.copyWith(sortOrder: item.sortOrder)); // ASSUMED(t2): saveItem 按 id 更新
                    },
            ),
            SheetActionTile(
              icon: Icons.arrow_downward_rounded,
              label: '下移',
              subtitle: idx >= dayList.length - 1 ? '已经是最后了' : '与下一条交换顺序',
              onTap: idx >= dayList.length - 1
                  ? null
                  : () async {
                      Navigator.of(sheetContext).pop();
                      final other = dayList[idx + 1];
                      await repo.saveItem(item.copyWith(sortOrder: other.sortOrder));
                      await repo.saveItem(other.copyWith(sortOrder: item.sortOrder));
                    },
            ),
            SheetActionTile(
              icon: Icons.event_repeat_rounded,
              label: '移动到其他日期',
              subtitle: cnFullDate(item.dateEpochDay),
              onTap: () async {
                final tripRow =
                    await repo.watchTrip(item.tripId).first;
                if (tripRow == null || !sheetContext.mounted) return;
                showDraggableSheet<DateTime>(
                  context: sheetContext,
                  initialChildSize: 0.5,
                  minChildSize: 0.36,
                  builder: (dayContext, __) => _DayPickSheet(
                    startDay: tripRow.startEpochDay,
                    endDay: tripRow.endEpochDay,
                    onPicked: (target) async {
                      Navigator.of(dayContext).pop();
                      Navigator.of(sheetContext).pop();
                      final all = await ref
                          .read(tripsRepoProvider)
                          .watchItems(item.tripId)
                          .first;
                      var maxSort = 0;
                      for (final e in all) {
                        if (e.dateEpochDay == target &&
                            e.sortOrder > maxSort) {
                          maxSort = e.sortOrder;
                        }
                      }
                      await repo.saveItem(
                          item.copyWith(dateEpochDay: target, sortOrder: maxSort + 10));
                      if (mounted) _toast('已移动到 ${cnFullDate(target)}');
                    },
                  ),
                );
              },
            ),
            SheetActionTile(
              icon: Icons.edit_rounded,
              label: '编辑安排',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addItem(context, item);
              },
            ),
            if ((item.costCents ?? 0) > 0 && _currentTrip != null)
              SheetActionTile(
                icon: Icons.receipt_long_rounded,
                label: '一键入账',
                subtitle: '生成等额账单并关联到本安排',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _quickBillSheet(context, _currentTrip!, item);
                },
              ),
            SheetActionTile(
              icon: Icons.delete_outline_rounded,
              label: '删除安排',
              danger: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDangerConfirmSheet(
                  context,
                  title: '删除「${item.name}」？',
                  message: '关联账单会保留，但解除与本安排的绑定。',
                  onConfirm: () async {
                    HapticFeedback.mediumImpact();
                    await repo.deleteItem(item.id); // ASSUMED(t2): 仅清 expense.tripItemId
                    if (mounted) _toast('已删除');
                  },
                );
              },
            ),
          ],
        ),
      );
  }

  // ============ 一键入账 ============

  /// 由安排快速生成等额账单并双向关联。
  /// 未绑定旅行团先引导绑定；已有未结算关联账单则引导编辑原账单（一安排一账单）。
  void _quickBillSheet(BuildContext context, Trip trip, TripItem item) {
    final gid = trip.groupId;
    if (gid == null) {
      _toast('先绑定旅行团，才能一键入账');
      _bindLedgerSheet(context, trip);
      return;
    }
    HapticFeedback.selectionClick();
    final ledger = ref.read(ledgerRepoProvider);
    ledger.watchMembers(gid).first.then((members) {
      if (!context.mounted) return;
      if (members.isEmpty) {
        _toast('先去「账本 → 成员」添加成员，再入账');
        return;
      }
      var payerId = members.first.id;
      final sharers = members.map((m) => m.id).toSet();
      showDraggableSheet(
        context: context,
        initialChildSize: 0.62,
        minChildSize: 0.42,
        builder: (sheetContext, scrollCtrl) =>
            StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding:
                const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('入账「${item.name}」',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  MoneyText(item.costCents ?? 0,
                      fontSize: AppFontSizes.headline, semanticColor: true),
                ]),
                const SizedBox(height: Spacing.xs),
                Text('金额取自计划费用 · 币种 ${item.costCurrency} · 日期 ${cnFullDate(item.dateEpochDay)}',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: Spacing.md),
                Text('付款人', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    for (final m in members)
                      GestureDetector(
                        onTap: () => setSheet(() => payerId = m.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.xs),
                          decoration: BoxDecoration(
                            color: payerId == m.id
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                : Theme.of(ctx).colorScheme.surfaceContainerLow,
                            borderRadius: AppRadius.capsule,
                            border: Border.all(
                                color: payerId == m.id
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).colorScheme.outlineVariant),
                          ),
                          child: Text(m.name,
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  fontWeight: payerId == m.id
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Row(children: [
                  Text('分摊成员（均摊）',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setSheet(() {
                      if (sharers.length == members.length) {
                        sharers.clear();
                      } else {
                        sharers.addAll(members.map((m) => m.id));
                      }
                    }),
                    child: Text(sharers.length == members.length ? '全不选' : '全选'),
                  ),
                ]),
                Flexible(
                  child: ListView(
                    controller: scrollCtrl,
                    shrinkWrap: true,
                    children: [
                      for (final m in members)
                        CheckboxListTile(
                          value: sharers.contains(m.id),
                          onChanged: (v) => setSheet(() {
                            v == true ? sharers.add(m.id) : sharers.remove(m.id);
                          }),
                          title: Text(m.name,
                              style: const TextStyle(fontSize: AppFontSizes.body)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.md),
                FilledButton(
                  onPressed: sharers.isEmpty || !sharers.contains(payerId)
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          final dup = await ledger.getLinkedBills(item.id);
                          if (dup.any((e) => e.settledRoundId == null)) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _toast('该安排已有未结算账单，请直接编辑原账单');
                            return;
                          }
                          await ledger.createExpenseFromTripItem(
                            item: item,
                            groupId: gid,
                            payerMemberId: payerId,
                            shareMemberIds: sharers.toList(),
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _toast('已入账，等额均摊 ${sharers.length} 人');
                        },
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.button)),
                  child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: Spacing.md),
                      child: Text('确认入账')),
                ),
              ],
            ),
          );
        }),
      );
    });
  }

  // ============ 账本绑定 / 关联账单 ============

  void _bindLedgerSheet(BuildContext context, Trip trip) {
    HapticFeedback.selectionClick();
    // 每次打开 sheet 只建一次流、闭包内复用：sheet 重建不再换流重订阅
    final groupsStream = ref.read(ledgerRepoProvider).watchGroups();
    showDraggableSheet(
      context: context,
      initialChildSize: 0.56,
      minChildSize: 0.4,
      builder: (sheetContext, scrollController) => Padding(
        padding:
            const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('绑定旅行团',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.xs),
            Text('绑定后，账单可关联到本行程与具体安排',
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: StreamBuilder<List<Group>>(
                stream: groupsStream,
                builder: (context, snap) {
                  final groups = snap.data ?? const <Group>[];
                  if (groups.isEmpty) {
                    return const EmptyState(
                        emoji: '💰', title: '还没有旅行团', message: '先到「账本」页创建一个旅行团');
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: groups.length + (trip.groupId != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == groups.length) {
                        return ListTile(
                          leading: const Icon(Icons.link_off_rounded),
                          title: const Text('解除绑定'),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await ref
                                .read(tripsRepoProvider)
                                .updateTrip(trip.copyWith(groupId: const Value(null)));
                            if (mounted) _toast('已解除绑定');
                          },
                        );
                      }
                      final g = groups[i];
                      final selected = trip.groupId == g.id;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(g.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(g.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: selected
                            ? Icon(Icons.check_circle_rounded,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          Navigator.of(sheetContext).pop();
                          await ref
                              .read(tripsRepoProvider)
                              .updateTrip(trip.copyWith(groupId: Value(g.id)));
                          if (mounted) _toast('已绑定「${g.name}」');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpensesSheet(BuildContext context, Trip trip) {
    HapticFeedback.selectionClick();
    showDraggableSheet(
      context: context,
      initialChildSize: 0.6,
      minChildSize: 0.42,
      builder: (sheetContext, scrollController) => Padding(
        padding:
            const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('关联账单',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: StreamBuilder<List<Expense>>(
                stream:
                    ref.read(ledgerRepoProvider).watchByTrip(trip.id),
                builder: (context, snap) {
                  final list = snap.data ?? const <Expense>[];
                  if (list.isEmpty) {
                    return const EmptyState(
                        emoji: '🧾', title: '还没有关联账单', message: '记账时选择本行程即可关联到这里');
                  }
                  var total = 0;
                  for (final e in list) {
                    total += e.amountCents;
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length + 1,
                    itemBuilder: (context, i) {
                      if (i == list.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: Spacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('合计 ',
                                  style: Theme.of(context).textTheme.bodySmall),
                              MoneyText(total, semanticColor: true),
                            ],
                          ),
                        );
                      }
                      final e = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(e.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(cnFullDate(e.dateEpochDay),
                            style: TextStyle(
                                fontSize: AppFontSizes.caption - 1)),
                        trailing: MoneyText(
                          e.amountCents,
                          semanticColor: true,
                          symbol:
                              (currencyByCode(e.currency)?.symbol) ?? '¥',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// 详情主体：滚动视图 + 分区组装
class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.trip,
    required this.items,
    required this.scrollController,
    required this.onItemLongPress,
    required this.onAddItem,
    required this.ensureWeather,
    required this.onBind,
    required this.onShowExpenses,
    required this.onQuickBill,
  });

  final Trip trip;
  final List<TripItem> items;
  final ScrollController scrollController;
  final void Function(BuildContext, TripItem, List<TripItem>) onItemLongPress;
  final void Function(BuildContext, TripItem?) onAddItem;
  final Future<List<WeatherDay>?> Function(Trip, List<TripItem>) ensureWeather;
  final VoidCallback onBind;
  final VoidCallback onShowExpenses;

  /// 一键入账（未入账徽章 / 长按菜单入口）
  final void Function(BuildContext, TripItem) onQuickBill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayEpochDay();
    // 行程关联账单：入账徽章 + 计划vs实际 共用一份数据
    final bills =
        ref.watch(tripBillsProvider(trip.id)).value ?? const <Expense>[];
    // itemId -> 最新一条未结算关联账单（仲裁约定：createdAt 最新为目标）
    final latestUnsettledByItem = <String, Expense>{};
    final byCreated = [...bills]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final e in byCreated) {
      final iid = e.tripItemId;
      if (iid != null && e.settledRoundId == null) {
        latestUnsettledByItem.putIfAbsent(iid, () => e);
      }
    }
    final status = classifyTrip(
      startEpochDay: trip.startEpochDay,
      endEpochDay: trip.endEpochDay,
      archived: trip.archived,
      today: today,
    );
    final progress =
        tripProgress(status, trip.startEpochDay, trip.endEpochDay, today);
    return Stack(
      children: [
        CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: _HeaderHero(trip: trip, status: status, scrollController: scrollController)),
        if (progress != null)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 6,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: CoverGradients.gradientFor(trip.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _QuickActionsCard(
            tripId: trip.id,
            bound: trip.groupId,
            onTapLedger: trip.groupId == null ? onBind : onShowExpenses,
          ),
        ),
        SliverToBoxAdapter(
          child: _OverviewCard(
            trip: trip,
            items: items,
            bills: bills,
            ensureWeather: ensureWeather,
            tripId: trip.id,
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate(
              _buildDaySections(context, ref, latestUnsettledByItem)),
        ),
        // 尾部留白：内容可从悬浮胶囊导航下方穿过，末尾垫高保证最后一条可达
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.contentTail,
            ),
          ),
        ),
        ],
      ),
      Positioned(
          right: Spacing.xl,
          bottom: AppBottomLayout.withSafeArea(
            context,
            AppBottomLayout.actionButtonOffset,
          ),
          child: FloatingActionButton.extended(
            heroTag: 'fab-add-item-detail',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            onPressed: () => onAddItem(context, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加安排'),
          ),
        ),
      ],
    );
  }

  /// 按天分组时间轴区块（[latestUnsettledByItem]：安排 id -> 最新未结算关联账单）
  List<Widget> _buildDaySections(BuildContext context, WidgetRef ref,
      Map<String, Expense> latestUnsettledByItem) {
    final byDay = <int, List<TripItem>>{};
    for (final it in items) {
      (byDay[it.dateEpochDay] ??= []).add(it);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final days = byDay.keys.toList()..sort();
    final widgets = <Widget>[];
    if (days.isNotEmpty) {
      widgets.add(const SectionHeader(
        title: '每日安排',
        subtitle: '轻点编辑 · 长按更多操作',
      ));
    }
    for (final day in days) {
      final list = byDay[day]!;
      widgets.add(_DayHeader(
        dayIndex: day - trip.startEpochDay + 1,
        day: day,
        count: list.length,
      ));
      for (var i = 0; i < list.length; i++) {
        final it = list[i];
        widgets.add(Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
          child: StaggerIn(
            index: i,
            child: GestureDetector(
              onTap: () => _openDetail(context, it),
              onLongPress: () => onItemLongPress(context, it, list),
              child: _ItemTile(
                item: it,
                isFirst: i == 0,
                isLast: i == list.length - 1,
                linkedBillCents: latestUnsettledByItem[it.id]?.amountCents,
                onQuickBill: onQuickBill,
              ),
            ),
          ),
        ));
      }
    }
    if (days.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.only(top: Spacing.huge),
        child: EmptyState(
          emoji: '🗺️',
          title: '还没有安排',
          message: '点右下角「添加安排」，从第一天开始填充旅程',
        ),
      ));
    }
    return widgets;
  }

  /// 打开安排详情页（详情页内可再进入编辑页）。
  void _openDetail(BuildContext context, TripItem item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ItemDetailScreen(tripId: trip.id, itemId: item.id),
    ));
  }

  /// 头部渐变延伸区
}

/// 渐变头图：大 emoji 视差 + 名称/目的地/日期/N天徽章
class _HeaderHero extends StatelessWidget {
  const _HeaderHero({
    required this.trip,
    required this.status,
    required this.scrollController,
  });

  final Trip trip;
  final TripLifeStatus status;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // 不使用 Hero：在现有路由/嵌套 Navigator 下，Hero 的 GlobalKey 子树
    // 在过渡期间会触发 framework.dart '_elements.contains(element)' 断言，
    // 打开行程详情直接红屏。这里去掉 Hero（保留渐变头视觉，仅失去展开转场）。
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.lg),
        decoration: BoxDecoration(
          gradient: CoverGradients.gradientFor(trip.cover),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: CoverGradients.onCover,
                                letterSpacing: -0.5)),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '${trip.destination.isEmpty ? '目的地待定' : trip.destination} · ${cnDateRange(trip.startEpochDay, trip.endEpochDay)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSizes.body,
                              color:
                                  CoverGradients.onCover.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  ParallaxBox(
                    scrollController: scrollController,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child:
                          Text(trip.emoji, style: const TextStyle(fontSize: 26, height: 1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  _HeaderPill(text: statusBadgeText(status, trip.startEpochDay, todayEpochDay())),
                  _HeaderPill(text: '共 ${tripTotalDays(trip.startEpochDay, trip.endEpochDay)} 天'),
                ],
              ),
            ],
          ),
        ),
    );
  }
}


/// 天气条：FutureBuilder + 骨架降级，服务未实现/失败时整条隐藏
class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({
    required this.trip,
    required this.items,
    required this.ensureWeather,
  });

  final Trip trip;
  final List<TripItem> items;
  final Future<List<WeatherDay>?> Function(Trip, List<TripItem>) ensureWeather;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WeatherDay>?>(
      future: ensureWeather(trip, items),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: 44,
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Expanded(child: SkeletonBox(height: 40, radius: AppRadius.inputValue)),
                  SizedBox(width: Spacing.sm),
                ],
              ],
            ),
          );
        }
        final days = snap.data;
        if (days == null || days.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        // 去卡片化：作为「行程概览」卡内的内联内容
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
            itemBuilder: (context, i) {
              final d = days[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadius.capsule,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.iconEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d.codeText} ${d.tempMax.round()}/${d.tempMin.round()}°',
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                fontWeight: FontWeight.w600)),
                        Text(cnMonthDay(d.date.millisecondsSinceEpoch ~/
                                86400000),
                            style: TextStyle(
                                fontSize: AppFontSizes.caption - 1,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 清单进度环入口卡 → 跳转清单 Tab
class _ChecklistEntryCard extends ConsumerStatefulWidget {
  const _ChecklistEntryCard({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_ChecklistEntryCard> createState() =>
      _ChecklistEntryCardState();
}

class _ChecklistEntryCardState extends ConsumerState<_ChecklistEntryCard> {
  /// 进度流与 build 解耦：tripId 固定，仅初始化时建一次
  late final Stream<int> _progressStream = ref
      .read(checklistRepoProvider)
      .watchByTrip(widget.tripId)
      .map((list) => list.isEmpty
          ? 0
          : ((list.where((c) => c.done).length / list.length) * 100).round());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 去卡片化：作为「行程概览」卡内的内联内容
    return InkWell(
      borderRadius: AppRadius.input,
      onTap: () {
        HapticFeedback.selectionClick();
        context.go('/checklist');
      },
      child: Row(
        children: [
          StreamBuilder<int>(
            stream: _progressStream,
            builder: (context, snap) {
              final pct = snap.data ?? 0;
              return ProgressRing(
                value: pct / 100,
                size: 44,
                strokeWidth: 5,
                color: scheme.primary,
                child: Text('$pct%',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 1,
                        fontWeight: FontWeight.w800)),
              );
            },
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('行前清单',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('行李与待办一件不落',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}


/// 天区块头：Day N 徽章 + 中文日期 + 条数
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dayIndex,
    required this.day,
    required this.count,
  });

  final int dayIndex;
  final int day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.xl, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: AppRadius.capsule,
            ),
            child: Text('Day $dayIndex',
                style: TextStyle(
                    fontSize: AppFontSizes.caption - 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: AppTextStyles.tabularFigures,
                    color: scheme.onPrimary)),
          ),
          const SizedBox(width: Spacing.sm),
          Text(cnFullDate(day),
              style: TextStyle(
                  fontSize: AppFontSizes.body,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: Spacing.sm),
          Text('$count 个安排',
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 时间轴条目卡：类型色节点 + 名称/时间/时长/费用；交通类渲染双端翼形卡
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.isFirst,
    required this.isLast,
    this.linkedBillCents,
    this.onQuickBill,
  });

  final TripItem item;
  final bool isFirst;
  final bool isLast;

  /// 最新未结算关联账单金额（null = 未入账）
  final int? linkedBillCents;
  final void Function(BuildContext, TripItem)? onQuickBill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = tripTypeVisual(item.type);
    final isTransport = item.type == 'transport';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              TypeDot(color: visual.color, icon: visual.icon, size: 36),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.only(top: 4),
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: AppRadius.input,
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (isTransport &&
                        (item.flightNo ?? '').isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: Spacing.sm),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: visual.color.withValues(alpha: 0.14),
                          borderRadius: AppRadius.capsule,
                        ),
                        child: Text(item.flightNo!,
                            style: TextStyle(
                                fontSize: AppFontSizes.caption - 1,
                                fontWeight: FontWeight.w700,
                                fontFeatures: AppTextStyles.tabularFigures,
                                color: visual.color)),
                      ),
                  ],
                ),
                if (isTransport &&
                    ((item.fromName ?? '').isNotEmpty ||
                        (item.toName ?? '').isNotEmpty)) ...[
                  const SizedBox(height: Spacing.sm),
                  _TransportWing(item: item, color: visual.color),
                ],
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    if (item.startTimeMin != null) ...[
                      Icon(Icons.schedule_rounded,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(hhmm(item.startTimeMin!),
                          style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              fontFeatures: AppTextStyles.tabularFigures)),
                      const SizedBox(width: Spacing.md),
                    ],
                    if (item.durationMin != null && item.durationMin! > 0) ...[
                      Icon(Icons.timelapse_rounded,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(formatDuration(item.durationMin!),
                          style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              fontFeatures: AppTextStyles.tabularFigures)),
                      const SizedBox(width: Spacing.md),
                    ],
                    if ((item.address ?? '').isNotEmpty)
                      Expanded(
                        child: Text(item.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.onSurfaceVariant)),
                      ),
                    if (item.costCents != null && item.costCents != 0)
                      MoneyText(
                        item.costCents!,
                        fontSize: AppFontSizes.caption,
                        symbol:
                            (currencyByCode(item.costCurrency ?? 'CNY')?.symbol) ??
                                '¥',
                      ),
                    if (item.costCents != null && item.costCents != 0) ...[
                      const SizedBox(width: Spacing.sm),
                      GestureDetector(
                        onTap: linkedBillCents == null && onQuickBill != null
                            ? () => onQuickBill!(context, item)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: linkedBillCents != null
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh,
                            borderRadius: AppRadius.capsule,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                linkedBillCents != null
                                    ? Icons.check_circle_rounded
                                    : Icons.receipt_long_rounded,
                                size: 11,
                                color: linkedBillCents != null
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                linkedBillCents != null ? '已入账' : '未入账',
                                style: TextStyle(
                                  fontSize: AppFontSizes.caption - 2,
                                  fontWeight: FontWeight.w600,
                                  color: linkedBillCents != null
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 计划 vs 实际 费用对比卡（联动数据来自 tripBillsProvider）
class _PlanActualCard extends StatelessWidget {
  const _PlanActualCard({
    required this.trip,
    required this.items,
    required this.bills,
  });

  final Trip trip;
  final List<TripItem> items;
  final List<Expense> bills;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && bills.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // drift 行 -> 领域记录（plannedVsActual 只消费金额/关联字段，其余给中性值）
    final records = [
      for (final e in bills)
        ExpenseRecord(
          id: e.id,
          groupId: e.groupId,
          dateEpochDay: e.dateEpochDay,
          title: e.title,
          categoryKey: e.categoryKey,
          type: e.type == 'prepay'
              ? ExpenseType.prepay
              : (e.type == 'refund' ? ExpenseType.refund : ExpenseType.normal),
          amountCents: e.amountCents,
          currency: e.currency,
          rate: e.rate,
          payers: const [],
          shares: const [],
          settledRoundId: e.settledRoundId,
          tripId: e.tripId,
          tripItemId: e.tripItemId,
        ),
    ];
    final plans = [
      for (final it in items)
        TripPlanItem(
          id: it.id,
          name: it.name,
          dateEpochDay: it.dateEpochDay,
          costCents: it.costCents,
          costCurrency: it.costCurrency,
        ),
    ];
    final r = plannedVsActual(plans, records);
    final diff = r.actualCents - r.plannedCents;

    Widget cell(String label, int cents, Color? color) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              MoneyText(cents, fontSize: AppFontSizes.bodyLarge, semanticColor: false),
            ],
          ),
        );

    // 去卡片化：作为「行程概览」卡内的内联内容
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('🧾', style: TextStyle(fontSize: 14)),
          const SizedBox(width: Spacing.sm),
          Text('费用 · 计划 vs 实际',
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const Spacer(),
          if (r.unlinkedCostItems > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.6),
                borderRadius: AppRadius.capsule,
              ),
              child: Text('${r.unlinkedCostItems} 项未入账',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption - 2,
                      fontWeight: FontWeight.w600,
                      color: scheme.onErrorContainer)),
            ),
        ]),
        const SizedBox(height: Spacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell('计划（CNY）', r.plannedCents, null),
            cell('实际', r.actualCents, null),
            cell(diff > 0 ? '超支' : (diff < 0 ? '结余' : '持平'), diff,
                diff > 0 ? scheme.error : scheme.primary),
          ],
        ),
      ],
    );
  }
}

/// 行程概览：把天气 / 清单 / 费用 三块合并进一张卡，让每日安排时间轴上移为首屏核心
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.trip,
    required this.items,
    required this.bills,
    required this.ensureWeather,
    required this.tripId,
  });

  final Trip trip;
  final List<TripItem> items;
  final List<Expense> bills;
  final Future<List<WeatherDay>?> Function(Trip, List<TripItem>) ensureWeather;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('行程概览',
              style: TextStyle(
                  fontSize: AppFontSizes.body, fontWeight: FontWeight.w700)),
          const SizedBox(height: Spacing.sm),
          _WeatherStrip(trip: trip, items: items, ensureWeather: ensureWeather),
          const SizedBox(height: Spacing.md),
          const Divider(height: 1),
          const SizedBox(height: Spacing.sm),
          _ChecklistEntryCard(tripId: tripId),
          const SizedBox(height: Spacing.md),
          const Divider(height: 1),
          const SizedBox(height: Spacing.sm),
          _PlanActualCard(trip: trip, items: items, bills: bills),
        ],
      ),
    );
  }
}

/// 交通段双端展示：出发地 ✈ 到达地
class _TransportWing extends StatelessWidget {
  const _TransportWing({required this.item, required this.color});

  final TripItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.capsule,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(item.fromName ?? '出发地',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: AppFontSizes.caption)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Icon(Icons.flight_takeoff_rounded, size: 15, color: color),
          ),
          Expanded(
            child: Text(item.toName ?? '到达地',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppFontSizes.caption)),
          ),
        ],
      ),
    );
  }
}


/// 头部玻璃徽章
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.text});

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
      child: Text(text,
          style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w700,
              fontFeatures: AppTextStyles.tabularFigures,
              color: CoverGradients.onCover)),
    );
  }
}

/// 移动安排到某天的日期列表抽屉
class _DayPickSheet extends StatelessWidget {
  const _DayPickSheet({
    required this.startDay,
    required this.endDay,
    required this.onPicked,
  });

  final int startDay;
  final int endDay;
  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('移动到哪一天？',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Spacing.md),
          Flexible(
            child: ListView.builder(
              itemCount: endDay - startDay + 1,
              itemBuilder: (context, i) {
                final day = startDay + i;
                final isCurrent = false;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Text('D$i',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption - 1,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer)),
                  ),
                  title: Text(cnFullDate(day)),
                  trailing: isCurrent
                      ? Icon(Icons.check_rounded,
                          size: 18, color: scheme.primary)
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

/// 头部快捷操作卡（原底部操作排上移）：地图 / 相册 / PDF / 海报 / 账本
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.tripId,
    required this.bound,
    required this.onTapLedger,
  });

  final String tripId;
  final String? bound;
  final VoidCallback onTapLedger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: AppRadius.input,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 2,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    // 内容优先：常用三件套（地图/相册/账本）+ 更多（含 PDF/海报），压缩为一行
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bound != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Text('已绑定旅行团 · 点击「账本」查看关联账单',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 2,
                        color: scheme.primary)),
              ),
            Row(
              children: [
                action(Icons.map_rounded, '地图',
                    () => context.push('/trips/map', extra: tripId)),
                action(Icons.photo_library_rounded, '相册',
                    () => context.push('/trips/album', extra: tripId)),
                action(Icons.account_balance_wallet_rounded, '账本', onTapLedger),
                action(Icons.more_horiz_rounded, '更多',
                    () => _openMoreSheet(context, tripId)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 「更多」抽屉：收纳使用频率较低的 PDF / 海报入口，保持主工具行精简
void _openMoreSheet(BuildContext context, String tripId) {
  HapticFeedback.selectionClick();
  showDraggableSheet(
    context: context,
    initialChildSize: 0.34,
    minChildSize: 0.26,
    builder: (ctx, _) => Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('更多操作',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppFontSizes.bodyLarge)),
          const SizedBox(height: Spacing.md),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('导出 PDF'),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/trips/export', extra: tripId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('生成海报'),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/trips/share', extra: tripId);
            },
          ),
        ],
      ),
    ),
  );
}

/// 详情加载骨架
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.xl),
      children: const [
        SkeletonBox(height: 180, radius: AppRadius.cardValue),
        SizedBox(height: Spacing.lg),
        SkeletonBox(height: 52, radius: AppRadius.inputValue),
        SizedBox(height: Spacing.lg),
        SkeletonListTile(),
        SkeletonListTile(),
        SkeletonListTile(),
      ],
    );
  }
}
