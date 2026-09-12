/// 共享账本完整版（受邀端，V2.6 §3.13 / §3.17.5；本轮补齐 K5）：
/// - 首页「共享账本」分组卡（数据源 shared_groups 镜像）；
/// - 团详情四 Tab：账单 / 成员 / 统计 / 结算，全部复用共享镜像数据；
/// - 在线直写：记/改/删账单、加/移成员、一键结算 → upsert 对应 *_sync
///   （owner_user_id 保持团 owner），成功后用写回结果刷新本地 shared_*；
///   失败 toast，不落本地业务表；
/// - 离线：全部写入口隐藏，卡片显示「离线仅可查看」；
/// - 管理操作（团名/图标/预算/归档/邀请/移除/删团）仅 owner 可见，member 端隐藏；
/// - 结算口径与本地账本一致（domain/settle_engine：已付−应摊，最少转账贪心）。
library;
import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../domain/models.dart';
import '../../../domain/settle_engine.dart';
import '../../../domain/share_splitter.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/share_link_sheet.dart';
import '../../../theme/tokens.dart';

/// 首页「共享账本」分组（空态不显示）。
class SharedLedgerSection extends ConsumerWidget {
  const SharedLedgerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = ref.watch(sharedGroupsStreamProvider);
    return shared.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: copy('share.sectionTitle')),
          for (final g in groups)
            Card(
              margin: const EdgeInsets.only(bottom: Spacing.md),
              child: ListTile(
                leading: Text(g.icon, style: const TextStyle(fontSize: 26)),
                title: Text(g.name),
                subtitle: Text(copy('share.collabBadge'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: AppFontSizes.caption)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/ledger/shared/${g.id}'),
              ),
            ),
        ]);
      },
    );
  }
}

/// 共享团详情（四 Tab 镜像展示 + 在线直写）。
class SharedGroupScreen extends ConsumerStatefulWidget {
  const SharedGroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<SharedGroupScreen> createState() => _SharedGroupScreenState();
}

class _SharedGroupScreenState extends ConsumerState<SharedGroupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  AppDatabase get _db => ref.read(dbProvider);

  /// 当前离线（可写通道是否可用）。
  bool get _online => ref.watch(cloudClientProvider) != null;

  /// 我是不是这个共享团的 owner。
  ///
  /// 成员增删 / 结算这类写操作在云端按「团长」语义落 owner_user_id，
  /// 非 owner 提交必然失败（历史上按钮却对所有人可见 → 点了只得到一句网络错误）。
  bool get _isOwner {
    final me = ref.read(currentUserIdProvider);
    final owner = ref.read(syncEngineProvider)?.sharedOwnerUserIdOf(widget.groupId);
    return me != null && owner != null && me == owner;
  }

  @override
  Widget build(BuildContext context) {
    final db = _db;
    final online = _online;
    final isOwner = _isOwner;
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _groupName(db),
          builder: (_, snap) => Text(snap.data ?? copy('share.sectionTitle')),
        ),
        actions: [
          IconButton(
            tooltip: '只读分享链接',
            icon: const Icon(Icons.link_rounded),
            onPressed: online
                ? () => showShareLinkSheet(context,
                    entityType: 'group', entityId: widget.groupId)
                : null,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '账单'),
            Tab(text: '成员'),
            Tab(text: '统计'),
            Tab(text: '结算'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _BillsTab(groupId: widget.groupId, online: online),
        _MembersTab(groupId: widget.groupId, online: online, isOwner: isOwner),
        _StatsTab(groupId: widget.groupId),
        _SettleTab(
            groupId: widget.groupId, online: online, isOwner: isOwner),
      ]),
    );
  }

  Future<String> _groupName(AppDatabase db) async {
    final rows = await (db.select(db.sharedGroups)
          ..where((g) => g.id.equals(widget.groupId)))
        .get();
    return rows.isEmpty ? copy('share.sectionTitle') : rows.first.name;
  }
}

// ============ 共享数据访问（镜像流 + 域模型映射） ============

List<ShareEntry> _parseShareList(String json) {
  try {
    final list = (jsonDecode(json) as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map)
          ShareEntry(
              memberId: (e['memberId'] ?? '').toString(),
              cents: ((e['cents'] as num?) ?? 0).toInt()),
    ];
  } catch (_) {
    return const [];
  }
}

