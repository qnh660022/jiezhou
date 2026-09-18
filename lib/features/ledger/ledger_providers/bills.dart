/// 账本桥接层 · 账单域（视图转换 + 增删改 Action）。
///
/// G4 拆分（V2.7.1 S2）：由 `ledger_providers.dart` barrel 统一 export。
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/uid.dart';
import '../../../data/providers.dart';
import '../../../data/db/database.dart' hide Settlement;
import '../../../domain/models.dart';
import '../../../domain/share_splitter.dart';
import '../ledger_models.dart';
import 'groups.dart';

/// 行程关联账单原始流（行程详情入账徽章 / 计划vs实际卡用；drift 行直出）
final tripBillsProvider =
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
  return ref.watch(ledgerRepoProvider).watchByTrip(tripId);
});

/// 当前团账单（全量；屏幕侧再做筛选）。
///
/// 【健壮性修复】原始实现在 `.map()` 内对每条记录做 `ExpenseType.values.byName` /
/// `ShareMode.values.byName` / `portionsJson` 解析，且 portions 字段被错误地当成
/// JSON 数组（实际是对象）强制 `as List`，任一记录解析抛异常就会让**整条流进入
/// error 状态**，StreamProvider 的 `.value` 变 null，账单列表整体回退到「一笔都还没记」
/// 的空状态——即「记账成功却不显示」。
///
/// 现改为：逐条 try 转换，单条失败只丢弃该条（绝不拖垮整页），portions 按对象解析，
/// 枚举按名字安全兜底。这同时覆盖了按份数模式必崩、以及脏数据导致整页空白两类问题。
final expensesProvider = StreamProvider<List<ExpenseRecord>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return Stream.value(const <ExpenseRecord>[]);
  return ref.watch(ledgerRepoProvider).watchExpenses(gid).map(
    (list) => [
      for (final e in list) _tryMapExpense(e),
    ].whereType<ExpenseRecord>().toList(),
  );
});

/// 单条账单记录 → 视图模型；解析失败返回 null（由上层 .whereType 丢弃）。
///
/// 【退款归一】约定「normal/prepay 为正、refund 为负」（见 core/money.dart）。
/// 历史数据与部分写入路径曾把退款存成正数，这里统一在读取边界幂等地
/// 归到负数口径（-abs），保证结算/统计/预算/成员榜等下游金额永远一致。
ExpenseRecord? _tryMapExpense(Expense e) {
  try {
    final isRefund = e.type == 'refund';
    final sign = isRefund ? -1 : 1;
    return ExpenseRecord(
      id: e.id,
      groupId: e.groupId,
      dateEpochDay: e.dateEpochDay,
      title: e.title,
      categoryKey: e.categoryKey,
      type: _safeExpenseType(e.type),
      amountCents: sign * e.amountCents.abs(),
      currency: e.currency,
      rate: e.rate,
      amountForeignCents: e.amountForeignCents,
      payers: [
        for (final p in _parseShareList(e.payersJson))
          ShareEntry(memberId: p.memberId, cents: sign * p.cents.abs()),
      ],
      shares: [
        for (final s in _parseShareList(e.sharesJson))
          ShareEntry(memberId: s.memberId, cents: sign * s.cents.abs()),
      ],
      shareMode: _safeShareMode(e.shareMode),
      // portions 是 JSON 对象（memberId->份数 或 memberId->bp），不是数组；修正解析避免 TypeError。
      // 语义由 shareMode 判别：portions 存份数、percent 存万分比 bp（S3）。
      portions: e.portionsJson == null ? null : _decodePortions(e.portionsJson!),
      note: e.note,
      settledRoundId: e.settledRoundId,
      tripId: e.tripId,
      tripItemId: e.tripItemId,
      fundId: e.fundId,
      payMethod: e.payMethod,
    );
  } catch (_) {
    return null;
  }
}

/// 公开的 drift 行 → 领域记录转换（含退款负号归一）。
/// 非 provider 场景（如行程详情自建记录）也统一走这里，杜绝漏归一。
ExpenseRecord? expenseRecordOf(Expense e) => _tryMapExpense(e);

