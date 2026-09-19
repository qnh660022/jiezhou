/// 行程内权限三态（V2.7.2 A12）：角色解析 + 可写判定。
///
/// 【设计要点】与 `lib/features/ledger/ledger_access.dart` **逐条同构**，
/// 差别仅在投影列：账本走 `travel_spaces.group_id`，行程走
/// `travel_spaces.trip_id`。两处角色语义必须一致，否则同一个旅伴空间里
/// 「行程能改、账本不能改」会自相矛盾。
///
/// * 角色唯一权威源是**空间成员表**（`space_members` 本地镜像），经
///   `travel_spaces.trip_id` 投影到行程；映射与云端 `_trip_role` 一致
///   （空间 owner→owner、editor→editor、其余→viewer）。
/// * 本地 `trips` 表里的行 = 我创建的行程 → owner。
/// * 解析不出角色时返回 `null`，UI 按**可写**处理：云 RLS 才是最终屏障，
///   「看不见的权限」比「误藏入口」安全。
/// * UI 只做「隐藏不置灰」（§S7.1.2），因此这里只提供布尔判定。
///
/// 【V2.8.3.3 背景】V2.7.2 A12 要求「旅伴空间完整适配（editor 可写 /
/// viewer 只读，覆盖 A1~A10 全部新 UI）」。各面板（WishlistPanel /
/// AssemblePanel / OutlineTab / KitTab）**都已预留 `canEdit` 参数**，
/// 但宿主从未传入 —— 详情页三处调用点全是硬编码 `true`，viewer 进详情页
/// 仍可写。本文件补齐缺失的判定基建。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_account.dart' show SpaceRole;
import '../../data/sync/sync_control_providers.dart' show currentUserIdProvider;

/// 行程角色（与账本/空间三值一一对应）。
abstract final class TripRole {
  static const String owner = 'owner';
  static const String editor = 'editor';
  static const String viewer = 'viewer';

  static String labelOf(String? role) => SpaceRole.label(role ?? '');
}

/// 某行程的访问能力（行程域 UI 门控的唯一判据）。
class TripAccess {
  const TripAccess({required this.role, required this.canWrite});

  /// 解析出的角色；`null` = 未知（按 owner 语义放开写入口，RLS 兜底）。
  final String? role;

  /// 可编辑行程内容（owner 与 editor）。viewer = false。
  final bool canWrite;

  /// 是否观察者（只读态）：隐藏一切写入口的判据。
  bool get readOnly => !canWrite;

  static const TripAccess owner = TripAccess(role: TripRole.owner, canWrite: true);

  /// 由角色字符串构造（未知/null 视为 owner 语义放开）。
  factory TripAccess.of(String? role) {
    final r = role ?? TripRole.owner;
    return TripAccess(role: r, canWrite: SpaceRole.canEdit(r));
  }
}

/// 解析「我在某行程的角色」。
///
/// 顺序：① 空间成员镜像（权威）→ ② 本地 trips 行（=我创建，owner）→ ③ null。
Future<String?> resolveMyTripRole(
  AppDatabase db,
  String tripId,
  String? myUserId,
) async {
  if (tripId.isEmpty) return null;
  if (myUserId != null && myUserId.isNotEmpty) {
    final spaceQuery = db.select(db.travelSpaces)
      ..where((s) => s.tripId.equals(tripId));
    spaceQuery.where((s) => s.status.equals('active'));
    final spaces = await spaceQuery.get();
    for (final s in spaces) {
      // 链式 where（AND 语义）：与 ledger_access 同写法，避免依赖 drift
      // 的 `&` 扩展，保持本文件只依赖 database.dart 的行类型。
      final q = db.select(db.spaceMembers)..where((m) => m.spaceId.equals(s.id));
      q.where((m) => m.userId.equals(myUserId));
      q.where((m) => m.deletedMs.isNull());
      final row = await q.getSingleOrNull();
      if (row != null) {
        switch (row.role) {
          case SpaceRole.owner:
            return TripRole.owner;
          case SpaceRole.editor:
            return TripRole.editor;
          default:
            return TripRole.viewer;
        }
      }
    }
  }
  final own = await (db.select(db.trips)..where((t) => t.id.equals(tripId)))
      .getSingleOrNull();
  if (own != null) return TripRole.owner;
  return null;
}

/// 我在某行程的角色（family 化，便于测试覆盖注入 viewer 态）。
final myTripRoleProvider =
    FutureProvider.family<String?, String>((ref, tripId) async {
  final db = ref.watch(dbProvider);
  final uid = ref.watch(currentUserIdProvider);
  return resolveMyTripRole(db, tripId, uid);
});

/// 某行程的 UI 访问能力。未知角色按「可写」放开（RLS 兜底）。
final tripAccessProvider =
    FutureProvider.family<TripAccess, String>((ref, tripId) async {
  final role = await ref.watch(myTripRoleProvider(tripId).future);
  return TripAccess.of(role);
});
