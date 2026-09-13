/// 旅伴空间动作层（V2.6.6.2 §5 / §6）：把「RPC + 本地镜像 + 写后读」三步收在一处。
///
/// 为什么要单独一层：旅伴中心（S3）、空间详情页（S5）、新建空间向导三处都要做
/// 同样的三件事，任何一处漏掉"写后立即 pull"就会出现「我改了但自己看不到」。
///
/// 统一返回**错误码字符串**（空串 = 成功），由 UI 决定文案与 toast。
library;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/sync/join_flow.dart';
import '../../data/sync/sync_account.dart';
import '../../data/sync/sync_control_providers.dart';

/// 把 [SpaceService] 适配成 [JoinRpc]，让「新入口优先、旧 RPC 兜底」的
/// 纯编排逻辑（join_flow.dart，可单测）能复用真实 RPC。
class _SupabaseJoinRpc implements JoinRpc {
  _SupabaseJoinRpc(this.space, this.collab);

  final SpaceService space;
  final CollabService collab;

  @override
  Future<Map<String, dynamic>> joinSpace(String code) async {
    // 直接走 SupabaseClient，保留原始 error 码（SpaceService 会把它折成元组）
    final res = await space.joinSpace(code);
    if (res.$3.isEmpty) {
      return {'ok': true, 'space_id': res.$1, 'legacy': res.$2};
    }
    return {'ok': false, 'error': res.$3};
  }

  @override
  Future<Map<String, dynamic>> addCollabMember(String code) async {
    final res = await collab.joinByCode(code);
    if (res.$2.isEmpty) return {'ok': true, 'groupId': res.$1};
    return {'ok': false, 'error': res.$2};
  }
}

/// 错误码 → 用户可读文案（统一口径，避免各页面各写一套）。
String spaceErrorText(String code) => switch (code) {
      '' => '',
      'unauthenticated' => '请先登录云端账号',
      'invalid_code' => '邀请码无效或已失效',
      'revoked_code' => '该邀请码已被撤销',
      'expired_code' => '该邀请码已过期',
      'not_owner' => '只有空间创建者能这么做',
      'not_member' => '你不在这个空间里',
      'cannot_remove_self' => '不能移除自己',
      'cannot_demote_owner' => '不能降低创建者的角色',
      'owner_cannot_leave' => '创建者不能退出，只能删除空间',
      'forbidden' => '你是观察者，只能查看',
      'group_already_in_space' => '该账本已经在一个空间里了',
      'name_required' => '请给空间起个名字',
      'trip_mismatch' => '该安排不属于这个空间关联的行程',
      'item_not_found' => '这条安排已不存在',
      'not_found' => '内容不存在或已删除',
      'bad_role' => '角色不合法',
      'PGRST202' => '云端还没升级：请先执行 docs/db_v2662.sql',
      _ => code.startsWith('PGRST') || code.contains('Postgrest')
          ? '云端还没升级：请先执行 docs/db_v2662.sql'
          : '操作失败，请稍后重试',
    };

abstract final class SpaceActions {
  /// 云功能是否可用。
  static bool _ready(WidgetRef ref) =>
      ref.read(cloudClientProvider) != null &&
      ref.read(currentUserIdProvider) != null;

  static String get _notSignedIn => 'unauthenticated';

