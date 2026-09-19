/// 旅伴中心（V2.6.6.2 §5，代号 S3；路由 `/profile/share`，path 不变以兼容旧入口）。
///
/// 收编 V2.6 时代散落 5 处的协作/分享入口（共享账本、邀请码、只读链接、分享中心、
/// 局域网同步），并升级为「协作世界的门厅」：
///
/// 四个固定分区（§5，**禁止把四个区平铺成一张长列表**，各区一张独立分区卡）：
/// 1. 我的空间（置顶，新增）：我创建/加入的空间卡列表 + 新建空间向导；
/// 2. 邀请与加入：生成/管理空间邀请码（角色、有效期）、输入/扫码加入
///    （复用 qr_scan_screen；旧账本邀请码走同一入口，join_space 内置兼容）；
/// 3. 只读分享链接：listMyShareLinks 能力平移（列表/复制/撤销/新建）；
/// 4. 局域网同步：现有能力平移。
///
/// 视觉（§6.4，D12）：Hero 层（页标题 display(34) + 一句话说明 caption +
/// 新建空间主按钮，不与列表争位）→ 分区层（区块标题 + 分区卡）→ 条目层（三段式）。
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
import '../../../shared/widgets/collab_polling_scope.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/share_link_sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../../companions/space_actions.dart';
import '../../companions/widgets/space_widgets.dart';
import '../../ledger/screens/qr_scan_screen.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class ShareCenterScreen extends ConsumerStatefulWidget {
  const ShareCenterScreen({super.key});

  @override
  ConsumerState<ShareCenterScreen> createState() => _ShareCenterScreenState();
}

class _ShareCenterScreenState extends ConsumerState<ShareCenterScreen> {
  List<Map<String, dynamic>>? _links;
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
    try {
      _links = share == null ? null : await share.listMyShareLinks();
    } catch (_) {
      _links = null;
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

  void _toast(String msg) {
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, msg);
}

  @override
  Widget build(BuildContext context) {
    return CollabPollingScope(
      child: Scaffold(
        appBar: AppBar(title: Text(copy('share.centerTitle'))),
        body: ListView(
          padding: const EdgeInsets.only(bottom: Spacing.xxxl),
          children: [
            const _Hero(),
            if (!_signedIn) _signInHint(),
            _spacesSection(),
            _inviteSection(),
            _readonlySection(),
            _lanSection(),
          ],
        ),
      ),
    );
  }

  // ===== Hero 层 =====

