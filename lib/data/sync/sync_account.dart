/// 云端账号 / 协作邀请 / 只读分享 的客户端服务层（RPC 封装 + Auth 操作）。
library;
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class CloudAccountException implements Exception {
  CloudAccountException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// 密码强度策略（V2.6.2 升级）：至少 8 位，且必须同时包含字母与数字。
/// 仅用于注册/改密等"设置新密码"场景；登录走服务端校验，不拦老用户。
/// 返回 null = 通过；否则返回 CloudAccountException 错误码
/// （`password_short` / `password_weak`）。
String? signupPasswordIssue(String password) {
  if (password.length < 8) return 'password_short';
  final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
  final hasDigit = password.contains(RegExp(r'[0-9]'));
  if (!hasLetter || !hasDigit) return 'password_weak';
  return null;
}

/// 登录/注册/登出/清除云端数据。
class CloudAccountService {
  CloudAccountService(this._client);

  final SupabaseClient _client;

  Session? get session => _client.auth.currentSession;
  String? get userId => _client.auth.currentUser?.id;
  String? get email => _client.auth.currentUser?.email;

  /// 注册即登录（服务端需关闭邮箱确认）。
  Future<void> signUp(String email, String password) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.session == null && res.user == null) {
        throw CloudAccountException('signup_failed');
      }
    } on AuthException catch (e) {
      throw CloudAccountException(_mapAuthError(e, signup: true));
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw CloudAccountException(_mapAuthError(e));
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  String _mapAuthError(AuthException e, {bool signup = false}) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'email_taken';
    }
    // 先判字符种类要求（消息含 "contain at least one character of each..."，
    // 也带 "at least" 字样，必须排在长度规则之前）。
    if (m.contains('password') && (m.contains('contain') || m.contains('character'))) {
      return 'password_weak';
    }
    if (m.contains('password') && (m.contains('at least') || m.contains('short'))) {
      return 'password_short';
    }
    if (m.contains('invalid login credentials')) return 'bad_credentials';
    if (m.contains('email not confirmed')) return 'email_not_confirmed';
    if (m.contains('rate limit')) return 'rate_limited';
    return signup ? 'signup_failed' : 'login_failed';
  }

  /// 清除云端数据（§3.15）：成功后本地 outbox 清空、游标归零（由调用方处理）。
  Future<void> purgeMyData() async {
    final res = await _client.rpc('purge_my_data');
    final ok = res is Map && res['ok'] == true;
    if (!ok) throw CloudAccountException('purge_failed');
  }

  /// 手动释放云端空间（软删行物理清理）→ 返回删除行数。
  Future<int> purgeDeletedRows(int retainMonths) async {
    final res = await _client.rpc('purge_deleted_rows', params: {'retain_months': retainMonths});
    if (res is Map && res['ok'] == true) {
      return (res['deletedRows'] as num?)?.toInt() ?? 0;
    }
    throw CloudAccountException('purge_failed');
  }

  /// 云端非敏感 AI 配置（app_settings：ai.base_url / ai.model，不含 key）。
  Future<String?> loadCloudAiSetting(String key) async {
    final rows = await _client.from('app_settings').select('value').eq('key', key).limit(1);
    if (rows is List && rows.isNotEmpty) {
      return (rows.first as Map)['value'] as String?;
    }
    return null;
  }

  Future<void> saveCloudAiSetting(String key, String value) async {
    await _client.from('app_settings').upsert({'key': key, 'value': value});
  }
}

/// 协作邀请（账本）客户端：邀请码加入 / 重新生成 / 移除 / 退出 / 名单。
class CollabService {
  CollabService(this._client);

  final SupabaseClient _client;

  /// 输入邀请码加入 → ok 时返回 groupId。
  Future<(String groupId, String error)> joinByCode(String code) async {
    final res = await _client.rpc('add_collab_member', params: {'code': code.trim().toUpperCase()});
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    if (map['ok'] == true) return (map['groupId'] as String, '');
    return ('', (map['error'] as String?) ?? 'invalid_code');
  }

