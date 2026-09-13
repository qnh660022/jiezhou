/// 协作空间详情页（V2.6.6.2 §6.1~§6.4，代号 S5）。
///
/// 路由：`/companions/space/:id`，支持 `?tab=trip|ledger|members|events`。
///
/// 四区块（§6.1）：
/// 1. 行程区：关联行程概要 + 行程项协作列表（editor/owner 可增删改；viewer 只读）。
///    写路径全部走 `upsert_trip_item_collab` / `delete_trip_item_collab` RPC，
///    成功后本地镜像合流，**不直写本地业务表**（与 shared_ledger 同一模式）。
/// 2. 账本区：嵌入 S4 抽出的四能力组件（账单/成员/统计/结算），数据源走共享镜像。
/// 3. 成员区：成员列表 + 角色徽标；owner 可改角色/移除/生成邀请码；成员可自助退出。
/// 4. 动态区：`space_events` 倒序流；未知 action 显示「更新了空间」。
///
/// 权限矩阵（§6.2）在 UI 与数据两侧同时生效：无权限的操作**隐藏，不置灰**。
library;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/repo/travel_spaces_repo.dart' show spaceActionLabel;
import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/widgets/collab_polling_scope.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../../ledger/widgets/shared_ledger_sections.dart';
import '../../today/today_providers.dart';
import '../../trips/screens/item_detail_screen.dart';
import '../space_actions.dart';
import '../widgets/space_widgets.dart';

class SpaceDetailScreen extends ConsumerStatefulWidget {
  const SpaceDetailScreen({super.key, required this.spaceId, this.initialTab});

  final String spaceId;
  final String? initialTab;

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabKeys = ['trip', 'ledger', 'members', 'events'];
  static const List<String> _tabLabels = ['行程', '账本', '成员', '动态'];

  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: _tabKeys.indexOf(widget.initialTab ?? 'trip').clamp(0, 3),
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(travelSpacesRepoProvider);
    final uid = ref.watch(currentUserIdProvider);
    final engine = ref.watch(syncEngineProvider);

