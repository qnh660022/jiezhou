// 🗺️ 行程详情：渐变延伸头 + 玻璃吸顶 + 按天时间轴 + 天气条 + 头部快捷操作卡
// 数据访问集中区 —— 按 t2 命名假设编写：
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/date_utils.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/repo/trips_repo.dart';
import '../../../data/services/weather_service.dart';
import '../../../domain/trip_bill_linker.dart';
import '../../../domain/day_shift_engine.dart';
import '../../ledger/ledger_providers.dart';
import '../trip_access.dart';
import '../trip_template_store.dart';
import '../widgets/assemble_panel.dart';

import '../widgets/trip_tab_panels.dart';

import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import '../widgets/day_ops_sheet.dart';
import '../guide_widgets.dart' show GuideRouteArgs;
import 'item_detail_screen.dart';
import 'item_edit_screen.dart';
import '../../../shared/widgets/app_snack_bar.dart';

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

  // 多选批量（V2.7.2 S4）：状态在宿主层
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};

  /// V2.8.3.2：底部双段视图（0=时间线 / 1=攻略·含原锦囊城市贴士）
  int _viewIndex = 0;

  /// V2.7.2 A12：viewer 只读判定缓存。
  ///
  /// 角色唯一权威源 = `trip_access.dart`（空间成员镜像 → 本地行程行 → 未知）。
  /// 未知/解析中一律按**可写**放开 —— 云 RLS 才是最终屏障，
  /// 「看不见的权限」比「误藏入口」安全（与 ledger_access 同口径）。
  /// 该字段只在 build 期写入，供各回调用同步读取（回调期不能 watch）。
  bool? _canWriteCache;

  bool get _canWrite => _canWriteCache ?? true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String message) {
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, message);
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
        body: const EmptyState(icon: AppIcons.compass, title: '未找到行程', message: '返回重新进入试试'),
      );
    }
    // V2.7.2 A12：viewer 只读 —— 角色由 trip_access 统一解析后再分发各门控点。
    _canWriteCache = ref.watch(tripAccessProvider(id)).valueOrNull?.canWrite;
    return Scaffold(
      appBar: GlassAppBar(
        title: '行程详情',
        scrollController: _scroll,
      ),
      // V2.8.3.2：四页签 → 双视图 + 底部停靠双段切换。
      // 视图0 = 时间线（原页签1 流链原样保留）；
      // 视图1 = 攻略（KitTab 承载 —— 锦囊页签删除，城市贴士并入攻略）。
      body: Stack(
        children: [
          IndexedStack(
            index: _viewIndex,
            children: [
          // ---- 视图 0：时间线（既有流链原样保留） ----
          StreamBuilder<Trip?>(
        stream: _tripStream ??= ref.read(tripsRepoProvider).watchTrip(id),
        builder: (context, tripSnap) {
          if (tripSnap.connectionState == ConnectionState.waiting) {
            // V2.8.2 S6：骨架→内容 300ms 淡接 morph
            return const AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _DetailSkeleton(key: ValueKey('detail-skeleton')),
            );
          }
          final trip = tripSnap.data;
          if (trip == null) {
            return const EmptyState(
                icon: AppIcons.compass, title: '行程不存在或已被删除', message: '回到列表看看其他旅程吧');
          }
          _currentTrip = trip;
          return StreamBuilder<List<TripItem>>(
            stream: _itemsStream ??= ref.read(tripsRepoProvider).watchItems(id),
            builder: (context, itemsSnap) {
              final items = itemsSnap.data ?? const <TripItem>[];
              // V2.8.2 S6：骨架→内容 300ms 淡接 morph
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: const ValueKey('detail-content'),
                  child: _DetailBody(
                trip: trip,
                items: items,
                canWrite: _canWrite,
                scrollController: _scroll,
                onItemLongPress: _showItemOps,
                onAddItem: _addItem,
                ensureWeather: _ensureWeather,
                onBind: () => _bindLedgerSheet(context, trip),
                onShowExpenses: () => _showExpensesSheet(context, trip),
                onQuickBill: (ctx, it) => _quickBillSheet(ctx, trip, it),
                multiSelect: _multiSelect,
                selectedIds: _selectedIds,
                onToggleSelect: (it) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (!_selectedIds.add(it.id)) _selectedIds.remove(it.id);
                  });
                },
                onEnterMultiSelect: (it) {
                  // V2.7.2 A12：viewer 只读
                  if (!_canWrite) return;
                  setState(() {
                    _multiSelect = true;
                    _selectedIds
                      ..clear()
                      ..add(it.id);
                  });
                },
                onExitMultiSelect: () => setState(() {
                  _multiSelect = false;
                  _selectedIds.clear();
                }),
                onBatchMove: (ids, dayIndex) async {
                  // V2.7.2 A12：viewer 只读
                  if (!_canWrite) return;
                  final target = trip.startEpochDay + dayIndex - 1;
                  await ref
                      .read(tripsRepoProvider)
                      .batchMove(trip.id, ids, target);
                  if (mounted) {
                    setState(() {
                      _multiSelect = false;
                      _selectedIds.clear();
                    });
                    _toast('已移动 ${ids.length} 项到第 $dayIndex 天');
                  }
                },
                onBatchDelete: (ids) async {
                  // V2.7.2 A12：viewer 只读
                  if (!_canWrite) return;
                  // V2.8.2 S6：并入统一 L2 危险确认（showDangerConfirm）
                  final ok = await showDangerConfirm(
                    context: context,
                    title: '删除 ${ids.length} 项安排？',
                    body: '共 ${ids.length} 项安排将被删除，关联账单会保留但解除绑定，不可恢复。',
                  );
                  if (!ok) return;
                  await ref.read(tripsRepoProvider).batchDelete(trip.id, ids);
                  if (mounted) {
                    setState(() {
                      _multiSelect = false;
                      _selectedIds.clear();
                    });
                    _toast('已删除 ${ids.length} 项');
                  }
                },
              ),
                ),
              );
            },
          );
        },
      ),
          // ---- 视图 1：攻略（原锦囊 S9 城市贴士并入） ----
          // V2.8.3.4：末尾留白与时间线同口径，避开胶囊底栏 + 底部停靠双段。
          KitTab(
            tripId: id,
            canEdit: _canWrite,
            bottomInset: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.dockedContentTail,
            ),
          ),
            ],
          ),
          // 底部停靠双段：时间线 / 攻略（原大纲/装配/锦囊页签收编：大纲入
          // 「更多」抽屉、装配改半屏抽屉、锦囊并入攻略）
          // V2.8.3.4：横向 inset 与全局胶囊底栏对齐（Spacing.lg），并紧贴其上方
          // （= actionButtonOffset，胶囊底栏总高 78+safe），两段视觉上连成一体。
          Positioned(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.actionButtonOffset,
            ),
            child: _DetailDock(
              index: _viewIndex,
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _viewIndex = i);
              },
            ),
          ),
        ],
      ),
    );
  }
  // ============ 条目操作 ============

  void _addItem(BuildContext context, TripItem? item) {
    // V2.7.2 A12：viewer 只读 —— 新增/编辑安排同走此入口。
    if (!_canWrite) {
      _toast('你是观察者，只能查看行程');
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => ItemEditScreen(tripId: _tripId!, item: item),
    ));
  }

  void _showItemOps(
      BuildContext context, TripItem item, List<TripItem> dayList) {
    // V2.7.2 A12：viewer 只读 —— 长按抽屉内的动作全部是写操作，整体拦截。
    if (!_canWrite) {
      _toast('你是观察者，只能查看行程');
      return;
    }
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
              icon: Icons.checklist_rounded,
              label: '多选',
              subtitle: '勾选多项后批量移动或删除',
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (mounted) {
                  setState(() {
                    _multiSelect = true;
                    _selectedIds
                      ..clear()
                      ..add(item.id);
                  });
                }
              },
            ),
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
              onTap: () async {
                Navigator.of(sheetContext).pop();
                // V2.8.2 S6：并入统一 L2 危险确认（showDangerConfirm）
                final ok = await showDangerConfirm(
                  context: context,
                  title: '删除「${item.name}」？',
                  body: '删除 1 项安排，关联账单会保留但解除绑定，不可恢复。',
                );
                if (!ok) return;
                HapticFeedback.mediumImpact();
                await repo.deleteItem(item.id); // ASSUMED(t2): 仅清 expense.tripItemId
                if (mounted) _toast('已删除');
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
                        icon: AppIcons.coins, title: '还没有旅行团', message: '先到「账本」页创建一个旅行团');
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
                        icon: AppIcons.wallet, title: '还没有关联账单', message: '记账时选择本行程即可关联到这里');
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
class _DetailBody extends ConsumerStatefulWidget {
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
    this.multiSelect = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.onEnterMultiSelect,
    this.onExitMultiSelect,
    this.onBatchMove,
    this.onBatchDelete,
    this.canWrite = true,
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