  /// 新建空间（RPC 成功后本地镜像 + 写后读）。
  static Future<(String spaceId, String error)> createSpace(
    WidgetRef ref, {
    required String name,
    String? tripId,
    String? groupId,
    String? note,
  }) async {
    if (!_ready(ref)) return ('', _notSignedIn);
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return ('', _notSignedIn);
    final (spaceId, err) = await svc.createSpace(
        name: name, tripId: tripId, groupId: groupId, note: note);
    if (err.isNotEmpty) return ('', err);
    final now = DateTime.now().millisecondsSinceEpoch;
    final uid = ref.read(currentUserIdProvider) ?? '';
    final repo = ref.read(travelSpacesRepoProvider);
    await repo.mirrorSpace(
      TravelSpacesCompanion.insert(
        id: spaceId,
        name: name,
        tripId: Value(tripId),
        groupId: Value(groupId),
        createdBy: uid,
        note: Value(note),
        status: const Value('active'),
        createdMs: now,
        updatedMs: now,
      ),
    );
    await repo.mirrorMember(
      SpaceMembersCompanion.insert(
        id: 'sm_local_$spaceId',
        spaceId: spaceId,
        userId: uid,
        role: const Value(SpaceRole.owner),
        displayName: const Value('我'),
        joinedMs: now,
        createdMs: now,
        updatedMs: now,
      ),
    );
    // 写后读：让服务端真正的 owner 成员行（含 display_name）覆盖本地占位
    await ref.read(syncEngineProvider)?.onJoinedSharedSpace(spaceId);
    return (spaceId, '');
  }

