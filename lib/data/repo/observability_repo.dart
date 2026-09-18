/// 协作可观测性（V2.7.1 S12）：冲突回执 + 审计轨迹。
///
/// 【仅本地】`conflict_records` / `audit_logs` 两张表**不登记 SyncEntity**，
/// 不上云、不进快照、不进备份、不进分享；本文件是它们唯一的读写入口，
/// 因此「是否漏进同步路径」只需审计本文件与 tables.dart（S12.4 禁止事项）。
///
/// 冲突回执与审计轨迹都不参与任何金额口径：一个只记 LWW 覆盖事实，
/// 一个只记字段名与新值，均不改写业务行。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/uid.dart';
import '../db/database.dart';

/// 审计开关（默认开）。关闭后 [recordAudit] 直接短路（S12 验收：关闭即停写）。
bool auditEnabled = true;

/// 冲突检测开关（默认开）。关闭只影响「是否落回执」，**绝不影响合并结果**
/// （S12.2：检测是纯观测；验收要求开关前后合并产物逐字段相同）。
bool conflictDetectionEnabled = true;

/// 单团审计保留上限（S12.3-5）：超出按 `atMs` 裁剪最旧。
const int kAuditRetentionPerGroup = 2000;

/// 审计实体标签（同时是 UI 筛选项的取值域）。
abstract final class AuditEntity {
  static const String group = 'group';
  static const String member = 'member';
  static const String expense = 'expense';
  static const String settlement = 'settlement';
  static const String fund = 'fund';
  static const String inbox = 'inbox';
  static const String category = 'category';
  static const String backup = 'backup';

  /// 可筛选实体顺序（UI 筛选用；backup 归入「其它」）。
  static const List<String> filterable = [
    group,
    member,
    expense,
    settlement,
    fund,
    inbox,
  ];

  static String labelOf(String entity) => switch (entity) {
        group => '账本',
        member => '成员',
        expense => '账单',
        settlement => '结算',
        fund => '公费池',
        inbox => '收件箱',
        category => '分类',
        backup => '导入导出',
        _ => '其它',
      };
}

/// 审计动作标签。
abstract final class AuditAction {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String archive = 'archive';
  static const String restore = 'restore';
  static const String settle = 'settle';
  static const String complete = 'complete';
  static const String undo = 'undo';
  static const String convert = 'convert';
  static const String close = 'close';
  static const String import_ = 'import';

  static String labelOf(String action) => switch (action) {
        create => '新增',
        update => '修改',
        delete => '删除',
        archive => '移除',
        restore => '恢复',
        settle => '创建结算',
        complete => '完成结算',
        undo => '撤销结算',
        convert => '归类',
        close => '关闭',
        import_ => '导入',
        _ => '变更',
      };
}

/// 冲突回执 winner 取值：`remote` = 云端胜（本地未上行改动被覆盖，唯一记录场景）。
const String kConflictWinnerRemote = 'remote';

/// 单条审计最多记录的字段数（防体积爆炸，S12.4-4）。
const int _kMaxAuditFields = 24;

/// 单个字段值最长保留字符数。
const int _kMaxValueChars = 120;

// ===========================================================================
// 审计轨迹（S12.3）
// ===========================================================================

/// 写一条审计记录。**仅本地**，不触发任何同步事件。
///
/// [changedFields] 只应给出「字段名 → 被改后的值」（禁止完整前后快照）。
/// 值会被截断、字段数会被裁剪，保证单条记录体积有界。
Future<void> recordAudit(
  AppDatabase db, {
  required String groupId,
  required String entity,
  required String entityId,
  required String action,
  String? actorMemberId,
  Map<String, Object?> changedFields = const {},
}) async {
  if (!auditEnabled) return;
  // 无归属不记：按团查询是唯一读取路径，落空 group_id 会污染筛选与裁剪。
  if (groupId.isEmpty) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.auditLogs).insert(AuditLogsCompanion(
        id: Value(newId('audit')),
        groupId: Value(groupId),
        entity: Value(entity),
        entityId: Value(entityId),
        action: Value(action),
        actorMemberId: Value(actorMemberId?.isEmpty == true ? null : actorMemberId),
        changedFieldsJson: Value(encodeAuditFields(changedFields)),
        atMs: Value(now),
      ));
  await _trimAudit(db, groupId);
}

/// 字段表 → JSON 字符串（截断 + 限量；null / 空值一律省略）。
String encodeAuditFields(Map<String, Object?> fields) {
  if (fields.isEmpty) return '{}';
  final out = <String, String>{};
  for (final e in fields.entries) {
    if (out.length >= _kMaxAuditFields) break;
    final v = e.value;
    if (v == null) continue;
    final s = v is String ? v : v.toString();
    if (s.isEmpty) continue;
    out[e.key] =
        s.length <= _kMaxValueChars ? s : '${s.substring(0, _kMaxValueChars)}…';
  }
  return jsonEncode(out);
}

/// 解析 `changedFieldsJson`；损坏数据返回空表（绝不抛）。
Map<String, String> decodeAuditFields(String raw) {
  if (raw.isEmpty || raw == '{}') return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries) e.key.toString(): e.value.toString(),
    };
  } catch (_) {
    return const {};
  }
}

/// 单团审计裁剪（写入后调用）：超出 [kAuditRetentionPerGroup] 时删最旧。
Future<void> _trimAudit(AppDatabase db, String groupId) async {
  final countExp = db.auditLogs.id.count();
  final row = await (db.selectOnly(db.auditLogs)
        ..addColumns([countExp])
        ..where(db.auditLogs.groupId.equals(groupId)))
      .getSingle();
  final total = row.read(countExp) ?? 0;
  final overflow = total - kAuditRetentionPerGroup;
  if (overflow <= 0) return;
  final victims = await (db.select(db.auditLogs)
        ..where((t) => t.groupId.equals(groupId))
        // 同一毫秒并列时用 id 兜底，保证裁剪确定性与「旧者先走」。
        ..orderBy([
          (t) => OrderingTerm.asc(t.atMs),
          (t) => OrderingTerm.asc(t.id),
        ])
        ..limit(overflow))
      .get();
  for (final v in victims) {
    await (db.delete(db.auditLogs)..where((t) => t.id.equals(v.id))).go();
  }
}