ExpenseRecord _sharedToRecord(SharedExpense e) => ExpenseRecord(
      id: e.id,
      groupId: e.groupId,
      dateEpochDay: e.dateEpochDay,
      title: e.title,
      categoryKey: e.categoryKey,
      type: ExpenseType.values.firstWhere((t) => t.name == e.type,
          orElse: () => ExpenseType.normal),
      amountCents: e.amountCents,
      currency: e.currency,
      rate: e.rate,
      payers: _parseShareList(e.payersJson),
      shares: _parseShareList(e.sharesJson),
      shareMode: ShareMode.values.firstWhere((m) => m.name == e.shareMode,
          orElse: () => ShareMode.equal),
      note: e.note,
      settledRoundId: e.settledRoundId,
    );

String _fmtDay(int epochDay) {
  final d = epochDayToDate(epochDay);
  return '${d.month}/${d.day}';
}

// ============ 在线直写通道（本轮补齐：详情页外全部写路径） ============

mixin SharedDirectWrite<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String get groupId;

  AppDatabase get db => ref.read(dbProvider);

  /// 云端 upsert（owner 保持团 owner）；成功后可选刷新本地镜像。
  Future<bool> directUpsert(String table, Map<String, dynamic> row,
      {void Function()? onMirror}) async {
    final client = ref.read(cloudClientProvider);
    if (client == null) return false;
    try {
      await client.from(table).upsert(row, onConflict: 'id');
      onMirror?.call();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> toastResult(bool ok, {String? okMsg}) async {
    _toast(ok ? (okMsg ?? '已写入云端') : copy('cloud.errNetwork'));
  }

  /// 成员 id 列表（镜像）。
  Future<List<SharedMember>> members() => (db.select(db.sharedMembers)
        ..where((m) => m.groupId.equals(groupId)))
      .get();

  /// 组装 expenses_sync 行（列与 db_v26.sql 对齐；owner 保持团 owner）。
  Map<String, dynamic> expenseRow({
    required String id,
    required List<Map<String, dynamic>> payers,
    required List<Map<String, dynamic>> shares,
    required int dateEpochDay,
    required String title,
    required String categoryKey,
    required String type,
    required int cents,
    required int createdMs,
    String? settledRoundId,
    bool deleted = false,
  }) =>
      {
        'id': id,
        'owner_user_id': ref.read(syncEngineProvider)?.sharedOwnerUserIdOf(groupId),
        'group_id': groupId,
        'date_epoch_day': dateEpochDay,
        'title': title,
        'category_key': categoryKey,
        'type': type,
        'amount_cents': cents,
        'currency': 'CNY',
        'rate': 1.0,
        'amount_foreign_cents': null,
        'payers_json': jsonEncode(payers),
        'shares_json': jsonEncode(shares),
        'share_mode': 'equal',
        'portions_json': null,
        'note': '',
        'settled_round_id': settledRoundId,
        'trip_id': null,
        'trip_item_id': null,
        'created_ms': createdMs,
        'updated_ms': DateTime.now().millisecondsSinceEpoch,
        'deleted': deleted,
      };

  Future<void> refreshExpenseMirror({
    required String id,
    required int dateEpochDay,
    required String title,
    required String categoryKey,
    required int cents,
    required String payersJson,
    required String sharesJson,
    required int createdAt,
    String? settledRoundId,
  }) async {
    await db.into(db.sharedExpenses).insertOnConflictUpdate(
          SharedExpensesCompanion.insert(
            id: id,
            groupId: groupId,
            dateEpochDay: Value(dateEpochDay),
            title: Value(title),
            categoryKey: Value(categoryKey),
            amountCents: Value(cents),
            payersJson: Value(payersJson),
            sharesJson: Value(sharesJson),
            createdAt: createdAt,
            settledRoundId: Value(settledRoundId),
          ),
        );
  }
}

// ============ Tab 1 账单 ============

class _BillsTab extends ConsumerStatefulWidget {
  const _BillsTab({required this.groupId, required this.online});

  final String groupId;
  final bool online;

  @override
  ConsumerState<_BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends ConsumerState<_BillsTab>
    with SharedDirectWrite {
  @override
  String get groupId => widget.groupId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<SharedExpense>>(
      stream: (db.select(db.sharedExpenses)
            ..where((e) => e.groupId.equals(widget.groupId))
            ..orderBy([(e) => OrderingTerm.desc(e.dateEpochDay)]))
          .watch(),
      builder: (_, snap) {
        final expenses = snap.data ?? const <SharedExpense>[];
        return ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            // 受邀成员也应能记账（共享账本的核心诉求）；此前只有编辑/删除，
            // 没有新增入口 → 成员只能围观。
            if (widget.online) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(copy('share.addBill')),
                ),
              ),
              const SizedBox(height: Spacing.md),
            ],
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                child: Text('暂无共享账单',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: AppFontSizes.caption)),
              )
            else
              for (final e in expenses)
                Card(
                  margin: const EdgeInsets.only(bottom: Spacing.sm),
                  child: ListTile(
                    dense: true,
                    title: Text(e.title),
                    subtitle: Text(
                        '${_fmtDay(e.dateEpochDay)} · ${e.categoryKey}'
                        '${e.settledRoundId != null ? ' · 已结算' : ''}',
                        style:
                            const TextStyle(fontSize: AppFontSizes.caption)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(formatMoney(e.amountCents),
                          style: TextStyle(
                              color: e.amountCents < 0
                                  ? SemanticColors.income
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w700)),
                      if (widget.online) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: '编辑',
                          onPressed: () => _edit(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          tooltip: '删除',
                          onPressed: () => _delete(e),
                        ),
                      ],
                    ]),
                    onTap: () => _showDetail(e),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// 新增一笔共享账单（在线直写；成功后写回本地镜像，无需等拉取）。
  Future<void> _add() async {
    final form = await showDialog<_BillForm?>(
      context: context,
      builder: (_) => const _BillFormDialog(),
    );
    if (form == null) return;
    final all = await members();
    if (all.isEmpty) {
      await toastResult(false);
      return;
    }
    final shares = splitShares(
        totalCents: form.cents, memberIds: all.map((m) => m.id).toList());
    final per = [
      for (final s in shares) {'memberId': s.memberId, 'cents': s.cents}
    ];
    final id = newId('expense');
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = expenseRow(
      id: id,
      payers: per,
      shares: per,
      dateEpochDay: form.dateEpochDay,
      title: form.title,
      categoryKey: form.categoryKey,
      type: 'normal',
      cents: form.cents,
      createdMs: now,
    );
    final ok = await directUpsert('expenses_sync', row, onMirror: () async {
      await refreshExpenseMirror(
        id: id,
        dateEpochDay: form.dateEpochDay,
        title: form.title,
        categoryKey: form.categoryKey,
        cents: form.cents,
        payersJson: row['payers_json'] as String,
        sharesJson: row['shares_json'] as String,
        createdAt: now,
      );
    });
    await toastResult(ok, okMsg: '已记账');
  }

  void _showDetail(SharedExpense e) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: FutureBuilder<List<SharedMember>>(
          future: members(),
          builder: (_, snap) {
            final nameOf = {for (final m in snap.data ?? const <SharedMember>[]) m.id: m.name};
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                Text(e.title, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: Spacing.sm),
                Text('${_fmtDay(e.dateEpochDay)} · ${e.categoryKey} · ${e.type}',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: AppFontSizes.caption)),
                const SizedBox(height: Spacing.md),
                const Text('付款', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final p in _parseShareList(e.payersJson))
                  ListTile(
                      dense: true,
                      title: Text(
                          '${nameOf[p.memberId] ?? p.memberId} 付 ${formatMoney(p.cents)}')),
                const SizedBox(height: Spacing.sm),
                const Text('分摊', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final s in _parseShareList(e.sharesJson))
                  ListTile(
                      dense: true,
                      title: Text(
                          '${nameOf[s.memberId] ?? s.memberId} 摊 ${formatMoney(s.cents)}')),
                if (e.note.isNotEmpty) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(e.note),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(SharedExpense e) async {
    final form = await showDialog<_BillForm?>(
      context: context,
      builder: (_) => _BillFormDialog(
        initial:
            _BillForm(e.title, e.amountCents, e.dateEpochDay, e.categoryKey),
      ),
    );
    if (form == null) return;
    final all = await members();
    final shares = splitShares(
        totalCents: form.cents, memberIds: all.map((m) => m.id).toList());
    final per = [
      for (final s in shares) {'memberId': s.memberId, 'cents': s.cents}
    ];
    final row = expenseRow(
      id: e.id,
      payers: per,
      shares: per,
      dateEpochDay: form.dateEpochDay,
      title: form.title,
      categoryKey: form.categoryKey,
      type: e.type,
      cents: form.cents,
      createdMs: e.createdAt,
      settledRoundId: e.settledRoundId,
    );
    final ok = await directUpsert('expenses_sync', row, onMirror: () async {
      await refreshExpenseMirror(
        id: e.id,
        dateEpochDay: form.dateEpochDay,
        title: form.title,
        categoryKey: form.categoryKey,
        cents: form.cents,
        payersJson: row['payers_json'] as String,
        sharesJson: row['shares_json'] as String,
        createdAt: e.createdAt,
        settledRoundId: e.settledRoundId,
      );
    });
    await toastResult(ok);
  }

  Future<void> _delete(SharedExpense e) async {
    final okConfirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('删除账单'),
        content: Text('删除「${e.title}」？云端共享成员都会看到该账单被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('删除')),
        ],
      ),
    );
    if (okConfirm != true) return;
    final row = expenseRow(
      id: e.id,
      payers: const [],
      shares: const [],
      dateEpochDay: e.dateEpochDay,
      title: e.title,
      categoryKey: e.categoryKey,
      type: e.type,
      cents: e.amountCents,
      createdMs: e.createdAt,
      settledRoundId: e.settledRoundId,
      deleted: true,
    );
    final ok = await directUpsert('expenses_sync', row, onMirror: () async {
      await (db.delete(db.sharedExpenses)..where((x) => x.id.equals(e.id))).go();
    });
    await toastResult(ok);
  }
}

