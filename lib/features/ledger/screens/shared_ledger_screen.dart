/// 共享账本完整版（受邀端，V2.6 §3.13 / §3.17.5；S4 起退化为薄壳）：
/// - 首页「共享账本」分组卡（数据源 shared_groups 镜像）；
/// - 团详情四 Tab：账单 / 成员 / 统计 / 结算 —— 组合
///   `widgets/shared_ledger_sections.dart` 的四个公开 section widget；
/// - 在线直写通道（`SharedDirectWrite`）随四能力一并迁到 widgets/，本文件
///   只负责「取数据源 + 判权限」这一层组合；四 Tab 的行为、文案、RPC 名称、
///   云端列名与权限可见性判定全部由 section 内部保持原样（零行为变化）；
/// - 离线：全部写入口隐藏，卡片显示「离线仅可查看」；
/// - 管理操作（团名/图标/预算/归档/邀请/移除/删团）仅 owner 可见，member 端隐藏；
/// - 结算口径与本地账本一致（domain/settle_engine：已付−应摊，最少转账贪心）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/share_link_sheet.dart';
import '../../../theme/tokens.dart';
import '../widgets/shared_ledger_sections.dart';

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
///
/// S4 起本页只做组合：数据源镜像（[MirrorLedgerSectionData]）+ 权限判定
/// （在线 / owner），四能力分别由账单/成员/统计/结算 section 承载。
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

  /// 受邀端镜像数据源（写通道字段在 build 时随 provider 取最新值）。
  LedgerSectionData _data() => MirrorLedgerSectionData(
        db: _db,
        groupId: widget.groupId,
        cloudClient: ref.read(cloudClientProvider),
        syncEngine: ref.read(syncEngineProvider),
      );

  @override
  Widget build(BuildContext context) {
    final db = _db;
    final online = _online;
    final isOwner = _isOwner;
    final data = _data();
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
        SharedBillsSection(data: data, online: online),
        SharedMembersSection(data: data, online: online, isOwner: isOwner),
        SharedStatsSection(data: data),
        SharedSettleSection(data: data, online: online, isOwner: isOwner),
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
