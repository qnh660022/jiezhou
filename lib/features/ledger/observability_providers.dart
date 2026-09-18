/// V2.7.1 S12：协作可观测性的 UI 数据源（冲突回执 + 审计轨迹）。
///
/// 全部数据源都指向**本地两张表**（`conflict_records` / `audit_logs`），
/// 不经过任何同步 Provider；团切换时按团重订阅（family）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repo/observability_repo.dart';
import 'ledger_providers.dart' show activeGroupIdProvider;

/// 当前激活团的未确认冲突总数（账本主页同步状态区展示）。
final unacknowledgedConflictCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(dbProvider);
  final gid = ref.watch(activeGroupIdProvider).value ?? '';
  return watchUnacknowledgedConflictCount(db, groupId: gid);
});

/// 当前激活团「存在未确认冲突」的实体 id 集合（账单行小标记）。
final conflictEntityIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(dbProvider);
  final gid = ref.watch(activeGroupIdProvider).value ?? '';
  if (gid.isEmpty) return Stream.value(const <String>{});
  return watchUnacknowledgedConflictEntityIds(db, gid);
});

/// 某团某实体的未确认冲突（点标记时弹提示用）。
final entityConflictsProvider =
    FutureProvider.family<List<ConflictRecord>, String>((ref, entityId) async {
  final db = ref.watch(dbProvider);
  return conflictsOfEntity(db, entityId);
});

/// 变更记录流；[entity] 为 null/空 = 全部（按实体筛选）。
final auditLogsProvider =
    StreamProvider.family<List<AuditLog>, String?>((ref, entity) {
  final db = ref.watch(dbProvider);
  final gid = ref.watch(activeGroupIdProvider).value ?? '';
  if (gid.isEmpty) return Stream.value(const <AuditLog>[]);
  return watchAuditLogs(db, gid, entity: entity);
});

/// 确认「知道了」：置位该实体的全部未确认回执（本地，纯提示语义）。
Future<void> acknowledgeEntityConflicts(WidgetRef ref, String entityId) async {
  final db = ref.read(dbProvider);
  await acknowledgeConflictsOfEntity(db, entityId);
}
