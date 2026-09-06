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
