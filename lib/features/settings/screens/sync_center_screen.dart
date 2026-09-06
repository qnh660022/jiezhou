/// 同步中心（V2.6 §3.17.2）：路由 /profile/cloud/sync。
/// 区块：状态卡 / 端点引导 / 上云开关 / 分享链接 / 邀请码 / 局域网入口 /
/// 同步频率 / 云端占用估算 / 释放云端空间。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/repo/ledger_repo.dart' hide Settlement;
import '../../../data/repo/trips_repo.dart';
import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../data/sync/sync_models.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';

class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  List<Map<String, dynamic>>? _shareLinks;
  List<Map<String, dynamic>>? _collabs;

  @override
  void initState() {
    super.initState();
    _reloadLists();
  }

  Future<void> _reloadLists() async {
    final share = ref.read(shareServiceProvider);
    final collab = ref.read(collabServiceProvider);
    try {
      _shareLinks = share == null ? null : await share.listMyShareLinks();
    } catch (_) {
      _shareLinks = null;
    }
    try {
      _collabs = collab == null ? null : await collab.listMyCollabs();
    } catch (_) {
      _collabs = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus(kind: SyncStatusKind.unconfigured);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(copy('sync.center'))),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          _statusCard(status, scheme),
          if (status.kind == SyncStatusKind.unconfigured) ...[
            const SizedBox(height: Spacing.lg),
            _guideCard(scheme),
          ],
          const SizedBox(height: Spacing.xl),
          SectionHeader(title: copy('sync.toggles.trips')),
          _tripToggles(),
          const SizedBox(height: Spacing.md),
          SectionHeader(title: copy('sync.toggles.ledger')),
          _groupToggles(),
          const SizedBox(height: Spacing.md),
          _categoriesRow(),
          const SizedBox(height: Spacing.xl),
          SectionHeader(title: copy('sync.links')),
          _shareLinksSection(),
          const SizedBox(height: Spacing.md),
          SectionHeader(title: copy('sync.invites')),
          _invitesSection(),
          const SizedBox(height: Spacing.xl),
          SectionHeader(title: copy('sync.freq.title')),
          _freqSection(),
          const SizedBox(height: Spacing.md),
          _usageSection(),
          const SizedBox(height: Spacing.md),
          _releaseSection(),
          const SizedBox(height: Spacing.md),
          _lanEntry(),
        ],
      ),
    );
  }

  // ===== 1 状态卡 =====

  Widget _statusCard(SyncStatus status, ColorScheme scheme) {
    final (color, label) = switch (status.kind) {
      SyncStatusKind.unconfigured => (scheme.outline, copy('sync.status.unconfigured')),
      SyncStatusKind.signedOut => (scheme.outline, copy('sync.status.signedOut')),
      SyncStatusKind.syncing => (const Color(0xFF2F80ED), copy('sync.status.syncing')),
      SyncStatusKind.idle => (const Color(0xFF1E9E6A), copy('sync.status.idle')),
      SyncStatusKind.offline => (SemanticColors.warning, copy('sync.status.offline')),
    };
    final last = status.lastSyncedAt;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: Spacing.sm),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                final engine = ref.read(syncEngineProvider);
                await engine?.syncNow();
                if (mounted) setState(() {});
              },
              child: Text(copy('sync.now')),
            ),
          ]),
          if (last != null) ...[
            const SizedBox(height: Spacing.xs),
            Text('${copy('sync.lastSynced')} '
                '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
          ],
          if (status.pendingCount > 0) ...[
            const SizedBox(height: Spacing.xs),
            Text('${copy('sync.pending')} ${status.pendingCount} ${copy('sync.rows')}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
          ],
          if (status.lastError != null) ...[
            const SizedBox(height: Spacing.xs),
            Text('${copy('sync.errorRecent')}：${status.lastError}',
                style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
          ],
        ]),
      ),
    );
  }

  // ===== 2 端点引导 =====

  Widget _guideCard(ColorScheme scheme) => Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(copy('sync.guideTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            Text(copy('sync.guideBody'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: () => context.push('/profile/cloud'),
              child: Text(copy('cloud.configSection')),
            ),
          ]),
        ),
      );

  // ===== 3 上云开关 =====

  Widget _tripToggles() {
    final repo = ref.watch(tripsRepoProvider);
    return StreamBuilder<List<Trip>>(
      stream: repo.watchAll(),
      builder: (context, snap) {
        final trips = snap.data ?? const <Trip>[];
        return Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            for (final t in trips)
              SwitchListTile(
                title: Text(t.name),
                subtitle: Text(t.destination, maxLines: 1, overflow: TextOverflow.ellipsis),
                value: ref.read(syncEngineProvider)?.tripSyncEnabled(t.id) ?? true,
                onChanged: (v) => _onToggleTrip(t, v),
              ),
          ]),
        );
      },
    );
  }

  Widget _groupToggles() {
    final repo = ref.watch(ledgerRepoProvider);
    return StreamBuilder<List<Group>>(
      stream: repo.watchGroups(),
      builder: (context, snap) {
        final groups = snap.data ?? const <Group>[];
        return Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            for (final g in groups)
              SwitchListTile(
                title: Text(g.name),
                value: ref.read(syncEngineProvider)?.groupSyncEnabled(g.id) ?? true,
                onChanged: (v) => _onToggleGroup(g, v),
              ),
          ]),
        );
      },
    );
  }

  Future<void> _onToggleTrip(Trip t, bool v) async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;
    if (!v) {
      final choice = await _pauseSheet();
      if (choice == null) return; // 取消
      if (choice == 2) {
        await engine.purgeEntityCloudRows(isTrip: true, id: t.id);
      }
      await engine.setTripSyncEnabled(t.id, false);
    } else {
      await engine.setTripSyncEnabled(t.id, true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onToggleGroup(Group g, bool v) async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;
    if (!v) {
      final choice = await _pauseSheet();
      if (choice == null) return;
      if (choice == 2) {
        await engine.purgeEntityCloudRows(isTrip: false, id: g.id);
      }
      await engine.setGroupSyncEnabled(g.id, false);
    } else {
      await engine.setGroupSyncEnabled(g.id, true);
    }
    if (mounted) setState(() {});
  }

  /// 关闭开关三选一（§3.9）：0 取消 / 1 仅暂停 / 2 连同删除云端数据。
  Future<int?> _pauseSheet() => showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(copy('sync.pauseKeep')), onTap: () => Navigator.pop(ctx, 1)),
            ListTile(
              title: Text(copy('sync.pausePurge')),
              subtitle: Text(copy('sync.pausePurgeWarn'),
                  style: const TextStyle(fontSize: AppFontSizes.caption)),
              onTap: () {
                showDialog<bool>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    title: Text(copy('sync.pausePurge')),
                    content: Text(copy('sync.pausePurgeWarn')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('确定')),
                    ],
                  ),
                ).then((ok) => Navigator.pop(ctx, ok == true ? 2 : null));
              },
            ),
            ListTile(title: Text(copy('sync.cancel')), onTap: () => Navigator.pop(ctx)),
          ]),
        ),
      );

  Widget _categoriesRow() => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(copy('sync.toggles.categories')),
          subtitle: Text(copy('sync.toggles.categoriesNote')),
          trailing: const Icon(Icons.lock_outline_rounded, size: 18),
        ),
      );

  // ===== 4 分享链接管理 =====

  Widget _shareLinksSection() {
    final links = _shareLinks;
    return Card(
      margin: EdgeInsets.zero,
      child: links == null
          ? const Padding(padding: EdgeInsets.all(Spacing.lg), child: Text('…'))
          : links.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text(copy('sync.linksEmpty'),
                      style: const TextStyle(fontSize: AppFontSizes.caption)))
              : Column(children: [
                  for (final l in links)
                    ListTile(
                      leading: Icon(
                        l['entity_type'] == 'trip'
                            ? Icons.flight_takeoff_rounded
                            : Icons.account_balance_wallet_rounded,
                        size: 20,
                      ),
                      title: Text((l['entity_id'] as String?) ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text((l['token'] as String?)?.substring(0, 8) ?? '',
                          style: const TextStyle(fontSize: AppFontSizes.caption)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () async {
                          final svc = ref.read(shareServiceProvider);
                          await svc?.deleteShareLink(l['token'] as String);
                          _reloadLists();
                        },
                      ),
                    ),
                ]),
    );
  }

  // ===== 5 邀请码管理 =====

  Widget _invitesSection() {
    final collabs = _collabs;
    return Card(
      margin: EdgeInsets.zero,
      child: (collabs == null || collabs.isEmpty)
          ? Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(copy('share.joinInvalid'),
                  style: const TextStyle(fontSize: AppFontSizes.caption)))
          : Column(children: [
              for (final c in collabs)
                if ((c['inviteCode'] as String?)?.isNotEmpty == true)
                  ListTile(
                    title: Text(c['groupId'] as String,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(c['inviteCode'] as String),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: copy('share.inviteRegen'),
                      onPressed: () async {
                        final svc = ref.read(collabServiceProvider);
                        try {
                          await svc?.regenerateInviteCode(c['groupId'] as String);
                          _reloadLists();
                        } on CloudAccountException {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(copy('share.ownerOnly'))));
                          }
                        }
                      },
                    ),
                  ),
            ]),
    );
  }

  // ===== 7 同步频率 =====

  Widget _freqSection() {
    final engine = ref.watch(syncEngineProvider);
    final current = engine?.freq ?? SyncFreq.standard;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        for (final f in SyncFreq.values)
          RadioListTile<SyncFreq>(
            title: Text(switch (f) {
              SyncFreq.economy => copy('sync.freq.economy'),
              SyncFreq.standard => copy('sync.freq.standard'),
              SyncFreq.realtime => copy('sync.freq.realtime'),
            }),
            subtitle: f == SyncFreq.realtime
                ? Text(copy('sync.freq.realtimeNote'),
                    style: const TextStyle(fontSize: AppFontSizes.caption))
                : null,
            value: f,
            groupValue: current,
            onChanged: (v) async {
              if (v != null) {
                await engine?.setFreq(v);
                if (mounted) setState(() {});
              }
            },
          ),
      ]),
    );
  }

  // ===== 8 云端占用估算（§3.19-11 固定单位行字节表） =====

  static const Map<String, int> _bytesPerRow = {
    'trips': 400, 'trip_items': 600, 'groups': 300, 'members': 120,
    'expenses': 400, 'settlements': 350, 'categories': 100,
  };

  Widget _usageSection() {
    final db = ref.watch(dbProvider);
    return FutureBuilder<Map<String, int>>(
      future: _countRows(db),
      builder: (context, snap) {
        final counts = snap.data;
        var totalBytes = 0;
        var topEntity = '';
        var topCount = 0;
        if (counts != null) {
          counts.forEach((k, v) {
            totalBytes += v * (_bytesPerRow[k] ?? 0);
            if (v > topCount) {
              topCount = v;
              topEntity = k;
            }
          });
        }
        final mb = (totalBytes / 1024 / 1024).toStringAsFixed(2);
        final topName = switch (topEntity) {
          'expenses' => '账单',
          'trip_items' => '安排',
          'trips' => '行程',
          'members' => '成员',
          'settlements' => '结算',
          'groups' => '账本',
          _ => '',
        };
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${copy('sync.cloudUsage')} $mb MB',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (topEntity.isNotEmpty)
                Text('行数最多的是「$topName」（$topCount 行）',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: AppFontSizes.caption)),
            ]),
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _countRows(AppDatabase db) async => {
        'trips': (await db.select(db.trips).get()).length,
        'trip_items': (await db.select(db.tripItems).get()).length,
        'groups': (await db.select(db.groups).get()).length,
        'members': (await db.select(db.members).get()).length,
        'expenses': (await db.select(db.expenses).get()).length,
        'settlements': (await db.select(db.settlements).get()).length,
        'categories': (await db.select(db.categories).get()).length,
      };

  // ===== 9 释放云端空间 =====

  Widget _releaseSection() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.cleaning_services_rounded, size: 20),
          title: Text(copy('sync.release')),
          onTap: () async {
            final svc = ref.read(cloudAccountServiceProvider);
            if (svc == null) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(copy('sync.status.signedOut'))));
              }
              return;
            }
            final months = await showModalBottomSheet<int>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final m in const [0, 3, 6, 12])
                    ListTile(
                      title: Text(m == 0 ? '全部清除（默认）' : '保留近 $m 个月'),
                      onTap: () => Navigator.pop(ctx, m),
                    ),
                ]),
              ),
            );
            if (months == null) return;
            try {
              final n = await svc.purgeDeletedRows(months);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${copy('sync.released')} $n ${copy('sync.rows')}')));
              }
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(copy('cloud.errGeneric'))));
              }
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.schedule_rounded, size: 20, color: scheme.outline),
          title: Text(copy('sync.releaseAutoNote'),
              style: TextStyle(color: scheme.outline)),
          enabled: false,
        ),
      ]),
    );
  }

  // ===== 6 局域网入口 =====

  Widget _lanEntry() => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.lan_rounded, size: 20),
          title: Text(copy('sync.lan')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/ledger/lan-sync'),
        ),
      );
}
