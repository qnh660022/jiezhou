/// 清单 DAO。
library;
import "package:drift/drift.dart";
import "../tables.dart";
import "../database.dart";
part "checklist_dao.g.dart";
@DriftAccessor(tables: [ChecklistItems])
class ChecklistDao extends DatabaseAccessor<AppDatabase> with _$ChecklistDaoMixin {
  ChecklistDao(AppDatabase db) : super(db);
  Stream<List<ChecklistItem>> watchByTrip(String tid) => (select(checklistItems)..where((c)=>c.tripId.equals(tid)&c.scope.equals("trip"))..orderBy([(c)=>OrderingTerm.asc(c.sortOrder)])).watch();
  Stream<List<ChecklistItem>> watchGlobal() => (select(checklistItems)..where((c)=>c.scope.equals("global"))..orderBy([(c)=>OrderingTerm.asc(c.sortOrder)])).watch();
  Future<void> insertItem(ChecklistItemsCompanion c) => into(checklistItems).insert(c);
  Future<void> updateItem(ChecklistItemsCompanion c) => update(checklistItems).replace(c);
  Future<void> deleteItem(String id) async { await (delete(checklistItems)..where((c)=>c.id.equals(id))).go(); }
  Future<void> importBatch(List<ChecklistItemsCompanion> items) async { await batch((b)=>b.insertAll(checklistItems,items)); }
  Future<void> copyFromTrip(String src, String dst) async {
    final srcItems = await (select(checklistItems)..where((c)=>c.tripId.equals(src))).get();
    for (final i in srcItems) { await into(checklistItems).insert(ChecklistItemsCompanion(id:Value(i.id+"_cp"),tripId:Value(dst),scope:Value("trip"),category:Value(i.category),label:Value(i.label),done:Value(false),sortOrder:Value(i.sortOrder))); }
  }
  Future<void> deleteByTrip(String tid) async { await (delete(checklistItems)..where((c)=>c.tripId.equals(tid))).go(); }
}
