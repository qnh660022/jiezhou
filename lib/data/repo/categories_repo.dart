/// 分类仓储。
library;
import "package:drift/drift.dart";
import "../db/database.dart";
import "../db/tables.dart";
import "../../core/uid.dart";
class CategoriesRepository {
  CategoriesRepository(this.db);
  final AppDatabase db;
  Stream<List<Category>> watchAll() => db.select(db.categories).watch();
  Stream<List<Category>> watchCategories() => db.select(db.categories).watch();
  Future<void> addCustom(String name, String icon) async { await db.into(db.categories).insert(CategoriesCompanion(key:Value(newId("cat")),name:Value(name),icon:Value(icon),builtin:Value(false))); }
  Future<void> deleteCustom(String key) async { await (db.delete(db.categories)..where((c)=>c.key.equals(key)&c.builtin.equals(false))).go(); }
  Future<bool> isReferenced(String key) async { final exps=await (db.select(db.expenses)..where((e)=>e.categoryKey.equals(key))).get(); return exps.isNotEmpty; }
  Future<void> addCustomCategory(String name, String icon) async { await db.into(db.categories).insert(CategoriesCompanion(key:Value(newId("cat")),name:Value(name),icon:Value(icon),builtin:Value(false))); }
  Future<void> deleteCustomCategory(String key) async { await (db.delete(db.categories)..where((c)=>c.key.equals(key)&c.builtin.equals(false))).go(); }
}

/// 18 个备选图标
const kCategoryIconChoices = ['🍜','🚕','🏨','🎫','🛍️','🎮','📦','🏛️','🚗','📝','📸','🎵','🏃','🎁','🛍','✈️','🚂','🗺️'];
