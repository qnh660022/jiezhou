/// 记账仓储：完整版，包含 bridge 层需要的全部方法。
library;
import "dart:async";
import "dart:convert";
import "dart:typed_data";
import "package:drift/drift.dart";
import "../db/database.dart" hide Settlement;
import "../../core/date_utils.dart";
import "../../core/uid.dart";
import "../../domain/models.dart";
import "../../domain/settle_strategy.dart";
import "../../domain/share_splitter.dart";
import "../../domain/group_backup.dart";
import "../../domain/full_backup.dart";
import "../../export/backup_format.dart";
import "prefs_repo.dart";
import "observability_repo.dart";
import "../sync/sync_outbox_service.dart";

class LedgerRepository {
  LedgerRepository(this.db, this.prefs);
  final AppDatabase db;
  final PrefsRepository prefs;

  /// 激活团 id 内存缓存；仓库为 Provider 级单例，与 UI 生命周期一致，
  /// broadcast 控制器随仓库常驻（不随页面 dispose）。
  String? _activeGroupId;

  /// S4：未知账本类型的降级日志钩子（App 层可挂到 debugPrint；默认静默）。
  static void Function(String message)? onUnknownKind;

  /// S4：账本类型归一。`travel` / `personal` / `loan`（解析层预留）原样保留；
  /// 其余未知值一律降级为 `travel` 并记一次日志（**不得崩溃**）。
  static String _normalizeKind(String raw) {
    final k = raw.trim().toLowerCase();
    if (k == 'travel' || k == 'personal' || k == 'loan') return k;
    onUnknownKind?.call('未知账本类型「$raw」已按 travel 处理');
    return 'travel';
  }
  bool _activeGroupLoaded = false;
  final StreamController<String?> _activeGroupCtl = StreamController<String?>.broadcast();

  /// 首次访问时从 SharedPreferences 恢复激活团 id
  Future<String?> _ensureLoadedActiveGroup() async {
    if (!_activeGroupLoaded) {
      _activeGroupId = await prefs.getActiveGroupId();
      _activeGroupLoaded = true;
    }
    return _activeGroupId;
  }

