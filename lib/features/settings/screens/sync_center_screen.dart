/// 同步中心（V2.6 §3.17.2）：路由 /profile/cloud/sync。
/// 区块：状态卡 / 端点引导 / 上云开关 / 分享链接 / 邀请码 / 局域网入口 /
/// 同步频率 / 云端占用估算 / 释放云端空间。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_account.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../data/sync/sync_models.dart';
import '../../../platform/network_probe.dart' show NetKind;
import '../../../shared/app_meta.dart' show shareLinkUrl;
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sync_status_capsule.dart'
    show syncStatusColor;
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
          const SizedBox(height: Spacing.md),
          _autoSyncCard(),
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
          _collabCenterEntry(),
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
    final color = syncStatusColor(scheme, status.kind);
    final label = switch (status.kind) {
      SyncStatusKind.unconfigured => copy('sync.status.unconfigured'),
      SyncStatusKind.signedOut => copy('sync.status.signedOut'),
      SyncStatusKind.syncing => copy('sync.status.syncing'),
      SyncStatusKind.idle => copy('sync.status.idle'),
      SyncStatusKind.offline => copy('sync.status.offline'),
    };
    final last = status.lastSyncedAt;
    final failUntil = ref.read(syncEngineProvider)?.throttleUntil;
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
                // 手动同步 = 重置死信与节流后全量重试（否则多次失败的行
                // 永远被跳过，「待同步 N 行」只增不减）。
                await engine?.retryFailedNow();
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
            // 死信提示：多次失败的行此前会被自动重试跳过，手动同步已改为先重置再重试
            FutureBuilder<int>(
              future: ref.read(syncEngineProvider)?.outbox.deadLetterCount() ??
                  Future.value(0),
              builder: (_, snap) {
                final n = snap.data ?? 0;
                if (n <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text('其中 $n 行${copy('sync.deadLetterHint')}',
                      style: TextStyle(
                          color: scheme.error, fontSize: AppFontSizes.caption)),
                );
              },
            ),
          ],
          if (status.lastError != null) ...[
            const SizedBox(height: Spacing.xs),
            Text('${copy('sync.errorRecent')}：${status.lastError}',
                style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
          ],
          // 失败节流中：告诉用户「什么时候会自己好」，否则只看到「离线」很慌。
          if (failUntil != null && failUntil.isAfter(DateTime.now())) ...[
            const SizedBox(height: Spacing.xs),
            Text(
                '失败次数过多，自动同步已暂停，将于 ${_hmm(failUntil)} 自动恢复'
                '（点「立即同步」可立刻重试）',
                style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
          ],
        ]),
      ),
    );
  }

  static String _hmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ===== 1.5 自动同步总开关 / 仅 Wi-Fi =====

  /// 「即改即同步」的总闸与网络条件闸。
  ///
  /// 总开关关闭后：停周期任务、不排写后 push，但本地写仍会入队（一条不丢），
  /// 手动「立即同步」照常可用；重新打开时会自动补推积压的改动。
  Widget _autoSyncCard() {
    final engine = ref.read(syncEngineProvider);
    final scheme = Theme.of(context).colorScheme;
    final auto = engine?.autoEnabled ?? true;
    final wifiOnly = engine?.wifiOnly ?? false;
    final kind = engine?.netKind ?? NetKind.unknown;
    final blocked = engine?.wifiBlockedNow ?? false;
    final caption = const TextStyle(fontSize: AppFontSizes.caption);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.sync_rounded, size: 20),
          title: Text(copy('sync.auto.title')),
          subtitle: Text(auto ? copy('sync.auto.onNote') : copy('sync.auto.offNote'),
              style: caption),
          value: auto,
          onChanged: engine == null
              ? null
              : (v) async {
                  await engine.setAutoEnabled(v);
                  if (mounted) setState(() {});
                },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi_rounded, size: 20),
          title: Text(copy('sync.auto.wifiOnly')),
          subtitle: Text(copy('sync.auto.wifiOnlyNote'), style: caption),
          value: wifiOnly,
          onChanged: engine == null
              ? null
              : (v) async {
                  await engine.setWifiOnly(v);
                  if (mounted) setState(() {});
                },
        ),
        if (blocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: scheme.error),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(copy('sync.wifiBlocked'),
                    style: caption.copyWith(color: scheme.error)),
              ),
            ]),
          )
        else if (wifiOnly && kind == NetKind.unknown)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
            child: Text(copy('sync.auto.wifiUnknown'),
                style: caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ]),
    );
  }

  // ===== 2 未启用提示（端点已改为构建时默认注入，无手填入口） =====

  Widget _guideCard(ColorScheme scheme) => Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(copy('cloud.notConfigured'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppFontSizes.caption)),
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

  // ===== 3.5 分享与协作中心入口 =====

  /// 同步页里最常被问的一句话是「邀请在哪、分享链接在哪」——直接给一个入口。
  Widget _collabCenterEntry() => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.ios_share_rounded, size: 20),
          title: Text(copy('sync.collabCenter')),
          subtitle: Text(copy('sync.collabCenterNote'),
              style: const TextStyle(fontSize: AppFontSizes.caption)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/profile/share'),
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
                  child: Text(
                      '${copy('sync.linksEmpty')}（在 行程分享页 / 共享团详情页 可生成）',
                      style: const TextStyle(fontSize: AppFontSizes.caption)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md,
                        Spacing.lg, Spacing.sm),
                    child: Text(
                        '只读链接：任何人不登录即可在浏览器查看，不能修改；口令在创建时设置。',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: AppFontSizes.caption)),
                  ),
                  for (final l in links)
                    _shareLinkTile(l),
                ]),
    );
  }

  /// 单条分享链接：本地反查实体名（同步表行 id 对人无意义），完整 URL 可复制。
  Widget _shareLinkTile(Map<String, dynamic> l) {
    final isTrip = l['entity_type'] == 'trip';
    final entityId = (l['entity_id'] as String?) ?? '';
    final token = (l['token'] as String?) ?? '';
    final db = ref.watch(dbProvider);
    return FutureBuilder<String>(
      future: _entityName(db, isTrip, entityId),
      builder: (_, snap) {
        final name = snap.data ?? entityId;
        return ListTile(
          leading: Icon(
            isTrip
                ? Icons.flight_takeoff_rounded
                : Icons.account_balance_wallet_rounded,
            size: 20,
          ),
          title: Text(name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('只读 · /s/${token.substring(0, token.length.clamp(0, 8))}…',
              style: const TextStyle(fontSize: AppFontSizes.caption)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: '复制链接',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: shareLinkUrl(token)));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('链接已复制')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: '撤销（拿到链接的人立即无法访问）',
              onPressed: () async {
                final svc = ref.read(shareServiceProvider);
                await svc?.deleteShareLink(token);
                _reloadLists();
              },
            ),
          ]),
        );
      },
    );
  }

  Future<String> _entityName(AppDatabase db, bool isTrip, String id) async {
    if (isTrip) {
      final rows = await (db.select(db.trips)..where((t) => t.id.equals(id))).get();
      if (rows.isNotEmpty) return rows.first.name;
      final shared = await (db.select(db.sharedGroups)
            ..where((g) => g.id.equals(id)))
          .get();
      if (shared.isNotEmpty) return shared.first.name;
      return '行程 $id';
    }
    final groups = await (db.select(db.groups)..where((g) => g.id.equals(id))).get();
    if (groups.isNotEmpty) return groups.first.name;
    final shared = await (db.select(db.sharedGroups)
          ..where((g) => g.id.equals(id)))
        .get();
    if (shared.isNotEmpty) return shared.first.name;
    return '账本 $id';
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
    // 缺省实时：与引擎 SyncFreqX.fromKey 的缺省保持一致（此前这里回落 standard，
    // 与引擎口径不符，首次进入页面会显示「标准 15s」而实际按实时跑）。
    final current = engine?.freq ?? SyncFreq.realtime;
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