  // ===== 多选批量（V2.7.2 S4；状态在宿主层，长按菜单可直达） =====

  /// 多选模式开关；false 时以下回调可不传
  final bool multiSelect;
  final Set<String> selectedIds;
  final void Function(TripItem)? onToggleSelect;
  final void Function(TripItem)? onEnterMultiSelect;
  final VoidCallback? onExitMultiSelect;

  /// 批量移动到第 N 天（宿主执行 + toast）
  final Future<void> Function(List<String> ids, int dayIndex)? onBatchMove;

  /// 批量删除（宿主强确认 + 执行 + toast）
  final Future<void> Function(List<String> ids)? onBatchDelete;

  /// V2.7.2 A12：viewer 只读 —— 由宿主按角色解析后下传（未知按可写放开）。
  /// 此处不再是 `_canWrite` 私有字段：body 与宿主是两个类，角色只应有单一来源。
  final bool canWrite;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  /// 当前选中的天（epochDay）；null = 总览（展示全部按天分组）
  int? _selectedDay;

  /// 行程概览卡是否展开：默认缩略（一行要点），点开才是天气/清单/费用全貌
  bool _overviewExpanded = false;

  /// 已展开「备选 ×N」的天（V2.7.2 S8）
  final Set<int> _expandedBackupDays = {};

  Trip get trip => widget.trip;
  List<TripItem> get items => widget.items;  

