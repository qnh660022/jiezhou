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

  /// 复合游标过滤表达式（纯函数，便于单测）：
  /// `updated_ms > last OR (updated_ms = last AND <idColumn> > lastId)`。
  ///
  /// [idColumn] 必须传**该实体的主键列名**（`categories_sync` 是 `key`，其余 `id`）。
  /// 此前硬编码 `id`，导致分类表数据超过一页时第二页 PostgREST 400（历史 bug M6）。
  static String compositeCursorFilter(
      int updatedMsAfter, String idAfter, String idColumn) {
    final idPart = idAfter.isEmpty
        ? ''
        : ',and(updated_ms.eq.$updatedMsAfter,$idColumn.gt.$idAfter)';
    return 'updated_ms.gt.$updatedMsAfter$idPart';
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String entity,
      {required int updatedMsAfter, required String idAfter, required int limit}) async {
    final idColumn = _idColumnOf(entity);
    final rows = await _client
        .from(entity)
        .select()
        .or(compositeCursorFilter(updatedMsAfter, idAfter, idColumn))
        .order('updated_ms')
        .order(idColumn)
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
