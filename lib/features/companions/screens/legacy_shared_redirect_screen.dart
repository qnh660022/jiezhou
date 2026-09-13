/// 老共享账本路由退役承接页（V2.6.6.2 §7.2）。
///
/// `/ledger/shared/:id` 不再渲染旧四 Tab 页，而是把 groupId 解析成对应的旅伴空间，
/// 再 `replace` 到空间详情页的账本区（`/companions/space/:spaceId?tab=ledger`）。
///
/// 为什么不做成 go_router 的同步 `redirect`：空间 id 需要查本地镜像表（异步），
/// 同步 redirect 里拿不到。这里用一个极薄的承接页承担异步解析，用户体验上等价。
///
/// 解析顺序：
/// 1. 本地 `travel_spaces` 里按 `group_id` 直接命中（迁移脚本已跑过）；
/// 2. 没命中 → 触发一次 pull（可能的迁移/新空间会在这轮下来）后再查一次；
/// 3. 仍没有 → 说明云端还没执行 db_v2662.sql / migrate_spaces_v2662.sql，
///    给出明确的手动操作指引（§0.3.13 云端 SQL 由需求方手动执行）。
library;
import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';

class LegacySharedRedirectScreen extends ConsumerStatefulWidget {
  const LegacySharedRedirectScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<LegacySharedRedirectScreen> createState() =>
      _LegacySharedRedirectScreenState();
}

class _LegacySharedRedirectScreenState
    extends ConsumerState<LegacySharedRedirectScreen> {
  bool _resolving = true;
  bool _notMigrated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve({bool allowPull = true}) async {
    if (mounted) {
      setState(() {
        _resolving = true;
        _notMigrated = false;
      });
    }
    final repo = ref.read(travelSpacesRepoProvider);
    var spaceId = await _find(repo.db);
    if (spaceId == null && allowPull) {
      // 迁移可能刚在云端执行：拉一轮再看
      await ref.read(syncEngineProvider)?.afterCollabWrite();
      spaceId = await _find(repo.db);
    }
    if (!mounted) return;
    if (spaceId == null) {
      setState(() {
        _resolving = false;
        _notMigrated = true;
      });
      return;
    }
    context.replace('/companions/space/$spaceId?tab=ledger');
  }

  Future<String?> _find(AppDatabase db) async {
    final rows = await (db.select(db.travelSpaces)
          ..where((s) => s.groupId.equals(widget.groupId) & s.deletedMs.isNull()))
        .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return Scaffold(
        appBar: GlassAppBar(title: '共享账本'),
        body: const Padding(
          padding: EdgeInsets.all(Spacing.xl),
          child: SkeletonBox(height: 120, radius: AppRadius.cardValue),
        ),
      );
    }
    assert(_notMigrated, '非解析中即应为"云端未迁移"分支');
    return Scaffold(
      appBar: GlassAppBar(title: '共享账本'),
      body: EmptyState(
        emoji: '🧭',
        title: '这个共享账本还没升级成空间',
        message: '云端需要先执行 docs/db_v2662.sql 与 docs/migrate_spaces_v2662.sql，'
            '再回到这里重试。升级不会删除任何账本数据。',
        actionLabel: '重试',
        onAction: () => unawaited(_resolve()),
      ),
    );
  }
}
