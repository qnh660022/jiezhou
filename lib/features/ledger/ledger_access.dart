/// 账本内权限三态（V2.7.1 S7 · E2）：角色解析 + 可写判定。
///
/// 【设计要点】
/// * 角色唯一权威源是**空间成员表**（`space_members_sync` 本地镜像），
///   经 `travel_spaces.group_id` 投影到账本；映射与云端 `_group_role`
///   完全一致（空间 owner→owner、editor→editor、viewer→viewer）。
/// * 本地 `groups` 表里的行 = 我创建的账本 → owner。
/// * 解析不出角色时返回 `null`，UI 按**可写**处理：云 RLS 才是最终屏障，
///   「看不见的权限」比「误藏入口」安全（规格 §S7.1.4）。
/// * UI 只做「隐藏不置灰」（§S7.1.2），因此这里只提供布尔判定，不提供禁用态。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_account.dart' show SpaceRole;
import '../../data/sync/sync_control_providers.dart' show currentUserIdProvider;

/// 账本角色（与云端/空间三值一一对应）。
abstract final class LedgerRole {
  static const String owner = 'owner';
  static const String editor = 'editor';
  static const String viewer = 'viewer';

  static String labelOf(String? role) => SpaceRole.label(role ?? '');
}

/// 某账本的访问能力（UI 门控的唯一判据）。
class LedgerAccess {
  const LedgerAccess({
    required this.role,
    required this.canWrite,
    required this.canManage,
    this.online = true,
  });

  /// 解析出的角色；`null` = 未知（按 owner 语义放开写入口，RLS 兜底）。
  final String? role;

  /// 可记账 / 可编辑（owner 与 editor）。viewer = false。
  final bool canWrite;

  /// 可管理成员与角色（仅 owner）。viewer/editor = false。
  final bool canManage;

  /// 是否处于协作在线态（离线时共享镜像不可写，由调用方叠加）。
  final bool online;

  /// 是否为观察者（只读态）：S7.1.3 隐藏清单的判据。
  bool get readOnly => !canWrite;

  static const LedgerAccess owner = LedgerAccess(
      role: LedgerRole.owner, canWrite: true, canManage: true);

  /// 由角色字符串构造（未知/null 视为 owner 语义放开）。
  factory LedgerAccess.of(String? role, {bool online = true}) {
    final r = role ?? LedgerRole.owner;
    return LedgerAccess(
      role: r,
      canWrite: SpaceRole.canEdit(r),
      canManage: SpaceRole.canManage(r),
      online: online,
    );
  }
}

/// 解析「我在某账本的角色」。
///
/// 顺序：① 空间成员镜像（权威）→ ② 本地 groups 行（=我创建，owner）→ ③ null。
Future<String?> resolveMyGroupRole(
  AppDatabase db,
  String groupId,
  String? myUserId,
) async {
  if (groupId.isEmpty) return null;
  if (myUserId != null && myUserId.isNotEmpty) {
    final spaceQuery = db.select(db.travelSpaces)
      ..where((s) => s.groupId.equals(groupId));
    spaceQuery.where((s) => s.status.equals('active'));
    final spaces = await spaceQuery.get();
    for (final s in spaces) {
      // 链式 where（AND 语义）：避免依赖 drift 的 `&` 扩展，保持本文件
      // 只依赖 database.dart 的行类型。
      final q = db.select(db.spaceMembers)..where((m) => m.spaceId.equals(s.id));
      q.where((m) => m.userId.equals(myUserId));
      q.where((m) => m.deletedMs.isNull());
      final row = await q.getSingleOrNull();
      if (row != null) {
        // 与云端 _group_role 映射逐字一致：owner→owner、editor→editor、其余→viewer。
        switch (row.role) {
          case SpaceRole.owner:
            return LedgerRole.owner;
          case SpaceRole.editor:
            return LedgerRole.editor;
          default:
            return LedgerRole.viewer;
        }
      }
    }
  }
  final own = await (db.select(db.groups)..where((g) => g.id.equals(groupId)))
      .getSingleOrNull();
  if (own != null) return LedgerRole.owner;
  return null;
}

/// 我在某账本的角色（family 化，便于测试覆盖注入 viewer 态）。
final myGroupRoleProvider =
    FutureProvider.family<String?, String>((ref, groupId) async {
  final db = ref.watch(dbProvider);
  final uid = ref.watch(currentUserIdProvider);
  return resolveMyGroupRole(db, groupId, uid);
});

/// 某账本的 UI 访问能力。未知角色按「可写」放开（RLS 兜底）。
final ledgerAccessProvider =
    FutureProvider.family<LedgerAccess, String>((ref, groupId) async {
  final role = await ref.watch(myGroupRoleProvider(groupId).future);
  return LedgerAccess.of(role);
});