  Widget _signInHint() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.sm),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        child: CompanionTile(
          icon: Icons.cloud_off_rounded,
          title: copy('sync.status.signedOut'),
          subtitle: copy('share.signInHint'),
          tint: scheme.outline,
          onTap: () => context.push('/profile/cloud'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }

  // ===== 1 我的空间（置顶） =====

  Widget _spacesSection() {
    final repo = ref.watch(travelSpacesRepoProvider);
    final uid = ref.watch(currentUserIdProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= DesktopLayout.breakpoint;
    // 门厅页只展示最近 3 个（避免"门厅变列表页"），全部列表走 /companions
    const previewLimit = 3;
    return CompanionSectionCard(
      title: '我的空间',
      subtitle: '一程一空间：行程与账本都能和旅伴一起管',
      trailingLabel: '全部',
      onTrailingTap: () => context.push('/companions'),
      child: StreamBuilder<List<TravelSpace>>(
        stream: repo.watchSpaces(includeArchived: isDesktop),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SkeletonBox(height: 72, radius: AppRadius.buttonValue);
          }
          final spaces = snap.data!;
          if (spaces.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                companionEmpty('还没有旅伴空间',
                    '建一个空间，把行程和账本分享给同行的旅伴。'),
                PrimaryButton(
                  label: '新建空间',
                  icon: Icons.add_rounded,
                  expanded: true,
                  onPressed: _signedIn ? () => _createSpace() : null,
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in spaces.take(previewLimit))
                StreamBuilder<List<SpaceMember>>(
                  stream: repo.watchMembers(s.id),
                  builder: (context, ms) {
                    final members = ms.data ?? const <SpaceMember>[];
                    return SpaceCard(
                      space: s,
                      members: members,
                      myRole: _roleOf(members, uid) ??
                          ref.read(syncEngineProvider)?.mySpaceRoleOf(s.id),
                      onTap: () => context.push('/companions/space/${s.id}'),
                    );
                  },
                ),
              if (spaces.length > previewLimit)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    '还有 ${spaces.length - previewLimit} 个空间，点右上「全部」查看',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: Spacing.md),
              PrimaryButton(
                label: '新建空间',
                icon: Icons.add_rounded,
                expanded: true,
                onPressed: _signedIn ? () => _createSpace() : null,
              ),
            ],
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

  Future<void> _createSpace() async {
    final spaceId = await showCreateSpaceSheet(context);
    if (!mounted || spaceId == null || spaceId.isEmpty) return;
    context.push('/companions/space/$spaceId');
  }

  // ===== 2 邀请与加入 =====

  Widget _inviteSection() {
    return CompanionSectionCard(
      title: '邀请与加入',
      subtitle: '空间邀请码 / 旧账本邀请码，都在这里输入',
      child: Column(
        children: [
          CompanionTile(
            icon: Icons.qr_code_2_rounded,
            title: '输入邀请码加入',
            subtitle: '6 位码，旧版共享账本邀请码同样有效（会自动升级为空间）',
            enabled: _signedIn,
            onTap: _joinByCode,
          ),
          const Divider(height: 1),
          CompanionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: '扫码加入',
            subtitle: '扫旅伴分享的二维码',
            enabled: _signedIn,
            onTap: _scanToJoin,
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode() async {
    final ctl = _codeCtl;
    ctl.clear();
    final code = await showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      builder: (d, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.sm,
          Spacing.lg,
          Spacing.lg,
        ),
        children: [
          Text('加入旅伴空间', style: Theme.of(d).textTheme.titleLarge),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: ctl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
                labelText: '邀请码（6 位）', counterText: ''),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(d, ctl.text.trim()),
                  child: const Text('加入'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    await _doJoin(code);
  }

  Future<void> _scanToJoin() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    await _doJoin(code);
  }

  Future<void> _doJoin(String raw) async {
    // 扫码结果可能是完整链接（/invite?c=XXXXXX），先抽码
    final code = _extractCode(raw);
    final (spaceId, legacy, err) =
        await SpaceActions.join(ref, code);
    if (!mounted) return;
    if (err.isNotEmpty) {
      _toast(spaceErrorText(err));
      return;
    }
    _toast(legacy ? '已加入（旧共享账本已升级为空间）' : '已加入旅伴空间');
    if (spaceId.isEmpty) {
      await _reload();
      return;
    }
    context.push('/companions/space/$spaceId');
  }

  /// 从任意文本里抽 6 位邀请码（兼容 `/invite?c=ABC123` 与纯码）。
  static String _extractCode(String raw) {
    final trimmed = raw.trim();
    final m = RegExp(r'[A-Za-z0-9]{6}').allMatches(trimmed.toUpperCase());
    if (m.isEmpty) return trimmed;
    return m.last.group(0)!;
  }

  // ===== 3 只读分享链接 =====

  Widget _readonlySection() {
    final links = _links;
    return CompanionSectionCard(
      title: '只读分享链接',
      subtitle: '拿到链接的人只能看，不能改',
      child: Column(
        children: [
          CompanionTile(
            icon: Icons.flight_takeoff_rounded,
            title: copy('share.tripLinkTitle'),
            subtitle: copy('share.tripLinkNote'),
            enabled: _signedIn,
            onTap: _pickTripForLink,
          ),
          const Divider(height: 1),
          CompanionTile(
            icon: Icons.account_balance_wallet_rounded,
            title: copy('share.groupLinkTitle'),
            subtitle: copy('share.groupLinkNote'),
            enabled: _signedIn,
            onTap: _pickGroupForLink,
          ),
          const Divider(height: 1),
          if (links == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text(copy('share.mySharedEmpty'),
                  style: const TextStyle(fontSize: AppFontSizes.caption)),
            )
          else if (links.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text(copy('share.readonlyEmpty'),
                  style: const TextStyle(fontSize: AppFontSizes.caption)),
            )
          else
            for (final l in links) _linkTile(l),
        ],
      ),
    );
  }

  Widget _linkTile(Map<String, dynamic> l) {
    final token = (l['token'] as String?) ?? '';
    final isTrip = l['entity_type'] == 'trip';
    final entityId = (l['entity_id'] as String?) ?? '';
    final db = ref.watch(dbProvider);
    return FutureBuilder<String>(
      future: _entityName(db, isTrip, entityId),
      builder: (_, snap) => CompanionTile(
        icon: isTrip
            ? Icons.flight_takeoff_rounded
            : Icons.account_balance_wallet_rounded,
        title: snap.data ?? entityId,
        subtitle: '/s/${token.substring(0, token.length.clamp(0, 8))}…',
        onTap: () => _copy(shareLinkUrl(token)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: copy('share.copyLink'),
            onPressed: () => _copy(shareLinkUrl(token)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            tooltip: '撤销链接',
            onPressed: () async {
              await ref.read(shareServiceProvider)?.deleteShareLink(token);
              _reload();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pickTripForLink() async {
    final db = ref.read(dbProvider);
    final trips = await (db.select(db.trips)).get();
    if (!mounted) return;
    if (trips.isEmpty) {
      _toast(copy('share.createReadonlyEmpty'));
      return;
    }
    final picked = await _pickEntity<(String, String)>(
      title: '选一个行程分享',
      rows: [
        for (final t in trips)
          (
            icon: Icons.flight_takeoff_rounded,
            label: '${t.emoji} ${t.name}',
            value: ('trip', t.id),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    await showShareLinkSheet(context,
        entityType: picked.$1, entityId: picked.$2);
    _reload();
  }

  Future<void> _pickGroupForLink() async {
    final db = ref.read(dbProvider);
    final groups = await (db.select(db.groups)).get();
    if (!mounted) return;
    if (groups.isEmpty) {
      _toast(copy('share.createReadonlyEmpty'));
      return;
    }
    final picked = await _pickEntity<(String, String)>(
      title: '选一个账本分享',
      rows: [
        for (final g in groups)
          (
            icon: Icons.account_balance_wallet_rounded,
            label: '${g.icon} ${g.name}',
            value: ('group', g.id),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    await showShareLinkSheet(context,
        entityType: picked.$1, entityId: picked.$2);
    _reload();
  }

  Future<T?> _pickEntity<T>({
    required String title,
    required List<({IconData icon, String label, T value})> rows,
  }) =>
      showDraggableSheet<T>(
        context: context,
        initialChildSize: 0.55,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            for (final r in rows)
              CompanionTile(
                icon: r.icon,
                title: r.label,
                onTap: () => Navigator.pop(ctx, r.value),
              ),
          ],
        ),
      );

  Future<String> _entityName(AppDatabase db, bool isTrip, String id) async {
    if (isTrip) {
      final rows = await (db.select(db.trips)..where((t) => t.id.equals(id))).get();
      return rows.isEmpty ? '行程 $id' : rows.first.name;
    }
    final groups = await (db.select(db.groups)..where((g) => g.id.equals(id))).get();
    return groups.isEmpty ? '账本 $id' : groups.first.name;
  }

  // ===== 4 局域网同步 =====

  Widget _lanSection() => CompanionSectionCard(
        title: copy('sync.lan'),
        subtitle: '两台手机连同一 Wi-Fi，断网也能互传账本与行程',
        child: CompanionTile(
          icon: Icons.lan_rounded,
          title: copy('share.lanEntry'),
          subtitle: '不经过云端，直接点对点传',
          onTap: () => context.push('/ledger/lan-sync'),
        ),
      );
}

// ============================================================
// Hero 层：页标题 display(34) + 一句话说明 + 主按钮不占列表位
// ============================================================

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('旅伴中心', style: AppTextStyles.display(scheme)),
          const SizedBox(height: Spacing.xs),
          Text(
            '和同行的人一起改行程、一起记账。',
            style: TextStyle(
                fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 邀请码展示/复制（供空间邀请与旧账本邀请复用）。
Future<void> showInviteCodeDialog(
  BuildContext context, {
  required String code,
  required String title,
}) =>
    showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.42,
      builder: (ctx, scrollController) {
        final scheme = Theme.of(ctx).colorScheme;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: Spacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xl, vertical: Spacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: AppRadius.input,
              ),
              child: Center(
                child: Text(code,
                    style: TextStyle(
                        fontSize: AppFontSizes.headline,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: scheme.onSurface)),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('也可以把邀请链接发出去：${inviteLinkUrl(code)}',
                style: TextStyle(
                    fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.lg),
            PrimaryButton(
              label: '复制邀请链接',
              expanded: true,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteLinkUrl(code)));
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );

/// 供测试与外部引用的空态占位（保持与其他页面一致的留白）。
Widget shareCenterEmpty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Text(text,
          style: const TextStyle(fontSize: AppFontSizes.caption)),
    );
