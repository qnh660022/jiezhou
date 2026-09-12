/// 分享与协作中心（聚合入口，路由 /profile/share）。
///
/// 解决的痛点：分享/协作能力此前散落在
/// 「账本 → 管理成员 →（成员页顶部）」与「行程详情 → 分享」，
/// 且未登录时邀请入口整块 `SizedBox.shrink()` 隐藏，用户根本找不到入口。
///
/// 本页把四件事收在一处：
/// 1. 我创建的账本 → 邀请旅伴（6 位邀请码 + 邀请链接）；
/// 2. 我加入的共享账本 → 进入详情（`/ledger/shared/:id`）；
/// 3. 只读分享链接 → 列表 / 复制 / 撤销 / 新建（行程 & 账本通用）；
/// 4. 加入别人的账本（输邀请码）+ 离线局域网同步。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/app_meta.dart' show inviteLinkUrl, shareLinkUrl;
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/share_link_sheet.dart';
import '../../../theme/tokens.dart';
import '../../ledger/screens/invite_companion_sheet.dart';

class ShareCenterScreen extends ConsumerStatefulWidget {
  const ShareCenterScreen({super.key});

  @override
  ConsumerState<ShareCenterScreen> createState() => _ShareCenterScreenState();
}

class _ShareCenterScreenState extends ConsumerState<ShareCenterScreen> {
  List<Map<String, dynamic>>? _links;
  List<Map<String, dynamic>>? _collabs;
  final _codeCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final share = ref.read(shareServiceProvider);
    final collab = ref.read(collabServiceProvider);
    try {
      _links = share == null ? null : await share.listMyShareLinks();
    } catch (_) {
      _links = null;
    }
    try {
      _collabs = collab == null ? null : await collab.listMyCollabs();
    } catch (_) {
      _collabs = null;
    }
    if (mounted) setState(() {});
  }

  bool get _signedIn => ref.read(cloudClientProvider) != null;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copy('share.copied'))));
  }

  /// 本团邀请码（从 listMyCollabs 反查；没有则 null）。
  String? _inviteCodeOf(String groupId) {
    for (final c in _collabs ?? const <Map<String, dynamic>>[]) {
      if (c['groupId'] == groupId) {
        final code = c['inviteCode'] as String?;
        if (code != null && code.isNotEmpty) return code;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(copy('share.centerTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          if (!_signedIn) ...[
            _signInHint(scheme),
            const SizedBox(height: Spacing.lg),
          ],
          SectionHeader(title: copy('share.myLedgers')),
          _myLedgersSection(),
          const SizedBox(height: Spacing.lg),
          SectionHeader(title: copy('share.myShared')),
          _joinedSection(),
          const SizedBox(height: Spacing.lg),
          SectionHeader(title: copy('sync.links')),
          _readonlySection(),
          const SizedBox(height: Spacing.lg),
          SectionHeader(title: copy('share.joinEntry')),
          _joinSection(),
          const SizedBox(height: Spacing.lg),
          SectionHeader(title: copy('sync.lan')),
          _lanSection(),
        ],
      ),
    );
  }

  /// 未登录提示（不再静默隐藏入口 —— 用户至少知道「要登录才有分享」）。
  Widget _signInHint(ColorScheme scheme) => Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        child: ListTile(
          leading: Icon(Icons.cloud_off_rounded, color: scheme.outline),
          title: Text(copy('sync.status.signedOut')),
          subtitle: Text(copy('share.signInHint'),
              style: const TextStyle(fontSize: AppFontSizes.caption)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/profile/cloud'),
        ),
      );

  // ===== 1 我创建的账本 → 邀请旅伴 =====

  Widget _myLedgersSection() {
    final repo = ref.watch(ledgerRepoProvider);
    return StreamBuilder<List<Group>>(
      stream: repo.watchGroups(),
      builder: (_, snap) {
        final groups = snap.data ?? const <Group>[];
        if (groups.isEmpty) {
          return _emptyCard(copy('share.myLedgersEmpty'));
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            for (final g in groups)
              ListTile(
                leading: Text(g.icon, style: const TextStyle(fontSize: 22)),
                title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  _inviteCodeOf(g.id) == null
                      ? copy('share.inviteNone')
                      : '${copy('share.inviteCodeLabel')}：${_inviteCodeOf(g.id)}',
                  style: const TextStyle(fontSize: AppFontSizes.caption),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    tooltip: copy('share.invite'),
                    onPressed: _signedIn
                        ? () async {
                            await showModalBottomSheet(
                              context: context,
                              builder: (_) =>
                                  InviteCompanionSheet(groupId: g.id),
                            );
                            _reload();
                          }
                        : null,
                  ),
                  if (_inviteCodeOf(g.id) != null)
                    IconButton(
                      icon: const Icon(Icons.link_rounded, size: 20),
                      tooltip: copy('share.copyLink'),
                      onPressed: () => _copy(inviteLinkUrl(_inviteCodeOf(g.id)!)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    tooltip: copy('share.createReadonly'),
                    onPressed: _signedIn
                        ? () => _createReadonly(entityType: 'group', entityId: g.id)
                        : null,
                  ),
                ]),
                onTap: () => context.push('/ledger/members'),
              ),
          ]),
        );
      },
    );
  }

  // ===== 2 我加入的共享账本 =====

  Widget _joinedSection() {
    final shared = ref.watch(sharedGroupsStreamProvider);
    return shared.when(
      loading: () => _emptyCard('…'),
      error: (_, __) => _emptyCard(copy('share.mySharedEmpty')),
      data: (groups) {
        if (groups.isEmpty) return _emptyCard(copy('share.mySharedEmpty'));
        return Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            for (final g in groups)
              ListTile(
                leading: Text(g.icon, style: const TextStyle(fontSize: 22)),
                title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(copy('share.collabBadge'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: AppFontSizes.caption)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/ledger/shared/${g.id}'),
              ),
          ]),
        );
      },
    );
  }

  // ===== 3 只读分享链接 =====

  Widget _readonlySection() {
    final links = _links;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.add_link_rounded, size: 20),
          title: Text(copy('share.createReadonly')),
          subtitle: Text(copy('share.readonlyNote'),
              style: const TextStyle(fontSize: AppFontSizes.caption)),
          enabled: _signedIn,
          onTap: _signedIn ? _pickEntityForLink : null,
        ),
        const Divider(height: 1),
        if (links == null)
          _emptyCard(copy('share.mySharedEmpty'))
        else if (links.isEmpty)
          _emptyCard(copy('share.readonlyEmpty'))
        else
          for (final l in links) _linkTile(l),
      ]),
    );
  }

  Widget _linkTile(Map<String, dynamic> l) {
    final token = (l['token'] as String?) ?? '';
    final isTrip = l['entity_type'] == 'trip';
    final entityId = (l['entity_id'] as String?) ?? '';
    final db = ref.watch(dbProvider);
    return FutureBuilder<String>(
      future: _entityName(db, isTrip, entityId),
      builder: (_, snap) {
        return ListTile(
          dense: true,
          leading: Icon(
            isTrip
                ? Icons.flight_takeoff_rounded
                : Icons.account_balance_wallet_rounded,
            size: 20,
          ),
          title: Text(snap.data ?? entityId, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '/s/${token.substring(0, token.length.clamp(0, 8))}…',
              style: const TextStyle(fontSize: AppFontSizes.caption)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: copy('share.copyLink'),
              onPressed: () => _copy(shareLinkUrl(token)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: '撤销链接',
              onPressed: () async {
                await ref.read(shareServiceProvider)?.deleteShareLink(token);
                _reload();
              },
            ),
          ]),
        );
      },
    );
  }

  /// 选一个行程或账本 → 弹只读链接创建面板。
  Future<void> _pickEntityForLink() async {
    final db = ref.read(dbProvider);
    final trips = await (db.select(db.trips)).get();
    final groups = await (db.select(db.groups)).get();
    if (!mounted) return;
    if (trips.isEmpty && groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy('share.createReadonlyEmpty'))));
      return;
    }
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final t in trips)
            ListTile(
              leading: const Icon(Icons.flight_takeoff_rounded, size: 20),
              title: Text(t.name),
              onTap: () => Navigator.pop(ctx, ('trip', t.id)),
            ),
          for (final g in groups)
            ListTile(
              leading: Text(g.icon, style: const TextStyle(fontSize: 20)),
              title: Text(g.name),
              onTap: () => Navigator.pop(ctx, ('group', g.id)),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    await _createReadonly(entityType: picked.$1, entityId: picked.$2);
  }

  Future<void> _createReadonly(
      {required String entityType, required String entityId}) async {
    await showShareLinkSheet(context,
        entityType: entityType, entityId: entityId);
    _reload();
  }

  Future<String> _entityName(AppDatabase db, bool isTrip, String id) async {
    if (isTrip) {
      final rows = await (db.select(db.trips)..where((t) => t.id.equals(id))).get();
      return rows.isEmpty ? '行程 $id' : rows.first.name;
    }
    final groups = await (db.select(db.groups)..where((g) => g.id.equals(id))).get();
    return groups.isEmpty ? '账本 $id' : groups.first.name;
  }

  // ===== 4 加入别人的账本 =====

  Widget _joinSection() {
    final ctl = _codeCtl;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.qr_code_2_rounded, size: 20),
        title: Text(copy('share.joinEntry')),
        subtitle: Text(copy('share.joinInvalid'),
            style: const TextStyle(fontSize: AppFontSizes.caption)),
        enabled: _signedIn,
        onTap: _signedIn
            ? () async {
                final code = await showDialog<String>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(copy('share.joinEntry')),
                    content: TextField(
                      controller: ctl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: '邀请码（6 位）', counterText: ''),
                      maxLength: 6,
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: Text(copy('sync.cancel'))),
                      FilledButton(
                          onPressed: () => Navigator.pop(d, ctl.text.trim()),
                          child: const Text('加入')),
                    ],
                  ),
                );
                if (code == null || code.isEmpty || !mounted) return;
                final svc = ref.read(collabServiceProvider);
                if (svc == null) return;
                final (groupId, error) = await svc.joinByCode(code);
                if (!mounted) return;
                if (error.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(copy('share.joinInvalid'))));
                  return;
                }
                // 加入成功：重置账本域游标并全量拉取镜像（引擎内部处理）
                await ref.read(syncEngineProvider)?.onJoinedSharedGroup(groupId);
                _reload();
                if (mounted) context.push('/ledger/shared/$groupId');
              }
            : null,
      ),
    );
  }

  // ===== 5 局域网 =====

  Widget _lanSection() => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.lan_rounded, size: 20),
          title: Text(copy('share.lanEntry')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/ledger/lan-sync'),
        ),
      );

  Widget _emptyCard(String text) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(text,
            style: const TextStyle(fontSize: AppFontSizes.caption)),
      );
}