  @override
  Widget build(BuildContext context) {
    final today = todayEpochDay();
    // 行程关联账单：入账徽章 + 计划vs实际 共用一份数据
    final bills =
        ref.watch(tripBillsProvider(trip.id)).value ?? const <Expense>[];
    // 每天区块的锚点：供「总览」点击跳转滚动定位用
    final dayKeys = <int, GlobalKey>{};
    for (final it in items) {
      dayKeys.putIfAbsent(it.dateEpochDay, GlobalKey.new);
    }
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

    final byDay = <int, List<TripItem>>{};
    for (final it in items) {
      (byDay[it.dateEpochDay] ??= []).add(it);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final days = byDay.keys.toList()..sort();

    // 选中了具体某天：自动校正到存在的天；半天无安排则回退总览
    if (_selectedDay != null && !days.contains(_selectedDay)) {
      _selectedDay = null;
    }

    final showAll = _selectedDay == null;
    final visibleDays =
        showAll ? days : [for (final d in days) if (d == _selectedDay) d];

    return Stack(
      children: [
        CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverToBoxAdapter(child: _HeaderHero(trip: trip, status: status, scrollController: widget.scrollController)),
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
            onTapLedger: trip.groupId == null ? widget.onBind : widget.onShowExpenses,
          ),
        ),
        // V2.8.3.2：「行程概览」折叠卡删除 —— 天数/安排数并入口袋信息，
        // 天气随行程上下文保留在时间线卡片流；日期栏成为唯一 day 导航。
        // 横向滑动日期栏 + 行尾「装配」入口（半屏抽屉唤起想去装配台）
        SliverToBoxAdapter(
          child: _DayPicker(
            trip: trip,
            days: days,
            items: items,
            selected: _selectedDay,
            onSelect: (d) {
              HapticFeedback.selectionClick();
              setState(() => _selectedDay = d);
            },
            onAssemble: widget.canWrite
                ? () => _openAssembleSheet(context, trip.id)
                : null,
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate(
              _buildDaySections(context, ref, latestUnsettledByItem, dayKeys, visibleDays, showAll)),
        ),
        // 尾部留白：内容可从悬浮胶囊导航下方穿过，末尾垫高保证最后一条可达
        // （V2.8.3.4：统一走 dockedContentTail —— 让位底部停靠双段 + FAB）
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.dockedContentTail,
            ),
          ),
        ),
        ],
      ),
      if (!widget.multiSelect)
      Positioned(
          right: Spacing.xl,
          // V2.8.3.4：FAB 停在底部停靠双段（时间线/攻略）之上
          bottom: AppBottomLayout.withSafeArea(
            context,
            AppBottomLayout.actionButtonOffset +
                AppBottomLayout.segmentDockHeight + Spacing.md,
          ),
          child: FloatingActionButton.extended(
            heroTag: 'fab-add-item-detail',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            onPressed: () => widget.onAddItem(context, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加安排'),
          ),
        ),
        if (widget.multiSelect)
          Positioned(
            left: Spacing.xl,
            right: Spacing.xl,
            bottom: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.actionButtonOffset + 62,
            ),
            child: _MultiSelectBar(
              count: widget.selectedIds.length,
              onSelectDayAll: () {
                for (final d in visibleDays) {
                  for (final it in (byDay[d] ?? const <TripItem>[])) {
                    widget.onToggleSelect?.call(it);
                  }
                }
              },
              onMove: widget.selectedIds.isEmpty || widget.onBatchMove == null
                  ? null
                  : () => _pickBatchMoveDay(context),
              onDelete: widget.selectedIds.isEmpty || widget.onBatchDelete == null
                  ? null
                  : () => widget.onBatchDelete!(widget.selectedIds.toList()),
              onExit: widget.onExitMultiSelect,
            ),
          ),
      ],
    );
  }

  /// 按天分组时间轴区块（[latestUnsettledByItem]：安排 id -> 最新未结算关联账单）
  List<Widget> _buildDaySections(BuildContext context, WidgetRef ref,
      Map<String, Expense> latestUnsettledByItem,
      Map<int, GlobalKey> dayKeys, List<int> visibleDays, bool showAll) {
    final byDay = <int, List<TripItem>>{};
    for (final it in items) {
      (byDay[it.dateEpochDay] ??= []).add(it);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final widgets = <Widget>[];
    if (visibleDays.isNotEmpty) {
      widgets.add(SectionHeader(
        title: showAll ? '每日安排' : '当天安排',
        subtitle: '轻点编辑 · 长按更多操作',
      ));
    }
    for (final day in visibleDays) {
      // S8 口径：备胎（backupOf != null）默认隐藏，天头计数展开灰显；
      // 不参与重排/多选/「有安排」计数
      final list = byDay[day]!.where((e) => e.backupOf == null).toList();
      final backups =
          byDay[day]!.where((e) => e.backupOf != null).toList();
      widgets.add(KeyedSubtree(
        key: dayKeys[day],
        child: _DayHeader(
          dayIndex: day - trip.startEpochDay + 1,
          day: day,
          count: list.length,
          onInsertDay: () => _onInsertDay(context),
          onRemoveDay: () =>
              _onRemoveDay(context, day - trip.startEpochDay + 1, list.length),
          canRemoveDay: tripDays(trip.startEpochDay, trip.endEpochDay) >= 2,
          onMultiSelect: widget.onEnterMultiSelect == null
              ? null
              : () => widget.onEnterMultiSelect!(list.first),
          backupCount: backups.length,
          backupsExpanded: _expandedBackupDays.contains(day),
          onToggleBackups: backups.isEmpty
              ? null
              : () => setState(() {
                    if (!_expandedBackupDays.remove(day)) {
                      _expandedBackupDays.add(day);
                    }
                  }),
        ),
      ));
      if (widget.multiSelect) {
        for (var i = 0; i < list.length; i++) {
          final it = list[i];
          widgets.add(Padding(
            padding:
                const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
            child: _SelectableTile(
              selected: widget.selectedIds.contains(it.id),
              onTap: () => widget.onToggleSelect?.call(it),
              child: _ItemTile(
                item: it,
                isFirst: i == 0,
                isLast: i == list.length - 1,
                linkedBillCents: latestUnsettledByItem[it.id]?.amountCents,
                onQuickBill: widget.onQuickBill,
                onOpenGuide: kIsWeb
                    ? null
                    : (it.guideRef == null || it.guideRef!.isEmpty)
                        ? null
                        : () => _openGuide(context, it),
              ),
            ),
          ));
        }
        continue;
      }
      // 当天重排（V2.8.3.4：长按才允许拖动）。
      // 原为无延迟的 Reorderable 拖拽监听 —— 手指一碰卡片即进入拖拽，滚动流
      // 里极易误拖（想去池同理）；改为 Delayed 版：按住约 500ms 后移动才开始
      // 拖拽，长按指纹仍归卡片的 onLongPress（长按不动 → 弹出操作抽屉）。
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: list.length,
          onReorder: (oldIndex, newIndex) async {
            // V2.7.2 A12：viewer 只读
            if (!widget.canWrite) return;
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = list.removeAt(oldIndex);
              list.insert(newIndex, moved);
            });
            final repo = ref.read(tripsRepoProvider);
            final ids = list.map((e) => e.id).toList();
            await repo.reorderDay(trip.id, day, ids);
          },
          itemBuilder: (context, i) {
            final it = list[i];
            return ReorderableDelayedDragStartListener(
              key: ValueKey(it.id),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: GestureDetector(
                  onTap: () => _openDetail(context, it),
                  onLongPress: () => widget.onItemLongPress(context, it, list),
                  child: _ItemTile(
                    item: it,
                    isFirst: i == 0,
                    isLast: i == list.length - 1,
                    linkedBillCents: latestUnsettledByItem[it.id]?.amountCents,
                    onQuickBill: widget.onQuickBill,
                    onOpenGuide: kIsWeb
                        ? null
                        : (it.guideRef == null || it.guideRef!.isEmpty)
                            ? null
                            : () => _openGuide(context, it),
                  ),
                ),
              ),
            );
          },
        ),
      ));
      // S8：备胎展开区（灰显，长按操作单）
      if (backups.isNotEmpty && _expandedBackupDays.contains(day)) {
        for (var i = 0; i < backups.length; i++) {
          final it = backups[i];
          widgets.add(Padding(
            padding:
                const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
            child: Opacity(
              opacity: 0.55,
              child: GestureDetector(
                onTap: () => _openDetail(context, it),
                onLongPress: () => _showBackupOps(context, it, list),
                child: _ItemTile(
                  item: it,
                  isFirst: false,
                  isLast: i == backups.length - 1,
                  linkedBillCents: null,
                ),
              ),
            ),
          ));
        }
      }
    }
    if (visibleDays.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.only(top: Spacing.huge),
        child: EmptyState(
          icon: Icons.map_rounded,
          title: '还没有安排',
          message: '点右下角「添加安排」，从第一天开始填充旅程',
        ),
      ));
    }
    return widgets;
  }

  /// 备胎操作单（V2.7.2 S8）：一键替换 / 转正 / 退回想去 / 删除。
  Future<void> _showBackupOps(
      BuildContext context, TripItem backup, List<TripItem> formalOfDay) async {
    final repo = ref.read(tripsRepoProvider);
    final main = formalOfDay.firstOrNull;
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Text('备选 · ${backup.name}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (main != null)
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text('一键替换「${main.name}」'),
              subtitle: const Text('互换正式/备选身份，时间字段不互换'),
              onTap: () => Navigator.pop(ctx, 'swap'),
            ),
          ListTile(
            leading: const Icon(Icons.vertical_align_top_rounded),
            title: const Text('转正（独立安排）'),
            onTap: () => Navigator.pop(ctx, 'promote'),
          ),
          ListTile(
            leading: const Icon(Icons.undo_rounded),
            title: const Text('退回想去'),
            onTap: () => Navigator.pop(ctx, 'wishlist'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded,
                color: Theme.of(ctx).colorScheme.error),
            title: Text('删除备选',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'swap':
        if (main == null) return;
        await repo.swapBackup(main.id, backup.id);
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('已替换')));
        break;
      case 'promote':
        await repo.promoteBackup(trip.id, backup.id);
        break;
      case 'wishlist':
        await repo.returnBackupToWishlist(trip.id, backup.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('已退回想去池')));
        break;
      case 'delete':
        await repo.deleteItem(backup.id);
        break;
    }
  }

  /// 打开安排详情页（详情页内可再进入编辑页）。
  void _openDetail(BuildContext context, TripItem item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ItemDetailScreen(tripId: trip.id, itemId: item.id),
    ));
  }

  /// 「攻略」角标（V2.7.2 S5 互链）：跳攻略页对应城并定位到条目。
  /// Web 端 /guide 路由未注册（角标不渲染，见调用点），此处不再判断。
  void _openGuide(BuildContext context, TripItem item) {
    final ref = item.guideRef;
    if (ref == null || ref.isEmpty) return;
    context.push('/guide',
        extra: GuideRouteArgs(tripId: trip.id, focusRef: ref));
  }

  // ===== 增减天数顺延（V2.7.2 S2） =====

  /// 批量移动：天序选择（含目标天信息），交给宿主回调执行
  Future<void> _pickBatchMoveDay(BuildContext context) async {
    final n = tripDays(trip.startEpochDay, trip.endEpochDay);
    if (n < 1) return;
    final k = await showDayInsertPicker(context, n: n);
    if (k == null || !context.mounted) return;
    // k=0（最前）对「移动」无意义：clamp 到 1..N
    final dayIndex = k < 1 ? 1 : k;
    await widget.onBatchMove?.call(widget.selectedIds.toList(), dayIndex);
  }

  Future<void> _onInsertDay(BuildContext context) async {
    final n = tripDays(trip.startEpochDay, trip.endEpochDay);
    if (n < 1) return;
    final k = await showDayInsertPicker(context, n: n);
    if (k == null || !context.mounted) return;
    HapticFeedback.mediumImpact();
    final repo = ref.read(tripsRepoProvider);
    final ops = insertDay(
      startEpochDay: trip.startEpochDay,
      endEpochDay: trip.endEpochDay,
      items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
      k: k,
    );
    await repo.applyDayOps(trip.id, ops);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已插入一天，后续安排自动顺延')));
    }
  }

  Future<void> _onRemoveDay(BuildContext context, int k, int affected) async {
    final n = tripDays(trip.startEpochDay, trip.endEpochDay);
    if (n < 2 || k < 1 || k > n) return;
    final mode = await showDayRemovePicker(
      context,
      k: k,
      n: n,
      affectedCount: affected,
    );
    if (mode == null || !context.mounted) return;
    final repo = ref.read(tripsRepoProvider);
    try {
      final ops = removeDay(
        startEpochDay: trip.startEpochDay,
        endEpochDay: trip.endEpochDay,
        items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
        k: k,
        mode: mode,
      );
      await repo.applyDayOps(trip.id, ops);
      if (context.mounted) {
        final text = switch (mode) {
          RemoveMode.shift => '已删除第 $k 天，安排顺延到次日',
          RemoveMode.merge => '已删除第 $k 天，安排并入前一日',
          RemoveMode.discard => '已删除第 $k 天及其安排',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      }
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
                        // V2.8.3.1：封面签条统一走 GlassTokens
                        color: Colors.white.withValues(alpha: GlassTokens.coverPillFillAlpha),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: GlassTokens.coverPillBorderAlpha)),
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
/// V2.8.2 S1：天气 emoji → 图标渲染映射（数据字段 iconEmoji 只读不动）。
/// 8 常见天气 + fallback；未知 emoji 原样显示（静默降级，guideRef 同哲学）。
IconData? weatherIconFor(String emoji) {
  final map = <String, IconData>{
    '☀️': Icons.wb_sunny_rounded,
    '🌤': Icons.wb_sunny_rounded,
    '⛅': Icons.cloud_rounded,
    '🌥': Icons.cloud_rounded,
    '☁️': Icons.cloud_rounded,
    '多云': Icons.cloud_rounded,
    '🌧': Icons.water_drop_rounded,
    '🌧️': Icons.water_drop_rounded,
    '⛈': Icons.bolt_rounded,
    '⛈️': Icons.bolt_rounded,
    '🌨': Icons.ac_unit_rounded,
    '❄️': Icons.ac_unit_rounded,
    '🌫': Icons.blur_on_rounded,
    '🌫️': Icons.blur_on_rounded,
  };
  return map[emoji.trim()];
}

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
                    // V2.8.2 S1：天气图标渲染映射（未知 emoji 原样回退）
                    if (weatherIconFor(d.iconEmoji) != null)
                      Icon(weatherIconFor(d.iconEmoji),
                          size: 16, color: scheme.onSurfaceVariant)
                    else
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


/// 多选模式的可勾选卡容器（V2.7.2 S4）：左侧勾选圈 + 原卡面
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Spacing.lg),
            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 多选批量条（V2.7.2 S4）：全选本天 / 移动到第 N 天 / 删除 / 退出