    return CollabPollingScope(
      child: StreamBuilder<TravelSpace?>(
        stream: repo.watchSpace(widget.spaceId),
        builder: (context, spaceSnap) {
          final space = spaceSnap.data;
          if (space == null) {
            // 空间还没合流到本地（刚加入 / 刚建）→ 给骨架而不是"不存在"
            if (spaceSnap.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: GlassAppBar(title: '旅伴空间'),
                body: const Padding(
                  padding: EdgeInsets.all(Spacing.xl),
                  child: SkeletonBox(height: 120, radius: AppRadius.cardValue),
                ),
              );
            }
            return Scaffold(
              appBar: GlassAppBar(title: '旅伴空间'),
              body: const EmptyState(
                emoji: '🧭',
                title: '空间不存在或已删除',
                message: '回到旅伴中心看看其它空间',
              ),
            );
          }
          return StreamBuilder<List<SpaceMember>>(
            stream: repo.watchMembers(widget.spaceId),
            builder: (context, memberSnap) {
              final members = memberSnap.data ?? const <SpaceMember>[];
              final myRole = _roleOf(members, uid) ??
                  engine?.mySpaceRoleOf(widget.spaceId) ??
                  (space.createdBy == uid ? SpaceRole.owner : null);
              final isOwner = myRole == SpaceRole.owner;
              final canWrite = SpaceRole.canEdit(myRole);
              return StreamBuilder<List<SpaceEvent>>(
                stream: repo.watchEvents(widget.spaceId, limit: 1),
                builder: (context, eventSnap) {
                  final latest = (eventSnap.data ?? const <SpaceEvent>[]);
                  return Scaffold(
                    appBar: GlassAppBar(
                      title: space.name,
                      actions: [
                        IconButton(
                          tooltip: '成员管理',
                          icon: const Icon(Icons.group_rounded),
                          onPressed: () => _tabs.animateTo(2),
                        ),
                        if (isOwner)
                          IconButton(
                            tooltip: '邀请旅伴',
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            onPressed: () => showSpaceInviteSheet(context,
                                spaceId: space.id, spaceName: space.name),
                          ),
                        IconButton(
                          tooltip: '空间设置',
                          icon: const Icon(Icons.more_horiz_rounded),
                          onPressed: () => _openSettings(space, isOwner),
                        ),
                      ],
                    ),
                    body: Column(
                      children: [
                        _Hero(
                          space: space,
                          members: members,
                          myRole: myRole,
                          unread: _unreadCount(latest),
                        ),
                        TabBar(
                          controller: _tabs,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: [for (final l in _tabLabels) Tab(text: l)],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _TripSection(
                                space: space,
                                canWrite: canWrite,
                              ),
                              _LedgerSection(
                                space: space,
                                myRole: myRole,
                                online: ref.watch(cloudClientProvider) != null,
                              ),
                              _MembersSection(
                                space: space,
                                members: members,
                                myRole: myRole,
                              ),
                              _EventsSection(spaceId: space.id),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String? _roleOf(List<SpaceMember> members, String? uid) {
    if (uid == null) return null;
    for (final m in members) {
      if (m.userId == uid) return m.role;
    }
    return null;
  }

  int _unreadCount(List<SpaceEvent> latest) {
    if (latest.isEmpty) return 0;
    final store = ref.read(todayLocalStoreProvider);
    final seen = store.spaceEventsSeenMs(widget.spaceId);
    return latest.first.createdMs > seen ? 1 : 0;
  }

  Future<void> _openSettings(TravelSpace space, bool isOwner) async {
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.5,
      builder: (ctx, scrollController) => _SpaceSettingsSheet(
        space: space,
        isOwner: isOwner,
        scrollController: scrollController,
      ),
    );
  }
}

// ============================================================
// Hero 层（§6.4：空间名 headline(28) + 胶囊徽标 + 头像叠放 + 未读角标）
// ============================================================

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.space,
    required this.members,
    required this.myRole,
    required this.unread,
  });

  final TravelSpace space;
  final List<SpaceMember> members;
  final String? myRole;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final db = ref.read(dbProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            space.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: Spacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.error,
                              borderRadius: AppRadius.capsule,
                            ),
                            child: Text('新动态',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onError)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    _HeroBadges(space: space, myRole: myRole, db: db),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              SpaceAvatarStack(
                names: [for (final m in members) m.displayName],
                size: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadges extends StatelessWidget {
  const _HeroBadges({required this.space, required this.myRole, required this.db});

  final TravelSpace space;
  final String? myRole;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String? trip, String? group})>(
      future: _names(),
      builder: (context, snap) {
        final names = snap.data;
        return Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            if (space.tripId != null)
              _Capsule(
                emoji: '🧳',
                label: names?.trip ?? '关联行程',
              ),
            if (space.groupId != null)
              _Capsule(
                emoji: '💰',
                label: names?.group ?? '关联账本',
              ),
            _Capsule(
              emoji: '👤',
              label: '我的角色：${myRole == null ? '成员' : SpaceRole.label(myRole!)}',
            ),
            if (space.status == 'archived') const _Capsule(emoji: '📦', label: '已归档'),
          ],
        );
      },
    );
  }

  Future<({String? trip, String? group})> _names() async {
    String? trip;
    String? group;
    if (space.tripId != null) {
      final rows =
          await (db.select(db.trips)..where((t) => t.id.equals(space.tripId!))).get();
      if (rows.isEmpty) {
        final shared = await (db.select(db.sharedTrips)
              ..where((t) => t.id.equals(space.tripId!)))
            .get();
        trip = shared.isEmpty ? null : shared.first.name;
      } else {
        trip = rows.first.name;
      }
    }
    if (space.groupId != null) {
      final rows =
          await (db.select(db.groups)..where((g) => g.id.equals(space.groupId!))).get();
      if (rows.isEmpty) {
        final shared = await (db.select(db.sharedGroups)
              ..where((g) => g.id.equals(space.groupId!)))
            .get();
        group = shared.isEmpty ? null : shared.first.name;
      } else {
        group = rows.first.name;
      }
    }
    return (trip: trip, group: group);
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.capsule,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 1 行程区
// ============================================================

class _TripSection extends ConsumerStatefulWidget {
  const _TripSection({required this.space, required this.canWrite});

  final TravelSpace space;
  final bool canWrite;

  @override
  ConsumerState<_TripSection> createState() => _TripSectionState();
}

class _TripSectionState extends ConsumerState<_TripSection> {
  @override
  Widget build(BuildContext context) {
    final tripId = widget.space.tripId;
    if (tripId == null) {
      return ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xxxl),
        children: [
          CompanionSectionCard(
            title: '行程区',
            child: companionEmpty('还没关联行程',
                '在空间设置里关联一个行程，旅伴就能一起改行程安排了。'),
          ),
        ],
      );
    }
    final repo = ref.watch(travelSpacesRepoProvider);
    return FutureBuilder<bool>(
      future: repo.isMyTrip(tripId),
      builder: (context, mineSnap) {
        if (!mineSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(Spacing.xl),
            child: SkeletonBox(height: 160, radius: AppRadius.cardValue),
          );
        }
        final mine = mineSnap.data!;
        return StreamBuilder<List<_ItemView>>(
          stream: mine
              ? (ref.read(dbProvider).select(ref.read(dbProvider).tripItems)
                    ..where((t) => t.tripId.equals(tripId)))
                  .watch()
                  .map((rows) => [
                        for (final r in rows)
                          _ItemView(
                            id: r.id,
                            tripId: r.tripId,
                            dateEpochDay: r.dateEpochDay,
                            type: r.type,
                            name: r.name,
                            address: r.address,
                            startTimeMin: r.startTimeMin,
                            note: r.note,
                            sortOrder: r.sortOrder,
                          ),
                      ])
              : repo.watchCollabTripItems(tripId).map((rows) => [
                    for (final r in rows)
                      _ItemView(
                        id: r.id,
                        tripId: r.tripId,
                        dateEpochDay: r.dateEpochDay,
                        type: r.type,
                        name: r.name,
                        address: r.address,
                        startTimeMin: r.startTimeMin,
                        note: r.note,
                        sortOrder: r.sortOrder,
                      ),
                  ]),
          builder: (context, itemSnap) {
            final items = itemSnap.data ?? const <_ItemView>[];
            return FutureBuilder<Trip?>(
              future: _trip(tripId),
              builder: (context, tripSnap) => ListView(
                padding: const EdgeInsets.only(bottom: Spacing.xxxl),
                children: [
                  CompanionSectionCard(
                    title: '行程概要',
                    child: _TripSummary(
                      view: tripSnap.data,
                      mine: mine,
                      itemCount: items.length,
                    ),
                  ),
                  CompanionSectionCard(
                    title: '行程安排',
                    subtitle: widget.canWrite
                        ? '你可以直接编辑，旅伴会同步看到'
                        : '观察者只能查看',
                    child: items.isEmpty
                        ? companionEmpty('还没有安排', '把要去的点排进去，旅伴一起补全。')
                        : _ItemList(
                            items: items,
                            canWrite: widget.canWrite,
                            onEdit: (v) => _editItem(tripId, v),
                            onDelete: (v) => _deleteItem(v),
                            onOpen: (v) => _openDetail(tripId, v, mine),
                          ),
                  ),
                  if (widget.canWrite)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.xl, Spacing.md, Spacing.xl, 0),
                      child: PrimaryButton(
                        label: '新增安排',
                        icon: Icons.add_rounded,
                        onPressed: () => _editItem(tripId, null),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Trip?> _trip(String tripId) async {
    final db = ref.read(dbProvider);
    final mine = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).get();
    if (mine.isNotEmpty) return mine.first;
    // 他人行程：用镜像行构造一个只读 Trip（仅供摘要展示）
    final shared =
        await (db.select(db.sharedTrips)..where((t) => t.id.equals(tripId))).get();
    if (shared.isEmpty) return null;
    final s = shared.first;
    return Trip(
      id: s.id,
      name: s.name,
      destination: s.destination,
      emoji: s.emoji,
      cover: s.cover,
      startEpochDay: s.startEpochDay,
      endEpochDay: s.endEpochDay,
      note: s.note,
      groupId: s.groupId,
      archived: s.archived,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  void _openDetail(String tripId, _ItemView v, bool mine) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ItemDetailScreen(
        tripId: tripId,
        itemId: v.id,
        itemOverride: mine ? null : v.toTripItem(),
        readOnly: !widget.canWrite,
      ),
    ));
  }

  Future<void> _editItem(String tripId, _ItemView? existing) async {
    final result = await showDraggableSheet<_ItemDraft>(
      context: context,
      initialChildSize: 0.8,
      minChildSize: 0.55,
      builder: (ctx, scrollController) => _CollabItemSheet(
        scrollController: scrollController,
        initial: existing,
        defaultDay: widget.space.tripId == null
            ? todayEpochDay()
            : existing?.dateEpochDay ?? todayEpochDay(),
      ),
    );
    if (result == null || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = <String, dynamic>{
      'id': existing?.id ?? 'ti_${now}_${result.name.hashCode.abs()}',
      'trip_id': tripId,
      'date_epoch_day': result.dateEpochDay,
      'type': existing?.type ?? 'attraction',
      'name': result.name,
      'address': result.address,
      'note': result.note,
      'start_time_min': result.startTimeMin,
      'sort_order': existing?.sortOrder ?? 0,
      'cost_currency': 'CNY',
      'from_name': '',
      'from_address': '',
      'to_name': '',
      'to_address': '',
      'created_ms': now,
    };
    final err = await SpaceActions.upsertTripItem(ref,
        spaceId: widget.space.id, item: item);
    if (!mounted) return;
    _toast(err.isEmpty ? '已同步给旅伴' : spaceErrorText(err));
  }

  Future<void> _deleteItem(_ItemView v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('删除这条安排？'),
        content: Text('「${v.name}」会从所有旅伴的设备上消失。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await SpaceActions.deleteTripItem(ref,
        spaceId: widget.space.id, itemId: v.id, summary: v.name);
    if (!mounted) return;
    _toast(err.isEmpty ? '已删除' : spaceErrorText(err));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 中立行程项视图（业务表行与镜像行统一，避免两套渲染分支）。
class _ItemView {
  const _ItemView({
    required this.id,
    required this.tripId,
    required this.dateEpochDay,
    required this.type,
    required this.name,
    required this.address,
    required this.startTimeMin,
    required this.note,
    required this.sortOrder,
  });

  final String id;
  final String tripId;
  final int dateEpochDay;
  final String type;
  final String name;
  final String address;
  final int? startTimeMin;
  final String note;
  final int sortOrder;

  String get timeText {
    final t = startTimeMin;
    if (t == null) return '全天';
    final h = (t ~/ 60).toString().padLeft(2, '0');
    final m = (t % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  TripItem toTripItem() => TripItem(
        id: id,
        tripId: tripId,
        dateEpochDay: dateEpochDay,
        type: type,
        name: name,
        address: address,
        lat: null,
        lng: null,
        photoUri: null,
        startTimeMin: startTimeMin,
        durationMin: null,
        costCents: null,
        costCurrency: 'CNY',
        note: note,
        fromName: '',
        fromAddress: '',
        fromLat: null,
        fromLng: null,
        toName: '',
        toAddress: '',
        toLat: null,
        toLng: null,
        flightNo: null,
        sortOrder: sortOrder,
        createdAt: 0,
        updatedAt: 0,
      );
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.view, required this.mine, required this.itemCount});

  final Trip? view;
  final bool mine;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (view == null) {
      return Text('关联的行程还没同步下来',
          style: TextStyle(
              fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant));
    }
    final t = view!;
    final days = tripDays(t.startEpochDay, t.endEpochDay);
    return Row(
      children: [
        CompanionLeadingIcon(icon: Icons.route_rounded),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t.emoji} ${t.name}',
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
              const SizedBox(height: 2),
              Text(
                '${fmtMonthDayOfEpoch(t.startEpochDay)} - '
                '${fmtMonthDayOfEpoch(t.endEpochDay)} · 共 $days 天 · $itemCount 条安排'
                '${t.destination.isEmpty ? '' : ' · ${t.destination}'}',
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (!mine)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: AppRadius.capsule,
            ),
            child: Text('旅伴的行程',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary)),
          ),
      ],
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  final List<_ItemView> items;
  final bool canWrite;
  final void Function(_ItemView) onEdit;
  final void Function(_ItemView) onDelete;
  final void Function(_ItemView) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 按日期分组（日期升序；同日内有时间的排前、无时间的排末）
    final byDay = <int, List<_ItemView>>{};
    for (final i in items) {
      byDay.putIfAbsent(i.dateEpochDay, () => []).add(i);
    }
    final days = byDay.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
            child: Text(
              '${fmtMonthDayOfEpoch(day)} ${fmtWeekday(epochDayToDate(day))}',
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant),
            ),
          ),
          for (final v in (byDay[day]!..sort((a, b) {
            final at = a.startTimeMin;
            final bt = b.startTimeMin;
            if ((at == null) != (bt == null)) return at == null ? 1 : -1;
            if (at != null && bt != null && at != bt) return at.compareTo(bt);
            return a.sortOrder.compareTo(b.sortOrder);
          })))
            CompanionTile(
              icon: _iconOf(v.type),
              title: v.name.isEmpty ? '（未命名安排）' : v.name,
              subtitle: '${v.timeText}'
                  '${v.address.isEmpty ? '' : ' · ${v.address}'}',
              onTap: () => onOpen(v),
              trailing: canWrite
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '编辑',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(v),
                        ),
                        IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () => onDelete(v),
                        ),
                      ],
                    )
                  : null,
            ),
        ],
      ],
    );
  }

  static IconData _iconOf(String type) => switch (type) {
        'transport' => Icons.flight_rounded,
        'food' => Icons.restaurant_rounded,
        'hotel' => Icons.hotel_rounded,
        'shopping' => Icons.shopping_bag_rounded,
        'note' => Icons.sticky_note_2_rounded,
        _ => Icons.place_rounded,
      };
}