// ============ Tab 2 成员 ============

class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab(
      {required this.groupId, required this.online, required this.isOwner});

  final String groupId;
  final bool online;
  final bool isOwner;

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab>
    with SharedDirectWrite {
  @override
  String get groupId => widget.groupId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<SharedMember>>(
      stream: (db.select(db.sharedMembers)
            ..where((m) => m.groupId.equals(widget.groupId)))
          .watch(),
      builder: (_, snap) {
        final list = snap.data ?? const <SharedMember>[];
        return ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                for (final m in list)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(m.name.isNotEmpty ? m.name.characters.first : '?',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    title: Text(m.name),
                    trailing: widget.online && widget.isOwner
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_outlined, size: 18),
                            tooltip: '移出本团',
                            onPressed: list.length <= 1 ? null : () => _remove(m),
                          )
                        : null,
                  ),
              ]),
            ),
            if (widget.online && widget.isOwner) ...[
              const SizedBox(height: Spacing.md),
              OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('添加成员'),
              ),
            ] else if (widget.online) ...[
              const SizedBox(height: Spacing.md),
              Text(copy('share.ownerOnlyTap'),
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: AppFontSizes.caption)),
            ],
            const SizedBox(height: Spacing.md),
            Text('成员变更即时写云端并对所有共享成员可见。',
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: AppFontSizes.caption)),
          ],
        );
      },
    );
  }

  Future<void> _add() async {
    final nameCtl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('添加成员'),
        content: TextField(controller: nameCtl, decoration: const InputDecoration(labelText: '成员名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(d, nameCtl.text.trim()),
              child: const Text('添加')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = newId('member');
    final now = DateTime.now().millisecondsSinceEpoch;
    final owner = ref.read(syncEngineProvider)?.sharedOwnerUserIdOf(groupId);
    final row = {
      'id': id,
      'owner_user_id': owner,
      'group_id': groupId,
      'name': name,
      'color_index': 0,
      'created_ms': now,
      'updated_ms': now,
      'deleted': false,
    };
    final ok = await directUpsert('members_sync', row, onMirror: () async {
      await db.into(db.sharedMembers).insertOnConflictUpdate(
            SharedMembersCompanion.insert(
                id: id, groupId: groupId, name: name, createdAt: now),
          );
    });
    await toastResult(ok);
  }

  Future<void> _remove(SharedMember m) async {
    final okConfirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('移出成员'),
        content: Text('将「${m.name}」移出本团？其历史账单分摊保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('移出')),
        ],
      ),
    );
    if (okConfirm != true) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = {
      'id': m.id,
      'owner_user_id': ref.read(syncEngineProvider)?.sharedOwnerUserIdOf(groupId),
      'group_id': groupId,
      'name': m.name,
      'color_index': m.colorIndex,
      'created_ms': m.createdAt,
      'updated_ms': now,
      'deleted': true,
    };
    final ok = await directUpsert('members_sync', row, onMirror: () async {
      await (db.delete(db.sharedMembers)..where((x) => x.id.equals(m.id))).go();
    });
    await toastResult(ok);
  }
}