class _MultiSelectBar extends StatelessWidget {
  const _MultiSelectBar({
    required this.count,
    required this.onSelectDayAll,
    required this.onMove,
    required this.onDelete,
    required this.onExit,
  });

  final int count;
  final VoidCallback onSelectDayAll;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      borderRadius: AppRadius.button,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onExit,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('退出'),
            ),
            Expanded(
              child: Text('已选 $count 项',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: onSelectDayAll,
              child: const Text('全选本天'),
            ),
            IconButton(
              tooltip: '移动到第 N 天',
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_rounded),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            ),
          ],
        ),
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
    this.onInsertDay,
    this.onRemoveDay,
    this.canRemoveDay = true,
    this.onMultiSelect,
    this.backupCount = 0,
    this.backupsExpanded = false,
    this.onToggleBackups,
  });

  final int dayIndex;
  final int day;
  final int count;

  /// 增减天数入口（V2.7.2 S2）：null = 不渲染（viewer 隐藏不置灰）
  final VoidCallback? onInsertDay;
  final VoidCallback? onRemoveDay;
  final bool canRemoveDay;

  /// 多选模式入口（V2.7.2 S4）：null = 不渲染
  final VoidCallback? onMultiSelect;

  /// 备选计数与展开开关（V2.7.2 S8）
  final int backupCount;
  final bool backupsExpanded;
  final VoidCallback? onToggleBackups;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasMenu = onInsertDay != null || onMultiSelect != null;
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
          if (backupCount > 0) ...[
            const SizedBox(width: Spacing.sm),
            InkWell(
              borderRadius: AppRadius.capsule,
              onTap: onToggleBackups,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.capsule,
                  border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      backupsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.bookmark_rounded,
                      size: 12,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text('备选 ×$backupCount',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption - 2,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ],
          const Spacer(),
          if (hasMenu)
            PopupMenuButton<String>(
              tooltip: '增减天数',
              padding: EdgeInsets.zero,
              splashRadius: 20,
              icon: Icon(Icons.more_vert_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
              onSelected: (v) {
                if (v == 'insert') onInsertDay?.call();
                if (v == 'remove') onRemoveDay?.call();
                if (v == 'multiselect') onMultiSelect?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'insert',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.add_circle_outline_rounded),
                      title: Text('插入一天…'),
                    )),
                if (canRemoveDay)
                  const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.remove_circle_outline_rounded),
                        title: Text('删除此天…'),
                      )),
                if (onMultiSelect != null)
                  const PopupMenuItem(
                      value: 'multiselect',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.checklist_rounded),
                        title: Text('多选批量…'),
                      )),
              ],
            ),
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
    this.onOpenGuide,
  });

  final TripItem item;
  final bool isFirst;
  final bool isLast;

  /// 最新未结算关联账单金额（null = 未入账）
  final int? linkedBillCents;
  final void Function(BuildContext, TripItem)? onQuickBill;

  /// 「攻略」角标点击（V2.7.2 S5 互链）；null = 不渲染角标。
  final VoidCallback? onOpenGuide;

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
                    if (item.guideRef != null &&
                        item.guideRef!.isNotEmpty &&
                        onOpenGuide != null)
                      GestureDetector(
                        onTap: onOpenGuide,
                        child: Container(
                          margin: const EdgeInsets.only(left: Spacing.sm),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.10),
                            borderRadius: AppRadius.capsule,
                            border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  size: 11, color: scheme.primary),
                              const SizedBox(width: 3),
                              Text('攻略',
                                  style: TextStyle(
                                      fontSize: AppFontSizes.caption - 2,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary)),
                            ],
                          ),
                        ),
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
    // drift 行 -> 领域记录（统一走 expenseRecordOf：退款已归为负数，
    // 计划 vs 实际 才会把退款正确冲减到实际支出里）
    final records = [
      for (final e in bills)
        if (expenseRecordOf(e) != null) expenseRecordOf(e)!,
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

/// 行程概览：默认「缩略」成一行要点（天数 / 安排数 / 费用合计），
/// 点开头才展示天气 / 清单 / 计划 vs 实际 全貌 —— 缩略 ≠ 隐藏。
/// 选中具体某天时（showAll=false）只显示当天的一行速览。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.trip,
    required this.items,
    required this.bills,
    required this.ensureWeather,
    required this.tripId,
    required this.showAll,
    required this.selectedDay,
    required this.expanded,
    required this.onToggle,
  });

  final Trip trip;
  final List<TripItem> items;
  final List<Expense> bills;
  final Future<List<WeatherDay>?> Function(Trip, List<TripItem>) ensureWeather;
  final String tripId;

  /// 是否处于「总览」态（横向选择栏首项）；false 表示只看某一天，概览精简
  final bool showAll;

  /// 当前选中的天（总览态为 null）
  final int? selectedDay;

  /// 总览态下是否展开全貌（默认缩略成一行要点）
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 缩略态的一行要点：行程总览的「骨架信息」，绝不因缩略而消失
    final dayCount = tripTotalDays(trip.startEpochDay, trip.endEpochDay);
    var planCost = 0;
    for (final it in items) {
      if (it.costCents != null && it.costCurrency == 'CNY') {
        planCost += it.costCents!;
      }
    }
    final summaryParts = <String>[
      '共 $dayCount 天',
      '${items.length} 个安排',
      if (planCost > 0) '计划 ¥${MoneyFormat.fenToYuan(planCost)}',
    ];

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 可点开的头部：总览主题 + 一行要点 + 展开/收起指示
          InkWell(
            onTap: showAll ? onToggle : null,
            borderRadius: AppRadius.input,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    showAll ? '行程概览' : '这一天',
                    style: TextStyle(
                        fontSize: AppFontSizes.body, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: Spacing.sm),
                  if (!showAll)
                    Text(
                      _dayCaption(trip),
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant),
                    )
                  else
                    Expanded(
                      child: Text(
                        summaryParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (showAll) ...[
                    const SizedBox(width: Spacing.sm),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!showAll)
            _DayMiniSummary(items: items, day: selectedDay)
          else if (expanded) ...[
            const SizedBox(height: Spacing.sm),
            _WeatherStrip(trip: trip, items: items, ensureWeather: ensureWeather),
            const SizedBox(height: Spacing.md),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            _ChecklistEntryCard(tripId: tripId),
            const SizedBox(height: Spacing.md),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            // S8 口径：备胎不参与「计划 vs 实际」计划侧汇总
            _PlanActualCard(
                trip: trip,
                items:
                    items.where((e) => e.backupOf == null).toList(),
                bills: bills),
          ],
        ],
      ),
    );
  }

  String _dayCaption(Trip trip) {
    final d = selectedDay;
    if (d == null) return '';
    return 'D${d - trip.startEpochDay + 1} · ${cnFullDate(d)}';
  }
}

