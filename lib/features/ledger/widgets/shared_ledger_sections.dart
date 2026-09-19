/// 共享账本四能力（账单 / 成员 / 统计 / 结算）可复用 widget（V2.6.6 §6.0，代号 S4）。
///
/// 从 `screens/shared_ledger_screen.dart` 原样抽出，**零行为变化**：
/// * 数据路径 / RPC 名称（`expenses_sync` / `members_sync` / `settlements_sync`）、
///   云端列名、写入语义（owner_user_id 保持团 owner、失败 toast 不落本地）；
/// * 权限三态：owner 可见管理操作、member 隐藏；`canWrite == false` 为 viewer
///   只读态 —— 直接隐藏全部写入口（不置灰）；
/// * 文案零改动（含 `share.addBill` / `share.ownerOnlyTap` 等 copy token）。
///
/// 四能力只通过 [LedgerSectionData] 取数：镜像端走 [MirrorLedgerSectionData]
/// （shared_* 镜像表），owner 本地团走 [LocalLedgerSectionData]（本地业务表）。
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient; // 离线写通道为空；仅用于镜像数据源持有的 client 类型

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../core/uid.dart';
// drift 生成类 Settlement 与 domain/models.dart 的 Settlement 同名：本文件只做
// 本地表行 → 中立 view-model 的映射，这里取 drift 行类（status 是 String），
// 因此隐藏域模型的同名类。
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/models.dart' hide Settlement;
import '../../../domain/settle_engine.dart';
import '../../../domain/share_splitter.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../../../shared/widgets/app_snack_bar.dart';

// ============ 数据源抽象 ============

/// 账本区数据源种类：
/// * mirror  —— 受邀端共享镜像表（shared_expenses / shared_members / shared_settlements）
/// * local   —— 本地业务表（expenses / members / settlements），owner 端本地团用
enum LedgerSectionSource { mirror, local }

/// 中立成员行（跨数据源统一）：镜像端 = SharedMember，本地端 = Member。
class LedgerMember {
  const LedgerMember({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.createdAt = 0,
  });

  final String id;
  final String name;

  /// 头像配色索引（本地端 Members.colorIndex；镜像端 SharedMembers.colorIndex）。
  final int colorIndex;
  final int createdAt;
}

/// 中立结算转账行（transfersJson 的元素）。
class LedgerTransfer {
  const LedgerTransfer({
    required this.from,
    required this.to,
    required this.cents,
  });

  final String from;
  final String to;
  final int cents;
}

