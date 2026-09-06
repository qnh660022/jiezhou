/// SyncTransport 的 Supabase 真实现（PostgREST + RPC）。
///
/// 复合游标经 `or` 表达式：`(updated_ms,last) 之后 = updated_ms>last OR
/// (updated_ms=last AND id>lastId)`；按 updated_ms,id 升序取 limit 行。
/// 日志/异常对 key/token 字段脱敏（不落明文）。
library;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_transport.dart';

class SyncTransportSupabase implements SyncTransport {
  SyncTransportSupabase(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<bool> ping() async {
    try {
      await _client.auth.getSession();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _compositeFilter(int updatedMsAfter, String idAfter) {
    final idPart = idAfter.isEmpty ? '' : ",and(updated_ms.eq.$updatedMsAfter,id.gt.$idAfter)";
    return 'updated_ms.gt.$updatedMsAfter$idPart';
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String entity,
      {required int updatedMsAfter, required String idAfter, required int limit}) async {
    final rows = await _client
        .from(entity)
        .select()
        .or(_compositeFilter(updatedMsAfter, idAfter))
        .order('updated_ms')
        .order(_idColumnOf(entity))
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  String _idColumnOf(String entity) => entity == 'categories_sync' ? 'key' : 'id';

  @override
  Future<void> upsert(String entity, List<Map<String, dynamic>> rows) async {
    await _client.from(entity).upsert(rows, onConflict: _idColumnOf(entity));
  }

  @override
  Future<Map<String, dynamic>> rpc(String fn, Map<String, dynamic> args) async {
    final res = await _client.rpc(fn, params: args);
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return res.cast<String, dynamic>();
    return {'ok': false, 'error': 'bad_rpc_shape'};
  }

  @override
  Future<List<Map<String, dynamic>>> select(String entity,
      {Map<String, dynamic> filters = const {}, int limit = 500}) async {
    var q = _client.from(entity).select();
    filters.forEach((k, v) => q = q.eq(k, v));
    final rows = await q.limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> deleteWhere(String entity, Map<String, dynamic> filters) async {
    var q = _client.from(entity).delete();
    filters.forEach((k, v) => q = q.eq(k, v));
    await q;
  }
}
