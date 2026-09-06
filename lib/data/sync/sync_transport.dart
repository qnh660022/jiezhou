/// 同步传输抽象：与 Supabase 的最小交互面（V2.6 §3.16.1，SPEC 接口面）。
///
/// 实现方：
/// - [SyncTransportSupabase]（生产，PostgREST）；
/// - 测试用内存 fake（test/sync/）。
library;

abstract class SyncTransport {
  /// 增量拉取：`(updated_ms,id) > (:updatedMsAfter,:idAfter)` 字典序，
  /// `order by updated_ms,id`，最多 [limit] 行。
  Future<List<Map<String, dynamic>>> fetch(String entity,
      {required int updatedMsAfter, required String idAfter, required int limit});

  /// 幂等上行（upsert；on conflict 主键 do update）。
  Future<void> upsert(String entity, List<Map<String, dynamic>> rows);

  /// 调用 RPC（json 出参）。
  Future<Map<String, dynamic>> rpc(String fn, Map<String, dynamic> args);

  /// 配置测活/会话检查。
  Future<bool> ping();

  /// 当前登录用户 id（未登录 null）。
  String? get currentUserId;

  /// 直读远端行（受邀端在线直写后回读刷新镜像 / 加入协作后全量拉取用）。
  /// [filters] 生成 `col=eq.value` 等值过滤条件。
  Future<List<Map<String, dynamic>>> select(String entity,
      {Map<String, dynamic> filters = const {}, int limit = 500});

  /// 删除远端行（关闭上云开关-「同时删除云端数据」路径；owner 行）。
  Future<void> deleteWhere(String entity, Map<String, dynamic> filters);
}