/// 中立结算轮（跨数据源统一）：镜像端 = SharedSettlement，本地端 = Settlement。
class LedgerSettlement {
  const LedgerSettlement({
    required this.id,
    required this.groupId,
    required this.status,
    required this.transfersJson,
    required this.expenseIdsJson,
    required this.roundNo,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String groupId;
  final String status;

  /// 转账建议 JSON（与云端 settlements_sync.transfers_json 同构）。
  final String transfersJson;

  /// 本轮涉事账单 id JSON。
  final String expenseIdsJson;
  final int roundNo;
  final int createdAt;
  final int? completedAt;
}

/// 数据源抽象：四能力只依赖它取数，不直接摸 db 表。
///
/// 实现方按 [source] 决定镜像表或本地业务表；`watch*` 必须按各端既有排序
/// 返回（排序本身也是行为的一部分）。
abstract class LedgerSectionData {
  /// 当前团的 id（写通道的 groupId，镜像端即共享团 id）。
  String get groupId;

  /// 数据源种类。
  LedgerSectionSource get source;

  /// 账单流（镜像：dateEpochDay desc；本地：dateEpochDay desc, createdAt desc）。
  Stream<List<ExpenseRecord>> watchExpenses();

  /// 成员流（统一成中立成员行；本地实现自行映射）。
  Stream<List<LedgerMember>> watchMembers();

  /// 结算流（createdAt desc）。
  Stream<List<LedgerSettlement>> watchSettlements();

  /// 成员快照（非流式；结算/详情弹层按需取一次）。
  Future<List<LedgerMember>> members();

  /// 账单快照（非流式）。
  Future<List<ExpenseRecord>> expenses();

  /// 账单创建时间（毫秒）：[ExpenseRecord] 是域模型、不含 createdAt，
  /// 但镜像 upsert 的 `created_ms` 必须沿用原值（改值 = 改数据路径），
  /// 因此由数据源按 id 回查一次。
  Future<int> createdAtOf(String expenseId);

  // ---- 本地落库（云端 upsert 成功后的镜像刷新 / 本地源直写） ----
  // 实现方自行决定落到哪张表；未接写入的源（本轮的 Local 源）应抛
  // UnsupportedError 而不是静默丢弃，避免下游误判写入成功。

  /// 账单 upsert 到本地表（镜像表或本地业务表）。
  ///
  /// [createdAt] 单独传：域模型 [ExpenseRecord] 不带 createdAt，而镜像行的
  /// `created_at` 必须保持原值（改值即改数据路径）。
  Future<void> upsertExpenseMirror(
    ExpenseRecord record, {
    required int createdAt,
  });

  /// 账单从本地表移除。
  Future<void> removeExpenseMirror(String id);

  /// 成员 upsert 到本地表。
  Future<void> upsertMemberMirror(LedgerMember member);

  /// 成员从本地表移除。
  Future<void> removeMemberMirror(String id);

  /// 结算轮 upsert 到本地表。
  Future<void> upsertSettlementMirror(LedgerSettlement settlement);

  /// 把若干账单标记为已参与结算轮 [settlementId]。
  Future<void> markExpensesSettled(
    Iterable<String> expenseIds,
    String settlementId,
  );
}

// ---- 共享数据访问（JSON 解析 + 域模型映射；与 S4 前实现逐字一致） ----

List<ShareEntry> parseShareList(String json) {
  try {
    final list = (jsonDecode(json) as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map)
          ShareEntry(
            memberId: (e['memberId'] ?? '').toString(),
            cents: ((e['cents'] as num?) ?? 0).toInt(),
          ),
    ];
  } catch (_) {
    return const [];
  }
}

ExpenseType _expenseTypeOf(String raw) => ExpenseType.values.firstWhere(
  (t) => t.name == raw,
  orElse: () => ExpenseType.normal,
);

ShareMode _shareModeOf(String raw) => ShareMode.values.firstWhere(
  (m) => m.name == raw,
  orElse: () => ShareMode.equal,
);

/// portionsJson → {memberId: 值}（portions=份数 / percent=bp，语义由 shareMode 判别）。
Map<String, int>? parsePortionsMap(String? json) {
  if (json == null || json.isEmpty || json == '{}') return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return null;
    final out = <String, int>{};
    decoded.forEach((k, v) {
      if (k is String) out[k] = v is num ? v.toInt() : 0;
    });
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

/// 镜像行 → 域模型（原 `_sharedToRecord`）。
ExpenseRecord sharedExpenseToRecord(SharedExpense e) => ExpenseRecord(
  id: e.id,
  groupId: e.groupId,
  dateEpochDay: e.dateEpochDay,
  title: e.title,
  categoryKey: e.categoryKey,
  type: _expenseTypeOf(e.type),
  amountCents: e.amountCents,
  currency: e.currency,
  rate: e.rate,
  payers: parseShareList(e.payersJson),
  shares: parseShareList(e.sharesJson),
  shareMode: _shareModeOf(e.shareMode),
  portions: parsePortionsMap(e.portionsJson),
  note: e.note,
  settledRoundId: e.settledRoundId,
);

/// 本地行 → 域模型（字段与镜像表完全同构 + V2.7.1 本地专有列）。
ExpenseRecord localExpenseToRecord(Expense e) => ExpenseRecord(
  id: e.id,
  groupId: e.groupId,
  dateEpochDay: e.dateEpochDay,
  title: e.title,
  categoryKey: e.categoryKey,
  type: _expenseTypeOf(e.type),
  amountCents: e.amountCents,
  currency: e.currency,
  rate: e.rate,
  payers: parseShareList(e.payersJson),
  shares: parseShareList(e.sharesJson),
  shareMode: _shareModeOf(e.shareMode),
  portions: parsePortionsMap(e.portionsJson),
  note: e.note,
  settledRoundId: e.settledRoundId,
  fundId: e.fundId,
  payMethod: e.payMethod,
);

/// `转账建议 JSON` → 中立转账行（解析失败回退空表，与原实现同）。
List<LedgerTransfer> parseTransfers(String json) {
  try {
    final list = (jsonDecode(json) as List?) ?? const [];
    return [
      for (final t in list)
        if (t is Map)
          LedgerTransfer(
            from: (t['from'] ?? '').toString(),
            to: (t['to'] ?? '').toString(),
            cents: ((t['cents'] as num?) ?? 0).toInt(),
          ),
    ];
  } catch (_) {
    return const [];
  }
}

String fmtShortDay(int epochDay) {
  final d = epochDayToDate(epochDay);
  return '${d.month}/${d.day}';
}

/// 共享镜像数据源：受邀端 shared_* 四件套。
///
/// [cloudClient] / [syncEngine] 仅用于写通道（云端 upsert 与 owner_user_id），
/// 读路径完全不依赖它们；二者可为 null（离线 / 测试）。
class MirrorLedgerSectionData implements LedgerSectionData {
  MirrorLedgerSectionData({
    required this.db,
    required this.groupId,
    this.cloudClient,
    this.syncEngine,
  });

  final AppDatabase db;

  @override
  final String groupId;

  /// 云客户端（离线时 null；写通道用）。
  final SupabaseClient? cloudClient;

  /// 同步引擎（取团 owner_user_id；未启动时 null）。
  final SyncEngine? syncEngine;

  @override
  LedgerSectionSource get source => LedgerSectionSource.mirror;

  /// 本团在云端的 owner_user_id（成员/结算行写回时保持团 owner）。
  String? get ownerUserId => syncEngine?.sharedOwnerUserIdOf(groupId);

  @override
  Stream<List<ExpenseRecord>> watchExpenses() =>
      (db.select(db.sharedExpenses)
            ..where((e) => e.groupId.equals(groupId))
            ..orderBy([(e) => OrderingTerm.desc(e.dateEpochDay)]))
          .watch()
          .map((rows) => [for (final e in rows) sharedExpenseToRecord(e)]);

  @override
  Stream<List<LedgerMember>> watchMembers() =>
      (db.select(db.sharedMembers)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .watch()
          .map(_toMembers);

  @override
  Stream<List<LedgerSettlement>> watchSettlements() =>
      (db.select(db.sharedSettlements)
            ..where((s) => s.groupId.equals(groupId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch()
          .map(_toSettlements);

  @override
  Future<List<LedgerMember>> members() async => _toMembers(
    await (db.select(db.sharedMembers)
          ..where((m) => m.groupId.equals(groupId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get(),
  );

  @override
  Future<List<ExpenseRecord>> expenses() async => [
    for (final e
        in await (db.select(db.sharedExpenses)
              ..where((e) => e.groupId.equals(groupId))
              ..orderBy([(e) => OrderingTerm.desc(e.dateEpochDay)]))
            .get())
      sharedExpenseToRecord(e),
  ];

  @override
  Future<int> createdAtOf(String expenseId) async {
    final row = await (db.select(
      db.sharedExpenses,
    )..where((e) => e.id.equals(expenseId))).getSingleOrNull();
    return row?.createdAt ?? DateTime.now().millisecondsSinceEpoch;
  }

  static List<LedgerMember> _toMembers(List<SharedMember> rows) => [
    for (final m in rows)
      LedgerMember(
        id: m.id,
        name: m.name,
        colorIndex: m.colorIndex,
        createdAt: m.createdAt,
      ),
  ];

  static List<LedgerSettlement> _toSettlements(List<SharedSettlement> rows) => [
    for (final s in rows)
      LedgerSettlement(
        id: s.id,
        groupId: s.groupId,
        status: s.status,
        transfersJson: s.transfersJson,
        expenseIdsJson: s.expenseIdsJson,
        roundNo: s.roundNo,
        createdAt: s.createdAt,
        completedAt: s.completedAt,
      ),
  ];

  @override
  Future<void> upsertExpenseMirror(
    ExpenseRecord r, {
    required int createdAt,
  }) async {
    await db
        .into(db.sharedExpenses)
        .insertOnConflictUpdate(
          SharedExpensesCompanion.insert(
            id: r.id,
            groupId: groupId,
            dateEpochDay: Value(r.dateEpochDay),
            title: Value(r.title),
            categoryKey: Value(r.categoryKey),
            type: Value(r.type.name),
            amountCents: Value(r.amountCents),
            currency: Value(r.currency),
            rate: Value(r.rate),
            amountForeignCents: Value(r.amountForeignCents),
            payersJson: Value(_encodeShares(r.payers)),
            sharesJson: Value(_encodeShares(r.shares)),
            shareMode: Value(r.shareMode.name),
            portionsJson: Value(
              r.portions == null ? null : jsonEncode(r.portions),
            ),
            note: Value(r.note ?? ''),
            settledRoundId: Value(r.settledRoundId),
            tripId: Value(r.tripId),
            tripItemId: Value(r.tripItemId),
            createdAt: createdAt,
          ),
        );
  }

  @override
  Future<void> removeExpenseMirror(String id) async {
    await (db.delete(db.sharedExpenses)..where((x) => x.id.equals(id))).go();
  }

  @override
  Future<void> upsertMemberMirror(LedgerMember m) async {
    await db
        .into(db.sharedMembers)
        .insertOnConflictUpdate(
          SharedMembersCompanion.insert(
            id: m.id,
            groupId: groupId,
            name: m.name,
            colorIndex: Value(m.colorIndex),
            createdAt: m.createdAt,
          ),
        );
  }

  @override
  Future<void> removeMemberMirror(String id) async {
    await (db.delete(db.sharedMembers)..where((x) => x.id.equals(id))).go();
  }

  @override
  Future<void> upsertSettlementMirror(LedgerSettlement s) async {
    await db
        .into(db.sharedSettlements)
        .insertOnConflictUpdate(
          SharedSettlementsCompanion.insert(
            id: s.id,
            groupId: groupId,
            status: Value(s.status),
            transfersJson: Value(s.transfersJson),
            expenseIdsJson: Value(s.expenseIdsJson),
            roundNo: Value(s.roundNo),
            createdAt: s.createdAt,
            completedAt: Value(s.completedAt),
          ),
        );
  }

  @override
  Future<void> markExpensesSettled(
    Iterable<String> expenseIds,
    String settlementId,
  ) async {
    for (final id in expenseIds) {
      await (db.update(db.sharedExpenses)..where((x) => x.id.equals(id))).write(
        SharedExpensesCompanion(settledRoundId: Value(settlementId)),
      );
    }
  }
}

/// 本地业务表数据源：owner 端本地团（expenses / members / settlements）。
///
/// 读路径完整可用；写路径按 S4 范围未接入（本地写有既有 repo 通道：
/// LedgerRepository.addExpense/updateExpense/deleteExpense 等，下游接本地写时
/// 应显式指定写入通道，避免出现「静默假成功」）。
class LocalLedgerSectionData implements LedgerSectionData {
  LocalLedgerSectionData({required this.db, required this.groupId});

  final AppDatabase db;

  @override
  final String groupId;

  @override
  LedgerSectionSource get source => LedgerSectionSource.local;

  @override
  Stream<List<ExpenseRecord>> watchExpenses() =>
      (db.select(db.expenses)
            ..where((e) => e.groupId.equals(groupId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.dateEpochDay),
              (e) => OrderingTerm.desc(e.createdAt),
            ]))
          .watch()
          .map((rows) => [for (final e in rows) localExpenseToRecord(e)]);

  @override
  Stream<List<LedgerMember>> watchMembers() =>
      (db.select(db.members)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .watch()
          .map(_toMembers);

  @override
  Stream<List<LedgerSettlement>> watchSettlements() =>
      (db.select(db.settlements)
            ..where((s) => s.groupId.equals(groupId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch()
          .map(_toSettlements);

  @override
  Future<List<LedgerMember>> members() async => _toMembers(
    await (db.select(db.members)
          ..where((m) => m.groupId.equals(groupId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get(),
  );

  @override
  Future<List<ExpenseRecord>> expenses() async => [
    for (final e
        in await (db.select(db.expenses)
              ..where((e) => e.groupId.equals(groupId))
              ..orderBy([(e) => OrderingTerm.desc(e.dateEpochDay)]))
            .get())
      localExpenseToRecord(e),
  ];

  @override
  Future<int> createdAtOf(String expenseId) async {
    final row = await (db.select(
      db.expenses,
    )..where((e) => e.id.equals(expenseId))).getSingleOrNull();
    return row?.createdAt ?? DateTime.now().millisecondsSinceEpoch;
  }

  static List<LedgerMember> _toMembers(List<Member> rows) => [
    for (final m in rows)
      LedgerMember(
        id: m.id,
        name: m.name,
        colorIndex: m.colorIndex,
        createdAt: m.createdAt,
      ),
  ];

  static List<LedgerSettlement> _toSettlements(List<Settlement> rows) => [
    for (final s in rows)
      LedgerSettlement(
        id: s.id,
        groupId: s.groupId,
        status: s.status,
        transfersJson: s.transfersJson,
        expenseIdsJson: s.expenseIdsJson,
        roundNo: s.roundNo,
        createdAt: s.createdAt,
        completedAt: s.completedAt,
      ),
  ];

  Never _noLocalWrite() => throw UnsupportedError(
    'LocalLedgerSectionData 本轮未接入本地写入通道'
    '（本地写走 LedgerRepository，见 S4 交付说明）',
  );

  @override
  Future<void> upsertExpenseMirror(
    ExpenseRecord record, {
    required int createdAt,
  }) async => _noLocalWrite();

  @override
  Future<void> removeExpenseMirror(String id) async => _noLocalWrite();

  @override
  Future<void> upsertMemberMirror(LedgerMember member) async => _noLocalWrite();

  @override
  Future<void> removeMemberMirror(String id) async => _noLocalWrite();

  @override
  Future<void> upsertSettlementMirror(LedgerSettlement settlement) async =>
      _noLocalWrite();

  @override
  Future<void> markExpensesSettled(
    Iterable<String> expenseIds,
    String settlementId,
  ) async => _noLocalWrite();
}

String _encodeShares(List<ShareEntry> shares) => jsonEncode([
  for (final s in shares) {'memberId': s.memberId, 'cents': s.cents},
]);

// ============ 在线直写通道（原 screens/shared_ledger_screen.dart，一字未改） ============

/// 在线直写通道：云端 upsert（owner 保持团 owner）+ 成员快照。
///
/// S4 起随四能力一并搬到 widgets/，屏幕壳 [SharedGroupScreen] 不再直接写库。
mixin SharedDirectWrite<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String get groupId;

  AppDatabase get db => ref.read(dbProvider);

  /// 云端 upsert（owner 保持团 owner）；成功后可选刷新本地镜像。
  Future<bool> directUpsert(
    String table,
    Map<String, dynamic> row, {
    void Function()? onMirror,
  }) async {
    final client = ref.read(cloudClientProvider);
    if (client == null) return false;
    try {
      await client.from(table).upsert(row, onConflict: 'id');
      onMirror?.call();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _toast(String msg) {
    showAppSnackBar(context, msg);
  }

  Future<void> toastResult(bool ok, {String? okMsg}) async {
    _toast(ok ? (okMsg ?? '已写入云端') : copy('cloud.errNetwork'));
  }

  /// 组装 expenses_sync 行（列与 db_v26.sql 对齐；owner 保持团 owner）。
  ///
  /// 无同步引擎（离线 / 未登录）时省略 owner_user_id 列 —— RLS 会拒绝该行，
  /// 上层照旧走失败 toast，与 S4 前「写入必然失败」的可观测行为一致。
  Map<String, dynamic> expenseRow({
    required String id,
    required List<Map<String, dynamic>> payers,
    required List<Map<String, dynamic>> shares,
    required int dateEpochDay,
    required String title,
    required String categoryKey,
    required String type,
    required int cents,
    required int createdMs,
    String? settledRoundId,
    bool deleted = false,
  }) => {
    'id': id,
    if (ref.read(syncEngineProvider) case final engine?)
      'owner_user_id': engine.sharedOwnerUserIdOf(groupId),
    'group_id': groupId,
    'date_epoch_day': dateEpochDay,
    'title': title,
    'category_key': categoryKey,
    'type': type,
    'amount_cents': cents,
    'currency': 'CNY',
    'rate': 1.0,
    'amount_foreign_cents': null,
    'payers_json': jsonEncode(payers),
    'shares_json': jsonEncode(shares),
    'share_mode': 'equal',
    'portions_json': null,
    'note': '',
    'settled_round_id': settledRoundId,
    'trip_id': null,
    'trip_item_id': null,
    'created_ms': createdMs,
    'updated_ms': DateTime.now().millisecondsSinceEpoch,
    'deleted': deleted,
  };
}

// ============ Tab 1 账单 ============

/// 账单能力（四能力之「账单」）。
class SharedBillsSection extends ConsumerStatefulWidget {
  const SharedBillsSection({
    super.key,
    required this.data,
    this.online = true,
    this.canWrite = true,
    this.onAddBill,
    this.onEditBill,
    this.onDeleteBill,
  });

  /// 取数 + 本地落库数据源。
  final LedgerSectionData data;

  /// 在线（写通道是否可用）。
  final bool online;

  /// 是否可写（viewer 只读态传 false → 隐藏全部写入口）。
  final bool canWrite;

  /// 自定义写入通道（默认走共享镜像在线直写）。
  final Future<void> Function()? onAddBill;
  final Future<void> Function(ExpenseRecord record)? onEditBill;
  final Future<void> Function(ExpenseRecord record)? onDeleteBill;

  @override
  ConsumerState<SharedBillsSection> createState() => _SharedBillsSectionState();
}

class _SharedBillsSectionState extends ConsumerState<SharedBillsSection>
    with SharedDirectWrite {
  @override
  String get groupId => widget.data.groupId;

  bool get _writable => widget.online && widget.canWrite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<ExpenseRecord>>(
      stream: widget.data.watchExpenses(),
      builder: (_, snap) {
        final expenses = snap.data ?? const <ExpenseRecord>[];
        return ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            // 受邀成员也应能记账（共享账本的核心诉求）；此前只有编辑/删除，
            // 没有新增入口 → 成员只能围观。
            if (_writable) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(copy('share.addBill')),
                ),
              ),
              const SizedBox(height: Spacing.md),
            ],
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                child: Text(
                  '暂无共享账单',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: AppFontSizes.caption,
                  ),
                ),
              )
            else
              for (final e in expenses)
                Card(
                  margin: const EdgeInsets.only(bottom: Spacing.sm),
                  child: ListTile(
                    dense: true,
                    title: Text(e.title),
                    subtitle: Text(
                      '${fmtShortDay(e.dateEpochDay)} · ${e.categoryKey}'
                      '${e.settledRoundId != null ? ' · 已结算' : ''}',
                      style: const TextStyle(fontSize: AppFontSizes.caption),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMoney(e.amountCents),
                          style: TextStyle(
                            color: e.amountCents < 0
                                ? SemanticColors.income
                                : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.canWrite) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: '编辑',
                            onPressed: () => _edit(e),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            tooltip: '删除',
                            onPressed: () => _delete(e),
                          ),
                        ],
                      ],
                    ),
                    onTap: () => _showDetail(e),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// 新增一笔共享账单（在线直写；成功后写回本地镜像，无需等拉取）。
  Future<void> _add() async {
    final custom = widget.onAddBill;
    if (custom != null) return custom();
    final form = await _showBillFormSheet(context);
    if (form == null) return;
    final all = await widget.data.members();
    if (all.isEmpty) {
      await toastResult(false);
      return;
    }
    final shares = splitShares(
      totalCents: form.cents,
      memberIds: [for (final m in all) m.id],
    );
    final per = [
      for (final s in shares) {'memberId': s.memberId, 'cents': s.cents},
    ];
    final id = newId('expense');
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = expenseRow(
      id: id,
      payers: per,
      shares: per,
      dateEpochDay: form.dateEpochDay,
      title: form.title,
      categoryKey: form.categoryKey,
      type: 'normal',
      cents: form.cents,
      createdMs: now,
    );
    final ok = await directUpsert(
      'expenses_sync',
      row,
      onMirror: () async {
        try {
          await widget.data.upsertExpenseMirror(
            ExpenseRecord(
              id: id,
              groupId: groupId,
              dateEpochDay: form.dateEpochDay,
              title: form.title,
              categoryKey: form.categoryKey,
              type: ExpenseType.normal,
              amountCents: form.cents,
              currency: 'CNY',
              rate: 1.0,
              payers: parseShareList(row['payers_json'] as String),
              shares: parseShareList(row['shares_json'] as String),
            ),
            createdAt: now,
          );
        } catch (_) {
          // 镜像刷新失败不影响云端已成功的事实：等下次拉取对齐。
        }
      },
    );
    await toastResult(ok, okMsg: '已记账');
  }

  void _showDetail(ExpenseRecord e) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SheetSurface(
        child: SafeArea(
          child: FutureBuilder<List<LedgerMember>>(
            future: widget.data.members(),
            builder: (_, snap) {
              final nameOf = {
                for (final m in snap.data ?? const <LedgerMember>[])
                  m.id: m.name,
              };
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  Text(e.title, style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${fmtShortDay(e.dateEpochDay)} · ${e.categoryKey} · ${e.type.name}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: AppFontSizes.caption,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  const Text(
                    '付款',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final p in e.payers)
                    ListTile(
                      dense: true,
                      title: Text(
                        '${nameOf[p.memberId] ?? '已移除成员'} 付 ${formatMoney(p.cents)}',
                      ),
                    ),
                  const SizedBox(height: Spacing.sm),
                  const Text(
                    '分摊',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final s in e.shares)
                    ListTile(
                      dense: true,
                      title: Text(
                        '${nameOf[s.memberId] ?? '已移除成员'} 摊 ${formatMoney(s.cents)}',
                      ),
                    ),
                  if ((e.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    Text(e.note!),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _edit(ExpenseRecord e) async {
    final custom = widget.onEditBill;
    if (custom != null) return custom(e);
    final form = await _showBillFormSheet(
      context,
      initial: _BillForm(
        e.title,
        e.amountCents,
        e.dateEpochDay,
        e.categoryKey,
      ),
    );
    if (form == null) return;
    final all = await widget.data.members();
    final shares = splitShares(
      totalCents: form.cents,
      memberIds: [for (final m in all) m.id],
    );
    final per = [
      for (final s in shares) {'memberId': s.memberId, 'cents': s.cents},
    ];
    // created_ms / created_at 沿用镜像原值（改值即改数据路径）
    final createdAt = await widget.data.createdAtOf(e.id);
    final row = expenseRow(
      id: e.id,
      payers: per,
      shares: per,
      dateEpochDay: form.dateEpochDay,
      title: form.title,
      categoryKey: form.categoryKey,
      type: e.type.name,
      cents: form.cents,
      createdMs: createdAt,
      settledRoundId: e.settledRoundId,
    );
    final ok = await directUpsert(
      'expenses_sync',
      row,
      onMirror: () async {
        try {
          await widget.data.upsertExpenseMirror(
            ExpenseRecord(
              id: e.id,
              groupId: groupId,
              dateEpochDay: form.dateEpochDay,
              title: form.title,
              categoryKey: form.categoryKey,
              type: e.type,
              amountCents: form.cents,
              currency: e.currency,
              rate: e.rate,
              payers: parseShareList(row['payers_json'] as String),
              shares: parseShareList(row['shares_json'] as String),
              settledRoundId: e.settledRoundId,
            ),
            createdAt: createdAt,
          );
        } catch (_) {
          // 同上：镜像刷新失败等下次拉取对齐。
        }
      },
    );
    await toastResult(ok);
  }

  Future<void> _delete(ExpenseRecord e) async {
    final custom = widget.onDeleteBill;
    if (custom != null) return custom(e);
    final okConfirm = await showDangerConfirm(
      context: context,
      title: '删除账单',
      body: '删除「${e.title}」？共 1 笔，云端共享成员都会看到该账单被删除。',
      confirmLabel: '删除',
    );
    if (!okConfirm) return;
    // created_ms 沿用镜像原值（改值即改数据路径）
    final createdAt = await widget.data.createdAtOf(e.id);
    final row = expenseRow(
      id: e.id,
      payers: const [],
      shares: const [],
      dateEpochDay: e.dateEpochDay,
      title: e.title,
      categoryKey: e.categoryKey,
      type: e.type.name,
      cents: e.amountCents,
      createdMs: createdAt,
      settledRoundId: e.settledRoundId,
      deleted: true,
    );
    final ok = await directUpsert(
      'expenses_sync',
      row,
      onMirror: () async {
        try {
          await widget.data.removeExpenseMirror(e.id);
        } catch (_) {
          // 同上：镜像刷新失败等下次拉取对齐。
        }
      },
    );
    await toastResult(ok);
  }
}

// ============ Tab 2 成员 ============

/// 成员能力（四能力之「成员」）。
class SharedMembersSection extends ConsumerStatefulWidget {
  const SharedMembersSection({
    super.key,
    required this.data,
    this.online = true,
    this.isOwner = false,
    this.canWrite = true,
    this.onAddMember,
    this.onRemoveMember,
    this.memberPickerBuilder,
  });

  final LedgerSectionData data;
  final bool online;
  final bool isOwner;

  /// 是否可写（viewer 只读态传 false → 隐藏全部写入口）。
  final bool canWrite;

  /// 自定义添加成员通道（默认弹「成员名」对话框 + 共享镜像在线直写）。
  final Future<void> Function(BuildContext context)? onAddMember;

  /// 自定义移出成员通道（默认弹确认框 + 共享镜像在线直写）。
  final Future<void> Function(BuildContext context, LedgerMember member)?
  onRemoveMember;

  /// 自定义成员选择器（非空时「添加成员」改走它，默认走内置输入框）。
  final WidgetBuilder? memberPickerBuilder;

  @override
  ConsumerState<SharedMembersSection> createState() =>
      _SharedMembersSectionState();
}

class _SharedMembersSectionState extends ConsumerState<SharedMembersSection>
    with SharedDirectWrite {
  @override
  String get groupId => widget.data.groupId;

  /// owner 且可写才渲染管理操作（member / viewer 一律隐藏）。
  bool get _canManage => widget.online && widget.canWrite && widget.isOwner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<LedgerMember>>(
      stream: widget.data.watchMembers(),
      builder: (_, snap) {
        final list = snap.data ?? const <LedgerMember>[];
        return ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final m in list)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          m.name.isNotEmpty ? m.name.characters.first : '?',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      title: Text(m.name),
                      trailing: _canManage
                          ? IconButton(
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                size: 18,
                              ),
                              tooltip: '移出本团',
                              onPressed: list.length <= 1
                                  ? null
                                  : () => _remove(m),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            if (_canManage) ...[
              const SizedBox(height: Spacing.md),
              OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('添加成员'),
              ),
            ] else if (widget.online && widget.canWrite) ...[
              const SizedBox(height: Spacing.md),
              Text(
                copy('share.ownerOnlyTap'),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: AppFontSizes.caption,
                ),
              ),
            ],
            const SizedBox(height: Spacing.md),
            Text(
              '成员变更即时写云端并对所有共享成员可见。',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: AppFontSizes.caption,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _add() async {
    final custom = widget.onAddMember;
    if (custom != null) return custom(context);
    final picker = widget.memberPickerBuilder;
    final String? name;
    if (picker != null) {
      name = await showDialog<String>(context: context, builder: picker);
    } else {
      name = await _askName();
    }
    if (name == null || name.isEmpty) return;
    final id = newId('member');
    final now = DateTime.now().millisecondsSinceEpoch;
    final member = LedgerMember(id: id, name: name, createdAt: now);
    bool ok;
    if (widget.data.source == LedgerSectionSource.mirror) {
      final row = {
        'id': id,
        'owner_user_id': ref
            .read(syncEngineProvider)
            ?.sharedOwnerUserIdOf(groupId),
        'group_id': groupId,
        'name': name,
        'color_index': 0,
        'created_ms': now,
        'updated_ms': now,
        'deleted': false,
      };
      ok = await directUpsert(
        'members_sync',
        row,
        onMirror: () async {
          try {
            await widget.data.upsertMemberMirror(member);
          } catch (_) {
            // 镜像刷新失败等下次拉取对齐。
          }
        },
      );
    } else {
      ok = await _localWrite(() => widget.data.upsertMemberMirror(member));
    }
    await toastResult(ok);
  }

  Future<String?> _askName() async {
    final nameCtl = TextEditingController();
    final name = await showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      builder: (d, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.sm,
          Spacing.lg,
          Spacing.lg,
        ),
        children: [
          Text('添加成员', style: Theme.of(d).textTheme.titleLarge),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: nameCtl,
            decoration: const InputDecoration(labelText: '成员名'),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(d, nameCtl.text.trim()),
                  child: const Text('添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return name;
  }

  Future<void> _remove(LedgerMember m) async {
    final custom = widget.onRemoveMember;
    if (custom != null) return custom(context, m);
    final okConfirm = await showConfirmSheet(
      context: context,
      title: '移出成员',
      body: '将「${m.name}」移出本团？其 1 份历史分摊记录保留。',
      confirmLabel: '移出',
      danger: true,
    );
    if (!okConfirm) return;
    bool ok;
    if (widget.data.source == LedgerSectionSource.mirror) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final row = {
        'id': m.id,
        'owner_user_id': ref
            .read(syncEngineProvider)
            ?.sharedOwnerUserIdOf(groupId),
        'group_id': groupId,
        'name': m.name,
        'color_index': m.colorIndex,
        'created_ms': m.createdAt,
        'updated_ms': now,
        'deleted': true,
      };
      ok = await directUpsert(
        'members_sync',
        row,
        onMirror: () async {
          try {
            await widget.data.removeMemberMirror(m.id);
          } catch (_) {
            // 镜像刷新失败等下次拉取对齐。
          }
        },
      );
    } else {
      ok = await _localWrite(() => widget.data.removeMemberMirror(m.id));
    }
    await toastResult(ok);
  }

  /// 本地写通道：成功/失败归一成 bool（失败落 copy('cloud.errNetwork') 文案）。
  Future<bool> _localWrite(Future<void> Function() op) async {
    try {
      await op();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============ Tab 3 统计 ============

/// 统计能力（四能力之「统计」）：合计 / 成员净额 / 分类占比。
class SharedStatsSection extends ConsumerStatefulWidget {
  const SharedStatsSection({super.key, required this.data});

  final LedgerSectionData data;

  @override
  ConsumerState<SharedStatsSection> createState() => _SharedStatsSectionState();
}

class _SharedStatsSectionState extends ConsumerState<SharedStatsSection> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<ExpenseRecord>>(
      stream: widget.data.watchExpenses(),
      builder: (_, snap) {
        final records = snap.data ?? const <ExpenseRecord>[];
        if (records.isEmpty) {
          return Center(
            child: Text(
              '暂无数据',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: AppFontSizes.caption,
              ),
            ),
          );
        }
        var total = 0;
        final byCategory = <String, int>{};
        for (final r in records) {
          // 退款以负数自然冲减；预付款单独口径，不进日常合计
          if (r.type != ExpenseType.prepay) total += r.amountCents;
          if (r.type != ExpenseType.prepay) {
            byCategory[r.categoryKey] =
                (byCategory[r.categoryKey] ?? 0) + r.amountCents;
          }
        }
        final cats = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return FutureBuilder<List<LedgerMember>>(
          future: widget.data.members(),
          builder: (_, memberSnap) {
            final members = memberSnap.data ?? const <LedgerMember>[];
            final balances = computeNetBalances([
              for (final m in members) MemberRecord(id: m.id, name: m.name),
            ], records);
            final nameOf = {for (final m in members) m.id: m.name};
            return ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '共享支出合计（不含预付）',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: AppFontSizes.caption,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          formatMoney(total),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                SectionHeader(title: '成员净额（正=应收，负=应付）'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final b in balances.entries)
                        ListTile(
                          dense: true,
                          title: Text(nameOf[b.key] ?? b.key),
                          trailing: Text(
                            formatMoney(b.value),
                            style: TextStyle(
                              color: b.value < 0
                                  ? scheme.error
                                  : SemanticColors.income,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                SectionHeader(title: '分类占比'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final c in cats)
                        ListTile(
                          dense: true,
                          title: Text(c.key),
                          trailing: Text(
                            '${formatMoney(c.value)}（${total == 0 ? 0 : (c.value * 100 ~/ total)}%）',
                            style: const TextStyle(
                              fontSize: AppFontSizes.caption,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============ Tab 4 结算 ============

/// 结算能力（四能力之「结算」）。
class SharedSettleSection extends ConsumerStatefulWidget {
  const SharedSettleSection({
    super.key,
    required this.data,
    this.online = true,
    this.isOwner = false,
    this.canWrite = true,
  });

  final LedgerSectionData data;
  final bool online;
  final bool isOwner;

  /// 是否可写（viewer 只读态传 false → 隐藏「一键结算」）。
  final bool canWrite;

  @override
  ConsumerState<SharedSettleSection> createState() =>
      _SharedSettleSectionState();
}

class _SharedSettleSectionState extends ConsumerState<SharedSettleSection>
    with SharedDirectWrite {
  @override
  String get groupId => widget.data.groupId;

  /// owner 且可写才渲染「一键结算」。
  bool get _canSettle => widget.online && widget.canWrite && widget.isOwner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<LedgerSettlement>>(
      stream: widget.data.watchSettlements(),
      builder: (_, settleSnap) {
        final settlements = settleSnap.data ?? const <LedgerSettlement>[];
        return StreamBuilder<List<ExpenseRecord>>(
          stream: widget.data.watchExpenses(),
          builder: (_, snap) {
            final expenses = snap.data ?? const <ExpenseRecord>[];
            final outstanding = [
              for (final e in expenses)
                if (e.settledRoundId == null) e,
            ];
            return FutureBuilder<List<LedgerMember>>(
              future: widget.data.members(),
              builder: (_, memberSnap) {
                final members = memberSnap.data ?? const <LedgerMember>[];
                final nameOf = {for (final m in members) m.id: m.name};
                return ListView(
                  padding: const EdgeInsets.all(Spacing.lg),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '未结算账单 ${outstanding.length} 笔',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            for (final e in outstanding.take(5))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(e.title),
                                trailing: Text(formatMoney(e.amountCents)),
                              ),
                            if (outstanding.length > 5)
                              Text(
                                '…等 ${outstanding.length} 笔',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: AppFontSizes.caption,
                                ),
                              ),
                            if (_canSettle && outstanding.isNotEmpty) ...[
                              const SizedBox(height: Spacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _settle,
                                  icon: const Icon(Icons.done_all_rounded),
                                  label: const Text('一键结算'),
                                ),
                              ),
                            ],
                            if (widget.online &&
                                widget.canWrite &&
                                !widget.isOwner)
                              Padding(
                                padding: const EdgeInsets.only(top: Spacing.sm),
                                child: Text(
                                  copy('share.ownerOnlyTap'),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: AppFontSizes.caption,
                                  ),
                                ),
                              ),
                            if (!widget.online)
                              Padding(
                                padding: const EdgeInsets.only(top: Spacing.sm),
                                child: Text(
                                  '离线仅可查看，结算需联网。',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: AppFontSizes.caption,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    SectionHeader(title: '历史结算'),
                    if (settlements.isEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.lg),
                          child: Text(
                            '还没有结算记录',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: AppFontSizes.caption,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final s in settlements)
                        Card(
                          margin: const EdgeInsets.only(bottom: Spacing.sm),
                          child: ListTile(
                            dense: true,
                            title: Text('第 ${s.roundNo} 轮结算'),
                            subtitle: Text(
                              '${fmtShortDay(s.createdAt ~/ 86400000)} · '
                              '${_transfersSummary(s.transfersJson, nameOf)}',
                              style: const TextStyle(
                                fontSize: AppFontSizes.caption,
                              ),
                            ),
                          ),
                        ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _transfersSummary(String json, Map<String, String> nameOf) {
    final list = parseTransfers(json);
    if (list.isEmpty) return '无需转账';
    return [
      for (final t in list)
        '${nameOf[t.from] ?? t.from} → ${nameOf[t.to] ?? t.to} '
            '${formatMoney(t.cents)}',
    ].join('；');
  }

  Future<void> _settle() async {
    final all = await widget.data.members();
    final expenses = await widget.data.expenses();
    final outstanding = [
      for (final e in expenses)
        if (e.settledRoundId == null) e,
    ];
    if (outstanding.isEmpty) return;
    final balances = computeNetBalances([
      for (final m in all) MemberRecord(id: m.id, name: m.name),
    ], outstanding);
    final plan = minTransferPlan(balances);
    final nameOf = {for (final m in all) m.id: m.name};
    if (!mounted) return; // await 之后必须复查：页面可能已被 pop
    final planLines = [
      for (final t in plan)
        '${nameOf[t.from] ?? t.from} → ${nameOf[t.to] ?? t.to}：'
            '${formatMoney(t.cents)}',
    ];
    final okConfirm = await showConfirmSheet(
      context: context,
      title: '确认结算',
      body: '结算后以下转账建议将入账：\n'
          '${plan.isEmpty ? '当前无需转账（已两清）' : planLines.join('\n')}',
      confirmLabel: '确认结算',
    );
    if (!okConfirm) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final settlements = await widget.data.watchSettlements().first;
    final nextRound = settlements.isEmpty
        ? 1
        : settlements.map((s) => s.roundNo).reduce((a, b) => a > b ? a : b) + 1;
    final sid = newId('settle');
    final transfersJson = jsonEncode([
      for (final t in plan) {'from': t.from, 'to': t.to, 'cents': t.cents},
    ]);
    final expenseIdsJson = jsonEncode([for (final e in outstanding) e.id]);
    final owner = ref.read(syncEngineProvider)?.sharedOwnerUserIdOf(groupId);
    final settlementRow = {
      'id': sid,
      'owner_user_id': owner,
      'group_id': groupId,
      'status': 'active',
      'transfers_json': transfersJson,
      'expense_ids_json': expenseIdsJson,
      'round_no': nextRound,
      'created_ms': now,
      'updated_ms': now,
      'deleted': false,
    };
    var ok = true;
    // 结算行 + 涉事账单回写 settled_round_id（逐条直写；任一失败即中断提示）
    final client = ref.read(cloudClientProvider);
    if (client == null) {
      await toastResult(false);
      return;
    }
    try {
      await client
          .from('settlements_sync')
          .upsert(settlementRow, onConflict: 'id');
      for (final e in outstanding) {
        await client.from('expenses_sync').upsert({
          'id': e.id,
          'owner_user_id': owner,
          'group_id': groupId,
          'date_epoch_day': e.dateEpochDay,
          'title': e.title,
          'category_key': e.categoryKey,
          'type': e.type.name,
          'amount_cents': e.amountCents,
          'currency': e.currency,
          'rate': e.rate,
          'amount_foreign_cents': e.amountForeignCents,
          'payers_json': _encodeShares(e.payers),
          'shares_json': _encodeShares(e.shares),
          'share_mode': e.shareMode.name,
          'portions_json': e.portions == null ? null : jsonEncode(e.portions),
          'note': e.note ?? '',
          'settled_round_id': sid,
          'trip_id': e.tripId,
          'trip_item_id': e.tripItemId,
          // created_ms 沿用镜像原值（改值即改数据路径）
          'created_ms': await widget.data.createdAtOf(e.id),
          'updated_ms': now,
          'deleted': false,
        }, onConflict: 'id');
      }
    } catch (_) {
      ok = false;
    }
    if (ok) {
      // 刷新本地镜像
      try {
        await widget.data.upsertSettlementMirror(
          LedgerSettlement(
            id: sid,
            groupId: groupId,
            status: 'active',
            transfersJson: transfersJson,
            expenseIdsJson: expenseIdsJson,
            roundNo: nextRound,
            createdAt: now,
          ),
        );
        await widget.data.markExpensesSettled([
          for (final e in outstanding) e.id,
        ], sid);
      } catch (_) {
        // 镜像刷新失败等下次拉取对齐。
      }
    }
    await toastResult(ok, okMsg: '结算完成（第 $nextRound 轮）');
  }

  /// 账单 JSON 序列化（与镜像/云端列同构）。
  String _encodeShares(List<ShareEntry> shares) => jsonEncode([
    for (final s in shares) {'memberId': s.memberId, 'cents': s.cents},
  ]);
}

// ============ 账单表单 ============

class _BillForm {
  _BillForm(this.title, this.cents, this.dateEpochDay, this.categoryKey);
  final String title;
  final int cents;
  final int dateEpochDay;
  final String categoryKey;
}

/// V2.8.1 S3：账单表单弹窗迁 L4 表单抽屉（原 _BillFormDialog，零业务变化）。
Future<_BillForm?> _showBillFormSheet(BuildContext context, {_BillForm? initial}) {
  return showDraggableSheet<_BillForm>(
    context: context,
    builder: (sheetContext, scrollController) => _BillFormSheet(
      initial: initial,
      scrollController: scrollController,
    ),
  );
}

class _BillFormSheet extends StatefulWidget {
  const _BillFormSheet({this.initial, required this.scrollController});

  final _BillForm? initial;
  final ScrollController scrollController;

  @override
  State<_BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<_BillFormSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : (widget.initial!.cents.abs() / 100).toStringAsFixed(
            widget.initial!.cents % 100 == 0 ? 0 : 2,
          ),
  );
  // widget 在 State 构造后才赋值：引用它的字段必须 late（首次访问时求值）
  late DateTime _date = widget.initial == null
      ? DateTime.now()
      : epochDayToDate(widget.initial!.dateEpochDay);
  late String _category = widget.initial?.categoryKey ?? 'other';

  static const _categories = [
    'other',
    'food',
    'transport',
    'hotel',
    'ticket',
    'shopping',
  ];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
      children: [
        Text(
          widget.initial == null ? '记一笔' : '编辑账单',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: '名目'),
        ),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '金额（元）'),
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final c in _categories)
              ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Text('日期：${_date.month}/${_date.day}'),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (d != null && mounted) setState(() => _date = d);
              },
              child: const Text('选择'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final cents = parseMoney(_amount.text);
                  if (_title.text.trim().isEmpty || cents == null) return;
                  Navigator.pop(
                    context,
                    _BillForm(
                      _title.text.trim(),
                      cents,
                      dateToEpochDay(_date),
                      _category,
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