  // === 团 ===
  Stream<List<Group>> watchGroups() => (db.select(db.groups)..orderBy([(g)=>OrderingTerm.desc(g.createdAt)])).watch();
  Future<Group?> getGroup(String id) async { final l=await (db.select(db.groups)..where((g)=>g.id.equals(id))).get(); return l.firstOrNull; }
  Future<Group> addGroup(String name, String icon, {String kind = 'travel'}) async {
    final id = newId("group");
    final now = DateTime.now().millisecondsSinceEpoch;
    final k = _normalizeKind(kind);
    // S4：个人账本 owner 即唯一成员（固定「我」），保证记账/统计开箱可用。
    final ownerMemberId = k == 'personal' ? newId("member") : null;
    await db.transaction(() async {
      await db.into(db.groups).insert(GroupsCompanion(id:Value(id),name:Value(name),icon:Value(icon),kind:Value(k),createdAt:Value(now),updatedAt:Value(now)));
      if (ownerMemberId != null) {
        await db.into(db.members).insert(MembersCompanion(
          id: Value(ownerMemberId), groupId: Value(id), name: const Value('我'),
          colorIndex: const Value(0), createdAt: Value(now),
        ));
      }
    });
    SyncOutboxService.notifyWrite("groups", id);
    if (ownerMemberId != null) SyncOutboxService.notifyWrite("members", ownerMemberId);
    await _audit(id, AuditEntity.group, id, AuditAction.create, fields: {
      'name': name,
      'icon': icon,
      'kind': k,
    });
    return (await getGroup(id))!;
  }
  Future<void> updateGroup(String id, String name, String icon) async {
    await (db.update(db.groups)..where((g)=>g.id.equals(id))).write(GroupsCompanion(name:Value(name),icon:Value(icon),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
    SyncOutboxService.notifyWrite("groups", id);
    await _audit(id, AuditEntity.group, id, AuditAction.update,
        fields: {'name': name, 'icon': icon});
  }

  /// 结束团（软归档）：只打标记，数据全部保留可改，可随时恢复。
  Future<void> archiveGroup(String id, bool archived) async {
    await (db.update(db.groups)..where((g)=>g.id.equals(id))).write(GroupsCompanion(archived:Value(archived),archivedAtMs:Value(archived ? DateTime.now().millisecondsSinceEpoch : null),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
    SyncOutboxService.notifyWrite("groups", id);
    await _audit(id, AuditEntity.group, id,
        archived ? AuditAction.archive : AuditAction.restore,
        fields: {'archived': archived});
  }
  /// 删团级联：事务内依次清理 账单→结算→成员→团，并把关联行程的 groupId 置 null。
  ///
  /// 若删除的正是当前激活团：自动切换到剩余团中 createdAt 最新的一个（走 setActiveGroup
  /// 三件套：内存缓存 + prefs + 广播），无剩余团则置 null。SQLite 未开启外键
  /// （NativeDatabase 不自动 PRAGMA foreign_keys，且存量库可能有脏数据不宜全局打开），
  /// 悬空 activeGroupId 会静默产出引用已消失团的「幽灵」成员/账单行——不可见且导出遗漏，
  /// 故必须在删除时点完成指针交接（逻辑层修复）。
  Future<void> deleteGroup(String id) async {
    // 删除前先收集子行 id：事务提交后要逐行发 delete 墓碑并把归属变更的行程
    // 重新入队，否则云端残留（其他端会一直看得见这个团 / 成员 / 账单）。
    final childMembers =
        await (db.select(db.members)..where((m) => m.groupId.equals(id))).get();
    final childExpenses =
        await (db.select(db.expenses)..where((e) => e.groupId.equals(id))).get();
    final childSettlements =
        await (db.select(db.settlements)..where((s) => s.groupId.equals(id))).get();
    // V2.7.1：公款池与收件箱同为团级实体，删团需级联清理并发行墓碑。
    final childFunds =
        await (db.select(db.funds)..where((f) => f.groupId.equals(id))).get();
    final childInbox =
        await (db.select(db.inboxItems)..where((i) => i.groupId.equals(id))).get();
    // V2.8.1：分类子预算同为团级实体，级联清理 + 逐行墓碑。
    final childSubBudgets =
        await (db.select(db.subBudgets)..where((b) => b.groupId.equals(id))).get();
    final linkedTrips =
        await (db.select(db.trips)..where((t) => t.groupId.equals(id))).get();
    final doomed = await getGroup(id);
    // S12.3：删团本身是记录点之一。写在事务前（记录「谁删了这个团」这一事实），
    // 该行随后成为本地孤儿（团已不存在，UI 不再可达），仅本地、受 2000 条裁剪约束。
    await _audit(id, AuditEntity.group, id, AuditAction.delete, fields: {
      'name': doomed?.name ?? '',
      'members': childMembers.length,
      'expenses': childExpenses.length,
      'settlements': childSettlements.length,
      'funds': childFunds.length,
      'inbox': childInbox.length,
      'subBudgets': childSubBudgets.length,
    });
    await db.transaction(() async {
      await (db.delete(db.expenses)..where((e)=>e.groupId.equals(id))).go();
      await (db.delete(db.settlements)..where((s)=>s.groupId.equals(id))).go();
      await (db.delete(db.funds)..where((f)=>f.groupId.equals(id))).go();
      await (db.delete(db.inboxItems)..where((i)=>i.groupId.equals(id))).go();
      await (db.delete(db.subBudgets)..where((b)=>b.groupId.equals(id))).go();
      await (db.delete(db.members)..where((m)=>m.groupId.equals(id))).go();
      await (db.update(db.trips)..where((t)=>t.groupId.equals(id))).write(TripsCompanion(groupId:Value(null)));
      await (db.delete(db.groups)..where((g)=>g.id.equals(id))).go();
    });
    // ⚠️ 一律在事务提交后 notify：hook 会立刻触发上行，事务内触发时 assemble
    // 读不到本地行，会被判成「已删除」而误发墓碑。
    SyncOutboxService.notifyWrite("groups", id, op: "delete");
    _notifyDelete("members", childMembers.map((m) => m.id));
    _notifyDelete("funds", childFunds.map((f) => f.id));
    _notifyDelete("inbox_items", childInbox.map((i) => i.id));
    _notifyDelete("sub_budgets", childSubBudgets.map((b) => b.id)); // V2.8.1
    _notifyDelete("expenses", childExpenses.map((e) => e.id));
    _notifyDelete("settlements", childSettlements.map((s) => s.id));
    for (final t in linkedTrips) {
      SyncOutboxService.notifyWrite("trips", t.id); // groupId 置空 → 重新上行
    }
    final current = await _ensureLoadedActiveGroup();
    if (current != id) return;
    final remaining = await (db.select(db.groups)
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .get();
    Group? next;
    for (final g in remaining) {
      if (g.id != id) { next = g; break; }
    }
    await setActiveGroup(next?.id);
  }

  /// 批量发 delete 墓碑（事务提交后调用；见 deleteGroup 注释）。
  void _notifyDelete(String entity, Iterable<String> ids) {
    for (final id in ids) {
      SyncOutboxService.notifyWrite(entity, id, op: "delete");
    }
  }

  /// 批量入队 upsert（导入 / 备份恢复 / 局域网合并等批量写路径用）。
  void _notifyUpsert(String entity, Iterable<String> ids) {
    for (final id in ids) {
      SyncOutboxService.notifyWrite(entity, id);
    }
  }

  // === S12.3 审计轨迹（**仅本地**；不登记 SyncEntity、不上云、不进备份） ===
  //
  // 记录点全部收口在本仓储（规格 §S12.3）：团 / 成员 / 账单 / 结算 / 公款池 /
  // 收件箱 / 分类的增删改，以及批量导入的「一条汇总」。字段表只放「字段名 →
  // 被改后的值」，由 recordAudit 做截断与限量，绝不保存完整快照。
  /// 写一条审计（失败不阻断业务：审计是旁路能力，绝不能因它让记账失败）。
  Future<void> _audit(
    String groupId,
    String entity,
    String entityId,
    String action, {
    Map<String, Object?> fields = const {},
  }) async {
    try {
      await recordAudit(
        db,
        groupId: groupId,
        entity: entity,
        entityId: entityId,
        action: action,
        changedFields: fields,
      );
    } catch (_) {
      // 审计写失败一律吞掉（隐私边界/磁盘异常都不应影响主流程）。
    }
  }
  /// 切换激活团：先更新内存缓存 → 持久化 → 广播给监听者
  Future<void> setActiveGroup(String? id) async {
    _activeGroupId = id;
    _activeGroupLoaded = true;
    await prefs.setActiveGroupId(id);
    _activeGroupCtl.add(id);
  }

  /// 激活团 id 流：首帧立即给出当前值（含持久化恢复），其后跟随变更事件
  Stream<String?> watchActiveGroupId() async* {
    yield await _ensureLoadedActiveGroup();
    yield* _activeGroupCtl.stream;
  }
  Future<void> setBudget(String gid, {bool enabled=false, int? budgetCents}) async {
    await (db.update(db.groups)..where((g)=>g.id.equals(gid))).write(GroupsCompanion(budgetEnabled:Value(enabled),budgetCents:Value(budgetCents),updatedAt:Value(DateTime.now().millisecondsSinceEpoch)));
    SyncOutboxService.notifyWrite("groups", gid); // 预算字段在 groups 上行映射内
  }

  // === 成员 ===
  Stream<List<Member>> watchMembers(String gid) => (db.select(db.members)..where((m)=>m.groupId.equals(gid))..orderBy([(m)=>OrderingTerm.asc(m.createdAt)])).watch();
  Future<List<Member>> getMembers(String gid) => (db.select(db.members)..where((m)=>m.groupId.equals(gid))).get();
  Future<String> addMember(String gid, String name) async {
    final id = newId("member");
    final count = await (db.selectOnly(db.members)..where(db.members.groupId.equals(gid))..addColumns([db.members.id.count()])).getSingle();
    final idx = (count.read(db.members.id.count()) ?? 0) % 8;
    await db.into(db.members).insert(MembersCompanion(
      id: Value(id),
      groupId: Value(gid),
      name: Value(name),
      colorIndex: Value(idx),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    SyncOutboxService.notifyWrite("members", id);
    await _audit(gid, AuditEntity.member, id, AuditAction.create,
        fields: {'name': name});
    return id;
  }
  Future<void> renameMember(String mid, String name) async {
    final rows = await (db.select(db.members)..where((m) => m.id.equals(mid))).get();
    await (db.update(db.members)..where((m)=>m.id.equals(mid))).write(MembersCompanion(name:Value(name)));
    SyncOutboxService.notifyWrite("members", mid);
    if (rows.isNotEmpty) {
      await _audit(rows.first.groupId, AuditEntity.member, mid,
          AuditAction.update, fields: {'name': name});
    }
  }

  /// S2 G1 软删除：置 `archived = true`。行仍在、姓名可查，历史账单照常参与净额。
  ///
  /// LWW 口径：Members 表无 updatedAt 列，同步层以 createdAt 承载 `updated_ms`；
  /// 本方法**不改 createdAt**（改它会篡改该行时间语义），只靠 `notifyWrite`
  /// 以「入队事件时点」上行——对端按更新的 updated_ms 合并即生效。
  Future<void> archiveMember(String mid) async {
    final rows = await (db.select(db.members)..where((m) => m.id.equals(mid))).get();
    if (rows.isEmpty) return;
    if (await _isFundManager(mid)) {
      throw StateError('该成员是公款池管理人，请先转移管理人后再移除');
    }
    await (db.update(db.members)..where((m) => m.id.equals(mid)))
        .write(const MembersCompanion(archived: Value(true)));
    SyncOutboxService.notifyWrite("members", mid);
    await _audit(rows.first.groupId, AuditEntity.member, mid, AuditAction.archive,
        fields: {'name': rows.first.name});
  }

  /// S2 G1 物理删除：**仅**当该成员未被任何账单引用且非公款池管理人时允许。
  /// 有引用 → 抛带明确文案的 [StateError]，提示改用「移除成员（保留历史）」。
  Future<void> deleteMember(String mid) async {
    final rows = await (db.select(db.members)..where((m) => m.id.equals(mid))).get();
    final name = rows.isEmpty ? mid : rows.first.name;
    final refs = await countMemberReferences(mid);
    if (refs > 0) {
      throw StateError('「$name」已参与 $refs 笔账单，无法删除；请改用「移除成员（保留历史）」');
    }
    if (await _isFundManager(mid)) {
      throw StateError('「$name」是公款池管理人，请先转移管理人后再移除');
    }
    await (db.delete(db.members)..where((m) => m.id.equals(mid))).go();
    SyncOutboxService.notifyWrite("members", mid, op: "delete");
    if (rows.isNotEmpty) {
      await _audit(rows.first.groupId, AuditEntity.member, mid,
          AuditAction.delete, fields: {'name': name});
    }
  }

  /// S2 G1 结构化引用判定：解析 `payersJson` / `sharesJson` 为数组后逐项比对
  /// `memberId`，**彻底移除 `LIKE '%id%'`**（`member_1` 与 `member_10` 互为子串
  /// 时曾误报）。解析失败按「存在引用」处理（宁可拦不可漏）。
  Future<bool> isMemberReferenced(String mid) async =>
      (await countMemberReferences(mid)) > 0;

  /// 引用计数（S2 G1）：含该 memberId 的账单笔数（同团范围内扫描）。
  Future<int> countMemberReferences(String mid) async {
    final m = await (db.select(db.members)..where((x) => x.id.equals(mid))).getSingleOrNull();
    final query = db.select(db.expenses);
    if (m != null) query.where((e) => e.groupId.equals(m.groupId));
    final exps = await query.get();
    var count = 0;
    for (final e in exps) {
      if (_jsonReferencesMember(e.payersJson, mid) ||
          _jsonReferencesMember(e.sharesJson, mid)) {
        count++;
      }
    }
    return count;
  }

  /// 是否公款池管理人（S8 联动：管理人不可被删除/归档，除非先转移）。
  Future<bool> _isFundManager(String mid) async {
    final rows = await (db.select(db.funds)
          ..where((f) => f.managerMemberId.equals(mid) & f.status.equals('open')))
        .get();
    return rows.isNotEmpty;
  }

  // === 账单 ===
  Stream<List<Expense>> watchExpenses(String gid) => (db.select(db.expenses)..where((e)=>e.groupId.equals(gid))..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay),(e)=>OrderingTerm.desc(e.createdAt)])).watch();
  Stream<List<Expense>> watchOutstanding(String gid) => (db.select(db.expenses)..where((e)=>e.groupId.equals(gid)&e.settledRoundId.isNull())..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay)])).watch();
  Stream<List<Expense>> watchByTrip(String tid) => (db.select(db.expenses)..where((e)=>e.tripId.equals(tid))..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay)])).watch();
  /// 按安排 id 盯关联账单流（安排卡入账徽章用）；createdAt 降序，首条即最新
  Stream<List<Expense>> watchByTripItem(String itemId) => (db.select(db.expenses)..where((e)=>e.tripItemId.equals(itemId))..orderBy([(e)=>OrderingTerm.desc(e.createdAt)])).watch();
  /// 安排关联账单一次性查询（仲裁/同步用）：按 createdAt 降序，首条即最新关联账单
  Future<List<Expense>> getLinkedBills(String itemId) => (db.select(db.expenses)..where((e)=>e.tripItemId.equals(itemId))..orderBy([(e)=>OrderingTerm.desc(e.createdAt)])).get();
  Future<void> addExpense(ExpensesCompanion e) async {
    await db.into(db.expenses).insert(e);
    SyncOutboxService.notifyWrite("expenses", e.id.value);
    await _audit(e.groupId.value, AuditEntity.expense, e.id.value,
        AuditAction.create,
        fields: {
          'title': e.title.value,
          'amountCents': e.amountCents.value,
        });
  }

  /// 从「显式赋值过的列」提取字段名 → 新值，供 S12 审计使用。
  ///
  /// 只含 present 的列，天然满足「只记变更字段」；值为 null（显式清空）的列
  /// 不记录——审计的价值在「改成了什么」，而不是「清空了哪个字段」。
  Map<String, Object?> _presentFields(List<(String, Value?)> cols) => {
        for (final (name, v) in cols)
          if (v != null && v.present && v.value != null) name: v.value,
      };

  /// 账单编辑可能改动的列（审计用白名单，避免把 id/groupId 等噪音写进去）。
  List<(String, Value?)> _expenseAuditColumns(ExpensesCompanion e) => [
        ('title', e.title),
        ('dateEpochDay', e.dateEpochDay),
        ('categoryKey', e.categoryKey),
        ('type', e.type),
        ('amountCents', e.amountCents),
        ('currency', e.currency),
        ('rate', e.rate),
        ('payersJson', e.payersJson),
        ('sharesJson', e.sharesJson),
        ('shareMode', e.shareMode),
        ('portionsJson', e.portionsJson),
        ('note', e.note),
        ('settledRoundId', e.settledRoundId),
        ('tripId', e.tripId),
        ('tripItemId', e.tripItemId),
        ('fundId', e.fundId),
        ('payMethod', e.payMethod),
      ];

  /// 一键入账：由安排预填生成账单并双向关联（tripId+tripItemId 落库）。
  ///
  /// * 预填口径见 domain/trip_bill_linker.dart：标题=安排名、金额=costCents、
  ///   币种=costCurrency、日期=dateEpochDay、分类按安排类型映射（可覆盖）；
  /// * 汇率换算不做：rate 固定 1.0，amountCents 原样取计划费用；
  /// * 分摊固定 equal 模式经 ShareSplitter 拆分；[shareMemberIds] 为空抛 ArgumentError。
  Future<String> createExpenseFromTripItem({
    required TripItem item,
    required String groupId,
    required String payerMemberId,
    required List<String> shareMemberIds,
    String? categoryKey,
  }) async {
    final cents = item.costCents ?? 0;
    if (cents <= 0) throw ArgumentError('安排未填计划费用，无法入账');
    if (shareMemberIds.isEmpty) throw ArgumentError('分摊成员不能为空');
    final shares = splitShares(totalCents: cents, memberIds: shareMemberIds);
    final id = newId("expense");
    await db.into(db.expenses).insert(ExpensesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      dateEpochDay: Value(item.dateEpochDay),
      title: Value(item.name.isEmpty ? '行程支出' : item.name),
      categoryKey: Value(categoryKey ?? _categoryKeyOfItemType(item.type)),
      type: const Value("normal"),
      amountCents: Value(cents),
      currency: Value(item.costCurrency),
      rate: const Value(1.0),
      payersJson: Value(jsonEncode([{"memberId": payerMemberId, "cents": cents}])),
      sharesJson: Value(jsonEncode([for (final s in shares) {"memberId": s.memberId, "cents": s.cents}])),
      shareMode: const Value("equal"),
      note: const Value(""),
      settledRoundId: const Value(null),
      tripId: Value(item.tripId),
      tripItemId: Value(item.id),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    SyncOutboxService.notifyWrite("expenses", id);
    // S12.3：一键入账路径同属账单新增记录点（标明来源，便于区分手工记账）。
    await _audit(groupId, AuditEntity.expense, id, AuditAction.create, fields: {
      'title': item.name,
      'amountCents': cents,
      'tripItemId': item.id,
      'from': 'trip_item',
    });
    return id;
  }

  /// 安排类型 -> 内置账单分类 key（categories_dao.initBuiltin 七类）
  static String _categoryKeyOfItemType(String itemType) {
    switch (itemType) {
      case 'food': return 'food';
      case 'transport': return 'transport';
      case 'stay': return 'stay';
      case 'attraction': return 'ticket';
      default: return 'other';
    }
  }

  Future<void> updateExpense(String id, ExpensesCompanion e) async {
    await (db.update(db.expenses)..where((x)=>x.id.equals(id))).write(e);
    SyncOutboxService.notifyWrite("expenses", id);
    final row = await (db.select(db.expenses)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (row != null) {
      await _audit(row.groupId, AuditEntity.expense, id, AuditAction.update,
          fields: _presentFields(_expenseAuditColumns(e)));
    }
  }
  Future<void> deleteExpense(String id) async {
    final row = await (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();
    await (db.delete(db.expenses)..where((e)=>e.id.equals(id))).go();
    SyncOutboxService.notifyWrite("expenses", id, op: "delete");
    if (row != null) {
      await _audit(row.groupId, AuditEntity.expense, id, AuditAction.delete,
          fields: {'title': row.title, 'amountCents': row.amountCents});
    }
  }
  Future<void> setExpenseSettled(String eid, bool settled) async {
    if(settled) { await (db.update(db.expenses)..where((e)=>e.id.equals(eid))).write(ExpensesCompanion(settledRoundId:Value("manual"))); } else { await (db.update(db.expenses)..where((e)=>e.id.equals(eid))).write(ExpensesCompanion(settledRoundId:Value(null))); }
    SyncOutboxService.notifyWrite("expenses", eid);
    final row = await (db.select(db.expenses)..where((e) => e.id.equals(eid))).getSingleOrNull();
    if (row != null) {
      await _audit(row.groupId, AuditEntity.expense, eid, AuditAction.update,
          fields: {'settledRoundId': settled ? 'manual' : null});
    }
  }

  // === 结算 ===
  Stream<List<Settlement>> watchSettlements(String gid) {
    return (db.select(db.settlements)
          ..where((s) => s.groupId.equals(gid))
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .watch()
        .map((list) => list.map((s) {
      // 统一兼容标准 List、单个 Map、元素被再次 JSON 编码的历史格式。
      // 解析失败时只丢弃坏元素，不把整轮结算伪装成“待转 0 笔”。
      final transfers = [
        for (final it in _decodeTransferMaps(s.transfersJson))
          if (_transferFrom(it).isNotEmpty &&
              _transferTo(it).isNotEmpty &&
              _transferCents(it) > 0)
            TransferRecord(
              from: _transferFrom(it),
              to: _transferTo(it),
              cents: _transferCents(it),
              done: _transferDone(it),
            ),
      ];
      return Settlement(
        id: s.id,
        groupId: s.groupId,
        status: s.status == 'active' ? SettlementStatus.active : SettlementStatus.completed,
        transfers: transfers,
        roundNo: s.roundNo,
        createdAt: s.createdAt,
        completedAt: s.completedAt,
        strategy: s.strategy,
      );
    }).toList());
  }

  /// 新建一轮结算：
  /// * 先清掉同团已有的 active 轮（脏数据/历史残留统一清理，避免多条 active 共存）；
  ///   旧 active 直接删除（未完成等于作废，配合用户重新点「开始这一轮」的强意图）。
  /// * roundNo 取已有最大 + 1，保证第 2 轮、第 3 轮自增正确。
  /// * 全部账单净额已平衡时（无人欠款）不创建空轮，返回 null；UI 据此给"无需结算"提示。
  /// * transfersJson 走 jsonEncode 而非字符串拼接，杜绝单元素/零元素边界损坏。
  Future<Settlement?> createSettlement(String gid,
      {SettleStrategy strategy = SettleStrategy.minTransfers}) async {
    // S4：个人账本无共同消费场景 → 直接短路，**不产生任何结算轮记录**。
    final group = await getGroup(gid);
    if (group != null && group.kind == 'personal') return null;

    final existing = await (db.select(db.settlements)
          ..where((s) => s.groupId.equals(gid) & s.status.equals('active')))
        .get();
    for (final old in existing) {
      await (db.delete(db.settlements)..where((x) => x.id.equals(old.id))).go();
      SyncOutboxService.notifyWrite("settlements", old.id, op: "delete");
    }

    final outstanding = await (db.select(db.expenses)
          ..where((e) => e.groupId.equals(gid) & e.settledRoundId.isNull()))
        .get();
    final balances = _computeBalances(outstanding);
    // S9：走 domain/settle_strategy（minTransfers 逐位不变；两策略均过 validatePlan）。
    final plan = buildPlan(balances: balances, strategy: strategy);
    if (plan.isEmpty) return null;

    final lastRound = await (db.select(db.settlements)
          ..where((s) => s.groupId.equals(gid))
          ..orderBy([(s) => OrderingTerm.desc(s.roundNo)])
          ..limit(1))
        .getSingleOrNull();
    final nextRoundNo = (lastRound?.roundNo ?? 0) + 1;

    final id = newId("settle");
    final transfersJson = jsonEncode([
      for (final t in plan)
        {
          "from": t.from,
          "to": t.to,
          "cents": t.cents,
          "done": false,
        }
    ]);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.settlements).insert(SettlementsCompanion(
      id: Value(id),
      groupId: Value(gid),
      status: const Value("active"),
      transfersJson: Value(transfersJson),
      expenseIdsJson: Value(jsonEncode([for (final e in outstanding) e.id])),
      roundNo: Value(nextRoundNo),
      strategy: Value(strategy.name),
      createdAt: Value(now),
    ));
    SyncOutboxService.notifyWrite("settlements", id);
    await _audit(gid, AuditEntity.settlement, id, AuditAction.settle, fields: {
      'roundNo': nextRoundNo,
      'strategy': strategy.name,
      'transfers': plan.length,
      'expenses': outstanding.length,
    });
    final created = Settlement(
      id: id,
      groupId: gid,
      status: SettlementStatus.active,
      transfers: [
        for (final t in plan)
          TransferRecord(
            from: t.from,
            to: t.to,
            cents: t.cents,
            done: false,
          )
      ],
      roundNo: nextRoundNo,
      createdAt: now,
      completedAt: null,
      strategy: strategy.name,
    );
    return created;
  }
  Future<void> markTransferDone(String sid, int index, bool done) async {
    final s = await (db.select(db.settlements)
          ..where((x) => x.id.equals(sid)))
        .getSingleOrNull();
    if (s == null) return;
    final list = _decodeTransferMaps(s.transfersJson);
    if (index < 0 || index >= list.length) return;
    list[index]['done'] = done;
    await (db.update(db.settlements)..where((x) => x.id.equals(sid))).write(
      SettlementsCompanion(transfersJson: Value(jsonEncode(list))),
    );
    SyncOutboxService.notifyWrite("settlements", sid);
    // S12.3：转账逐笔确认也是记录点（审计只记第几笔与最终状态）。
    await _audit(s.groupId, AuditEntity.settlement, sid, AuditAction.update,
        fields: {'transfer#': index, 'done': done});
  }
  Future<void> completeSettlement(String sid) async {
    final s = await (db.select(db.settlements)..where((x)=>x.id.equals(sid))).getSingleOrNull();
    if (s == null) return;
    final eids = jsonDecode(s.expenseIdsJson) as List;
    for (final e in eids) {
      await (db.update(db.expenses)..where((x)=>x.id.equals(e))).write(ExpensesCompanion(settledRoundId:Value(sid)));
    }
    await (db.update(db.settlements)..where((x)=>x.id.equals(sid))).write(SettlementsCompanion(status:Value("completed"),completedAt:Value(DateTime.now().millisecondsSinceEpoch)));
    // 回写的 settled_round_id 是账单行内容 → 必须一并上行，
    // 否则云端账单永远「未结算」，其他端重复催款。
    _notifyUpsert("expenses", eids.map((e) => e.toString()));
    SyncOutboxService.notifyWrite("settlements", sid);
    await _audit(s.groupId, AuditEntity.settlement, sid, AuditAction.complete,
        fields: {'roundNo': s.roundNo, 'expenses': eids.length});
  }

  Future<void> undoLastSettlement(String gid) async {
    final s = await (db.select(db.settlements)..where((x)=>x.groupId.equals(gid)&x.status.equals("completed"))..orderBy([(x)=>OrderingTerm.desc(x.createdAt)])).get();
    if (s.isEmpty) return;
    final last = s.first;
    final eids = jsonDecode(last.expenseIdsJson) as List;
    for (final e in eids) {
      await (db.update(db.expenses)..where((x)=>x.id.equals(e))).write(ExpensesCompanion(settledRoundId:Value(null)));
    }
    await (db.delete(db.settlements)..where((x)=>x.id.equals(last.id))).go();
    _notifyUpsert("expenses", eids.map((e) => e.toString()));
    SyncOutboxService.notifyWrite("settlements", last.id, op: "delete");
    await _audit(gid, AuditEntity.settlement, last.id, AuditAction.undo,
        fields: {'roundNo': last.roundNo, 'expenses': eids.length});
  }

  // === 公款池（S8 · N1） ===
  //
  // 核心建模红线（§S8.2）：
  //   入金 = prepay：payers = 各缴款人（各自金额）、shares = 管理人（缴纳总额）
  //   出金 = normal：payers = 管理人（本次支出）、shares = 按分摊模式
  // 这样 settle_engine 零改动即自动产出「管理人退每人 X」的方案。

  Stream<List<Fund>> watchFunds(String gid) => (db.select(db.funds)
        ..where((f) => f.groupId.equals(gid))
        ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
      .watch();

  Future<Fund?> getFund(String id) async =>
      (await (db.select(db.funds)..where((f) => f.id.equals(id))).get()).firstOrNull;

  /// 该团当前未关闭的池（一池一管理人；同时只应有一个 open 池）。
  Future<Fund?> getOpenFund(String gid) async => (await (db.select(db.funds)
        ..where((f) => f.groupId.equals(gid) & f.status.equals('open'))
        ..orderBy([(f) => OrderingTerm.desc(f.createdAt)])
        ..limit(1))
      .get()).firstOrNull;

  Future<Fund> addFund({
    required String gid,
    required String name,
    required String managerMemberId,
    int? targetCents,
  }) async {
    final manager = await (db.select(db.members)
          ..where((m) => m.id.equals(managerMemberId)))
        .getSingleOrNull();
    if (manager == null) throw StateError('管理人不存在，请先选择一位成员');
    if (manager.archived) throw StateError('该成员已移除，不能担任公款池管理人');
    if (manager.groupId != gid) throw StateError('管理人必须属于本账本');
    final id = newId('fund');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.funds).insert(FundsCompanion(
          id: Value(id),
          groupId: Value(gid),
          name: Value(name.trim().isEmpty ? '旅行基金' : name.trim()),
          managerMemberId: Value(managerMemberId),
          targetCents: Value(targetCents),
          status: const Value('open'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    SyncOutboxService.notifyWrite('funds', id);
    await _audit(gid, AuditEntity.fund, id, AuditAction.create, fields: {
      'name': name,
      'managerMemberId': managerMemberId,
      'targetCents': targetCents,
    });
    return (await getFund(id))!;
  }

  /// 改名 / 转移管理人 / 改计划金额。**只改 Fund 一行，不改历史账单**。
  ///
  /// [updateTarget] 为 true 时才会改写 `targetCents`（支持显式传 null 清空）。
  Future<void> updateFund(
    String fundId, {
    String? name,
    String? managerMemberId,
    int? targetCents,
    bool updateTarget = false,
  }) async {
    final comp = FundsCompanion(
      name: name == null ? const Value.absent() : Value(name.trim()),
      managerMemberId:
          managerMemberId == null ? const Value.absent() : Value(managerMemberId),
      targetCents: updateTarget ? Value(targetCents) : const Value.absent(),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await (db.update(db.funds)..where((f) => f.id.equals(fundId))).write(comp);
    SyncOutboxService.notifyWrite('funds', fundId);
    final fund = await getFund(fundId);
    if (fund != null) {
      await _audit(fund.groupId, AuditEntity.fund, fundId, AuditAction.update,
          fields: {
            'name': name,
            'managerMemberId': managerMemberId,
            if (updateTarget) 'targetCents': targetCents,
          });
    }
  }

  /// 关闭池（只读化）：关闭后禁止再新增入金/出金账单。
  Future<void> closeFund(String fundId) async {
    await (db.update(db.funds)..where((f) => f.id.equals(fundId))).write(
      FundsCompanion(
        status: const Value('closed'),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    SyncOutboxService.notifyWrite('funds', fundId);
    final fund = await getFund(fundId);
    if (fund != null) {
      await _audit(fund.groupId, AuditEntity.fund, fundId, AuditAction.close,
          fields: {'name': fund.name, 'status': 'closed'});
    }
  }

  Future<Fund> _openFundOrThrow(String fundId) async {
    final fund = await getFund(fundId);
    if (fund == null) throw StateError('公款池不存在');
    if (fund.status != 'open') throw StateError('公款池已关闭，不能再记入金或出金');
    final manager = await (db.select(db.members)
          ..where((m) => m.id.equals(fund.managerMemberId)))
        .getSingleOrNull();
    if (manager == null || manager.archived) {
      throw StateError('公款池管理人已失效，请先转移管理人');
    }
    return fund;
  }

  /// 记入金：`prepay` + payers=缴款人 / shares=管理人。
  ///
  /// [contributions] 为 memberId -> 缴纳额（分，正数）。返回新账单 id。
  Future<String> addFundContribution({
    required String fundId,
    required Map<String, int> contributions,
    int? dateEpochDay,
    String? note,
  }) async {
    final fund = await _openFundOrThrow(fundId);
    final entries = contributions.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) throw StateError('请至少填写一位缴款人的金额');
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final id = newId('expense');
    await db.into(db.expenses).insert(ExpensesCompanion(
          id: Value(id),
          groupId: Value(fund.groupId),
          dateEpochDay: Value(dateEpochDay ?? todayEpochDay()),
          title: Value('公费入金 · ${fund.name}'),
          categoryKey: const Value('other'),
          type: const Value('prepay'),
          amountCents: Value(total),
          currency: const Value('CNY'),
          rate: const Value(1.0),
          payersJson: Value(jsonEncode([
            for (final e in entries) {'memberId': e.key, 'cents': e.value},
          ])),
          // 红线：shares 恒为管理人，金额 = 缴纳总额。
          sharesJson: Value(jsonEncode([
            {'memberId': fund.managerMemberId, 'cents': total},
          ])),
          shareMode: const Value('custom'),
          note: Value(note ?? ''),
          fundId: Value(fundId),
          payMethod: const Value('fund'),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
    SyncOutboxService.notifyWrite('expenses', id);
    await _audit(fund.groupId, AuditEntity.fund, fundId, AuditAction.update,
        fields: {'入金': total, '人数': entries.length});
    return id;
  }

  /// 记出金：`normal` + payers=管理人 / shares 按分摊模式。
  Future<String> addFundExpense({
    required String fundId,
    required String title,
    required String categoryKey,
    required int amountCents,
    required List<String> shareMemberIds,
    ShareMode shareMode = ShareMode.equal,
    Map<String, int>? portions,
    int? dateEpochDay,
    String? note,
  }) async {
    final fund = await _openFundOrThrow(fundId);
    if (amountCents <= 0) throw StateError('请填写有效金额');
    if (shareMemberIds.isEmpty) throw StateError('请选择参与分摊的成员');
    final shares = splitShares(
      totalCents: amountCents,
      memberIds: shareMemberIds,
      mode: shareMode,
      portions: portions ?? const {},
    );
    final id = newId('expense');
    await db.into(db.expenses).insert(ExpensesCompanion(
          id: Value(id),
          groupId: Value(fund.groupId),
          dateEpochDay: Value(dateEpochDay ?? todayEpochDay()),
          title: Value(title.trim().isEmpty ? '公费支出' : title.trim()),
          categoryKey: Value(categoryKey),
          type: const Value('normal'),
          amountCents: Value(amountCents),
          currency: const Value('CNY'),
          rate: const Value(1.0),
          // 红线：payer 恒为管理人。
          payersJson: Value(jsonEncode([
            {'memberId': fund.managerMemberId, 'cents': amountCents},
          ])),
          sharesJson: Value(jsonEncode([
            for (final s in shares) {'memberId': s.memberId, 'cents': s.cents},
          ])),
          shareMode: Value(shareMode.name),
          portionsJson: Value(portions == null || portions.isEmpty ? null : jsonEncode(portions)),
          note: Value(note ?? ''),
          fundId: Value(fundId),
          payMethod: const Value('fund'),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
    SyncOutboxService.notifyWrite('expenses', id);
    await _audit(fund.groupId, AuditEntity.fund, fundId, AuditAction.update,
        fields: {'出金': amountCents, 'title': title});
    return id;
  }

  /// 某池的全部账单（含已入账，供详情页列表展示）。
  Future<List<Expense>> fundExpenses(String fundId) =>
      (db.select(db.expenses)
            ..where((e) => e.fundId.equals(fundId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.dateEpochDay),
              (e) => OrderingTerm.desc(e.createdAt),
            ]))
          .get();

  // === 记账收件箱（S10 · N3） ===
  //
  // 红线：独立暂存表 InboxItems；pending 条目**不得**参与任何统计 / 结算 / 预算 /
  // 导出 / 备份 / 分享与只读快照。归类必须「先转正再移除」，禁止用删除代替归类。

  Stream<List<InboxItem>> watchInboxItems(String gid) => (db.select(db.inboxItems)
        ..where((i) => i.groupId.equals(gid))
        ..orderBy([(i) => OrderingTerm.desc(i.capturedAt)]))
      .watch();

  Future<InboxItem?> getInboxItem(String id) async =>
      (await (db.select(db.inboxItems)..where((i) => i.id.equals(id))).get())
          .firstOrNull;

  /// 捕捉一条（只填金额 + 可选备注），落 pending。
  Future<String> captureInboxItem({
    required String gid,
    required int amountCents,
    String? note,
    String source = 'manual',
    int? capturedAtMs,
  }) async {
    if (amountCents <= 0) throw StateError('请填写有效金额');
    final id = newId('inbox');
    final now = capturedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.into(db.inboxItems).insert(InboxItemsCompanion(
          id: Value(id),
          groupId: Value(gid),
          amountCents: Value(amountCents),
          note: Value(note),
          capturedAt: Value(now),
          source: Value(source),
          status: const Value('pending'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    SyncOutboxService.notifyWrite('inbox_items', id);
    return id;
  }

  /// 归类转正：把一个 pending 条目变成正式账单。
  ///
  /// **幂等键 = [InboxItems.convertedExpenseId]**：已存在则跳过写入、仅补状态与通知，
  /// 因此「账单已插入但状态回写失败」后重试**不会**重复生成账单。
  ///
  /// [expense] 为归类表单构造的账单（id 由调用方给定，便于同事务写入幂等键）。
  Future<String> convertInboxItem({
    required String itemId,
    required ExpensesCompanion expense,
  }) async {
    final item = await getInboxItem(itemId);
    if (item == null) throw StateError('收件箱条目不存在');
    final existing = item.convertedExpenseId;
    if (existing != null && existing.isNotEmpty) {
      // 幂等：已转正，仅确保同步事件到位。
      SyncOutboxService.notifyWrite('inbox_items', itemId);
      return existing;
    }
    final expenseId = expense.id.value;
    await db.transaction(() async {
      await db.into(db.expenses).insert(expense);
      await (db.update(db.inboxItems)..where((i) => i.id.equals(itemId))).write(
        InboxItemsCompanion(
          status: const Value('converted'),
          convertedExpenseId: Value(expenseId),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
    // 事务提交成功后再通知（§3.1 事务与通知顺序）。
    SyncOutboxService.notifyWrite('expenses', expenseId);
    SyncOutboxService.notifyWrite('inbox_items', itemId);
    await _audit(item.groupId, AuditEntity.inbox, itemId, AuditAction.convert,
        fields: {'expenseId': expenseId, 'amountCents': item.amountCents});
    return expenseId;
  }

  /// 删除条目：**仅允许已转正条目**；pending 必须先归类（S10 红线）。
  Future<void> deleteInboxItem(String itemId) async {
    final item = await getInboxItem(itemId);
    if (item == null) return;
    if (item.status == 'pending') {
      throw StateError('请先归类再移除：未归类的条目不能直接删除');
    }
    await (db.delete(db.inboxItems)..where((i) => i.id.equals(itemId))).go();
    SyncOutboxService.notifyWrite('inbox_items', itemId, op: 'delete');
    await _audit(item.groupId, AuditEntity.inbox, itemId, AuditAction.delete,
        fields: {'amountCents': item.amountCents, 'note': item.note});
  }

  // === 分类子预算（V2.8.1 S8） ===
  //
  // 团级实体（与公款池同级）：用户自选分类（上限 5，校验放 UI 层，repo 不拦），
  // 金额 int 分；独立口径——不计入 groups.budget_cents 总预算。

  /// 该团全部子预算（updatedAt 升序，稳定读序便于列表 diff）。
  Stream<List<SubBudget>> watchSubBudgets(String gid) => (db.select(db.subBudgets)
        ..where((b) => b.groupId.equals(gid))
        ..orderBy([
          (b) => OrderingTerm.asc(b.updatedAt),
          (b) => OrderingTerm.asc(b.categoryKey),
        ]))
      .watch();

  /// 新增一条子预算（不校验分类上限/重复，口径放 UI 层）。
  Future<SubBudget> addSubBudget(String gid, String categoryKey, int amountCents) async {
    final id = newId('subbud');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.subBudgets).insert(SubBudgetsCompanion(
          id: Value(id),
          groupId: Value(gid),
          categoryKey: Value(categoryKey),
          amount: Value(amountCents),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    SyncOutboxService.notifyWrite('sub_budgets', id);
    return (await (db.select(db.subBudgets)..where((b) => b.id.equals(id))).get()).first;
  }

  /// 改金额：只动 amount + updatedAt，**不改 createdAt**（LWW 时间语义）。
  Future<void> updateSubBudget(String id, int amountCents) async {
    await (db.update(db.subBudgets)..where((b) => b.id.equals(id))).write(
      SubBudgetsCompanion(
        amount: Value(amountCents),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    SyncOutboxService.notifyWrite('sub_budgets', id);
  }

  Future<void> deleteSubBudget(String id) async {
    await (db.delete(db.subBudgets)..where((b) => b.id.equals(id))).go();
    SyncOutboxService.notifyWrite('sub_budgets', id, op: 'delete');
  }

  // === 分类 ===
  Stream<List<Category>> watchCategories() => db.select(db.categories).watch();

  // === 导入导出 ===
  /// 导出团 JSON：账单携带全部字段（date 与 dateEpochDay 双键兼容新旧导入方）
  Future<String> exportGroupJson(String gid) async {
    final g=await getGroup(gid);
    final ms=await getMembers(gid);
    final es=await (db.select(db.expenses)..where((e)=>e.groupId.equals(gid))).get();
    return jsonEncode({
      "app":"travel-assistant-v2","version":1,
      "group":{"id":gid,"name":g?.name??"","icon":g?.icon??"📁","kind":g?.kind??"travel"},
      "members":[for(final m in ms){"id":m.id,"name":m.name,"colorIndex":m.colorIndex}],
      "expenses":[for(final e in es){
        "id":e.id,"title":e.title,"amountCents":e.amountCents,
        "date":e.dateEpochDay,"dateEpochDay":e.dateEpochDay,
        "type":e.type,"currency":e.currency,"rate":e.rate,
        "amountForeignCents":e.amountForeignCents,
        "payersJson":e.payersJson,"sharesJson":e.sharesJson,
        "shareMode":e.shareMode,"portionsJson":e.portionsJson,
        "note":e.note,"categoryKey":e.categoryKey,
        "settledRoundId":e.settledRoundId,"tripId":e.tripId,
        "createdAt":e.createdAt,
      }],
    });
  }
  /// 导入团 JSON（真实现）：
  /// * 根结构 {group:{name,icon},members:[{id,name,colorIndex}],expenses:[...]}；
  ///   非法 JSON / 缺 group 节点抛 FormatException('数据格式不正确')。
  /// * 团/成员/账单一律换发全新 id；成员保留 colorIndex 并建立旧→新映射。
  /// * 账单兼容「全字段」与「最小字段(id,title,amountCents,dateEpochDay/date)」两种形态；
  ///   payersJson/sharesJson/portionsJson 内 memberId 全部重映射，
  ///   settledRoundId 一律重置 null（结算轮不随备份迁移）。
  Future<ImportReport> importGroupJson(String text) async {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('数据格式不正确');
    }
    if (decoded is! Map || decoded['group'] is! Map) {
      throw const FormatException('数据格式不正确');
    }
    final gRaw = (decoded['group'] as Map).cast<String, dynamic>();
    final mRaw = [
      if (decoded['members'] is List)
        for (final m in decoded['members'] as List)
          if (m is Map) m.cast<String, dynamic>(),
    ];
    final eRaw = [
      if (decoded['expenses'] is List)
        for (final e in decoded['expenses'] as List)
          if (e is Map) e.cast<String, dynamic>(),
    ];

    final warnings = <String>[];
    var droppedShares = 0, droppedPortions = 0, badExpenses = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // ① 团：换发新 id 落库
    final newGid = newId("group");
    final gName = (gRaw['name'] as String?) ?? '';
    final gIcon = (gRaw['icon'] as String?) ?? '📁';
    await db.into(db.groups).insert(GroupsCompanion(
      id: Value(newGid),
      name: Value(gName.isEmpty ? '导入的团' : gName),
      icon: Value(gIcon),
      kind: Value(_normalizeKind((gRaw['kind'] as String?) ?? 'travel')),
      createdAt: Value(now), updatedAt: Value(now),
    ));

    // ② 成员：旧→新 id 映射，保留 colorIndex；③ 账单：同一事务内落库
    final memberMap = <String,String>{};
    final newMemberIds = <String>[];
    final newExpenseIds = <String>[];
    final report = await db.transaction<ImportReport>(() async {
      var memberCount = 0, expenseCount = 0;
      for (final m in mRaw) {
        final nid = newId("member");
        final oldId = m['id'];
        if (oldId is String) memberMap[oldId] = nid;
        final name = ((m['name'] as String?) ?? '').trim();
        await db.into(db.members).insert(MembersCompanion(
          id: Value(nid), groupId: Value(newGid),
          name: Value(name.isEmpty ? '(未命名)' : name),
          colorIndex: Value(m['colorIndex'] is num ? (m['colorIndex'] as num).toInt() % 8 : 0),
          createdAt: Value(now)));
        newMemberIds.add(nid);
        memberCount++;
      }

      // ③ 账单
      for (final e in eRaw) {
        final title = ((e['title'] as String?) ?? '').trim();
        final amount = _asIntOrNull(e['amountCents']);
        if (title.isEmpty || amount == null) { badExpenses++; continue; }
        final payers = _remapShareList(e['payersJson'] ?? e['payers'], memberMap, () => droppedShares++);
        final shares = _remapShareList(e['sharesJson'] ?? e['shares'], memberMap, () => droppedShares++);
        final portions = _remapPortionsMap(e['portionsJson'] ?? e['portions'], memberMap, () => droppedPortions++);
        final newEid = newId("expense");
        await db.into(db.expenses).insert(ExpensesCompanion(
          id: Value(newEid),
          groupId: Value(newGid),
          dateEpochDay: Value(_epochDayOf(e)),
          title: Value(title),
          categoryKey: Value(((e['categoryKey'] as String?) ?? '').isEmpty ? 'other' : e['categoryKey'] as String),
          type: Value(kExpenseTypeNames.contains(e['type']) ? e['type'] as String : 'normal'),
          amountCents: Value(amount),
          currency: Value(((e['currency'] as String?) ?? '').isEmpty ? 'CNY' : e['currency'] as String),
          rate: Value(e['rate'] is num ? (e['rate'] as num).toDouble() : 1.0),
          amountForeignCents: Value(_asIntOrNull(e['amountForeignCents'])),
          payersJson: Value(jsonEncode(payers)),
          sharesJson: Value(jsonEncode(shares)),
          shareMode: Value(kShareModeNames.contains(e['shareMode']) ? e['shareMode'] as String : 'equal'),
          portionsJson: Value(portions),
          note: Value((e['note'] as String?) ?? ''),
          settledRoundId: const Value(null), // 结算轮不迁移，重置为未结算
          tripId: const Value(null),          // 行程不在本备份范围内，悬空引用置空
          createdAt: Value(now),
        ));
        newExpenseIds.add(newEid);
        expenseCount++;
      }
      if (droppedShares > 0) warnings.add('$droppedShares 条分摊记录因成员缺失被丢弃');
      if (droppedPortions > 0) warnings.add('$droppedPortions 条份数记录因成员缺失被丢弃');
      if (badExpenses > 0) warnings.add('$badExpenses 条无效账单已跳过');
      return ImportReport(groups:1, members:memberCount, expenses:expenseCount, warnings:warnings);
    });
    // 事务提交后统一入队：导入同样是本地写入，必须同步到云端（否则只在本机可见）。
    SyncOutboxService.notifyWrite("groups", newGid);
    _notifyUpsert("members", newMemberIds);
    _notifyUpsert("expenses", newExpenseIds);
    // S12.3：JSON 导入同理只记一条 import 汇总。
    await _audit(newGid, AuditEntity.backup, newGid, AuditAction.import_,
        fields: {
          'members': report.members,
          'expenses': report.expenses,
        });
    return report;
  }

  // === 专有格式备份（.tav） ===
  /// 导出完整团备份（团+成员+账单+结算轮+行程及安排+自定义分类）为二进制 .tav。
  Future<Uint8List> exportGroupBackupBytes(String gid) async {
    final backup = await _buildFullGroupMap(gid);
    return encodeBackup(kGroupBackupMagic, backup);
  }

  /// 局域网同步用：把团整包以稳定 id 导出为 JSON 快照（与 .tav 同一结构，不含信封）。
  /// 除当前团外，额外带上【全机其余行程】（含未绑团、绑其他团的），
  /// 让「行程」和账本一样能参与局域网共享；行程自带 items 数组。
  Future<String> exportGroupSnapshotJson(String gid) async {
    final map = Map<String, dynamic>.from(
        await _buildFullGroupMap(gid)); // 深拷贝，避免污染上层复用结构
    final trips = map['trips'] as List;
    final already = {for (final t in trips) (t as Map)['id']};
    final all = await (db.select(db.trips)).get();
    for (final t in all) {
      if (already.contains(t.id)) continue;
      final items = await (db.select(db.tripItems)
            ..where((i) => i.tripId.equals(t.id)))
          .get();
      final wishlist = await (db.select(db.wishlistItems)
            ..where((w) => w.tripId.equals(t.id)))
          .get();
      trips.add(<String, dynamic>{
        ...t.toJson(),
        'items': [for (final it in items) it.toJson()],
        'wishlist': [for (final w in wishlist) w.toJson()],
      });
    }
    return jsonEncode(map);
  }

  /// Android 已通过 manifest 放行网络，见 AndroidManifest.xml。

  /// 组装整包结构（稳定 id，供 .tav 与局域网快照共用）。
  Future<Map<String, dynamic>> _buildFullGroupMap(String gid) async {
    final g = await getGroup(gid);
    final members = await getMembers(gid);
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.groupId.equals(gid)))
        .get();
    final settlements = await (db.select(db.settlements)
          ..where((s) => s.groupId.equals(gid)))
        .get();
    final trips = await (db.select(db.trips)
          ..where((t) => t.groupId.equals(gid)))
        .get();
    final categories = await (db.select(db.categories)
          ..where((c) => c.builtin.equals(false)))
        .get();
    // V2.8.1：分类子预算随团整包带出（.tav 与局域网快照共用结构）。
    final subBudgets = await (db.select(db.subBudgets)
          ..where((b) => b.groupId.equals(gid)))
        .get();
    final tripsWithItems = <Map<String, dynamic>>[];
    for (final t in trips) {
      final items = await (db.select(db.tripItems)
            ..where((i) => i.tripId.equals(t.id)))
          .get();
      final wishlist = await (db.select(db.wishlistItems)
            ..where((w) => w.tripId.equals(t.id)))
          .get();
      tripsWithItems.add(<String, dynamic>{
        ...t.toJson(),
        'items': [for (final it in items) it.toJson()],
        'wishlist': [for (final w in wishlist) w.toJson()],
      });
    }
    return buildGroupBackup(
      group: g?.toJson() ?? <String, dynamic>{'id': gid, 'name': '', 'icon': '📁'},
      members: [for (final m in members) m.toJson()],
      expenses: [for (final e in expenses) _groupExpenseMap(e)],
      settlements: [for (final s in settlements) _groupSettlementMap(s)],
      trips: tripsWithItems,
      customCategories: [for (final c in categories) c.toJson()],
      subBudgets: [for (final b in subBudgets) b.toJson()],
    );
  }

  /// 局域网同步：把收到的整包快照合并进本地。
  /// 口径：实体 id 稳定，逐条 upsert；退/重复以【更新/创建时间晚者胜】（LWW）。
  /// 收到团 id 本地不存在则原样采纳（同 id 入库，别端即“同一本账”）。
  /// 返回人类可读摘要。
  Future<String> mergeGroupSnapshotJson(String raw) async {
    final backup = parseGroupBackupMap(
        (jsonDecode(raw) as Map).cast<String, dynamic>());
    final gid = backup.group['id'] as String? ?? '';
    if (gid.isEmpty) return '快照缺少团 id';
    final now = DateTime.now().millisecondsSinceEpoch;
    var addGroup = 0, updGroup = 0, members = 0, expenses = 0, settlements = 0,
        trips = 0, items = 0;

    // 局域网快照合并进来的行同样是本地写入 → 事务提交后统一入队上行，
    // 否则这些数据只在合并的这台机器上存在，永远上不了云。
    final touched = <String, Set<String>>{};
    void mark(String entity, String id) => (touched[entity] ??= {}).add(id);

    await db.transaction(() async {
      // ---- 团 ----
      final g = backup.group;
      final existsGroup = await getGroup(gid);
      if (existsGroup == null) {
        await db.into(db.groups).insert(GroupsCompanion(
          id: Value(gid),
          name: Value(_nonEmpty(g['name'] as String?, '同步的团')),
          icon: Value(_nonEmpty(g['icon'] as String?, '📁')),
          budgetEnabled: Value(g['budgetEnabled'] is bool ? g['budgetEnabled'] as bool : false),
          budgetCents: Value(g['budgetCents'] is int ? g['budgetCents'] as int? : null),
          archived: Value(g['archived'] is bool ? g['archived'] as bool : false),
          archivedAtMs: Value(g['archivedAtMs'] is int ? g['archivedAtMs'] as int? : null),
          kind: Value(_normalizeKind(g['kind'] as String? ?? 'travel')),
          createdAt: Value(g['createdAt'] is int ? g['createdAt'] as int : now),
          updatedAt: Value(now),
        ));
        addGroup++;
        mark('groups', gid);
      } else {
        final inUpd = g['updatedAt'] is int ? g['updatedAt'] as int : 0;
        if (inUpd >= (existsGroup.updatedAt ?? 0)) {
          await (db.update(db.groups)..where((x) => x.id.equals(gid))).write(
            GroupsCompanion(
              name: Value(_nonEmpty(g['name'] as String?, existsGroup.name)),
              icon: Value(_nonEmpty(g['icon'] as String?, existsGroup.icon)),
              budgetEnabled: Value(g['budgetEnabled'] is bool ? g['budgetEnabled'] as bool : existsGroup.budgetEnabled),
              budgetCents: Value(g['budgetCents'] is int ? g['budgetCents'] as int? : existsGroup.budgetCents),
              kind: Value(_normalizeKind(g['kind'] as String? ?? existsGroup.kind)),
              updatedAt: Value(now),
            ),
          );
          updGroup++;
          mark('groups', gid);
        }
      }

      // ---- 成员（id 稳定，upsert）----
      for (final m in backup.members) {
        final mid = m['id'] as String?;
        if (mid == null) continue;
        final hit = await (db.select(db.members)..where((x) => x.id.equals(mid))).get();
        final name = _nonEmpty(m['name'] as String?, '(未命名)');
        final colorIndex = m['colorIndex'] is int ? (m['colorIndex'] as int) % 8 : 0;
        if (hit.isEmpty) {
          await db.into(db.members).insert(MembersCompanion(
            id: Value(mid), groupId: Value(gid), name: Value(name),
            colorIndex: Value(colorIndex),
            createdAt: Value(m['createdAt'] is int ? m['createdAt'] as int : now),
          ));
        } else {
          await (db.update(db.members)..where((x) => x.id.equals(mid))).write(
            MembersCompanion(
              groupId: Value(gid), name: Value(name), colorIndex: Value(colorIndex),
            ),
          );
        }
        members++;
        mark('members', mid);
      }

      // ---- 账单（LWW：createdAt 晚者胜；本地无则入库）----
      for (final e in backup.expenses) {
        final eid = e['id'] as String?;
        if (eid == null) continue;
        final hit = await (db.select(db.expenses)..where((x) => x.id.equals(eid))).get();
        final inCreated = e['createdAt'] is int ? e['createdAt'] as int : now;
        final localCreated = hit.isEmpty ? null : hit.first.createdAt;
        if (hit.isNotEmpty && localCreated != null && localCreated > inCreated) {
          continue; // 本地更新
        }
        final comp = ExpensesCompanion(
          id: Value(eid),
          groupId: Value(gid),
          dateEpochDay: Value(_epochDayOfMap(e)),
          title: Value(_nonEmpty(e['title'] as String?, '未命名账单')),
          categoryKey: Value(_nonEmpty(e['categoryKey'] as String?, 'other')),
          type: Value(kExpenseTypeNames.contains(e['type']) ? e['type'] as String : 'normal'),
          amountCents: Value(e['amountCents'] is int ? e['amountCents'] as int : 0),
          currency: Value(_nonEmpty(e['currency'] as String?, 'CNY')),
          rate: Value(e['rate'] is num ? (e['rate'] as num).toDouble() : 1.0),
          amountForeignCents: Value(e['amountForeignCents'] is int ? e['amountForeignCents'] as int? : null),
          payersJson: Value(e['payers'] is List ? jsonEncode(e['payers']) : '[]'),
          sharesJson: Value(e['shares'] is List ? jsonEncode(e['shares']) : '[]'),
          shareMode: Value(kShareModeNames.contains(e['shareMode']) ? e['shareMode'] as String : 'equal'),
          portionsJson: Value(e['portions'] is List && (e['portions'] as List).isNotEmpty ? jsonEncode(e['portions']) : null),
          note: Value((e['note'] as String? ?? '')),
          settledRoundId: Value(e['settledRoundId'] is String ? e['settledRoundId'] as String? : null),
          tripId: Value(e['tripId'] is String ? e['tripId'] as String? : null),
          tripItemId: Value(e['tripItemId'] is String ? e['tripItemId'] as String? : null),
          fundId: Value(e['fundId'] is String ? e['fundId'] as String? : null),
          payMethod: Value(e['payMethod'] is String ? e['payMethod'] as String? : null),
          createdAt: Value(inCreated),
        );
        if (hit.isEmpty) {
          await db.into(db.expenses).insert(comp);
        } else {
          await (db.update(db.expenses)..where((x) => x.id.equals(eid))).write(comp);
        }
        expenses++;
        mark('expenses', eid);
      }

      // ---- 结算轮（LWW createdAt）----
      for (final s in backup.settlements) {
        final sid = s['id'] as String?;
        if (sid == null) continue;
        final hit = await (db.select(db.settlements)..where((x) => x.id.equals(sid))).get();
        final inCreated = s['createdAt'] is int ? s['createdAt'] as int : now;
        final localCreated = hit.isEmpty ? null : hit.first.createdAt;
        if (hit.isNotEmpty && localCreated != null && localCreated > inCreated) {
          continue;
        }
        final comp = SettlementsCompanion(
          id: Value(sid),
          groupId: Value(gid),
          status: Value(_nonEmpty(s['status'] as String?, 'active')),
          transfersJson: Value(s['transfers'] is List ? jsonEncode(s['transfers']) : '[]'),
          expenseIdsJson: Value(s['expenseIds'] is List ? jsonEncode(s['expenseIds']) : '[]'),
          roundNo: Value(s['roundNo'] is int ? s['roundNo'] as int : 1),
          createdAt: Value(inCreated),
          completedAt: Value(s['completedAt'] is int ? s['completedAt'] as int? : null),
        );
        if (hit.isEmpty) {
          await db.into(db.settlements).insert(comp);
        } else {
          await (db.update(db.settlements)..where((x) => x.id.equals(sid))).write(comp);
        }
        settlements++;
        mark('settlements', sid);
      }

      // ---- 行程 + 安排（LWW updatedAt）----
      for (final t in backup.trips) {
        final tid = t['id'] as String?;
        if (tid == null) continue;
        final hit = await (db.select(db.trips)..where((x) => x.id.equals(tid))).get();
        final inUpd = t['updatedAt'] is int ? t['updatedAt'] as int : 0;
        final localUpd = hit.isEmpty ? -1 : (hit.first.updatedAt ?? 0);
        final apply = hit.isEmpty || inUpd >= localUpd;
        if (apply) {
          if (hit.isEmpty) {
            await db.into(db.trips).insert(TripsCompanion(
              id: Value(tid),
              name: Value(_nonEmpty(t['name'] as String?, '同步的行程')),
              destination: Value((t['destination'] as String? ?? '')),
              emoji: Value(_nonEmpty(t['emoji'] as String?, '✈️')),
              cover: Value(_nonEmpty(t['cover'] as String?, 'ocean')),
              startEpochDay: Value(t['startEpochDay'] is int ? t['startEpochDay'] as int : 0),
              endEpochDay: Value(t['endEpochDay'] is int ? t['endEpochDay'] as int : 0),
              note: Value((t['note'] as String? ?? '')),
              groupId: Value(
                  _nonEmpty(t['groupId'] as String?, gid)), // 保留行程自身归属，独立行程保持未绑团
              archived: Value(t['archived'] is bool ? t['archived'] as bool : false),
              createdAt: Value(t['createdAt'] is int ? t['createdAt'] as int : now),
              updatedAt: Value(now),
            ));
          } else {
            await (db.update(db.trips)..where((x) => x.id.equals(tid))).write(TripsCompanion(
              name: Value(_nonEmpty(t['name'] as String?, hit.first.name)),
              destination: Value((t['destination'] as String? ?? '')),
              emoji: Value(_nonEmpty(t['emoji'] as String?, '✈️')),
              cover: Value(_nonEmpty(t['cover'] as String?, 'ocean')),
              startEpochDay: Value(t['startEpochDay'] is int ? t['startEpochDay'] as int : hit.first.startEpochDay),
              endEpochDay: Value(t['endEpochDay'] is int ? t['endEpochDay'] as int : hit.first.endEpochDay),
              note: Value((t['note'] as String? ?? '')),
              archived: Value(t['archived'] is bool ? t['archived'] as bool : hit.first.archived),
              updatedAt: Value(now),
            ));
          }
          trips++;
          mark('trips', tid);
        }
        if (apply) {
          for (final it in _asMapList(t['items'])) {
            final iid = it['id'] as String;
            final ihit = await (db.select(db.tripItems)..where((x) => x.id.equals(iid))).get();
            final iUpd = it['updatedAt'] is int ? it['updatedAt'] as int : 0;
            final iLocal = ihit.isEmpty ? -1 : (ihit.first.updatedAt ?? 0);
            if (ihit.isNotEmpty && iLocal > iUpd) continue;
            final comp = _tripItemCompanion(it, now, tid);
            if (ihit.isEmpty) {
              await db.into(db.tripItems).insert(comp);
            } else {
              await (db.update(db.tripItems)..where((x) => x.id.equals(iid))).write(comp);
            }
            items++;
            mark('trip_items', iid);
          }
          // V2.7.2：想去池随行程合并（LWW updatedAt；行内无日期语义）
          for (final w in _asMapList(t['wishlist'])) {
            final wid = w['id'] as String?;
            if (wid == null) continue;
            final whit = await (db.select(db.wishlistItems)..where((x) => x.id.equals(wid))).get();
            final wUpd = w['updatedAt'] is int ? w['updatedAt'] as int : 0;
            final wLocal = whit.isEmpty ? -1 : (whit.first.updatedAt ?? 0);
            if (whit.isNotEmpty && wLocal > wUpd) continue;
            final comp = _wishlistItemCompanion(w, now, tid);
            if (whit.isEmpty) {
              await db.into(db.wishlistItems).insert(comp);
            } else {
              await (db.update(db.wishlistItems)..where((x) => x.id.equals(wid))).write(comp);
            }
            mark('wishlist_items', wid);
          }
        }
      }
      // ---- 分类子预算（V2.8.1，LWW updatedAt；行内无外键强约束）----
      for (final b in backup.subBudgets) {
        final bid = b['id'] as String?;
        if (bid == null) continue;
        final bhit = await (db.select(db.subBudgets)..where((x) => x.id.equals(bid))).get();
        final bUpd = b['updatedAt'] is int ? b['updatedAt'] as int : 0;
        final bLocal = bhit.isEmpty ? -1 : bhit.first.updatedAt;
        if (bhit.isNotEmpty && bLocal > bUpd) continue;
        final comp = SubBudgetsCompanion(
          id: Value(bid),
          groupId: Value(gid),
          categoryKey: Value(b['categoryKey'] as String? ?? ''),
          amount: Value(b['amount'] is int ? b['amount'] as int : 0),
          createdAt: Value(b['createdAt'] is int ? b['createdAt'] as int : now),
          updatedAt: Value(bUpd),
        );
        if (bhit.isEmpty) {
          await db.into(db.subBudgets).insert(comp);
        } else {
          await (db.update(db.subBudgets)..where((x) => x.id.equals(bid))).write(comp);
        }
        mark('sub_budgets', bid);
      }
    });

    for (final kv in touched.entries) {
      _notifyUpsert(kv.key, kv.value);
    }
    // S12.3：局域网合并同为批量导入，只记一条 import 汇总。
    await _audit(gid, AuditEntity.backup, gid, AuditAction.import_, fields: {
      '来源': '局域网快照',
      'members': members,
      'expenses': expenses,
      'settlements': settlements,
    });

    return '合并完成：团$addGroup新增/更新$updGroup · 成员$members · 账单$expenses · '
        '结算$settlements · 行程$trips · 安排$items';
  }

  /// 导入专有 .tav 备份（亦兼容旧 JSON 文本回退）。
  Future<ImportReport> importGroupBackupBytes(Uint8List bytes) async {
    Map<String, dynamic> root;
    if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kGroupBackupMagic])) {
      root = decodeBackup(bytes, acceptedMagics: [kGroupBackupMagic]);
    } else {
      return importGroupJson(utf8.decode(bytes)); // 旧 JSON 备份
    }
    final backup = parseGroupBackupMap(root);
    final existingByName = await _existingCategoryNameToKey();
    final result = applyImport(backup, existingCategoryByName: existingByName);
    final report = await _insertFullBackup(result);
    // S12.3：批量导入不逐条记录，只记一条 import 汇总（防体积爆炸）。
    await _audit(
        result.group['id'] as String? ?? '', AuditEntity.backup,
        result.group['id'] as String? ?? '', AuditAction.import_,
        fields: {
          'members': report.members,
          'expenses': report.expenses,
          'settlements': report.settlements,
        });
    return report;
  }

  // === 全量备份（.tavA / 同步码） ===
  /// 组装全量备份根结构：全部团（每团整包）+ 未绑团行程（含安排/清单）。
  Future<Map<String, dynamic>> _buildFullBackupRoot() async {
    final allGroups = await (db.select(db.groups)).get();
    final groups = <Map<String, dynamic>>[];
    for (final g in allGroups) {
      groups.add(await _buildFullGroupMap(g.id));
    }
    final standalone = <Map<String, dynamic>>[];
    final unbound =
        await (db.select(db.trips)..where((t) => t.groupId.isNull())).get();
    for (final t in unbound) {
      final items = await (db.select(db.tripItems)
            ..where((i) => i.tripId.equals(t.id)))
          .get();
      final checklist = await (db.select(db.checklistItems)
            ..where((c) => c.tripId.equals(t.id)))
          .get();
      final wishlist = await (db.select(db.wishlistItems)
            ..where((w) => w.tripId.equals(t.id)))
          .get();
      standalone.add(<String, dynamic>{
        ...t.toJson(),
        'items': [for (final it in items) it.toJson()],
        'checklist': [for (final c in checklist) c.toJson()],
        'wishlist': [for (final w in wishlist) w.toJson()],
      });
    }
    return buildFullBackup(groups: groups, standaloneTrips: standalone);
  }

  /// 导出全量备份：全部团（每团整包）+ 未绑团行程，打包为二进制 .tavA。
  Future<Uint8List> exportFullBackupBytes() async {
    final root = await _buildFullBackupRoot();
    return encodeBackup(kFullBackupMagic, root);
  }

  /// 导出全量快照为 JSON（与 .tavA 同一结构、不含信封），供「二维码/口令码」使用。
  /// 不依赖任何团存在：一个团都没有时也能导出（至少带走未绑团行程）。
  Future<String> exportFullBackupJson() async {
    final root = await _buildFullBackupRoot();
    return jsonEncode(root);
  }

  /// 导入全量备份：replace=true 先清空全部数据再合并（恢复）；false 则逐团 LWW 合并。
  Future<FullImportReport> importFullBackupBytes(
    Uint8List bytes, {
    required bool replace,
  }) async {
    final root = decodeBackup(bytes, acceptedMagics: [kFullBackupMagic]);
    return importFullBackupRoot(root, replace: replace);
  }

  /// 导入全量同步码 JSON（口令码/扫码粘贴）：恒为 LWW 合并（不给覆盖恢复入口）。
  Future<FullImportReport> importFullBackupRawJson(String raw) async {
    final root = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return importFullBackupRoot(root, replace: false);
  }

  /// 全量备份导入内核：先按需清空，再逐团 LWW 合并 + 独立行程 upsert。
  Future<FullImportReport> importFullBackupRoot(
    Map<String, dynamic> root, {
    required bool replace,
  }) async {
    final backup = parseFullBackupMap(root);
    final report = fullImportReportFor(backup, replace: replace);
    if (replace) {
      await _clearAllData();
    }
    // 逐团合并（每团独立事务，避免嵌套事务；合并语义与局域网快照一致）
    for (final g in backup.groups) {
      final single = buildGroupBackup(
        group: (g['group'] as Map?)?.cast<String, dynamic>() ?? const {},
        members: _asMapList(g['members']),
        expenses: _asMapList(g['expenses']),
        settlements: _asMapList(g['settlements']),
        trips: _asMapList(g['trips']),
        customCategories: _asMapList(g['customCategories']),
        subBudgets: _asMapList(g['subBudgets']), // V2.8.1：旧包无键 → 空清单
      );
      await mergeGroupSnapshotJson(jsonEncode(single));
    }
    // 未绑团独立行程：稳定 id upsert（行程+安排+清单）
    for (final t in backup.standaloneTrips) {
      await _upsertStandaloneTrip(t);
    }
    // S12.3：全量备份导入按团各记一条 import 汇总（绝不逐行记录）。
    for (final g in backup.groups) {
      final gid = ((g['group'] as Map?)?['id'] as String?) ?? '';
      if (gid.isEmpty) continue;
      await _audit(gid, AuditEntity.backup, gid, AuditAction.import_, fields: {
        '来源': replace ? '全量备份（覆盖恢复）' : '全量备份（合并）',
        'members': _asMapList(g['members']).length,
        'expenses': _asMapList(g['expenses']).length,
      });
    }
    return report;
  }

  Future<void> _upsertStandaloneTrip(Map<String, dynamic> t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tid = t['id'] as String?;
    if (tid == null) return;
    // 备份导入的独立行程也要上云（调用方无事务包裹，可直接入队）。
    final touchedItemIds = <String>[];
    final hit = await (db.select(db.trips)..where((x) => x.id.equals(tid))).get();
    final inUpd = t['updatedAt'] is int ? t['updatedAt'] as int : 0;
    final localUpd = hit.isEmpty ? -1 : hit.first.updatedAt;
    if (hit.isNotEmpty && localUpd > inUpd) return; // 本地更新
    if (hit.isEmpty) {
      await db.into(db.trips).insert(TripsCompanion(
        id: Value(tid),
        name: Value(_nonEmpty(t['name'] as String?, '同步的行程')),
        destination: Value((t['destination'] as String? ?? '')),
        emoji: Value(_nonEmpty(t['emoji'] as String?, '✈️')),
        cover: Value(_nonEmpty(t['cover'] as String?, 'ocean')),
        startEpochDay:
            Value(t['startEpochDay'] is int ? t['startEpochDay'] as int : 0),
        endEpochDay:
            Value(t['endEpochDay'] is int ? t['endEpochDay'] as int : 0),
        note: Value((t['note'] as String? ?? '')),
        groupId: Value(null),
        archived: Value(t['archived'] is bool ? t['archived'] as bool : false),
        createdAt: Value(t['createdAt'] is int ? t['createdAt'] as int : now),
        updatedAt: Value(now),
      ));
    } else {
      await (db.update(db.trips)..where((x) => x.id.equals(tid))).write(
        TripsCompanion(
          name: Value(_nonEmpty(t['name'] as String?, hit.first.name)),
          destination: Value((t['destination'] as String? ?? '')),
          emoji: Value(_nonEmpty(t['emoji'] as String?, hit.first.emoji)),
          cover: Value(_nonEmpty(t['cover'] as String?, hit.first.cover)),
          startEpochDay: Value(t['startEpochDay'] is int
              ? t['startEpochDay'] as int
              : hit.first.startEpochDay),
          endEpochDay: Value(t['endEpochDay'] is int
              ? t['endEpochDay'] as int
              : hit.first.endEpochDay),
          note: Value((t['note'] as String? ?? '')),
          archived: Value(t['archived'] is bool
              ? t['archived'] as bool
              : hit.first.archived),
          updatedAt: Value(now),
        ),
      );
    }
    for (final it in _asMapList(t['items'])) {
      final iid = it['id'] as String?;
      if (iid == null) continue;
      final ihit =
          await (db.select(db.tripItems)..where((x) => x.id.equals(iid))).get();
      final iUpd = it['updatedAt'] is int ? it['updatedAt'] as int : 0;
      final iLocal = ihit.isEmpty ? -1 : ihit.first.updatedAt;
      if (ihit.isNotEmpty && iLocal > iUpd) continue;
      final comp = _tripItemCompanion(it, now, tid);
      if (ihit.isEmpty) {
        await db.into(db.tripItems).insert(comp);
      } else {
        await (db.update(db.tripItems)..where((x) => x.id.equals(iid)))
            .write(comp);
      }
      touchedItemIds.add(iid);
    }
    for (final c in _asMapList(t['checklist'])) {
      final cid = c['id'] as String?;
      if (cid == null) continue;
      final chit =
          await (db.select(db.checklistItems)..where((x) => x.id.equals(cid))).get();
      if (chit.isNotEmpty) continue;
      await db.into(db.checklistItems).insert(ChecklistItemsCompanion(
        id: Value(cid),
        scope: Value('trip'),
        tripId: Value(tid),
        category: Value(_nonEmpty(c['category'] as String?, 'other')),
        label: Value(_nonEmpty(c['label'] as String?, '事项')),
        done: Value(c['done'] is bool ? c['done'] as bool : false),
        sortOrder: Value(c['sortOrder'] is int ? c['sortOrder'] as int : 0),
      ));
    }
    // V2.7.2：全量备份携带的想去池行（LWW updatedAt）
    for (final w in _asMapList(t['wishlist'])) {
      final wid = w['id'] as String?;
      if (wid == null) continue;
      final whit =
          await (db.select(db.wishlistItems)..where((x) => x.id.equals(wid))).get();
      final wUpd = w['updatedAt'] is int ? w['updatedAt'] as int : 0;
      final wLocal = whit.isEmpty ? -1 : (whit.first.updatedAt ?? 0);
      if (whit.isNotEmpty && wLocal > wUpd) continue;
      final comp = _wishlistItemCompanion(w, now, tid);
      if (whit.isEmpty) {
        await db.into(db.wishlistItems).insert(comp);
      } else {
        await (db.update(db.wishlistItems)..where((x) => x.id.equals(wid))).write(comp);
      }
      _notifyUpsert('wishlist_items', {wid});
    }
    SyncOutboxService.notifyWrite('trips', tid);
    _notifyUpsert('trip_items', touchedItemIds);
  }

  /// 清空全部业务数据（覆盖恢复用）。按外键依赖倒序删除。
  ///
  /// 覆盖恢复 = 整库替换（新导入的行都是新 id），所以必须在删除前收集旧 id，
  /// 提交后逐行发 delete 墓碑；否则云端会永久留着被覆盖掉的旧账本。
  /// categories 不在此列：字典表被清空后由备份 / 内置种子重建，云端副本无害。
  Future<void> _clearAllData() async {
    final oldGroups = (await db.select(db.groups).get()).map((r) => r.id).toList();
    final oldMembers = (await db.select(db.members).get()).map((r) => r.id).toList();
    final oldExpenses = (await db.select(db.expenses).get()).map((r) => r.id).toList();
    final oldSettlements =
        (await db.select(db.settlements).get()).map((r) => r.id).toList();
    final oldTrips = (await db.select(db.trips).get()).map((r) => r.id).toList();
    final oldItems = (await db.select(db.tripItems).get()).map((r) => r.id).toList();
    final oldFunds = (await db.select(db.funds).get()).map((r) => r.id).toList();
    final oldInbox = (await db.select(db.inboxItems).get()).map((r) => r.id).toList();
    final oldWishlist = (await db.select(db.wishlistItems).get()).map((r) => r.id).toList();
    // V2.8.1：分类子预算同样整库清理 + 逐行墓碑（团已不存在，孤儿行不可见也不可达）。
    final oldSubBudgets = (await db.select(db.subBudgets).get()).map((r) => r.id).toList();
    await db.transaction(() async {
      await db.delete(db.expenses).go();
      await db.delete(db.settlements).go();
      await db.delete(db.funds).go();
      await db.delete(db.inboxItems).go();
      await db.delete(db.subBudgets).go();
      await db.delete(db.tripItems).go();
      await db.delete(db.wishlistItems).go();
      await db.delete(db.checklistItems).go();
      await db.delete(db.albumPhotos).go();
      await db.delete(db.trips).go();
      await db.delete(db.members).go();
      await db.delete(db.categories).go();
      await db.delete(db.groups).go();
    });
    _notifyDelete('groups', oldGroups);
    _notifyDelete('members', oldMembers);
    _notifyDelete('funds', oldFunds);
    _notifyDelete('inbox_items', oldInbox);
    _notifyDelete('expenses', oldExpenses);
    _notifyDelete('settlements', oldSettlements);
    _notifyDelete('sub_budgets', oldSubBudgets);
    _notifyDelete('trips', oldTrips);
    _notifyDelete('trip_items', oldItems);
    _notifyDelete('wishlist_items', oldWishlist);
  }

  /// CSV 批量导入账单到指定团。
  ///
  /// [rows] 每项为已归一化账单：
  ///   {title, amountCents, dateEpochDay, categoryKey, type,
  ///    payerNames, shareMode, shareNames, currency, rate, note}
  /// 付款/分账成员按姓名创建/复用（缺失自动新建）。返回导入摘要。
  Future<ImportReport> bulkImportExpenses(
    String groupId, {
    required List<Map<String, dynamic>> rows,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // ① 收集全部成员姓名，缺失则新建
    final names = <String>{};
    for (final r in rows) {
      for (final n in (r['payerNames'] as List? ?? <dynamic>[])) {
        final s = n.toString().trim();
        if (s.isNotEmpty) names.add(s);
      }
      for (final n in (r['shareNames'] as List? ?? <dynamic>[])) {
        final s = n.toString().trim();
        if (s.isNotEmpty) names.add(s);
      }
    }
    final existing =
        await (db.select(db.members)..where((m) => m.groupId.equals(groupId))).get();
    final nameToId = <String, String>{
      for (final m in existing)
        if (m.name.isNotEmpty) m.name: m.id,
    };
    final toCreate = <String>[];
    for (final n in names) {
      if (!nameToId.containsKey(n)) {
        nameToId[n] = newId('member');
        toCreate.add(n);
      }
    }
    final allIds = nameToId.values.toList();

    var memberCount = 0, expenseCount = 0, badRows = 0;
    final warnings = <String>[];
    final newMemberIds = <String>[];
    final newExpenseIds = <String>[];
    await db.transaction(() async {
      for (final n in toCreate) {
        await db.into(db.members).insert(MembersCompanion(
          id: Value(nameToId[n]!),
          groupId: Value(groupId),
          name: Value(n),
          colorIndex: Value(0),
          createdAt: Value(now),
        ));
        newMemberIds.add(nameToId[n]!);
        memberCount++;
      }
      for (final r in rows) {
        final title = (r['title'] as String? ?? '').trim();
        final amount = r['amountCents'];
        if (title.isEmpty || amount is! int) {
          badRows++;
          continue;
        }
        final payerNames =
            (r['payerNames'] as List? ?? <dynamic>[]).map((n) => n.toString().trim()).toList();
        var shareNames =
            (r['shareNames'] as List? ?? <dynamic>[]).map((n) => n.toString().trim()).toList();
        if (shareNames.isEmpty) shareNames = names.toList(); // 未指定分账人→全部成员
        final payerIds =
            payerNames.map((n) => nameToId[n]).whereType<String>().toSet().toList();
        final shareIds =
            shareNames.map((n) => nameToId[n]).whereType<String>().toSet().toList();
        if (payerIds.isEmpty) payerIds.addAll(allIds); // 未指定付款人→全部成员
        if (shareIds.isEmpty) shareIds.addAll(allIds);
        if (payerIds.isEmpty || shareIds.isEmpty) {
          badRows++;
          continue;
        }
        final mode = ShareMode.values.firstWhere(
          (m) => m.name == r['shareMode'],
          orElse: () => ShareMode.equal,
        );
        // S3：percent 模式下把「分摊百分比」列（已按分摊人顺序对齐）归一为 bp 表；
        // 全 0/全空回退 equal（与 share_splitter 同口径）。
        var effectiveMode = mode;
        Map<String, int>? portions;
        List<ShareEntry> shares;
        try {
          if (mode == ShareMode.percent) {
            final values =
                (r['sharePercentValues'] as List?)?.whereType<int>().toList() ??
                    const <int>[];
            final raw = <String, int>{};
            for (var i = 0; i < shareNames.length && i < values.length; i++) {
              final id = nameToId[shareNames[i]];
              if (id != null && values[i] > 0) raw[id] = values[i];
            }
            final bp = normalizePercentToBp(raw);
            if (bp.isEmpty) {
              effectiveMode = ShareMode.equal;
              shares = splitShares(totalCents: amount, memberIds: shareIds);
            } else {
              portions = bp;
              shares = splitShares(
                totalCents: amount,
                memberIds: shareIds,
                mode: ShareMode.percent,
                portions: bp,
              );
            }
          } else {
            shares = splitShares(
              totalCents: amount,
              memberIds: shareIds,
              mode: mode,
            );
          }
        } catch (_) {
          badRows++;
          continue;
        }
        final payers = splitShares(
          totalCents: amount,
          memberIds: payerIds,
          mode: ShareMode.equal,
        );
        final categoryKey = (r['categoryKey'] as String? ?? '').trim();
        final typeRaw = (r['type'] as String? ?? 'normal').trim();
        final type = kExpenseTypeNames.contains(typeRaw) ? typeRaw : 'normal';
        final newEid = newId('expense');
        await db.into(db.expenses).insert(ExpensesCompanion(
          id: Value(newEid),
          groupId: Value(groupId),
          dateEpochDay: Value(r['dateEpochDay'] is int ? r['dateEpochDay'] as int : 0),
          title: Value(title),
          categoryKey: Value(categoryKey.isEmpty ? 'other' : categoryKey),
          type: Value(type),
          amountCents: Value(amount),
          currency: Value(((r['currency'] as String?) ?? '').trim().isEmpty ? 'CNY' : (r['currency'] as String)),
          rate: Value(r['rate'] is num ? (r['rate'] as num).toDouble() : 1.0),
          amountForeignCents: const Value(null),
          payersJson: Value(jsonEncode([
            for (final p in payers) {'memberId': p.memberId, 'cents': p.cents},
          ])),
          sharesJson: Value(jsonEncode([
            for (final s in shares) {'memberId': s.memberId, 'cents': s.cents},
          ])),
          shareMode: Value(effectiveMode.name),
          portionsJson: Value(portions == null ? null : jsonEncode(portions)),
          note: Value((r['note'] as String? ?? '')),
          settledRoundId: const Value(null),
          createdAt: Value(now),
        ));
        expenseCount++;
        newExpenseIds.add(newEid);
      }
    });
    // 提交后入队：CSV 批量导入也是本地写入，必须同步到云端。
    _notifyUpsert('members', newMemberIds);
    _notifyUpsert('expenses', newExpenseIds);
    await _audit(groupId, AuditEntity.backup, groupId, AuditAction.import_,
        fields: {
          '来源': 'CSV',
          'members': memberCount,
          'expenses': expenseCount,
        });
    if (badRows > 0) warnings.add('$badRows 条无效记录已跳过');
    return ImportReport(
      groups: 0,
      members: memberCount,
      expenses: expenseCount,
      warnings: warnings,
    );
  }

  Future<Map<String, String>> _existingCategoryNameToKey() async {
    final rows = await (db.select(db.categories)).get();
    final map = <String, String>{};
    for (final c in rows) {
      if (c.name.isNotEmpty) map[c.name] = c.key;
    }
    return map;
  }

  Future<ImportReport> _insertFullBackup(ImportResult r) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final warnings = <String>[];
    // 事务内收集 id，提交后再统一入队（见方法末尾注释）。
    final backupGroupId = r.group['id'] as String;
    final memberIds = <String>[];
    final expenseIds = <String>[];
    final settlementIds = <String>[];
    final backupTripIds = <String>[];
    final backupTripItemIds = <String>[];
    final backupCategoryKeys = <String>[];
    // V2.8.1：.tav 恢复路径的子预算行 id（事务内收集，提交后统一入队）。
    final backupSubBudgetIds = <String>[];
    final report = await db.transaction<ImportReport>(() async {
      await db.into(db.groups).insert(GroupsCompanion(
        id: Value(r.group['id'] as String),
        name: Value(_nonEmpty(r.group['name'] as String?, '导入的团')),
        icon: Value(_nonEmpty(r.group['icon'] as String?, '📁')),
        budgetEnabled:
            Value(r.group['budgetEnabled'] is bool ? r.group['budgetEnabled'] as bool : false),
        budgetCents:
            Value(r.group['budgetCents'] is int ? r.group['budgetCents'] as int? : null),
        kind: Value(_normalizeKind(r.group['kind'] as String? ?? 'travel')),
        createdAt: Value(r.group['createdAt'] is int ? r.group['createdAt'] as int : now),
        updatedAt: Value(now),
      ));
      for (final m in r.members) {
        memberIds.add(m['id'] as String);
        await db.into(db.members).insert(MembersCompanion(
          id: Value(m['id'] as String),
          groupId: Value(r.group['id'] as String),
          name: Value(_nonEmpty(m['name'] as String?, '(未命名)')),
          colorIndex: Value(m['colorIndex'] is int ? (m['colorIndex'] as int) % 8 : 0),
          createdAt: Value(m['createdAt'] is int ? m['createdAt'] as int : now),
        ));
      }
      for (final e in r.expenses) {
        expenseIds.add(e['id'] as String);
        await db.into(db.expenses).insert(ExpensesCompanion(
          id: Value(e['id'] as String),
          groupId: Value(r.group['id'] as String),
          dateEpochDay: Value(_epochDayOfMap(e)),
          title: Value(_nonEmpty(e['title'] as String?, '未命名账单')),
          categoryKey: Value(_nonEmpty(e['categoryKey'] as String?, 'other')),
          type: Value(kExpenseTypeNames.contains(e['type']) ? e['type'] as String : 'normal'),
          amountCents: Value(e['amountCents'] is int ? e['amountCents'] as int : 0),
          currency: Value(_nonEmpty(e['currency'] as String?, 'CNY')),
          rate: Value(e['rate'] is num ? (e['rate'] as num).toDouble() : 1.0),
          amountForeignCents:
              Value(e['amountForeignCents'] is int ? e['amountForeignCents'] as int? : null),
          payersJson: Value(jsonEncode(e['payers'] is List ? e['payers'] : [])),
          sharesJson: Value(jsonEncode(e['shares'] is List ? e['shares'] : [])),
          shareMode:
              Value(kShareModeNames.contains(e['shareMode']) ? e['shareMode'] as String : 'equal'),
          portionsJson: Value(e['portions'] is List ? jsonEncode(e['portions']) : null),
          note: Value((e['note'] as String? ?? '')),
          settledRoundId: Value(e['settledRoundId'] is String ? e['settledRoundId'] as String? : null),
          tripId: Value(e['tripId'] is String ? e['tripId'] as String? : null),
          tripItemId: Value(e['tripItemId'] is String ? e['tripItemId'] as String? : null),
          fundId: Value(e['fundId'] is String ? e['fundId'] as String? : null),
          payMethod: Value(e['payMethod'] is String ? e['payMethod'] as String? : null),
          createdAt: Value(e['createdAt'] is int ? e['createdAt'] as int : now),
        ));
      }
      for (final s in r.settlements) {
        settlementIds.add(s['id'] as String);
        await db.into(db.settlements).insert(SettlementsCompanion(
          id: Value(s['id'] as String),
          groupId: Value(r.group['id'] as String),
          status: Value(_nonEmpty(s['status'] as String?, 'active')),
          transfersJson:
              Value(jsonEncode(s['transfers'] is List ? s['transfers'] : [])),
          expenseIdsJson:
              Value(jsonEncode(s['expenseIds'] is List ? s['expenseIds'] : [])),
          roundNo: Value(s['roundNo'] is int ? s['roundNo'] as int : 1),
          createdAt: Value(s['createdAt'] is int ? s['createdAt'] as int : now),
          completedAt: Value(s['completedAt'] is int ? s['completedAt'] as int? : null),
        ));
      }
      var tripCount = 0, itemCount = 0;
      for (final t in r.trips) {
        backupTripIds.add(t['id'] as String);
        await db.into(db.trips).insert(TripsCompanion(
          id: Value(t['id'] as String),
          name: Value(_nonEmpty(t['name'] as String?, '导入的行程')),
          destination: Value((t['destination'] as String? ?? '')),
          emoji: Value(_nonEmpty(t['emoji'] as String?, '✈️')),
          cover: Value(_nonEmpty(t['cover'] as String?, 'ocean')),
          startEpochDay: Value(t['startEpochDay'] is int ? t['startEpochDay'] as int : 0),
          endEpochDay: Value(t['endEpochDay'] is int ? t['endEpochDay'] as int : 0),
          note: Value((t['note'] as String? ?? '')),
          groupId: Value(r.group['id'] as String),
          archived: Value(t['archived'] is bool ? t['archived'] as bool : false),
          createdAt: Value(t['createdAt'] is int ? t['createdAt'] as int : now),
          updatedAt: Value(now),
        ));
        tripCount++;
        for (final it in _asMapList(t['items'])) {
          if (it['id'] is String) backupTripItemIds.add(it['id'] as String);
          await db.into(db.tripItems).insert(_tripItemCompanion(it, now, t['id'] as String));
          itemCount++;
        }
      }
      for (final c in r.customCategories) {
        if (c['key'] is String) backupCategoryKeys.add(c['key'] as String);
        await db.into(db.categories).insert(
          CategoriesCompanion(
            key: Value(c['key'] as String),
            name: Value((c['name'] as String? ?? '')),
            icon: Value(_nonEmpty(c['icon'] as String?, '📦')),
            builtin: Value(c['builtin'] is bool ? c['builtin'] as bool : false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      // V2.8.1：分类子预算落库（applyImport 已换发新 id + 归新团）。
      for (final b in r.subBudgets) {
        final bid = b['id'] as String?;
        if (bid == null) continue;
        backupSubBudgetIds.add(bid);
        await db.into(db.subBudgets).insert(SubBudgetsCompanion(
          id: Value(bid),
          groupId: Value(r.group['id'] as String),
          categoryKey: Value(b['categoryKey'] as String? ?? ''),
          amount: Value(b['amount'] is int ? b['amount'] as int : 0),
          createdAt: Value(b['createdAt'] is int ? b['createdAt'] as int : now),
          updatedAt: Value(b['updatedAt'] is int ? b['updatedAt'] as int : now),
        ));
      }
      return ImportReport(
        groups: 1,
        members: r.members.length,
        expenses: r.expenses.length,
        settlements: r.settlements.length,
        trips: tripCount,
        tripItems: itemCount,
        reusedCategories: r.stats.reusedCategories,
        warnings: warnings,
      );
    });
    // 提交后入队：备份恢复是本地写入，必须同步到云端。
    // ⚠️ 必须在事务提交之后：hook 会触发 debounce→drain，若在事务内触发，
    // assemble 读不到未提交的行会走 delete 分支，可能把云端已有行软删。
    SyncOutboxService.notifyWrite("groups", backupGroupId);
    _notifyUpsert("members", memberIds);
    _notifyUpsert("expenses", expenseIds);
    _notifyUpsert("settlements", settlementIds);
    _notifyUpsert("trips", backupTripIds);
    _notifyUpsert("trip_items", backupTripItemIds);
    _notifyUpsert("categories", backupCategoryKeys);
    _notifyUpsert("sub_budgets", backupSubBudgetIds); // V2.8.1
    return report;
  }

  Map<String, dynamic> _groupExpenseMap(Expense e) => <String, dynamic>{
        'id': e.id,
        'title': e.title,
        'amountCents': e.amountCents,
        'dateEpochDay': e.dateEpochDay,
        'type': e.type,
        'currency': e.currency,
        'rate': e.rate,
        'amountForeignCents': e.amountForeignCents,
        'payers': _safeJsonList(e.payersJson),
        'shares': _safeJsonList(e.sharesJson),
        'portions': _safeJson(e.portionsJson),
        'note': e.note,
        'categoryKey': e.categoryKey,
        'settledRoundId': e.settledRoundId,
        'tripId': e.tripId,
        'tripItemId': e.tripItemId,
        // V2.7.1：公款池与支付方式标签随备份/快照带出（金额口径不变）。
        'fundId': e.fundId,
        'payMethod': e.payMethod,
        'createdAt': e.createdAt,
      };

  Map<String, dynamic> _groupSettlementMap(dynamic s) => <String, dynamic>{
        'id': s.id,
        'status': s.status,
        'roundNo': s.roundNo,
        'createdAt': s.createdAt,
        'completedAt': s.completedAt,
        'transfers': _safeJson(s.transfersJson),
        'expenseIds': _safeJson(s.expenseIdsJson),
      };

  /// 稳定解析：单条脏数据绝不让整包快照导出失败（否则对方永远拉取不到账本）。
  Object? _safeJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  List<dynamic> _safeJsonList(String? raw) {
    final v = _safeJson(raw);
    return v is List ? v : <dynamic>[];
  }

  TripItemsCompanion _tripItemCompanion(Map<String, dynamic> it, int now, String tripId) {
    return TripItemsCompanion(
      id: Value(it['id'] as String),
      tripId: Value(tripId),
      dateEpochDay: Value(it['dateEpochDay'] is int ? it['dateEpochDay'] as int : 0),
      type: Value(_nonEmpty(it['type'] as String?, 'attraction')),
      name: Value(_nonEmpty(it['name'] as String?, '安排')),
      address: Value((it['address'] as String? ?? '')),
      lat: Value(it['lat'] is num ? (it['lat'] as num).toDouble() : null),
      lng: Value(it['lng'] is num ? (it['lng'] as num).toDouble() : null),
      photoUri: Value(it['photoUri'] as String?),
      startTimeMin: Value(it['startTimeMin'] is int ? it['startTimeMin'] as int? : null),
      durationMin: Value(it['durationMin'] is int ? it['durationMin'] as int? : null),
      costCents: Value(it['costCents'] is int ? it['costCents'] as int? : null),
      costCurrency: Value(_nonEmpty(it['costCurrency'] as String?, 'CNY')),
      note: Value((it['note'] as String? ?? '')),
      fromName: Value((it['fromName'] as String? ?? '')),
      fromAddress: Value((it['fromAddress'] as String? ?? '')),
      fromLat: Value(it['fromLat'] is num ? (it['fromLat'] as num).toDouble() : null),
      fromLng: Value(it['fromLng'] is num ? (it['fromLng'] as num).toDouble() : null),
      toName: Value((it['toName'] as String? ?? '')),
      toAddress: Value((it['toAddress'] as String? ?? '')),
      toLat: Value(it['toLat'] is num ? (it['toLat'] as num).toDouble() : null),
      toLng: Value(it['toLng'] is num ? (it['toLng'] as num).toDouble() : null),
      flightNo: Value(it['flightNo'] as String?),
      sortOrder: Value(it['sortOrder'] is int ? it['sortOrder'] as int : 0),
      createdAt: Value(it['createdAt'] is int ? it['createdAt'] as int : now),
      updatedAt: Value(now),
    );
  }

  /// 想去池行 companion（备份/快照合并共用；updatedAt 恒为 now，LWW 基准）。
  WishlistItemsCompanion _wishlistItemCompanion(Map<String, dynamic> w, int now, String tripId) {
    return WishlistItemsCompanion(
      id: Value(w['id'] as String),
      tripId: Value(tripId),
      cityKey: Value(w['cityKey'] as String? ?? ''),
      name: Value(_nonEmpty(w['name'] as String?, '想去的地方')),
      address: Value(w['address'] as String? ?? ''),
      type: Value(_nonEmpty(w['type'] as String?, 'attraction')),
      durationMin: Value(w['durationMin'] is int ? w['durationMin'] as int? : null),
      tag: Value(w['tag'] as String?),
      guideRef: Value(w['guideRef'] as String?),
      note: Value(w['note'] as String? ?? ''),
      sortOrder: Value(w['sortOrder'] is int ? w['sortOrder'] as int : 0),
      createdAt: Value(w['createdAt'] is int ? w['createdAt'] as int : now),
      updatedAt: Value(now),
    );
  }

  static const kExpenseTypeNames = {'normal','refund','prepay'};
  static const kShareModeNames = {'equal','portions','percent','custom'};

  // === 辅助 ===
  /// 净额计算（与 domain/settle_engine 同口径）：已付 − 应摊。
  /// 退款行（type=='refund'）在存储层可能是正数，这里按「退款为负」约定
  /// 翻转符号，否则退款会被当成一笔新增支出/收入，结算方案方向完全反掉 —— 钱算错。
  Map<String, int> _computeBalances(List<Expense> expenses) {
    final balances = <String, int>{};
    for (final e in expenses) {
      if (e.settledRoundId != null) continue;
      final sign = e.type == 'refund' ? -1 : 1;
      _addShareJson(balances, e.payersJson, sign);
      _addShareJson(balances, e.sharesJson, -sign);
    }
    return balances;
  }

  void _addShareJson(Map<String, int> balances, String json, int sign) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        final memberId = item['memberId'];
        if (memberId is! String || memberId.isEmpty) continue;
        final cents = _asIntOrNull(item['cents']) ?? 0;
        if (cents == 0) continue;
        balances[memberId] = (balances[memberId] ?? 0) + sign * cents;
      }
    } catch (_) {
      // 单条账单格式异常不应影响同团其他账单的结算。
    }
  }
  // 最少转账方案已统一收敛到 domain/settle_strategy.dart 的 buildPlan
  // （S9：两策略共用同一入口，minTransfers 逐位不变）。此前的库内重复实现已删除。
  /// V2.8.1 S6：批量删除（单事务 + 逐行墓碑 + 审计）。返回实际删除行数。
  Future<int> deleteExpensesBatch(List<String> ids) async {
    var n = 0;
    await db.transaction(() async {
      for (final id in ids) {
        final row = await (db.select(db.expenses)..where((x) => x.id.equals(id))).getSingleOrNull();
        if (row == null) continue;
        await (db.delete(db.expenses)..where((x) => x.id.equals(id))).go();
        SyncOutboxService.notifyWrite("expenses", id, op: "delete");
        await _audit(row.groupId, AuditEntity.expense, id, AuditAction.delete,
            fields: {'title': row.title, 'amountCents': row.amountCents, 'from': 'batch'});
        n++;
      }
    });
    return n;
  }

  /// V2.8.1 S6：批量改分类（单事务 + 逐行 notifyWrite）。返回实际更新行数。
  Future<int> updateExpensesCategoryBatch(List<String> ids, String categoryKey) async {
    var n = 0;
    await db.transaction(() async {
      for (final id in ids) {
        await (db.update(db.expenses)..where((x) => x.id.equals(id)))
            .write(ExpensesCompanion(categoryKey: Value(categoryKey)));
        SyncOutboxService.notifyWrite("expenses", id);
        n++;
      }
    });
    return n;
  }
}

/// —— 导入解析辅助（库内私有） ——

/// S2 G1：结构化判定 JSON 数组（payers/shares）是否含指定 memberId。
///
/// 不再用 `LIKE '%id%'`（子串对抗会误报）；解析失败按「存在引用」保守拦截。
bool _jsonReferencesMember(String json, String mid) {
  final s = json.trim();
  if (s.isEmpty || s == '[]') return false;
  try {
    final decoded = jsonDecode(s);
    if (decoded is! List) return true; // 非数组形态：保守视为存在引用
    for (final it in decoded) {
      if (it is Map && it['memberId'] == mid) return true;
    }
    return false;
  } catch (_) {
    return true; // JSON 损坏：宁可拦不可漏
  }
}

/// 宽松取整：num 直接转，纯数字字符串尝试解析，其余 null
int? _asIntOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

/// 结算转账记录的宽松解码器：兼容标准数组、单个对象、嵌套 JSON 字符串。
List<Map<String, dynamic>> _decodeTransferMaps(String json) {
  final output = <Map<String, dynamic>>[];

  void append(Object? value) {
    if (value is String) {
      try {
        append(jsonDecode(value));
      } catch (_) {}
      return;
    }
    if (value is List) {
      for (final item in value) append(item);
      return;
    }
    if (value is Map) {
      output.add(value.cast<String, dynamic>());
    }
  }

  try {
    append(jsonDecode(json));
  } catch (_) {}
  return output;
}

String _transferFrom(Map<String, dynamic> item) =>
    (item['from'] ?? item['fromMemberId'])?.toString() ?? '';

String _transferTo(Map<String, dynamic> item) =>
    (item['to'] ?? item['toMemberId'])?.toString() ?? '';

int _transferCents(Map<String, dynamic> item) => _asIntOrNull(item['cents']) ?? 0;

bool _transferDone(Map<String, dynamic> item) {
  final value = item['done'];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return false;
}

/// 空串/ null 时回退到兜底值
String _nonEmpty(String? v, String fallback) {
  final t = (v ?? '').trim();
  return t.isEmpty ? fallback : t;
}

/// 任意 List 安全转成 Map 列表（过滤非 Map 元素）
List<Map<String, dynamic>> _asMapList(Object? v) => [
      for (final e in (v as List<dynamic>? ?? <dynamic>[]))
        if (e is Map) (e as Map).cast<String, dynamic>(),
    ];

/// 取账单的日期（兼容 date / dateEpochDay 两种键）
int _epochDayOfMap(Map<String, dynamic> e) {
  final d = e['dateEpochDay'] ?? e['date'];
  return d is int ? d : 0;
}

/// 账单日期：优先 dateEpochDay(int)，兼容 date 键（int epochDay 或可解析的 ISO 字符串），兜底今天
int _epochDayOf(Map<String,dynamic> e) {
  final v = e['dateEpochDay'] ?? e['date'];
  if (v is num) return v.toInt();
  if (v is String) {
    final n = int.tryParse(v);
    if (n != null) return n;
    final d = DateTime.tryParse(v);
    if (d != null) return dateToEpochDay(d);
  }
  return todayEpochDay();
}

/// payers/shares 列表重映射：接受 JSON 字符串或已解码数组；
/// memberId 无法映射的条目剔除并计数
List<Map<String,Object>> _remapShareList(Object? raw, Map<String,String> memberMap, void Function() onDrop) {
  List items;
  if (raw == null) return const [];
  try {
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == '[]') return const [];
      final dec = jsonDecode(s);
      if (dec is! List) return const [];
      items = dec;
    } else if (raw is List) {
      items = raw;
    } else {
      return const [];
    }
  } catch (_) {
    return const [];
  }
  final out = <Map<String,Object>>[];
  for (final it in items) {
    if (it is! Map) continue;
    final mid = it['memberId'];
    final mapped = mid is String ? memberMap[mid] : null;
    if (mapped == null) { onDrop(); continue; }
    out.add({'memberId': mapped, 'cents': _asIntOrNull(it['cents']) ?? 0});
  }
  return out;
}

/// portions 份数表重映射：接受 JSON 字符串或已解码 Map；
/// key 无法映射的条目剔除并计数；空表返回 null
String? _remapPortionsMap(Object? raw, Map<String,String> memberMap, void Function() onDrop) {
  Map m;
  if (raw == null) return null;
  try {
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == '{}') return null;
      final dec = jsonDecode(s);
      if (dec is! Map) return null;
      m = dec;
    } else if (raw is Map) {
      m = raw;
    } else {
      return null;
    }
  } catch (_) {
    return null;
  }
  final out = <String,int>{};
  m.forEach((k, v) {
    final nk = k is String ? memberMap[k] : null;
    if (nk == null) { onDrop(); return; }
    out[nk] = _asIntOrNull(v) ?? 0;
  });
  return out.isEmpty ? null : jsonEncode(out);
}

