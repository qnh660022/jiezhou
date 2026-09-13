// V2.6.6.2 §10.5：join_space 对旧码的回退语义（mock 旧 RPC 行为）。
//
// 真实场景（§7.1 部署顺序：先云端后客户端）：
//   * 云端已跑 db_v2662.sql → join_space 内置旧码回退，返回 {ok, space_id, legacy:true}；
//   * 云端还没升级 → join_space 不存在，PostgREST 抛 PGRST202；
//   * 老客户端仍在用 add_collab_member —— 迁移不得删除 group_collab 数据。
// 本用例用假 RPC 覆盖以上全部分支。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/sync/join_flow.dart';

/// 可编程假 RPC：记录调用顺序，按脚本返回或抛错。
class FakeJoinRpc implements JoinRpc {
  FakeJoinRpc({
    this.joinSpaceResult,
    this.joinSpaceThrows = false,
    this.legacyResult,
    this.legacyThrows = false,
  });

  Map<String, dynamic>? joinSpaceResult;
  bool joinSpaceThrows;
  Map<String, dynamic>? legacyResult;
  bool legacyThrows;

  final List<String> calls = [];
  final List<String> codes = [];

  @override
  Future<Map<String, dynamic>> joinSpace(String code) async {
    calls.add('join_space');
    codes.add(code);
    if (joinSpaceThrows) {
      throw Exception(
          'PostgrestException(message: Could not find the function public.join_space(p_code), code: PGRST202)');
    }
    return joinSpaceResult ?? {'ok': false, 'error': 'invalid_code'};
  }

  @override
  Future<Map<String, dynamic>> addCollabMember(String code) async {
    calls.add('add_collab_member');
    codes.add(code);
    if (legacyThrows) throw Exception('network down');
    return legacyResult ?? {'ok': false, 'error': 'invalid_code'};
  }
}

void main() {
  group('新入口命中（空间邀请码）', () {
    test('返回 space_id 且 legacy=false', () async {
      final rpc = FakeJoinRpc(
          joinSpaceResult: {'ok': true, 'space_id': 'space_1', 'legacy': false});
      final out = await joinByCodeWithLegacyFallback(rpc, 'abcd12');
      expect(out.ok, isTrue);
      expect(out.spaceId, 'space_1');
      expect(out.legacy, isFalse);
      expect(rpc.calls, ['join_space'], reason: '命中新入口就不该再打旧 RPC');
      expect(rpc.codes.single, 'ABCD12', reason: '码统一大写后上行');
    });
  });

  group('服务端内置旧码回退（云端已升级）', () {
    test('legacy=true 且带回 space_id，不再打旧 RPC', () async {
      final rpc = FakeJoinRpc(joinSpaceResult: {
        'ok': true,
        'space_id': 'space_legacy',
        'legacy': true,
      });
      final out = await joinByCodeWithLegacyFallback(rpc, 'OLD123');
      expect(out.ok, isTrue);
      expect(out.spaceId, 'space_legacy');
      expect(out.legacy, isTrue);
      expect(rpc.calls, ['join_space']);
      expect(joinOutcomeMessage(out), contains('旧版共享账本'));
    });
  });

  group('客户端兜底（云端未升级 / join_space 不存在）', () {
    test('join_space 抛 PGRST202 → 退到 add_collab_member 并拿到 groupId', () async {
      final rpc = FakeJoinRpc(
        joinSpaceThrows: true,
        legacyResult: {'ok': true, 'groupId': 'g1'},
      );
      final out = await joinByCodeWithLegacyFallback(rpc, 'legacy');
      expect(out.ok, isTrue);
      expect(out.groupId, 'g1');
      expect(out.legacy, isTrue,
          reason: '客户端兜底路径必须标记 legacy，UI 据此提示"自动升级为空间"');
      expect(out.spaceId, isEmpty);
      expect(needsSpaceLookup(out), isTrue,
          reason: '老云端没有 space 概念，需要按 groupId 反查/提示升级云端');
      expect(rpc.calls, ['join_space', 'add_collab_member']);
    });

    test('join_space 返回 invalid_code → 也退旧 RPC（老码不在空间表里）', () async {
      final rpc = FakeJoinRpc(
        joinSpaceResult: {'ok': false, 'error': 'invalid_code'},
        legacyResult: {'ok': true, 'groupId': 'g2'},
      );
      final out = await joinByCodeWithLegacyFallback(rpc, 'MIX123');
      expect(out.ok, isTrue);
      expect(out.groupId, 'g2');
      expect(rpc.calls, ['join_space', 'add_collab_member']);
    });

    test('两条路径都不认 → invalid_code（不允许把失败当成功）', () async {
      final rpc = FakeJoinRpc(
        joinSpaceResult: {'ok': false, 'error': 'invalid_code'},
        legacyResult: {'ok': false, 'error': 'invalid_code'},
      );
      final out = await joinByCodeWithLegacyFallback(rpc, 'NOPE99');
      expect(out.ok, isFalse);
      expect(out.error, 'invalid_code');
      expect(joinOutcomeMessage(out), contains('无效'));
    });

    test('旧 RPC 也抛错 → failed（不抛给 UI）', () async {
      final rpc = FakeJoinRpc(joinSpaceThrows: true, legacyThrows: true);
      final out = await joinByCodeWithLegacyFallback(rpc, 'X1');
      expect(out.ok, isFalse);
      expect(out.error, 'failed');
    });
  });

  group('不该退旧路径的情况', () {
    test('未登录：直接报 unauthenticated', () async {
      final rpc = FakeJoinRpc(
        joinSpaceResult: {'ok': false, 'error': 'unauthenticated'},
        legacyResult: {'ok': true, 'groupId': 'g1'},
      );
      final out = await joinByCodeWithLegacyFallback(rpc, 'ANY123');
      expect(out.ok, isFalse);
      expect(out.error, 'unauthenticated');
      expect(rpc.calls, ['join_space'], reason: '账号态错误退旧 RPC 没有意义');
    });

    test('空间码已撤销 / 已过期：明确报错，不退旧路径', () async {
      for (final code in ['revoked_code', 'expired_code']) {
        final rpc = FakeJoinRpc(
          joinSpaceResult: {'ok': false, 'error': code},
          legacyResult: {'ok': true, 'groupId': 'g1'},
        );
        final out = await joinByCodeWithLegacyFallback(rpc, 'CODE12');
        expect(out.error, code);
        expect(rpc.calls, ['join_space']);
      }
    });

    test('空码直接判无效，不打网络', () async {
      final rpc = FakeJoinRpc();
      final out = await joinByCodeWithLegacyFallback(rpc, '   ');
      expect(out.ok, isFalse);
      expect(out.error, 'invalid_code');
      expect(rpc.calls, isEmpty);
    });
  });
}