  Future<String> regenerateInviteCode(String groupId) async {
    final res = await _client.rpc('regenerate_invite_code', params: {'group_id': groupId});
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    if (map['ok'] == true) return map['code'] as String;
    throw CloudAccountException((map['error'] as String?) ?? 'not_owner');
  }

  Future<void> removeMember(String groupId, String targetUserId) async {
    final res = await _client.rpc('remove_collab_member',
        params: {'group_id': groupId, 'target': targetUserId});
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    if (map['ok'] != true) throw CloudAccountException((map['error'] as String?) ?? 'not_owner');
  }

  Future<void> leave(String groupId) async {
    final res = await _client.rpc('leave_collab', params: {'group_id': groupId});
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    if (map['ok'] != true) throw CloudAccountException((map['error'] as String?) ?? 'not_member');
  }

  /// 我的协作名单：[{groupId, ownerUserId, inviteCode?}]。
  Future<List<Map<String, dynamic>>> listMyCollabs() async {
    final res = await _client.rpc('list_my_collabs');
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    if (map['ok'] != true) return const [];
    final list = (map['collabs'] as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// 为团开启协作：owner 首次邀请时建立 group_collab 行（邀请码服务端可重签）。
  /// 若已存在则原样返回现码（幂等）。
  Future<String> ensureInvite(String groupId) async {
    final collabs = await listMyCollabs();
    for (final c in collabs) {
      if (c['groupId'] == groupId && (c['inviteCode'] as String?)?.isNotEmpty == true) {
        return c['inviteCode'] as String;
      }
    }
    // 首次：生成 6 位码写入 group_collab（owner 直表写，owner_all 放行）
    final code = genInviteCode();
    await _client.from('group_collab').upsert({
      'group_id': groupId,
      'owner_user_id': _client.auth.currentUser?.id,
      'invite_code': code,
      'member_user_id': <String>[],
    }, onConflict: 'group_id');
    return code;
  }

  /// 受邀成员列表（owner 查看：需要成员邮箱 → group_collab 只有 id；
  /// 成员展示名以本地 shared 镜像/邀请记录为准，这里仅返回 userId 列表）。
  Future<List<String>> listMemberUserIds(String groupId) async {
    final rows = await _client
        .from('group_collab')
        .select('member_user_id, owner_user_id')
        .eq('group_id', groupId)
        .limit(1);
    if (rows is List && rows.isNotEmpty) {
      final row = (rows.first as Map)['member_user_id'];
      if (row is List) return row.cast<String>();
    }
    return const [];
  }
}

/// 邀请码字符集（去 0/O/1/I；与服务端一致）。客户端仅用于本地展示回退。
String genInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  final sb = StringBuffer();
  for (var i = 0; i < 6; i++) {
    sb.write(chars[rng.nextInt(chars.length)]);
  }
  return sb.toString();
}

/// 只读分享（行程 + 账本）客户端：生成/删除链接，拉取快照。
class ShareService {
  ShareService(this._client);

  final SupabaseClient _client;