/// 「这一天」速览卡：当天安排数与计划费用的一行小结（缩略而不隐藏）
class _DayMiniSummary extends StatelessWidget {
  const _DayMiniSummary({required this.items, this.day});

  final List<TripItem> items;

  /// 选中的那天（epochDay）
  final int? day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var count = 0;
    var cost = 0;
    for (final it in items) {
      if (day != null && it.dateEpochDay != day) continue;
      if (it.costCents != null && it.costCurrency == 'CNY') cost += it.costCents!;
      count++;
    }
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Text(
        '$count 个安排' +
            (cost > 0 ? ' · 计划 ¥${MoneyFormat.fenToYuan(cost)}' : ''),
        style: TextStyle(
            fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// 横向滑动日期选择栏：最前固定「总览」，后面每一天一个胶囊；选中某天只看当天。
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.trip,
    required this.days,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.onAssemble,
  });

  final Trip trip;
  final List<int> days;
  final List<TripItem> items;
  final int? selected;
  final ValueChanged<int?> onSelect;

  /// V2.8.3.2：行尾「装配」入口（半屏抽屉唤起想去装配台）
  final VoidCallback? onAssemble;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length + (onAssemble != null ? 2 : 1),
          separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
          itemBuilder: (context, i) {
            // 第 0 项固定为「总览」
            if (i == 0) {
              return _DayChip(
                label: '总览',
                caption: '全部${days.length}天',
                active: selected == null,
                icon: Icons.view_agenda_outlined,
                onTap: () => onSelect(null),
              );
            }
            // V2.8.3.2：行尾「装配」入口（想去池落点，半屏抽屉）
            if (onAssemble != null && i == days.length + 1) {
              return _DayChip(
                label: '装配',
                caption: '想去池落点',
                active: false,
                icon: Icons.extension_rounded,
                onTap: onAssemble!,
              );
            }
            final day = days[i - 1];
            final count = items.where((it) => it.dateEpochDay == day).length;
            return _DayChip(
              label: 'D${day - trip.startEpochDay + 1}',
              caption: fmtMonthDayOfEpoch(day),
              active: selected == day,
              badge: count,
              onTap: () => onSelect(day),
            );
          },
        ),
      ),
    );
  }
}

