/// 分类仓储。
library;
import "package:drift/drift.dart";
import "../db/database.dart";
import "../db/tables.dart";
import "../../core/uid.dart";
import "../sync/sync_outbox_service.dart";
class CategoriesRepository {
  CategoriesRepository(this.db);
  final AppDatabase db;
  Stream<List<Category>> watchAll() => db.select(db.categories).watch();
  Stream<List<Category>> watchCategories() => db.select(db.categories).watch();
  Future<void> addCustom(String name, String icon) async { final k = newId("cat"); await db.into(db.categories).insert(CategoriesCompanion(key:Value(k),name:Value(name),icon:Value(icon),builtin:Value(false))); SyncOutboxService.notifyWrite("categories", k); }
  Future<void> deleteCustom(String key) async { await (db.delete(db.categories)..where((c)=>c.key.equals(key)&c.builtin.equals(false))).go(); SyncOutboxService.notifyWrite("categories", key, op: "delete"); }
  Future<bool> isReferenced(String key) async { final exps=await (db.select(db.expenses)..where((e)=>e.categoryKey.equals(key))).get(); return exps.isNotEmpty; }
  Future<void> addCustomCategory(String name, String icon) async { final k = newId("cat"); await db.into(db.categories).insert(CategoriesCompanion(key:Value(k),name:Value(name),icon:Value(icon),builtin:Value(false))); SyncOutboxService.notifyWrite("categories", k); }
  Future<void> deleteCustomCategory(String key) async { await (db.delete(db.categories)..where((c)=>c.key.equals(key)&c.builtin.equals(false))).go(); SyncOutboxService.notifyWrite("categories", key, op: "delete"); }
}

/// 18 个备选图标
const kCategoryIconChoices = ['🍜','🚕','🏨','🎫','🛍️','🎮','📦','🏛️','🚗','📝','📸','🎵','🏃','🎁','🛍','✈️','🚂','🗺️'];
