/// 统一「加入协作」编排（V2.6.6.2 §3.5 join_space + §7.1/§7.4 旧码兼容）。
///
/// 为什么单独抽一层：服务端 `join_space` 本身已经内置了「先查空间邀请码、未命中
/// 再回退旧账本邀请码」的逻辑，但**老云端根本没有这个函数**（新客户端先于云端
/// 升级、或用户所在环境还没跑 db_v2662.sql 时），PostgREST 会以 `PGRST202`
/// 抛错而不是返回 `{ok:false}`。这就要求客户端也有一条兜底路径：
///
/// ```
/// join_space（新入口，含服务端旧码回退）
///   ├─ ok                → 直接用返回的 space_id
///   ├─ unauthenticated   → 直接报错（别再退，退了也是同一个错）
///   ├─ invalid_code      → 退到旧 add_collab_member
///   └─ 抛异常（PGRST202）→ 退到旧 add_collab_member
/// add_collab_member（旧 RPC）
///   └─ ok → 拿到 groupId，但拿不到 spaceId（老云端没有空间概念）
/// ```
///
/// 这一层是**纯编排**（只依赖注入的 [JoinRpc]），因此 §10.5 的回退语义可以完全
/// 用假 RPC 覆盖，不需要真的连云端。
library;

/// 加入结果。
class JoinOutcome {
  const JoinOutcome({
    this.spaceId = '',
    this.groupId = '',
    this.legacy = false,
    this.error = '',
  });

  /// 新空间 id（旧码兜底路径下可能为空，此时用 [groupId] 找对应空间）。
  final String spaceId;

  /// 旧语义的账本 id（legacy 路径返回）。
  final String groupId;

  /// 是否走了「旧账本邀请码」回退路径（服务端 join_space 的 legacy 标记，
  /// 或客户端退到 add_collab_member）。
  final bool legacy;

  /// 错误码；空串 = 成功。
  final String error;

  bool get ok => error.isEmpty;

  @override
  String toString() =>
      'JoinOutcome(spaceId: $spaceId, groupId: $groupId, legacy: $legacy, error: $error)';
}

/// 加入流程依赖的两个 RPC（真实实现见 sync_account.dart 的适配器）。
abstract class JoinRpc {
  /// 新入口：`join_space(p_code)`。
  Future<Map<String, dynamic>> joinSpace(String code);

  /// 旧入口：`add_collab_member(code)`。
  Future<Map<String, dynamic>> addCollabMember(String code);
}

/// 执行「新入口优先、旧 RPC 兜底」的加入编排。
Future<JoinOutcome> joinByCodeWithLegacyFallback(
  JoinRpc rpc,
  String rawCode,
) async {
  final code = rawCode.trim().toUpperCase();
  if (code.isEmpty) {
    return const JoinOutcome(error: 'invalid_code');
  }

  Map<String, dynamic>? first;
  try {
    first = await rpc.joinSpace(code);
  } catch (_) {
    // PGRST202（函数未部署）/ 网络异常：一律走兜底，把"新入口不可用"和
    // "码无效"区分开交给旧 RPC 再判一次。
    first = null;
  }

  if (first != null) {
    if (first['ok'] == true) {
      return JoinOutcome(
        spaceId: (first['space_id'] as String?) ?? '',
        legacy: first['legacy'] == true,
      );
    }
    final err = (first['error'] as String?) ?? 'failed';
    // 未登录是账号态问题，退回旧 RPC 只会拿到同一个错误
    if (err != 'invalid_code' && err != 'revoked_code' && err != 'expired_code') {
      return JoinOutcome(error: err);
    }
    if (err == 'revoked_code' || err == 'expired_code') {
      // 空间码确实存在但已失效：明确告诉用户，不再退旧路径
      return JoinOutcome(error: err);
    }
  }

  // ===== 兜底：旧账本邀请码 =====
  try {
    final legacyRes = await rpc.addCollabMember(code);
    if (legacyRes['ok'] == true) {
      return JoinOutcome(
        groupId: (legacyRes['groupId'] as String?) ?? '',
        legacy: true,
      );
    }
    return JoinOutcome(
        error: (legacyRes['error'] as String?) ?? 'invalid_code');
  } catch (_) {
    return const JoinOutcome(error: 'failed');
  }
}

/// 加入成功后的提示文案（区分新旧路径，让用户知道发生了什么）。
String joinOutcomeMessage(JoinOutcome outcome) {
  if (!outcome.ok) return '邀请码无效或已失效';
  if (outcome.legacy) {
    return '已加入（旧版共享账本已自动升级为旅伴空间）';
  }
  return '已加入旅伴空间';
}

/// 是否需要为「旧码兜底且服务端没给 spaceId」的情况反查空间 id。
///
/// 老云端没有 space 概念，因此返回 null 时调用方应提示用户升级云端
/// （本版本交付含 docs/db_v2662.sql + docs/migrate_spaces_v2662.sql）。
bool needsSpaceLookup(JoinOutcome outcome) =>
    outcome.ok && outcome.spaceId.isEmpty;