  /// 生成分享链接。pass 非空（4 位数字）时服务端算 bcrypt 哈希——
  /// 但 bcrypt 哈希须由服务端算：此处经 RPC 建行（见 db_v26.sql 的 create_share_link）。
  Future<String> createShareLink({required String entityType, required String entityId, String? pass}) async {
    final res = await _client.rpc('create_share_link', params: {
      'entity_type': entityType,
      'entity_id': entityId,
      'pass': (pass == null || pass.isEmpty) ? null : pass,
    });
    final map = (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
    if (map['ok'] == true) return map['token'] as String;
    throw CloudAccountException((map['error'] as String?) ?? 'share_failed');
  }

  Future<void> deleteShareLink(String token) async {
    await _client.from('share_links').delete().eq('token', token);
  }

  /// 我创建的分享链接（同步中心管理列表）。
  Future<List<Map<String, dynamic>>> listMyShareLinks() async {
    final rows = await _client
        .from('share_links')
        .select('token,entity_type,entity_id,created_at')
        .order('created_at');
    return (rows as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// 匿名拉取只读快照（need_pass / bad_pass / not_found 语义化错误）。
  Future<Map<String, dynamic>> getShareSnapshot(String token, String? pass) async {
    final res = await _client.rpc('get_share_snapshot', params: {'token': token, 'pass': pass});
    return (res is Map) ? res.cast<String, dynamic>() : {'ok': false, 'error': 'not_found'};
  }
}

// ============================================================
// V2.6.6.2 旅伴空间客户端（§3.5 RPC 契约）
//
// 统一约定：
//   * 每个方法返回 (值, errorCode)，errorCode 为空串表示成功；调用方负责 UI 文案；
//   * `unauthenticated` 单独识别（未登录提示），其余归为通用失败；
//   * 所有 RPC 都返回 {ok: bool, ...}；服务端函数未部署时 PostgREST 抛
//     PGRST202，由调用方 catch 后提示「云端未升级」。
// ============================================================

/// 空间成员角色（与云端 space_members_sync.role 取值一致）。
abstract final class SpaceRole {
  static const String owner = 'owner';
  static const String editor = 'editor';
  static const String viewer = 'viewer';

  static const List<String> all = [owner, editor, viewer];

  static String label(String role) => switch (role) {
        owner => '创建者',
        editor => '编辑者',
        viewer => '观察者',
        _ => '成员',
      };

  /// UI 权限位：能否编辑协作内容（行程项 / 账单 / 结算）。
  static bool canEdit(String? role) => role == owner || role == editor;

  /// UI 权限位：能否管理成员与空间设置。
  static bool canManage(String? role) => role == owner;
}

/// 协作空间（旅伴空间）客户端。
class SpaceService {
  SpaceService(this._client);

  final SupabaseClient _client;

  String? get userId => _client.auth.currentUser?.id;

  Map<String, dynamic> _asMap(Object? res) =>
      res is Map ? res.cast<String, dynamic>() : <String, dynamic>{};

  String _errOf(Map<String, dynamic> m, [String fallback = 'failed']) =>
      (m['error'] as String?) ?? fallback;

  /// 我的空间名单：[{spaceId, name, tripId, groupId, status, createdBy, role, inviteCode}]。
  ///
  /// 与 [CollabService.listMyCollabs] 同构：同步引擎每轮 pull 前刷新协作上下文用。
  Future<List<Map<String, dynamic>>> listMySpaces() async {
    final res = await _client.rpc('list_my_spaces');
    final map = _asMap(res);
    if (map['ok'] != true) return const [];
    final list = (map['spaces'] as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// 建空间（+ owner 成员行）。成功返回 (spaceId, '')。
  Future<(String spaceId, String error)> createSpace({
    required String name,
    String? tripId,
    String? groupId,
    String? note,
  }) async {
    final res = await _client.rpc('create_space', params: {
      'p_name': name,
      'p_trip_id': tripId,
      'p_group_id': groupId,
      'p_note': note,
    });
    final m = _asMap(res);
    if (m['ok'] == true) return ((m['space_id'] as String?) ?? '', '');
    return ('', _errOf(m));
  }

  /// 改空间（仅 owner）。传 null 表示不改该字段。
  Future<String> updateSpace({
    required String spaceId,
    String? name,
    String? status,
    String? tripId,
    String? groupId,
  }) async {
    final res = await _client.rpc('update_space', params: {
      'p_space_id': spaceId,
      'p_name': name,
      'p_status': status,
      'p_trip_id': tripId,
      'p_group_id': groupId,
    });
    final m = _asMap(res);
    return m['ok'] == true ? '' : _errOf(m);
  }

  /// 生成空间邀请码（仅 owner）。返回 (code, expiresMs, error)。
  Future<(String code, int? expiresMs, String error)> createInvite({
    required String spaceId,
    String role = SpaceRole.editor,
    int? ttlHours,
  }) async {
    final res = await _client.rpc('create_space_invite', params: {
      'p_space_id': spaceId,
      'p_role': role,
      'p_ttl_hours': ttlHours,
    });
    final m = _asMap(res);
    if (m['ok'] == true) {
      return ((m['code'] as String?) ?? '', (m['expires_ms'] as num?)?.toInt(), '');
    }
    return ('', null, _errOf(m));
  }

  /// 加入空间（单一入口；自动兼容旧账本邀请码）。返回 (spaceId, legacy, error)。
  Future<(String spaceId, bool legacy, String error)> joinSpace(String code) async {
    final res = await _client
        .rpc('join_space', params: {'p_code': code.trim().toUpperCase()});
    final m = _asMap(res);
    if (m['ok'] == true) {
      return ((m['space_id'] as String?) ?? '', m['legacy'] == true, '');
    }
    return ('', false, _errOf(m, 'invalid_code'));
  }

  /// 改成员角色（仅 owner）。
  Future<String> setMemberRole({
    required String spaceId,
    required String targetUserId,
    required String role,
  }) async {
    final res = await _client.rpc('set_space_member_role', params: {
      'p_space_id': spaceId,
      'p_target': targetUserId,
      'p_role': role,
    });
    final m = _asMap(res);
    return m['ok'] == true ? '' : _errOf(m);
  }

  /// 移除成员（仅 owner；不能移除自己）。
  Future<String> removeMember({
    required String spaceId,
    required String targetUserId,
  }) async {
    final res = await _client.rpc('remove_space_member', params: {
      'p_space_id': spaceId,
      'p_target': targetUserId,
    });
    final m = _asMap(res);
    return m['ok'] == true ? '' : _errOf(m);
  }

  /// 协作直写行程项（空间 owner/editor）。成功返回 (写回行, '')。
  Future<(Map<String, dynamic>? row, String error)> upsertTripItem({
    required String spaceId,
    required Map<String, dynamic> item,
  }) async {
    final res = await _client.rpc('upsert_trip_item_collab', params: {
      'p_item': item,
      'p_space_id': spaceId,
    });
    final m = _asMap(res);
    if (m['ok'] == true) {
      final row = m['row'];
      return (row is Map ? row.cast<String, dynamic>() : null, '');
    }
    return (null, _errOf(m));
  }

  /// 协作删除行程项（空间 owner/editor）。
  Future<String> deleteTripItem({
    required String spaceId,
    required String itemId,
  }) async {
    final res = await _client.rpc('delete_trip_item_collab', params: {
      'p_item_id': itemId,
      'p_space_id': spaceId,
    });
    final m = _asMap(res);
    return m['ok'] == true ? '' : _errOf(m);
  }

  /// 自助退出空间（owner 不可用，只能删空间）。
  Future<String> leaveSpace(String spaceId) async {
    final res = await _client.rpc('leave_space', params: {'p_space_id': spaceId});
    final m = _asMap(res);
    return m['ok'] == true ? '' : _errOf(m);
  }

  /// 删空间（仅 owner；动态保留为只读残档）。
  Future<String> deleteSpace(String spaceId) async {
    final res = await _client.rpc('delete_space', params: {'p_space_id': spaceId});
    final m = _asMap(res);
    return m['ok'] == true ? '' : _errOf(m);
  }

  /// 账本域协作写成功后补一条空间动态（尽力而为，§4.2）。
  ///
  /// 失败一律吞掉：动态流是展示素材，绝不能因为它让主操作（记账/结算）报错，
  /// 也不进 outbox 重试（避免死信放大）。
  Future<void> appendEvent({
    required String spaceId,
    required String action,
    required String entityKind,
    String? entityId,
    String summary = '',
  }) async {
    final uid = userId;
    if (uid == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _client.from('space_events_sync').insert({
        'id': 'evt_${now}_${action.hashCode.abs()}',
        'space_id': spaceId,
        'actor_user': uid,
        'action': action,
        'entity_kind': entityKind,
        'entity_id': entityId,
        'summary': summary,
        'created_ms': now,
        'updated_ms': now,
        'deleted': false,
      });
    } catch (_) {
      // 动态补齐失败不影响主操作
    }
  }
}
