/// 测试用内存 Transport（IMPL：内存 Map + 计数器）。
library;
import 'sync_transport.dart';

class SyncTransportFake implements SyncTransport {
  SyncTransportFake();

  /// 云端存储：table → (id → row)。
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};

  /// 计数器（断言拆批/重试用）。
  int upsertCalls = 0;
  int fetchCalls = 0;
  int rpcCalls = 0;

  /// 可注入失败：下一次 upsert 抛错。
  Object? nextUpsertError;

  /// 当前登录用户。
  String? user;

  @override
  String? get currentUserId => user;

  @override
  Future<bool> ping() async => true;

  void seedRow(String entity, Map<String, dynamic> row) {
    final idCol = entity == 'categories_sync' ? 'key' : 'id';
    tables.putIfAbsent(entity, () => {})[row[idCol] as String] = row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String entity,
      {required int updatedMsAfter, required String idAfter, required int limit}) async {
    fetchCalls++;
    final all = (tables[entity]?.values.toList() ?? const [])
      ..sort((a, b) {
        final am = (a['updated_ms'] as num).toInt();
        final bm = (b['updated_ms'] as num).toInt();
        if (am != bm) return am.compareTo(bm);
        final aid = a[_idCol(entity)] as String;
        final bid = b[_idCol(entity)] as String;
        return aid.compareTo(bid);
      });
    final filtered = all.where((r) {
      final ms = (r['updated_ms'] as num).toInt();
      final id = r[_idCol(entity)] as String;
      final afterMs = ms > updatedMsAfter;
      final sameMs = ms == updatedMsAfter && id.compareTo(idAfter) > 0;
      return afterMs || sameMs;
    }).toList();
    return filtered.take(limit).map((r) => Map<String, dynamic>.from(r)).toList();
  }

  String _idCol(String entity) => entity == 'categories_sync' ? 'key' : 'id';

  @override
  Future<void> upsert(String entity, List<Map<String, dynamic>> rows) async {
    if (nextUpsertError != null) {
      final err = nextUpsertError;
      nextUpsertError = null;
      throw err!;
    }
    upsertCalls++;
    final t = tables.putIfAbsent(entity, () => {});
    for (final r in rows) {
      final id = r[_idCol(entity)] as String;
      // upsert 合并：delete 行只覆盖 deleted/updated_ms，不吞其他列（§3.6）
      t[id] = {...(t[id] ?? const <String, dynamic>{}), ...r};
    }
  }

  @override
  Future<Map<String, dynamic>> rpc(String fn, Map<String, dynamic> args) async {
    rpcCalls++;
    return {'ok': true};
  }

  @override
  Future<List<Map<String, dynamic>>> select(String entity,
      {Map<String, dynamic> filters = const {}, int limit = 500}) async {
    return (tables[entity]?.values.toList() ?? const []);
  }

  @override
  Future<void> deleteWhere(String entity, Map<String, dynamic> filters) async {
    tables[entity]?.removeWhere((id, row) {
      return filters.entries.every((f) => row[f.key] == f.value);
    });
  }
}