// ============ Tab 3 统计 ============

class _StatsTab extends ConsumerStatefulWidget {
  const _StatsTab({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<_StatsTab> {
  AppDatabase get db => ref.read(dbProvider);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<SharedExpense>>(
      stream: (db.select(db.sharedExpenses)
            ..where((e) => e.groupId.equals(widget.groupId)))
          .watch(),
      builder: (_, snap) {
        final expenses = snap.data ?? const <SharedExpense>[];
        if (expenses.isEmpty) {
          return Center(
              child: Text('暂无数据',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: AppFontSizes.caption)));
        }
        final records = [for (final e in expenses) _sharedToRecord(e)];
        var total = 0;
        final byCategory = <String, int>{};
        for (final r in records) {
          // 退款以负数自然冲减；预付款单独口径，不进日常合计
          if (r.type != ExpenseType.prepay) total += r.amountCents;
          if (r.type != ExpenseType.prepay) {
            byCategory[r.categoryKey] = (byCategory[r.categoryKey] ?? 0) + r.amountCents;
          }
        }
        final cats = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return FutureBuilder<List<SharedMember>>(
          future: (db.select(db.sharedMembers)
                ..where((m) => m.groupId.equals(widget.groupId)))
              .get(),
          builder: (_, memberSnap) {
            final members = memberSnap.data ?? const <SharedMember>[];
            final balances = computeNetBalances(
              [for (final m in members) MemberRecord(id: m.id, name: m.name)],
              records,
            );
            final nameOf = {for (final m in members) m.id: m.name};
            return ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('共享支出合计（不含预付）',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: AppFontSizes.caption)),
                          const SizedBox(height: Spacing.xs),
                          Text(formatMoney(total),
                              style: Theme.of(context).textTheme.headlineSmall),
                        ]),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                SectionHeader(title: '成员净额（正=应收，负=应付）'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    for (final b in balances.entries)
                      ListTile(
                        dense: true,
                        title: Text(nameOf[b.key] ?? b.key),
                        trailing: Text(formatMoney(b.value),
                            style: TextStyle(
                                color: b.value < 0
                                    ? scheme.error
                                    : SemanticColors.income,
                                fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
                const SizedBox(height: Spacing.lg),
                SectionHeader(title: '分类占比'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    for (final c in cats)
                      ListTile(
                        dense: true,
                        title: Text(c.key),
                        trailing: Text(
                            '${formatMoney(c.value)}（${total == 0 ? 0 : (c.value * 100 ~/ total)}%）',
                            style: const TextStyle(fontSize: AppFontSizes.caption)),
                      ),
                  ]),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============ Tab 4 结算 ============

class _SettleTab extends ConsumerStatefulWidget {
  const _SettleTab(
      {required this.groupId, required this.online, required this.isOwner});

  final String groupId;
  final bool online;
  final bool isOwner;

  @override
  ConsumerState<_SettleTab> createState() => _SettleTabState();
}

class _SettleTabState extends ConsumerState<_SettleTab>
    with SharedDirectWrite {
  @override
  String get groupId => widget.groupId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<SharedSettlement>>(
      stream: (db.select(db.sharedSettlements)
            ..where((s) => s.groupId.equals(widget.groupId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch(),
      builder: (_, settleSnap) {
        final settlements = settleSnap.data ?? const <SharedSettlement>[];
        return StreamBuilder<List<SharedExpense>>(
          stream: (db.select(db.sharedExpenses)
                ..where((e) => e.groupId.equals(widget.groupId)))
              .watch(),
          builder: (_, snap) {
            final expenses = snap.data ?? const <SharedExpense>[];
            final outstanding = [
              for (final e in expenses)
                if (e.settledRoundId == null) e
            ];
            return FutureBuilder<List<SharedMember>>(
              future: members(),
              builder: (_, memberSnap) {
                final members = memberSnap.data ?? const <SharedMember>[];
                final nameOf = {for (final m in members) m.id: m.name};
                return ListView(
                  padding: const EdgeInsets.all(Spacing.lg),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('未结算账单 ${outstanding.length} 笔',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              for (final e in outstanding.take(5))
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.title),
                                  trailing: Text(formatMoney(e.amountCents)),
                                ),
                              if (outstanding.length > 5)
                                Text('…等 ${outstanding.length} 笔',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: AppFontSizes.caption)),
                              if (widget.online &&
                                  widget.isOwner &&
                                  outstanding.isNotEmpty) ...[
                                const SizedBox(height: Spacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _settle,
                                    icon: const Icon(Icons.done_all_rounded),
                                    label: const Text('一键结算'),
                                  ),
                                ),
                              ],
                              if (widget.online && !widget.isOwner)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: Spacing.sm),
                                  child: Text(copy('share.ownerOnlyTap'),
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: AppFontSizes.caption)),
                                ),
                              if (!widget.online)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: Spacing.sm),
                                  child: Text('离线仅可查看，结算需联网。',
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: AppFontSizes.caption)),
                                ),
                            ]),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    SectionHeader(title: '历史结算'),
                    if (settlements.isEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.lg),
                          child: Text('还没有结算记录',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: AppFontSizes.caption)),
                        ),
                      )
                    else
                      for (final s in settlements)
                        Card(
                          margin: const EdgeInsets.only(bottom: Spacing.sm),
                          child: ListTile(
                            dense: true,
                            title: Text('第 ${s.roundNo} 轮结算'),
                            subtitle: Text(
                                '${_fmtDay(s.createdAt ~/ 86400000)} · '
                                '${_transfersSummary(s.transfersJson, nameOf)}',
                                style: const TextStyle(
                                    fontSize: AppFontSizes.caption)),
                          ),
                        ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _transfersSummary(String json, Map<String, String> nameOf) {
    final list = (jsonDecode(json) as List?) ?? const [];
    if (list.isEmpty) return '无需转账';
    return [
      for (final t in list)
        if (t is Map)
          '${nameOf[t['from']] ?? t['from']} → ${nameOf[t['to']] ?? t['to']} '
              '${formatMoney(((t['cents'] as num?) ?? 0).toInt())}'
    ].join('；');
  }

  Future<void> _settle() async {
    final all = await members();
    final db = this.db;
    final expenses = await (db.select(db.sharedExpenses)
          ..where((e) => e.groupId.equals(groupId)))
        .get();
    final outstanding = [
      for (final e in expenses)
        if (e.settledRoundId == null) e
    ];
    if (outstanding.isEmpty) return;
    final balances = computeNetBalances(
      [for (final m in all) MemberRecord(id: m.id, name: m.name)],
      [for (final e in outstanding) _sharedToRecord(e)],
    );
    final plan = minTransferPlan(balances);
    final nameOf = {for (final m in all) m.id: m.name};
    final okConfirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('确认结算'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment:
            CrossAxisAlignment.start, children: [
          const Text('结算后以下转账建议将入账：'),
          const SizedBox(height: Spacing.sm),
          if (plan.isEmpty)
            const Text('当前无需转账（已两清）'),
          for (final t in plan)
            Text('${nameOf[t.from] ?? t.from} → ${nameOf[t.to] ?? t.to}：'
                '${formatMoney(t.cents)}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('确认结算')),
        ],
      ),
    );
    if (okConfirm != true) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final settlements = await (db.select(db.sharedSettlements)
          ..where((s) => s.groupId.equals(groupId)))
        .get();
    final nextRound = settlements.isEmpty
        ? 1
        : settlements.map((s) => s.roundNo).reduce((a, b) => a > b ? a : b) + 1;
    final sid = newId('settle');
    final owner = ref.read(syncEngineProvider)?.sharedOwnerUserIdOf(groupId);
    final settlementRow = {
      'id': sid,
      'owner_user_id': owner,
      'group_id': groupId,
      'status': 'active',
      'transfers_json': jsonEncode([
        for (final t in plan) {'from': t.from, 'to': t.to, 'cents': t.cents}
      ]),
      'expense_ids_json': jsonEncode([for (final e in outstanding) e.id]),
      'round_no': nextRound,
      'created_ms': now,
      'updated_ms': now,
      'deleted': false,
    };
    var ok = true;
    // 结算行 + 涉事账单回写 settled_round_id（逐条直写；任一失败即中断提示）
    final client = ref.read(cloudClientProvider);
    if (client == null) {
      await toastResult(false);
      return;
    }
    try {
      await client.from('settlements_sync').upsert(settlementRow, onConflict: 'id');
      for (final e in outstanding) {
        await client.from('expenses_sync').upsert({
          'id': e.id,
          'owner_user_id': owner,
          'group_id': groupId,
          'date_epoch_day': e.dateEpochDay,
          'title': e.title,
          'category_key': e.categoryKey,
          'type': e.type,
          'amount_cents': e.amountCents,
          'currency': e.currency,
          'rate': e.rate,
          'amount_foreign_cents': e.amountForeignCents,
          'payers_json': e.payersJson,
          'shares_json': e.sharesJson,
          'share_mode': e.shareMode,
          'portions_json': e.portionsJson,
          'note': e.note,
          'settled_round_id': sid,
          'trip_id': e.tripId,
          'trip_item_id': e.tripItemId,
          'created_ms': e.createdAt,
          'updated_ms': now,
          'deleted': false,
        }, onConflict: 'id');
      }
    } catch (_) {
      ok = false;
    }
    if (ok) {
      // 刷新本地镜像
      await db.into(db.sharedSettlements).insertOnConflictUpdate(
            SharedSettlementsCompanion.insert(
              id: sid,
              groupId: groupId,
              transfersJson: Value(settlementRow['transfers_json'] as String),
              expenseIdsJson:
                  Value(settlementRow['expense_ids_json'] as String),
              roundNo: Value(nextRound),
              createdAt: now,
            ),
          );
      for (final e in outstanding) {
        await (db.update(db.sharedExpenses)..where((x) => x.id.equals(e.id)))
            .write(SharedExpensesCompanion(settledRoundId: Value(sid)));
      }
    }
    await toastResult(ok, okMsg: '结算完成（第 $nextRound 轮）');
  }
}

// ============ 账单表单 ============

class _BillForm {
  _BillForm(this.title, this.cents, this.dateEpochDay, this.categoryKey);
  final String title;
  final int cents;
  final int dateEpochDay;
  final String categoryKey;
}

class _BillFormDialog extends StatefulWidget {
  const _BillFormDialog({this.initial});

  final _BillForm? initial;

  @override
  State<_BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends State<_BillFormDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _amount = TextEditingController(
      text: widget.initial == null
          ? ''
          : (widget.initial!.cents.abs() / 100).toStringAsFixed(
              widget.initial!.cents % 100 == 0 ? 0 : 2));
  // widget 在 State 构造后才赋值：引用它的字段必须 late（首次访问时求值）
  late DateTime _date = widget.initial == null
      ? DateTime.now()
      : epochDayToDate(widget.initial!.dateEpochDay);
  late String _category = widget.initial?.categoryKey ?? 'other';

  static const _categories = ['other', 'food', 'transport', 'hotel', 'ticket', 'shopping'];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '记一笔' : '编辑账单'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: '名目')),
        TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '金额（元）')),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final c in _categories)
              ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(children: [
          Text('日期：${_date.month}/${_date.day}'),
          const Spacer(),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (d != null) setState(() => _date = d);
            },
            child: const Text('选择'),
          ),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final cents = parseMoney(_amount.text);
            if (_title.text.trim().isEmpty || cents == null) return;
            Navigator.pop(
                context,
                _BillForm(_title.text.trim(), cents, dateToEpochDay(_date), _category));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