/// 某团全部审计（倒序；[entity] 非空时按实体筛选）。
Stream<List<AuditLog>> watchAuditLogs(
  AppDatabase db,
  String groupId, {
  String? entity,
}) {
  final q = db.select(db.auditLogs)
    ..where((t) => t.groupId.equals(groupId))
    ..orderBy([
      (t) => OrderingTerm.desc(t.atMs),
      (t) => OrderingTerm.desc(t.id),
    ]);
  if (entity != null && entity.isNotEmpty) {
    q.where((t) => t.entity.equals(entity));
  }
  return q.watch();
}

/// 一次性取某团审计（测试与导出核对用）。
Future<List<AuditLog>> getAuditLogs(
  AppDatabase db,
  String groupId, {
  String? entity,
  int? limit,
}) {
  final q = db.select(db.auditLogs)
    ..where((t) => t.groupId.equals(groupId))
    ..orderBy([
      (t) => OrderingTerm.desc(t.atMs),
      (t) => OrderingTerm.desc(t.id),
    ]);
  if (entity != null && entity.isNotEmpty) {
    q.where((t) => t.entity.equals(entity));
  }
  if (limit != null) q.limit(limit);
  return q.get();
}

// ===========================================================================
// 冲突回执（S12.2）
// ===========================================================================

/// 写一条覆盖冲突回执（**不存被覆盖版本体**）。
///
/// 判定与调用点见 `sync_merger.dart`：`local != null && pending != null &&
/// cloudMs > localMs`——本地有未上行改动且被云端胜出。本地胜不记（本地会重推，
/// 自动收敛，记了只会造成噪声）。
Future<void> recordConflict(
  AppDatabase db, {
  required String groupId,
  required String entity,
  required String entityId,
  required int localUpdatedMs,
  required int remoteUpdatedMs,
  String winner = kConflictWinnerRemote,
  int? detectedAtMs,
}) async {
  if (!conflictDetectionEnabled) return;
  if (groupId.isEmpty) return;
  await db.into(db.conflictRecords).insert(ConflictRecordsCompanion(
        id: Value(newId('conflict')),
        groupId: Value(groupId),
        entity: Value(entity),
        entityId: Value(entityId),
        localUpdatedMs: Value(localUpdatedMs),
        remoteUpdatedMs: Value(remoteUpdatedMs),
        winner: Value(winner),
        detectedAtMs: Value(detectedAtMs ?? DateTime.now().millisecondsSinceEpoch),
        acknowledged: const Value(0),
      ));
}

/// 未确认冲突总数（[groupId] 为空 = 全库）。
Stream<int> watchUnacknowledgedConflictCount(
  AppDatabase db, {
  String? groupId,
}) {
  final q = db.select(db.conflictRecords)
    ..where((t) => t.acknowledged.equals(0));
  if (groupId != null && groupId.isNotEmpty) {
    q.where((t) => t.groupId.equals(groupId));
  }
  return q.watch().map((rows) => rows.length);
}

/// 某团「存在未确认冲突」的实体 id 集合（账单行小标记用）。
Stream<Set<String>> watchUnacknowledgedConflictEntityIds(
  AppDatabase db,
  String groupId,
) {
  final q = db.select(db.conflictRecords)
    ..where((t) => t.groupId.equals(groupId) & t.acknowledged.equals(0));
  return q.watch().map((rows) => {for (final r in rows) r.entityId});
}

/// 某实体未确认冲突（最新的在前；UI 弹关联提示用）。
Future<List<ConflictRecord>> conflictsOfEntity(
  AppDatabase db,
  String entityId,
) =>
    (db.select(db.conflictRecords)
          ..where((t) => t.entityId.equals(entityId) & t.acknowledged.equals(0))
          ..orderBy([(t) => OrderingTerm.desc(t.detectedAtMs)]))
        .get();

/// 一次性取某团回执（测试用）。
Future<List<ConflictRecord>> getConflicts(
  AppDatabase db,
  String groupId,
) =>
    (db.select(db.conflictRecords)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.detectedAtMs)]))
        .get();

/// 确认（置 `acknowledged = 1`）。同一实体多条一并确认，语义 = 「知道了」。
Future<void> acknowledgeConflictsOfEntity(
  AppDatabase db,
  String entityId,
) async {
  if (entityId.isEmpty) return;
  await (db.update(db.conflictRecords)
        ..where((t) => t.entityId.equals(entityId) & t.acknowledged.equals(0)))
      .write(const ConflictRecordsCompanion(acknowledged: Value(1)));
}

/// 按 id 确认单条。
Future<void> acknowledgeConflict(AppDatabase db, String id) async {
  if (id.isEmpty) return;
  await (db.update(db.conflictRecords)..where((t) => t.id.equals(id)))
      .write(const ConflictRecordsCompanion(acknowledged: Value(1)));
}

/// 团被删除 / 退出协作时清理该团的可观测性数据（本地缓存，无同步语义）。
Future<void> clearObservabilityOfGroup(AppDatabase db, String groupId) async {
  if (groupId.isEmpty) return;
  await (db.delete(db.conflictRecords)..where((t) => t.groupId.equals(groupId)))
      .go();
  await (db.delete(db.auditLogs)..where((t) => t.groupId.equals(groupId))).go();
}
