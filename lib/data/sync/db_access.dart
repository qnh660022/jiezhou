/// assemble 用：按实体读本地行最新值（云端列格式）；行不存在返回 null（→ delete 信封）。
library;
import '../db/database.dart';
import 'sync_codec.dart';

class SyncDbAccessor {
  SyncDbAccessor(this.db);

  final AppDatabase db;

  /// 返回云端列格式的行 map（不含 updated_ms/deleted/id，由信封补齐）；不存在 → null。
  Future<Map<String, dynamic>?> readBusinessRow(String entity, String rowId) async {
    switch (entity) {
      case 'trips':
        final rows = await (db.select(db.trips)..where((t) => t.id.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.tripToCloud(rows.first);
      case 'trip_items':
        final rows = await (db.select(db.tripItems)..where((t) => t.id.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.tripItemToCloud(rows.first);
      case 'groups':
        final rows = await (db.select(db.groups)..where((t) => t.id.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.groupToCloud(rows.first);
      case 'members':
        final rows = await (db.select(db.members)..where((t) => t.id.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.memberToCloud(rows.first);
      case 'expenses':
        final rows = await (db.select(db.expenses)..where((t) => t.id.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.expenseToCloud(rows.first);
      case 'settlements':
        final rows = await (db.select(db.settlements)..where((t) => t.id.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.settlementToCloud(rows.first);
      case 'categories':
        final rows = await (db.select(db.categories)..where((t) => t.key.equals(rowId))).get();
        return rows.isEmpty ? null : SyncCodec.categoryToCloud(rows.first);
    }
    return null;
  }
}