/// V2.8.3.2：详情页底部停靠双段切换（时间线 / 攻略）。
/// 实色胶囊（选中主色填充），悬浮于全局胶囊底栏上方；替代原四页签。
class _DetailDock extends StatelessWidget {
  const _DetailDock({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: index == i ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      i == 0 ? '时间线' : '攻略',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            index == i ? FontWeight.w800 : FontWeight.w600,
                        color: index == i
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 横向胶囊：选中态主色填充；badge 显示当天安排条数
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.caption,
    required this.active,
    required this.onTap,
    this.badge,
    this.icon,
  });

  final String label;
  final String caption;
  final bool active;
  final VoidCallback onTap;
  final int? badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active
          ? scheme.primary
          : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppRadius.cardValue),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardValue),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        size: 15,
                        color: active ? scheme.onPrimary : scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w800,
                      color: active ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? scheme.onPrimary.withValues(alpha: 0.2)
                            : scheme.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.capsule,
                      ),
                      child: Text(
                        '$badge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              active ? scheme.onPrimary : scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSizes.caption - 2,
                  color: active
                      ? scheme.onPrimary.withValues(alpha: 0.85)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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
        // V2.8.3.1：封面签条统一走 GlassTokens
        color: Colors.white.withValues(alpha: GlassTokens.coverPillFillAlpha),
        borderRadius: AppRadius.capsule,
        border: Border.all(
            color: Colors.white.withValues(alpha: GlassTokens.coverPillBorderAlpha)),
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
      // V2.8.2 S6：快捷卡接 PressableScale（按压缩放；点按仍由内层 InkWell 承接）
      return Expanded(
        child: PressableScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
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
            // V2.8.3.2：长文案说明条 → 紧凑徽章（绑定关系一眼可见，点账本看账单）
            if (bound != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.luggage_rounded,
                      size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text('已关联账本',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption - 2,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ]),
              ),
            Row(
              children: [
                action(Icons.map_rounded, '地图',
                    () => context.push('/trips/map', extra: tripId)),
                action(Icons.photo_library_rounded, '相册',
                    () => context.push('/trips/album', extra: tripId)),
                // 目的地攻略：与地图/相册同排（用户变更 2026-09-06；Web 仍不注册路由）
                // 2026-09 改走顶层 /guide：从行程详情打开也不切走行程 Tab
                if (!kIsWeb)
                  action(
                      Icons.menu_book_rounded,
                      '攻略',
                      () => context.push('/guide',
                          extra: GuideRouteArgs(tripId: tripId))),
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

/// V2.7.2 A12：详情页写权限（未知角色按可写放开；与 `trip_access.dart` 同源）。
///
/// 顶层抽屉函数没有 build 上下文缓存，故就地从 Provider 容器同步读取；
/// 详情页 build 期已 watch 过同一 provider，此处读到的通常已是解析结果。
bool _tripCanWrite(BuildContext context, String tripId) =>
    ProviderScope.containerOf(context)
        .read(tripAccessProvider(tripId))
        .valueOrNull
        ?.canWrite ??
    true;

/// 「更多」抽屉：收纳使用频率较低的 PDF / 海报 / 模板入口，保持主工具行精简
void _openMoreSheet(BuildContext context, String tripId) {
  HapticFeedback.selectionClick();
  final canWrite = _tripCanWrite(context, tripId);
  showDraggableSheet(
    context: context,
    initialChildSize: 0.38,
    minChildSize: 0.28,
    // V2.8.3.4：内容必须挂在 DraggableScrollableSheet 提供的 scrollController
    // 上，否则抽屉没有可拖拽的滚动体 —— 表现为「展开后无法再次上拉」。
    builder: (ctx, sheetScroll) => ListView(
      controller: sheetScroll,
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.md, Spacing.xl, Spacing.xl),
      children: [
          Text('更多操作',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppFontSizes.bodyLarge)),
          const SizedBox(height: Spacing.md),
          // V2.8.3.2：大纲收入「更多」（原页签移除，往返式导入导出功能不删）
          ListTile(
            leading: const Icon(Icons.segment_rounded),
            title: const Text('行程大纲'),
            subtitle: const Text('文本大纲查看 / 编辑，支持往返导入导出'),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(ctx).pop();
              _openOutlineSheet(context, tripId);
            },
          ),
          // V2.7.2 A12：viewer 只读 —— 存模板是写操作，观察者不可见
          if (canWrite)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('存为行程模板'),
              subtitle: const Text('保存安排结构，之后可一键复用'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.of(ctx).pop();
                await _saveAsTemplate(context, tripId);
              },
            ),
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
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('分享行程'),
            subtitle: const Text('海报图片，或生成只读链接（对方无需登录）'),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/trips/share', extra: tripId);
            },
          ),
      ],
    ),
  );
}

