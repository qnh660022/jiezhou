/// 分类仓储。
library;
import "package:drift/drift.dart";
import "../db/database.dart";
import "../db/tables.dart";
import "../../core/uid.dart";
import "observability_repo.dart";
import "prefs_repo.dart";
import "../sync/sync_outbox_service.dart";
class CategoriesRepository {
  CategoriesRepository(this.db, {this.prefs});
  final AppDatabase db;

  /// S12.3：分类是**跨团字典表**（无 group_id 列），审计需要团归属，故以
  /// 「操作发生时的激活团」作为归属；未注入 prefs 或没有激活团时不记（不崩）。
  final PrefsRepository? prefs;

  Future<String?> _auditGroupId() async {
    try {
      return await prefs?.getActiveGroupId();
    } catch (_) {
      return null;
    }
  }

  Stream<List<Category>> watchAll() => db.select(db.categories).watch();
  Stream<List<Category>> watchCategories() => db.select(db.categories).watch();
  Future<void> addCustom(String name, String icon) async { final k = newId("cat"); await db.into(db.categories).insert(CategoriesCompanion(key:Value(k),name:Value(name),icon:Value(icon),builtin:Value(false))); SyncOutboxService.notifyWrite("categories", k); await _auditCategory(k, AuditAction.create, name); }
  Future<void> deleteCustom(String key) async { await (db.delete(db.categories)..where((c)=>c.key.equals(key)&c.builtin.equals(false))).go(); SyncOutboxService.notifyWrite("categories", key, op: "delete"); await _auditCategory(key, AuditAction.delete, null); }
  Future<bool> isReferenced(String key) async { final exps=await (db.select(db.expenses)..where((e)=>e.categoryKey.equals(key))).get(); return exps.isNotEmpty; }
  Future<void> addCustomCategory(String name, String icon) async { final k = newId("cat"); await db.into(db.categories).insert(CategoriesCompanion(key:Value(k),name:Value(name),icon:Value(icon),builtin:Value(false))); SyncOutboxService.notifyWrite("categories", k); await _auditCategory(k, AuditAction.create, name); }
  Future<void> deleteCustomCategory(String key) async { await (db.delete(db.categories)..where((c)=>c.key.equals(key)&c.builtin.equals(false))).go(); SyncOutboxService.notifyWrite("categories", key, op: "delete"); await _auditCategory(key, AuditAction.delete, null); }

  /// 分类审计（锚定激活团；无归属则跳过）。失败一律吞掉，不影响分类操作。
  Future<void> _auditCategory(String key, String action, String? name) async {
    final gid = await _auditGroupId();
    if (gid == null || gid.isEmpty) return;
    await recordAudit(
      db,
      groupId: gid,
      entity: AuditEntity.category,
      entityId: key,
      action: action,
      changedFields: {if (name != null) 'name': name},
    );
  }
}

/// 18 个备选图标
const kCategoryIconChoices = ['🍜','🚕','🏨','🎫','🛍️','🎮','📦','🏛️','🚗','📝','📸','🎵','🏃','🎁','🛍','✈️','🚂','🗺️'];