/// 安全解析按份数/百分比表：JSON 对象 -> {memberId: 值}；格式异常返回 null 而非抛错。
Map<String, int>? _decodePortions(String json) {
  if (json.isEmpty) return null;
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

/// 账单类型枚举安全解析：未知字符串兜底 normal（避免 .byName 抛错拖垮整页）
ExpenseType _safeExpenseType(String s) {
  for (final t in ExpenseType.values) {
    if (t.name == s) return t;
  }
  return ExpenseType.normal;
}

/// 分摊方式枚举安全解析：未知字符串兜底 equal
ShareMode _safeShareMode(String s) {
  for (final m in ShareMode.values) {
    if (m.name == s) return m;
  }
  return ShareMode.equal;
}

List<ShareEntry> _parseShareList(String json) {
  if (json.isEmpty || json == '[]') return const [];
  try {
    final list = _jsonDecode(json);
    return list.map((e) => ShareEntry(
      memberId: e['memberId'] as String,
      cents: (e['cents'] as num).toInt(),
    )).toList();
  } catch (_) {
    return const [];
  }
}

List<dynamic> _jsonDecode(String s) => jsonDecode(s) as List<dynamic>;

// ---------------------------------------------------------------------------
// 领域引擎包装（分摊）
// ---------------------------------------------------------------------------

/// 各分摊模式的统一入口（percent 传归一 bp；custom 由屏内先校验守恒再传入 shares）
List<ShareEntry> computeSplit({
  required int totalCents,
  required List<String> memberIds,
  required ShareMode mode,
  Map<String, int>? portions,
}) =>
    splitShares(
      totalCents: totalCents,
      memberIds: memberIds,
      mode: mode,
      portions: portions ?? {},
    );

// ---------------------------------------------------------------------------
// 动作封装：账单
// ---------------------------------------------------------------------------

/// 草稿 → drift Companion（新增/更新/收件箱归类共用同一序列化口径）。
ExpensesCompanion expenseCompanionOf(ExpenseDraft draft, {String? id}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return ExpensesCompanion(
    id: Value(id ?? draft.id ?? newId('expense')),
    groupId: Value(draft.groupId),
    dateEpochDay: Value(draft.dateEpochDay),
    title: Value(draft.title),
    categoryKey: Value(draft.categoryKey),
    type: Value(draft.type.name),
    amountCents: Value(draft.amountCents),
    currency: Value(draft.currency),
    rate: Value(draft.rate),
    // ShareEntry 不是 JSON encodable 对象，必须先转换成数据库约定的 Map。
    payersJson: Value(jsonEncode([
      for (final e in draft.payers) {'memberId': e.memberId, 'cents': e.cents},
    ])),
    sharesJson: Value(jsonEncode([
      for (final e in draft.shares) {'memberId': e.memberId, 'cents': e.cents},
    ])),
    shareMode: Value(draft.shareMode.name),
    portionsJson: Value(draft.portions == null ? null : jsonEncode(draft.portions)),
    note: Value(draft.note ?? ''),
    tripId: Value(draft.tripId),
    tripItemId: Value(draft.tripItemId),
    fundId: Value(draft.fundId),
    payMethod: Value(draft.payMethod),
    createdAt: Value(now),
  );
}

/// 新增或更新账单
Future<void> saveExpense(WidgetRef ref, ExpenseDraft draft) async {
  final repo = ref.read(ledgerRepoProvider);
  final comp = expenseCompanionOf(draft);
  if (draft.id == null) {
    await repo.addExpense(comp);
  } else {
    await repo.updateExpense(draft.id!, comp);
  }
}

Future<void> deleteExpense(WidgetRef ref, String expenseId) =>
    ref.read(ledgerRepoProvider).deleteExpense(expenseId);

/// 单笔手动结 / 反结（账单详情开关）
Future<void> setExpenseSettled(WidgetRef ref, ExpenseRecord expense, bool settled) =>
    ref.read(ledgerRepoProvider).setExpenseSettled(expense.id, settled);

/// 记账默认日期兜底
int todayOr(int epochDay) => epochDay <= 0 ? todayEpochDay() : epochDay;