/// V2.8.3.2：装配半屏抽屉 —— 想去装配台不再占页签/全屏，从 Day 行「装配」唤起。
/// 落点/撤销/容量/备胎引擎零改动（AssemblePanel 原样承载）。
void _openAssembleSheet(BuildContext context, String tripId) {
  HapticFeedback.selectionClick();
  // V2.7.2 A12：viewer 只读（装配台落点即写库）
  final canEdit = _tripCanWrite(context, tripId);
  showDraggableSheet(
    context: context,
    initialChildSize: 0.82,
    minChildSize: 0.5,
    maxChildSize: 0.94,
    builder: (_, __) => AssemblePanel(tripId: tripId, canEdit: canEdit),
  );
}

/// V2.8.3.2：大纲抽屉 —— 原页签移入「更多」，文本编辑 + 往返式导入导出原样保留。
void _openOutlineSheet(BuildContext context, String tripId) {
  HapticFeedback.selectionClick();
  // V2.7.2 A12：viewer 只读（大纲面板自带只读态：文本域只读、无导入按钮）
  final canEdit = _tripCanWrite(context, tripId);
  showDraggableSheet(
    context: context,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    maxChildSize: 0.94,
    builder: (_, __) => OutlineTab(tripId: tripId, canEdit: canEdit),
  );
}

/// 把行程安排存为模板（结构快照，同名覆盖）
Future<void> _saveAsTemplate(BuildContext context, String tripId) async {
  final container = ProviderScope.containerOf(context);
  final repo = container.read(tripsRepoProvider);
  final trip = await repo.getById(tripId);
  if (trip == null) return;
  final items = await repo.getItems(tripId);
  if (items.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('行程还没有安排，先加点内容再存模板吧')));
    return;
  }
  await saveTemplate(TripTemplate(
    id: newId('tpl'),
    name: trip.name,
    destination: trip.destination,
    emoji: trip.emoji,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
    items: [
      for (final i in items)
        TripTemplateItem(
          day: (i.dateEpochDay - trip.startEpochDay) + 1,
          name: i.name,
          type: i.type,
          startTimeMin: i.startTimeMin,
          costCents: i.costCents,
          address: i.address,
          note: i.note,
        ),
    ],
  ));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('「${trip.name}」已存为模板（${items.length} 条安排）')));
  }
}

/// 详情加载骨架
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({super.key});

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