class _ItemDraft {
  const _ItemDraft({
    required this.name,
    required this.address,
    required this.note,
    required this.dateEpochDay,
    required this.startTimeMin,
  });

  final String name;
  final String address;
  final String note;
  final int dateEpochDay;
  final int? startTimeMin;
}

/// 协作行程项编辑面板（写路径走 RPC，故不复用本地 ItemEditScreen）。
class _CollabItemSheet extends StatefulWidget {
  const _CollabItemSheet({
    required this.scrollController,
    required this.initial,
    required this.defaultDay,
  });

  final ScrollController scrollController;
  final _ItemView? initial;
  final int defaultDay;

  @override
  State<_CollabItemSheet> createState() => _CollabItemSheetState();
}

class _CollabItemSheetState extends State<_CollabItemSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.initial?.address ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.initial?.note ?? '');
  late int _day = widget.initial?.dateEpochDay ?? widget.defaultDay;
  late int? _timeMin = widget.initial?.startTimeMin;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
      children: [
        Text(widget.initial == null ? '新增安排' : '编辑安排',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Spacing.lg),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: '地点（可选）'),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '备注（可选）'),
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: '日期：${fmtMonthDayOfEpoch(_day)}',
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: epochDayToDate(_day),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) {
                    setState(() => _day = dateToEpochDay(picked));
                  }
                },
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: SecondaryButton(
                label: _timeMin == null
                    ? '时间：全天'
                    : '时间：${(_timeMin! ~/ 60).toString().padLeft(2, '0')}:'
                        '${(_timeMin! % 60).toString().padLeft(2, '0')}',
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: (_timeMin ?? 540) ~/ 60,
                      minute: (_timeMin ?? 540) % 60,
                    ),
                  );
                  if (picked != null) {
                    setState(() => _timeMin = picked.hour * 60 + picked.minute);
                  }
                },
              ),
            ),
          ],
        ),
        if (_timeMin != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _timeMin = null),
              child: const Text('改为全天'),
            ),
          ),
        const SizedBox(height: Spacing.lg),
        Text('改动会立即同步给空间里的所有旅伴。',
            style: TextStyle(
                fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.xl),
        PrimaryButton(
          label: '保存',
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(_ItemDraft(
              name: name,
              address: _address.text.trim(),
              note: _note.text.trim(),
              dateEpochDay: _day,
              startTimeMin: _timeMin,
            ));
          },
        ),
        const SizedBox(height: Spacing.sm),
        SecondaryButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ============================================================
