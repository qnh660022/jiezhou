/// 分类 DAO。
library;
import "package:drift/drift.dart";
import "../tables.dart";
import "../database.dart";
part "categories_dao.g.dart";
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(AppDatabase db) : super(db);
  Stream<List<Category>> watchAll() => select(categories).watch();
  Future<List<Category>> getAll() => select(categories).get();
  Future<Category?> getByKey(String key) => (select(categories)..where((c)=>c.key.equals(key))).getSingleOrNull();
  Future<void> insertCat(CategoriesCompanion c) => into(categories).insert(c);
  Future<void> updateCat(CategoriesCompanion c) => update(categories).replace(c);
  Future<void> deleteCat(String key) async { await (delete(categories)..where((c)=>c.key.equals(key))).go(); }
  Future<void> initBuiltin() async {
    const bs = [("food","餐饮","🍜"),("transport","交通","🚕"),("stay","住宿","🏨"),("ticket","门票","🎫"),("shopping","购物","🛍"),("fun","娱乐","🎮"),("other","其他","📦")];
    for (final (k,n,i) in bs) { if (await getByKey(k)==null) await into(categories).insert(CategoriesCompanion(key:Value(k),name:Value(n),icon:Value(i),builtin:Value(true))); }
  }
}