  /// 改空间（仅 owner）。
  static Future<String> updateSpace(
    WidgetRef ref, {
    required String spaceId,
    String? name,
    String? status,
    String? tripId,
    String? groupId,
  }) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final err = await svc.updateSpace(
        spaceId: spaceId,
        name: name,
        status: status,
        tripId: tripId,
        groupId: groupId);
    if (err.isNotEmpty) return err;
    await ref.read(syncEngineProvider)?.afterCollabWrite();
    return '';
  }

  /// 加入空间（新入口优先，旧账本码兜底）。
  ///
  /// 返回 (spaceId, legacy, error)。旧码兜底且服务端未给 spaceId 时，
  /// 会按 groupId 反查本地空间行。
  static Future<(String spaceId, bool legacy, String error)> join(
    WidgetRef ref,
    String code,
  ) async {
    if (!_ready(ref)) return ('', false, _notSignedIn);
    final space = ref.read(spaceServiceProvider);
    final collab = ref.read(collabServiceProvider);
    if (space == null || collab == null) return ('', false, _notSignedIn);

    final outcome =
        await joinByCodeWithLegacyFallback(_SupabaseJoinRpc(space, collab), code);
    if (!outcome.ok) return ('', false, outcome.error);

    final engine = ref.read(syncEngineProvider);
    await engine?.onJoinedSharedSpace(outcome.spaceId);
    if (outcome.spaceId.isNotEmpty) {
      return (outcome.spaceId, outcome.legacy, '');
    }
    // 旧码兜底路径：服务端只回了 groupId（老云端尚不支持空间）。
    // 拉一轮后用 group_id 反查本地空间行；查不到说明云端还没跑迁移脚本。
    await engine?.afterCollabWrite();
    final spaceId = await _spaceIdByGroup(ref, outcome.groupId);
    if (spaceId == null) return ('', true, 'PGRST202');
    return (spaceId, true, '');
  }

  static Future<String?> _spaceIdByGroup(WidgetRef ref, String groupId) async {
    if (groupId.isEmpty) return null;
    final db = ref.read(dbProvider);
    final rows = await (db.select(db.travelSpaces)
          ..where((s) => s.groupId.equals(groupId) & s.deletedMs.isNull()))
        .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  /// 生成空间邀请码（仅 owner）。
  static Future<(String code, String error)> createInvite(
    WidgetRef ref, {
    required String spaceId,
    String role = SpaceRole.editor,
    int? ttlHours,
  }) async {
    if (!_ready(ref)) return ('', _notSignedIn);
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return ('', _notSignedIn);
    final (code, _, err) =
        await svc.createInvite(spaceId: spaceId, role: role, ttlHours: ttlHours);
    return (code, err);
  }

  /// 改成员角色（仅 owner）。
  static Future<String> setMemberRole(
    WidgetRef ref, {
    required String spaceId,
    required String targetUserId,
    required String role,
  }) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final err = await svc.setMemberRole(
        spaceId: spaceId, targetUserId: targetUserId, role: role);
    if (err.isNotEmpty) return err;
    await ref.read(syncEngineProvider)?.afterCollabWrite();
    return '';
  }

  /// 移除成员（仅 owner）。
  static Future<String> removeMember(
    WidgetRef ref, {
    required String spaceId,
    required String targetUserId,
  }) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final err =
        await svc.removeMember(spaceId: spaceId, targetUserId: targetUserId);
    if (err.isNotEmpty) return err;
    await ref.read(travelSpacesRepoProvider)
        .markMemberRemoved(spaceId, targetUserId,
            DateTime.now().millisecondsSinceEpoch);
    await ref.read(syncEngineProvider)?.afterCollabWrite();
    return '';
  }

  /// 退出空间（owner 不可用）。
  static Future<String> leave(WidgetRef ref, String spaceId) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final err = await svc.leaveSpace(spaceId);
    if (err.isNotEmpty) return err;
    await ref.read(syncEngineProvider)?.onLeftSharedSpace(spaceId);
    return '';
  }

  /// 删除空间（仅 owner；动态保留为只读残档）。
  static Future<String> deleteSpace(WidgetRef ref, String spaceId) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final err = await svc.deleteSpace(spaceId);
    if (err.isNotEmpty) return err;
    await ref.read(syncEngineProvider)?.onSpaceDeleted(spaceId);
    return '';
  }

  /// 协作直写行程项（空间 owner/editor）：RPC → 本地镜像 → 写后读。
  ///
  /// ⚠️ 与共享账本同一模式：**不直写本地业务表**，失败 toast 不落本地。
  static Future<String> upsertTripItem(
    WidgetRef ref, {
    required String spaceId,
    required Map<String, dynamic> item,
  }) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final (row, err) = await svc.upsertTripItem(spaceId: spaceId, item: item);
    if (err.isNotEmpty) return err;
    final repo = ref.read(travelSpacesRepoProvider);
    if (row != null) {
      await repo.mirrorCollabTripItem(row);
    } else {
      await repo.mirrorCollabTripItem(item);
    }
    await _appendEvent(ref, spaceId, 'trip_item_updated', 'trip_item',
        item['id'] as String?, (item['name'] as String?) ?? '行程项');
    await ref.read(syncEngineProvider)?.afterCollabWrite();
    return '';
  }

  /// 协作删除行程项。
  static Future<String> deleteTripItem(
    WidgetRef ref, {
    required String spaceId,
    required String itemId,
    String summary = '',
  }) async {
    if (!_ready(ref)) return _notSignedIn;
    final svc = ref.read(spaceServiceProvider);
    if (svc == null) return _notSignedIn;
    final err = await svc.deleteTripItem(spaceId: spaceId, itemId: itemId);
    if (err.isNotEmpty) return err;
    await ref.read(travelSpacesRepoProvider).removeCollabTripItem(itemId);
    await _appendEvent(
        ref, spaceId, 'trip_item_deleted', 'trip_item', itemId, summary);
    await ref.read(syncEngineProvider)?.afterCollabWrite();
    return '';
  }

  /// 账本域协作写成功后补一条空间动态（§4.2 尽力而为）。
  static Future<void> appendLedgerEvent(
    WidgetRef ref, {
    required String spaceId,
    required String action,
    required String entityKind,
    String? entityId,
    String summary = '',
  }) =>
      _appendEvent(ref, spaceId, action, entityKind, entityId, summary);

  static Future<void> _appendEvent(
    WidgetRef ref,
    String spaceId,
    String action,
    String entityKind,
    String? entityId,
    String summary,
  ) async {
    final svc = ref.read(spaceServiceProvider);
    final repo = ref.read(travelSpacesRepoProvider);
    final uid = ref.read(currentUserIdProvider) ?? '';
    // 本地立即可见（离线也不丢展示）
    await repo.appendEventLocal(
      id: 'evt_local_${DateTime.now().microsecondsSinceEpoch}',
      spaceId: spaceId,
      actorUser: uid,
      action: action,
      entityKind: entityKind,
      entityId: entityId,
      summary: summary,
    );
    await svc?.appendEvent(
      spaceId: spaceId,
      action: action,
      entityKind: entityKind,
      entityId: entityId,
      summary: summary,
    );
  }
}
