/// 清单仓储。
library;
import "package:drift/drift.dart";
import "../db/database.dart";
import "../../core/uid.dart";
class ChecklistRepository {
  ChecklistRepository(this.db);
  final AppDatabase db;
  Stream<List<ChecklistItem>> watchByTrip(String tid) => (db.select(db.checklistItems)..where((c)=>c.tripId.equals(tid)&c.scope.equals("trip"))..orderBy([(c)=>OrderingTerm.asc(c.sortOrder)])).watch();
  Stream<List<ChecklistItem>> watchGlobal() => (db.select(db.checklistItems)..where((c)=>c.scope.equals("global"))..orderBy([(c)=>OrderingTerm.asc(c.sortOrder)])).watch();
  /// V2.9.0:[done] 可选参数(默认 false,向后兼容)——删除撤销回填完成态用。
  /// V2.9.0:scope 收口——global 条目强制 tripId 落 null,防止行李页持久化的
  /// 选中行程 id 混入全局待办(此前 deleteTrip 按 tripId 级联会连带清光全局待办)。
  Future<void> addItem(String? tripId, String scope, String category, String text, int order, {bool done = false}) async {
    final effectiveTripId = scope == "global" ? null : tripId;
    await db.into(db.checklistItems).insert(ChecklistItemsCompanion(id:Value(newId("check")),tripId:Value(effectiveTripId),scope:Value(scope),category:Value(category),label:Value(text),done:Value(done),sortOrder:Value(order)));
  }
  Future<void> toggleDone(String id, bool done) async { await (db.update(db.checklistItems)..where((c)=>c.id.equals(id))).write(ChecklistItemsCompanion(done:Value(done))); }
  Future<void> deleteItem(String id) async { await (db.delete(db.checklistItems)..where((c)=>c.id.equals(id))).go(); }
  Future<void> importBatch(List<ChecklistItemsCompanion> items) async { await db.batch((b)=>b.insertAll(db.checklistItems,items)); }
  /// V2.9.0:复制行程清单三处收口——
  /// ① 只复制 scope='trip' 的条目(防混入历史脏数据 global 行);
  /// ② 新 id 用 newId("check") 生成(原 i.id+"_cp" 二次复制必撞唯一主键抛异常);
  /// ③ 按目标清单已存 label 去重(trim 后全等跳过),重复复制不重复落库。
  Future<void> copyFromTrip(String src, String dst) async {
    final items=await (db.select(db.checklistItems)..where((c)=>c.tripId.equals(src)&c.scope.equals("trip"))).get();
    final dstLabels={for (final e in await (db.select(db.checklistItems)..where((c)=>c.tripId.equals(dst)&c.scope.equals("trip"))).get()) e.label.trim()};
    for(final i in items) {
      final label=i.label.trim();
      if (dstLabels.contains(label)) continue;
      dstLabels.add(label);
      await db.into(db.checklistItems).insert(ChecklistItemsCompanion(id:Value(newId("check")),tripId:Value(dst),scope:Value("trip"),category:Value(i.category),label:Value(i.label),done:Value(false),sortOrder:Value(i.sortOrder)));
    }
  }
  Future<void> updateItem(String id, {String? label, String? category}) async { final c = ChecklistItemsCompanion(label: label != null ? Value(label) : const Value.absent(), category: category != null ? Value(category) : const Value.absent()); await (db.update(db.checklistItems)..where((t)=>t.id.equals(id))).write(c); }
  Future<void> reorderItem(String id, int newSortOrder) async { await (db.update(db.checklistItems)..where((t)=>t.id.equals(id))).write(ChecklistItemsCompanion(sortOrder:Value(newSortOrder))); }
  /// V2.7.2 S9：城市锦囊「行前准备」转清单。
  /// 同 trip 同 label（trim 后全等）已存在 → 跳过返回 false；成功返回 true。
  /// category 固定 'other'（不新增清单分类）；清单不在同步层，无 notifyWrite。
  Future<bool> addKitPrepItem({required String tripId, required String label}) async {
    final text = label.trim();
    if (text.isEmpty) return false;
    final dup = await (db.select(db.checklistItems)
          ..where((c) => c.tripId.equals(tripId) & c.scope.equals("trip") & c.label.equals(text)))
        .get();
    if (dup.isNotEmpty) return false;
    await addItem(tripId, "trip", "other", text, 0);
    return true;
  }
  Future<List<ChecklistItem>> getAllByScope(String scope, {String? tripId}) async { final q = db.select(db.checklistItems)..where((c)=>c.scope.equals(scope)&(tripId != null ? c.tripId.equals(tripId) : const Constant(true)))..orderBy([(c)=>OrderingTerm.asc(c.sortOrder)]); return q.get(); }
}
