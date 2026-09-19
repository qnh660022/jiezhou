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
    // ⚠️ 必须 toList() 成一个**可变的**新列表再排序：
    // `tables[entity]?.values.toList() ?? const []` 在表为空时拿到的是 const 空表，
    // `..sort()` 会抛 `Unsupported operation: Cannot modify an unmodifiable list`，
    // 而该异常会被 SyncPuller 的整轮 try 吞成「本轮拉取失败」——结果是**空表实体
    // 永远拉不动**，且 drain 也因 pull 失败被跳过（写后读整条链路失效）。
    final all =
        (tables[entity]?.values ?? const <Map<String, dynamic>>[]).toList()
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

  /// 云表「not null 且无默认值」列（口径：docs/db_v26.sql 逐表核对）。
  /// 真表漏传会被 PostgREST 以 23502 拒绝（`null value in column "created_ms"
  /// ... violates not-null constraint`）→ 该实体整批失败 → 8 次后退化成死信。
  /// fake 必须与真表同样严格，否则这类 bug 在测试里会静默通过
  /// （历史 bug：categories_sync 漏 created_ms，分类同步长期卡死）。
  /// 未列入的列均有默认值或有默认表达式（owner_user_id default auth.uid()），
  /// id/key 为主键、deleted/updated_ms 由信封恒带。
  static const Map<String, Set<String>> requiredColumns = {
    // ===== V2.6.6.2 旅伴空间三表 =====
    // spaces_sync：name / status / created_by 均 not null 且无默认值（§3.1）；
    // created_ms 由 §0.3.1 硬性边界约束（not null 无默认值）。
    'spaces_sync': {'name', 'status', 'created_by', 'created_ms'},
    // space_members_sync：display_name / role / joined_ms / created_ms 全部
    // not null 无默认值；space_id / user_id 同。
    'space_members_sync': {
      'space_id', 'user_id', 'role', 'display_name', 'joined_ms', 'created_ms',
    },
    // space_events_sync：append-only，但 created_ms 必带（updated_ms 由信封恒带）。
    'space_events_sync': {
      'space_id', 'actor_user', 'action', 'entity_kind', 'summary', 'created_ms',
    },
    // ===== V2.6 既有表 =====
    'trips_sync': {'created_ms'},
    'trip_items_sync': {'trip_id', 'created_ms'},
    'groups_sync': {'created_ms'},
    'members_sync': {'group_id', 'created_ms'},
    'expenses_sync': {'group_id', 'created_ms'},
    'settlements_sync': {'group_id', 'created_ms'},
    'categories_sync': {'created_ms'},
    // ===== V2.7.1 公款池 / 记账收件箱 =====
    // funds_sync：name / manager_member_id 均 not null 无默认值；updated_ms 由信封恒带。
    'funds_sync': {'group_id', 'name', 'manager_member_id', 'created_ms', 'updated_ms'},
    // inbox_items_sync：amount_cents / captured_ms / source / status 均 not null 无默认值。
    'inbox_items_sync': {
      'group_id', 'amount_cents', 'captured_ms', 'source', 'status', 'created_ms', 'updated_ms',
    },
    // ===== V2.7.2 想去池 =====
    // wishlist_items_sync 最小列集（规格 §S1 登记 6）：trip_id / name / type /
    // created_ms / updated_ms；guide_ref / backup_of 等为 nullable，不得加入 required。
    'wishlist_items_sync': {'trip_id', 'name', 'type', 'created_ms', 'updated_ms'},
    // ===== V2.8.1 分类子预算 =====
    // 最小列集与 docs/db_v281.sql 云端 DDL 对齐：id / group_id / category_key /
    // amount / created_ms / updated_ms（deleted/server_updated 由云端默认值兜底，
    // owner_user_id default auth.uid()）。
    'sub_budgets_sync': {
      'id', 'group_id', 'category_key', 'amount', 'created_ms', 'updated_ms',
    },
  };

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
      // 墓碑是 UPDATE 既有行（新行不发明文墓碑，见 pusher.assemble），不校验缺列。
      if (r['deleted'] != true) {
        for (final col in requiredColumns[entity] ?? const <String>{}) {
          if (r[col] == null) {
            throw Exception(
                'PostgrestException(23502): null value in column "$col" '
                'of relation "$entity" violates not-null constraint');
          }
        }
      }
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