// 2 账本区（嵌入 S4 四能力组件）
// ============================================================

class _LedgerSection extends ConsumerStatefulWidget {
  const _LedgerSection({
    required this.space,
    required this.myRole,
    required this.online,
  });

  final TravelSpace space;
  final String? myRole;
  final bool online;

  @override
  ConsumerState<_LedgerSection> createState() => _LedgerSectionState();
}

class _LedgerSectionState extends ConsumerState<_LedgerSection>
    with SingleTickerProviderStateMixin {
  late final TabController _sub = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.space.groupId;
    if (groupId == null) {
      return ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xxxl),
        children: [
          CompanionSectionCard(
            title: '账本区',
            child: companionEmpty('还没关联账本',
                '在空间设置里关联一个账本，旅伴就能一起记账、AA 结算。'),
          ),
        ],
      );
    }
    final data = MirrorLedgerSectionData(
      db: ref.read(dbProvider),
      groupId: groupId,
      cloudClient: ref.read(cloudClientProvider),
      syncEngine: ref.read(syncEngineProvider),
    );
    final isOwner = widget.myRole == SpaceRole.owner;
    final canWrite = SpaceRole.canEdit(widget.myRole);

    // 账本区协作写成功后补空间动态（§4.2）：四能力组件内部写的是 *_sync 表，
    // 这里用 listener 捕获写完成事件，把「谁记了一笔账」记进动态流。
    return Column(
      children: [
        TabBar(
          controller: _sub,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '账单'),
            Tab(text: '成员'),
            Tab(text: '统计'),
            Tab(text: '结算'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: [
              SharedBillsSection(
                data: data,
                online: widget.online,
                canWrite: canWrite,
                onAddBill: () async => _log('expense_added', '记账'),
              ),
              SharedMembersSection(
                data: data,
                online: widget.online,
                isOwner: isOwner,
                canWrite: canWrite,
              ),
              SharedStatsSection(data: data),
              SharedSettleSection(
                data: data,
                online: widget.online,
                isOwner: isOwner,
                canWrite: canWrite,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _log(String action, String summary) {
    // 尽力而为：动态写入失败不影响记账主操作
    SpaceActions.appendLedgerEvent(
      ref,
      spaceId: widget.space.id,
      action: action,
      entityKind: 'expense',
      summary: summary,
    );
  }
}

// ============================================================
// 3 成员区
// ============================================================

class _MembersSection extends ConsumerStatefulWidget {
  const _MembersSection({
    required this.space,
    required this.members,
    required this.myRole,
  });

  final TravelSpace space;
  final List<SpaceMember> members;
  final String? myRole;

  @override
  ConsumerState<_MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends ConsumerState<_MembersSection> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(currentUserIdProvider);
    final isOwner = widget.myRole == SpaceRole.owner;
    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.xxxl),
      children: [
        CompanionSectionCard(
          title: '成员',
          subtitle: '${widget.members.length} 位旅伴',
          trailingLabel: isOwner ? '邀请' : null,
          onTrailingTap: isOwner
              ? () => showSpaceInviteSheet(context,
                  spaceId: widget.space.id, spaceName: widget.space.name)
              : null,
          child: Column(
            children: [
              for (final m in widget.members)
                CompanionTile(
                  icon: Icons.person_rounded,
                  title: m.displayName.isEmpty ? '旅伴' : m.displayName,
                  subtitle: m.userId == uid ? '这是我' : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpaceRoleBadge(role: m.role),
                      // 管理操作仅 owner 可见（隐藏，不置灰）
                      if (isOwner && m.role != SpaceRole.owner)
                        IconButton(
                          tooltip: '管理成员',
                          icon: const Icon(Icons.more_horiz_rounded, size: 18),
                          onPressed: () => _manage(m),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!isOwner && widget.myRole != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
            child: SecondaryButton(
              label: '退出空间',
              onPressed: _leave,
            ),
          ),
        if (isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
            child: Text(
              '你是创建者：不能退出空间，只能删除空间。',
              style:
                  TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Future<void> _manage(SpaceMember m) async {
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.42,
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
        children: [
          Text(m.displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          for (final r in const [SpaceRole.editor, SpaceRole.viewer])
            CompanionTile(
              icon: r == SpaceRole.editor
                  ? Icons.edit_rounded
                  : Icons.visibility_rounded,
              title: '设为${SpaceRole.label(r)}',
              subtitle: r == SpaceRole.editor ? '可以增删改行程与账本' : '只能查看，不能改动',
              onTap: () async {
                Navigator.pop(ctx);
                final err = await SpaceActions.setMemberRole(ref,
                    spaceId: widget.space.id, targetUserId: m.userId, role: r);
                if (!mounted) return;
                _toast(err.isEmpty ? '已更新角色' : spaceErrorText(err));
              },
            ),
          CompanionTile(
            icon: Icons.person_remove_outlined,
            title: '移出空间',
            subtitle: '历史账单分摊保留，对方不再能访问',
            tint: Theme.of(context).colorScheme.error,
            onTap: () async {
              Navigator.pop(ctx);
              final err = await SpaceActions.removeMember(ref,
                  spaceId: widget.space.id, targetUserId: m.userId);
              if (!mounted) return;
              _toast(err.isEmpty ? '已移出' : spaceErrorText(err));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('退出这个空间？'),
        content: const Text('退出后你不再看到空间里的行程与账本；重新加入需要新的邀请码。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await SpaceActions.leave(ref, widget.space.id);
    if (!mounted) return;
    if (err.isEmpty) {
      _toast('已退出空间');
      if (context.mounted) context.pop();
    } else {
      _toast(spaceErrorText(err));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ============================================================
// 4 动态区
// ============================================================

class _EventsSection extends ConsumerStatefulWidget {
  const _EventsSection({required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<_EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends ConsumerState<_EventsSection> {
  @override
  void initState() {
    super.initState();
    // 打开动态区即视为已读（角标是"有没有新动态"，不是消息中心）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(travelSpacesRepoProvider);
      final events = await repo
          .watchEvents(widget.spaceId, limit: 1)
          .first
          .catchError((_) => const <SpaceEvent>[]);
      if (events.isEmpty) return;
      await ref
          .read(todayLocalStoreProvider)
          .markSpaceEventsSeen(widget.spaceId, events.first.createdMs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(travelSpacesRepoProvider);
    return StreamBuilder<List<SpaceEvent>>(
      stream: repo.watchEvents(widget.spaceId),
      builder: (context, snap) {
        final events = snap.data ?? const <SpaceEvent>[];
        if (events.isEmpty) {
          return ListView(
            padding: const EdgeInsets.only(bottom: Spacing.xxxl),
            children: [
              CompanionSectionCard(
                title: '协作动态',
                child: companionEmpty('还没有动态',
                    '旅伴改了行程、记了账，这里会按时间倒序列出来。'),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: Spacing.xxxl),
          itemCount: events.length,
          itemBuilder: (context, i) => _EventTile(event: events[i]),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final SpaceEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 动态流条目按 entity_kind 切换图标与点缀色（行程/账本/成员三色取主题 Scheme）
    final (icon, tint) = switch (event.entityKind) {
      'trip_item' => (Icons.route_rounded, scheme.primary),
      'expense' => (Icons.receipt_long_rounded, scheme.secondary),
      'member' => (Icons.group_rounded, scheme.tertiary),
      _ => (Icons.auto_awesome_rounded, scheme.primary),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanionLeadingIcon(icon: icon, tint: tint),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // 未知 action 一律显示「更新了空间」（§3.4 / §6.1）
                  spaceActionLabel(event.action),
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface),
                ),
                if (event.summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(event.summary,
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 2),
                Text(
                  _relTime(event.createdMs),
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relTime(int ms) {
    if (ms <= 0) return '';
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    if (diff < 60 * 1000) return '刚刚';
    if (diff < 3600 * 1000) return '${diff ~/ 60000} 分钟前';
    if (diff < 86400 * 1000) return '${diff ~/ 3600000} 小时前';
    if (diff < 7 * 86400 * 1000) return '${diff ~/ 86400000} 天前';
    return fmtIsoDate(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}

// ============================================================
// 空间设置（仅 owner 可写）
// ============================================================

class _SpaceSettingsSheet extends ConsumerStatefulWidget {
  const _SpaceSettingsSheet({
    required this.space,
    required this.isOwner,
    required this.scrollController,
  });

  final TravelSpace space;
  final bool isOwner;
  final ScrollController scrollController;

  @override
  ConsumerState<_SpaceSettingsSheet> createState() => _SpaceSettingsSheetState();
}

class _SpaceSettingsSheetState extends ConsumerState<_SpaceSettingsSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.space.name);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = ref.read(dbProvider);
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
      children: [
        Text('空间设置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Spacing.lg),
        TextField(
          controller: _name,
          enabled: widget.isOwner,
          decoration: const InputDecoration(labelText: '空间名'),
        ),
        const SizedBox(height: Spacing.md),
        // 关联行程 / 账本（仅 owner 可改）
        if (widget.isOwner) ...[
          Text('关联行程', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          FutureBuilder<List<Trip>>(
            future: (db.select(db.trips)).get(),
            builder: (_, snap) => _LinkChips<Trip>(
              items: snap.data ?? const <Trip>[],
              selectedId: widget.space.tripId,
              labelOf: (t) => '${t.emoji} ${t.name}',
              onPick: (id) => _update(tripId: id),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text('关联账本', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          FutureBuilder<List<Group>>(
            future: (db.select(db.groups)).get(),
            builder: (_, snap) => _LinkChips<Group>(
              items: snap.data ?? const <Group>[],
              selectedId: widget.space.groupId,
              labelOf: (g) => '${g.icon} ${g.name}',
              onPick: (id) => _update(groupId: id),
            ),
          ),
        ] else
          Text('只有空间创建者能修改空间名与关联内容。',
              style: TextStyle(
                  fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.xl),
        if (widget.isOwner) ...[
          PrimaryButton(
            label: _busy ? '保存中…' : '保存空间名',
            onPressed: _busy ? null : () => _update(name: _name.text.trim()),
          ),
          const SizedBox(height: Spacing.sm),
          SecondaryButton(
            label: widget.space.status == 'archived' ? '取消归档' : '归档空间',
            onPressed: _busy
                ? null
                : () => _update(
                    status: widget.space.status == 'archived' ? 'active' : 'archived'),
          ),
          const SizedBox(height: Spacing.sm),
          SecondaryButton(
            label: '删除空间',
            onPressed: _busy ? null : _delete,
          ),
        ],
      ],
    );
  }

  Future<void> _update({String? name, String? status, String? tripId, String? groupId}) async {
    setState(() => _busy = true);
    final err = await SpaceActions.updateSpace(ref,
        spaceId: widget.space.id,
        name: name,
        status: status,
        tripId: tripId,
        groupId: groupId);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(err.isEmpty ? '已保存' : spaceErrorText(err))));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('删除空间？'),
        content: const Text('空间、成员与邀请码都会失效；协作动态会保留为只读残档。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await SpaceActions.deleteSpace(ref, widget.space.id);
    if (!mounted) return;
    if (err.isEmpty) {
      Navigator.pop(context);
      if (context.mounted) context.pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(spaceErrorText(err))));
    }
  }
}

class _LinkChips<T> extends StatelessWidget {
  const _LinkChips({
    required this.items,
    required this.selectedId,
    required this.labelOf,
    required this.onPick,
  });

  final List<T> items;
  final String? selectedId;
  final String Function(T) labelOf;
  final void Function(String? id) onPick;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('暂无可选项',
          style: TextStyle(
              fontSize: AppFontSizes.caption,
              color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final it in items)
          Builder(builder: (context) {
            final id = _idOf(it);
            return ChoiceChip(
              label: Text(labelOf(it)),
              selected: id == selectedId,
              onSelected: (_) => onPick(id == selectedId ? null : id),
            );
          }),
      ],
    );
  }

  String? _idOf(T it) {
    if (it is Trip) return it.id;
    if (it is Group) return it.id;
    return null;
  }
}

/// 供旅伴中心复用的 JSON 便捷解析（动态摘要里偶尔带 JSON 片段）。
String safeJsonSummary(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is String ? decoded : raw;
  } catch (_) {
    return raw;
  }
}
