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
import "../../domain/share_splitter.dart";
import "../../domain/group_backup.dart";
import "../../export/backup_format.dart";
import "prefs_repo.dart";

class LedgerRepository {
  LedgerRepository(this.db, this.prefs);
  final AppDatabase db;
  final PrefsRepository prefs;

  /// 激活团 id 内存缓存；仓库为 Provider 级单例，与 UI 生命周期一致，
  /// broadcast 控制器随仓库常驻（不随页面 dispose）。
  String? _activeGroupId;
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
  Future<Group> addGroup(String name, String icon) async { final id=newId("group"); final now=DateTime.now().millisecondsSinceEpoch; await db.into(db.groups).insert(GroupsCompanion(id:Value(id),name:Value(name),icon:Value(icon),createdAt:Value(now),updatedAt:Value(now))); return (await getGroup(id))!; }
  Future<void> updateGroup(String id, String name, String icon) async { await (db.update(db.groups)..where((g)=>g.id.equals(id))).write(GroupsCompanion(name:Value(name),icon:Value(icon),updatedAt:Value(DateTime.now().millisecondsSinceEpoch))); }
  /// 删团级联：事务内依次清理 账单→结算→成员→团，并把关联行程的 groupId 置 null。
  ///
  /// 若删除的正是当前激活团：自动切换到剩余团中 createdAt 最新的一个（走 setActiveGroup
  /// 三件套：内存缓存 + prefs + 广播），无剩余团则置 null。SQLite 未开启外键
  /// （NativeDatabase 不自动 PRAGMA foreign_keys，且存量库可能有脏数据不宜全局打开），
  /// 悬空 activeGroupId 会静默产出引用已消失团的「幽灵」成员/账单行——不可见且导出遗漏，
  /// 故必须在删除时点完成指针交接（逻辑层修复）。
  Future<void> deleteGroup(String id) async {
    await db.transaction(() async {
      await (db.delete(db.expenses)..where((e)=>e.groupId.equals(id))).go();
      await (db.delete(db.settlements)..where((s)=>s.groupId.equals(id))).go();
      await (db.delete(db.members)..where((m)=>m.groupId.equals(id))).go();
      await (db.update(db.trips)..where((t)=>t.groupId.equals(id))).write(TripsCompanion(groupId:Value(null)));
      await (db.delete(db.groups)..where((g)=>g.id.equals(id))).go();
    });
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
  Future<void> setBudget(String gid, {bool enabled=false, int? budgetCents}) async { await (db.update(db.groups)..where((g)=>g.id.equals(gid))).write(GroupsCompanion(budgetEnabled:Value(enabled),budgetCents:Value(budgetCents),updatedAt:Value(DateTime.now().millisecondsSinceEpoch))); }

  // === 成员 ===
  Stream<List<Member>> watchMembers(String gid) => (db.select(db.members)..where((m)=>m.groupId.equals(gid))..orderBy([(m)=>OrderingTerm.asc(m.createdAt)])).watch();
  Future<List<Member>> getMembers(String gid) => (db.select(db.members)..where((m)=>m.groupId.equals(gid))).get();
  Future<String> addMember(String gid, String name) async { final id=newId("member"); final count=await (db.selectOnly(db.members)..where(db.members.groupId.equals(gid))..addColumns([db.members.id.count()])).getSingle(); final idx=(count.read(db.members.id.count())??0)%8; await db.into(db.members).insert(MembersCompanion(id:Value(id),groupId:Value(gid),name:Value(name),colorIndex:Value(idx),createdAt:Value(DateTime.now().millisecondsSinceEpoch))); return id; }
  Future<void> renameMember(String mid, String name) async { await (db.update(db.members)..where((m)=>m.id.equals(mid))).write(MembersCompanion(name:Value(name))); }
  Future<void> deleteMember(String mid) async { await (db.delete(db.members)..where((m)=>m.id.equals(mid))).go(); }
  Future<bool> isMemberReferenced(String mid) async { final exps=await (db.select(db.expenses)..where((e)=>e.payersJson.like("%$mid%")|e.sharesJson.like("%$mid%"))).get(); return exps.isNotEmpty; }

  // === 账单 ===
  Stream<List<Expense>> watchExpenses(String gid) => (db.select(db.expenses)..where((e)=>e.groupId.equals(gid))..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay),(e)=>OrderingTerm.desc(e.createdAt)])).watch();
  Stream<List<Expense>> watchOutstanding(String gid) => (db.select(db.expenses)..where((e)=>e.groupId.equals(gid)&e.settledRoundId.isNull())..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay)])).watch();
  Stream<List<Expense>> watchByTrip(String tid) => (db.select(db.expenses)..where((e)=>e.tripId.equals(tid))..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay)])).watch();
  /// 按安排 id 盯关联账单流（安排卡入账徽章用）；createdAt 降序，首条即最新
  Stream<List<Expense>> watchByTripItem(String itemId) => (db.select(db.expenses)..where((e)=>e.tripItemId.equals(itemId))..orderBy([(e)=>OrderingTerm.desc(e.createdAt)])).watch();
  /// 安排关联账单一次性查询（仲裁/同步用）：按 createdAt 降序，首条即最新关联账单
  Future<List<Expense>> getLinkedBills(String itemId) => (db.select(db.expenses)..where((e)=>e.tripItemId.equals(itemId))..orderBy([(e)=>OrderingTerm.desc(e.createdAt)])).get();
  Future<void> addExpense(ExpensesCompanion e) => db.into(db.expenses).insert(e);

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

  Future<void> updateExpense(String id, ExpensesCompanion e) => (db.update(db.expenses)..where((x)=>x.id.equals(id))).write(e);
  Future<void> deleteExpense(String id) async { await (db.delete(db.expenses)..where((e)=>e.id.equals(id))).go(); }
  Future<void> setExpenseSettled(String eid, bool settled) async { if(settled) { await (db.update(db.expenses)..where((e)=>e.id.equals(eid))).write(ExpensesCompanion(settledRoundId:Value("manual"))); } else { await (db.update(db.expenses)..where((e)=>e.id.equals(eid))).write(ExpensesCompanion(settledRoundId:Value(null))); } }

  // === 结算 ===
  Stream<List<Settlement>> watchSettlements(String gid) {
    return (db.select(db.settlements)
          ..where((s) => s.groupId.equals(gid))
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .watch()
        .map((list) => list.map((s) {
      // 解析 transfersJson：每条 {from, to, cents, done}。
      // 历史脏数据 / 单元素 JSON 字符串拼接的老格式都做兜底，避免 UI 永远 0 笔。
      final transfers = <TransferRecord>[];
      try {
        final raw = jsonDecode(s.transfersJson);
        if (raw is List) {
          for (final it in raw) {
            if (it is! Map) continue;
            final from = (it['from'] as String?) ?? '';
            final to = (it['to'] as String?) ?? '';
            final cents = (it['cents'] as num?)?.toInt() ?? 0;
            final done = (it['done'] as bool?) ?? false;
            if (from.isNotEmpty && to.isNotEmpty && cents > 0) {
              transfers.add(TransferRecord(from: from, to: to, cents: cents, done: done));
            }
          }
        }
      } catch (_) {
        // 历史脏数据：保持空 list，让 UI 给出"开始新轮"提示
      }
      return Settlement(
        id: s.id,
        groupId: s.groupId,
        status: s.status == 'active' ? SettlementStatus.active : SettlementStatus.completed,
        transfers: transfers,
        roundNo: s.roundNo,
        createdAt: s.createdAt,
        completedAt: s.completedAt,
      );
    }).toList());
  }

  /// 新建一轮结算：
  /// * 先清掉同团已有的 active 轮（脏数据/历史残留统一清理，避免多条 active 共存）；
  ///   旧 active 直接删除（未完成等于作废，配合用户重新点「开始这一轮」的强意图）。
  /// * roundNo 取已有最大 + 1，保证第 2 轮、第 3 轮自增正确。
  /// * 全部账单净额已平衡时（无人欠款）不创建空轮，返回 null；UI 据此给"无需结算"提示。
  /// * transfersJson 走 jsonEncode 而非字符串拼接，杜绝单元素/零元素边界损坏。
  Future<Settlement?> createSettlement(String gid) async {
    final existing = await (db.select(db.settlements)
          ..where((s) => s.groupId.equals(gid) & s.status.equals('active')))
        .get();
    for (final old in existing) {
      await (db.delete(db.settlements)..where((x) => x.id.equals(old.id))).go();
    }

    final outstanding = await (db.select(db.expenses)
          ..where((e) => e.groupId.equals(gid) & e.settledRoundId.isNull()))
        .get();
    final balances = _computeBalances(outstanding);
    final plan = _minTransferPlan(balances);
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
          "from": t["from"],
          "to": t["to"],
          "cents": t["cents"],
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
      createdAt: Value(now),
    ));
    final created = Settlement(
      id: id,
      groupId: gid,
      status: SettlementStatus.active,
      transfers: [
        for (final t in plan)
          TransferRecord(
            from: t["from"] as String,
            to: t["to"] as String,
            cents: t["cents"] as int,
            done: false,
          )
      ],
      roundNo: nextRoundNo,
      createdAt: now,
      completedAt: null,
    );
    return created;
  }
  Future<void> markTransferDone(String sid, int index, bool done) async { final s=await (db.select(db.settlements)..where((x)=>x.id.equals(sid))).getSingleOrNull(); if(s==null) return; final list=jsonDecode(s.transfersJson) as List; if(index<0||index>=list.length) return; list[index]["done"]=done; await (db.update(db.settlements)..where((x)=>x.id.equals(sid))).write(SettlementsCompanion(transfersJson:Value(jsonEncode(list)))); }
  Future<void> completeSettlement(String sid) async { final s=await (db.select(db.settlements)..where((x)=>x.id.equals(sid))).getSingleOrNull(); if(s==null) return; final eids=jsonDecode(s.expenseIdsJson) as List; for(final e in eids) { await (db.update(db.expenses)..where((x)=>x.id.equals(e))).write(ExpensesCompanion(settledRoundId:Value(sid))); } await (db.update(db.settlements)..where((x)=>x.id.equals(sid))).write(SettlementsCompanion(status:Value("completed"),completedAt:Value(DateTime.now().millisecondsSinceEpoch))); }
  Future<void> undoLastSettlement(String gid) async { final s=await (db.select(db.settlements)..where((x)=>x.groupId.equals(gid)&x.status.equals("completed"))..orderBy([(x)=>OrderingTerm.desc(x.createdAt)])).get(); if(s.isEmpty) return; final last=s.first; final eids=jsonDecode(last.expenseIdsJson) as List; for(final e in eids) { await (db.update(db.expenses)..where((x)=>x.id.equals(e))).write(ExpensesCompanion(settledRoundId:Value(null))); } await (db.delete(db.settlements)..where((x)=>x.id.equals(last.id))).go(); }

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
      "group":{"id":gid,"name":g?.name??"","icon":g?.icon??"📁"},
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
      createdAt: Value(now), updatedAt: Value(now),
    ));

    // ② 成员：旧→新 id 映射，保留 colorIndex；③ 账单：同一事务内落库
    final memberMap = <String,String>{};
    return db.transaction<ImportReport>(() async {
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
        await db.into(db.expenses).insert(ExpensesCompanion(
          id: Value(newId("expense")),
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
        expenseCount++;
      }
      if (droppedShares > 0) warnings.add('$droppedShares 条分摊记录因成员缺失被丢弃');
      if (droppedPortions > 0) warnings.add('$droppedPortions 条份数记录因成员缺失被丢弃');
      if (badExpenses > 0) warnings.add('$badExpenses 条无效账单已跳过');
      return ImportReport(groups:1, members:memberCount, expenses:expenseCount, warnings:warnings);
    });
  }

  // === 专有格式备份（.tav） ===
  /// 导出完整团备份（团+成员+账单+结算轮+行程及安排+自定义分类）为二进制 .tav。
  Future<Uint8List> exportGroupBackupBytes(String gid) async {
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
    final tripsWithItems = <Map<String, dynamic>>[];
    for (final t in trips) {
      final items = await (db.select(db.tripItems)
            ..where((i) => i.tripId.equals(t.id)))
          .get();
      tripsWithItems.add(<String, dynamic>{
        ...t.toJson(),
        'items': [for (final it in items) it.toJson()],
      });
    }
    final backup = buildGroupBackup(
      group: g?.toJson() ?? <String, dynamic>{'id': gid, 'name': '', 'icon': '📁'},
      members: [for (final m in members) m.toJson()],
      expenses: [for (final e in expenses) _groupExpenseMap(e)],
      settlements: [for (final s in settlements) _groupSettlementMap(s)],
      trips: tripsWithItems,
      customCategories: [for (final c in categories) c.toJson()],
    );
    return encodeBackup(kGroupBackupMagic, backup);
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
    return _insertFullBackup(result);
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
    return db.transaction<ImportReport>(() async {
      await db.into(db.groups).insert(GroupsCompanion(
        id: Value(r.group['id'] as String),
        name: Value(_nonEmpty(r.group['name'] as String?, '导入的团')),
        icon: Value(_nonEmpty(r.group['icon'] as String?, '📁')),
        budgetEnabled:
            Value(r.group['budgetEnabled'] is bool ? r.group['budgetEnabled'] as bool : false),
        budgetCents:
            Value(r.group['budgetCents'] is int ? r.group['budgetCents'] as int? : null),
        createdAt: Value(r.group['createdAt'] is int ? r.group['createdAt'] as int : now),
        updatedAt: Value(now),
      ));
      for (final m in r.members) {
        await db.into(db.members).insert(MembersCompanion(
          id: Value(m['id'] as String),
          groupId: Value(r.group['id'] as String),
          name: Value(_nonEmpty(m['name'] as String?, '(未命名)')),
          colorIndex: Value(m['colorIndex'] is int ? (m['colorIndex'] as int) % 8 : 0),
          createdAt: Value(m['createdAt'] is int ? m['createdAt'] as int : now),
        ));
      }
      for (final e in r.expenses) {
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
          createdAt: Value(e['createdAt'] is int ? e['createdAt'] as int : now),
        ));
      }
      for (final s in r.settlements) {
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
          await db.into(db.tripItems).insert(_tripItemCompanion(it, now, t['id'] as String));
          itemCount++;
        }
      }
      for (final c in r.customCategories) {
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
        'payers': jsonDecode(e.payersJson),
        'shares': jsonDecode(e.sharesJson),
        'portions': e.portionsJson == null ? <dynamic>[] : jsonDecode(e.portionsJson!),
        'note': e.note,
        'categoryKey': e.categoryKey,
        'settledRoundId': e.settledRoundId,
        'tripId': e.tripId,
        'tripItemId': e.tripItemId,
      };

  Map<String, dynamic> _groupSettlementMap(dynamic s) => <String, dynamic>{
        'id': s.id,
        'status': s.status,
        'roundNo': s.roundNo,
        'createdAt': s.createdAt,
        'completedAt': s.completedAt,
        'transfers': jsonDecode(s.transfersJson),
        'expenseIds': jsonDecode(s.expenseIdsJson),
      };

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

  static const kExpenseTypeNames = {'normal','refund','prepay'};
  static const kShareModeNames = {'equal','portions','custom'};

  // === 辅助 ===
  Map<String,int> _computeBalances(List<Expense> expenses) { final b=<String,int>{}; for(final e in expenses) { if(e.settledRoundId!=null) continue; if(e.type=="prepay") continue; try { final payers=jsonDecode(e.payersJson) as List; for(final p in payers) { final mid=p["memberId"]??""; final cents=(p["cents"]??0) as int; b[mid]=(b[mid]??0)+cents; } final shares=jsonDecode(e.sharesJson) as List; for(final s in shares) { final mid=s["memberId"]??""; final cents=(s["cents"]??0) as int; b[mid]=(b[mid]??0)-cents; } } catch(_){} } return b; }
  List<Map<String,dynamic>> _minTransferPlan(Map<String,int> balances) {
    final owes = [for(final e in balances.entries.where((e)=>e.value<0)) {"id":e.key,"amt":-e.value}];
    final gets = [for(final e in balances.entries.where((e)=>e.value>0)) {"id":e.key,"amt":e.value}];
    owes.sort((a,b) => (b["amt"] as int).compareTo(a["amt"] as int));
    gets.sort((a,b) => (b["amt"] as int).compareTo(a["amt"] as int));
    final plan = <Map<String,dynamic>>[];
    var i = 0, j = 0;
    while (i < owes.length && j < gets.length) {
      final d = owes[i]["amt"] as int, c = gets[j]["amt"] as int;
      final m = d < c ? d : c;
      if (m > 0) plan.add({"from": owes[i]["id"], "to": gets[j]["id"], "cents": m});
      owes[i]["amt"] = d - m;
      gets[j]["amt"] = c - m;
      if (owes[i]["amt"] == 0) i++;
      if (gets[j]["amt"] == 0) j++;
    }
    return plan;
  }}

/// —— 导入解析辅助（库内私有） ——

/// 宽松取整：num 直接转，纯数字字符串尝试解析，其余 null
int? _asIntOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

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
