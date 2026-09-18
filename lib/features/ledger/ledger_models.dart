/// 记账线 UI 视图模型：屏幕只认本文件的稳定类型，
/// 与数据层的字段差异全部在 ledger_providers.dart 的转换层吸收。
///
/// 【约定】金额一律 int 分且带符号（normal/prepay 为正、refund 为负），
/// 展示层统一走 MoneyText / formatMoney，禁止在屏幕里手工拼金额字符串。
library;

import '../../core/uid.dart';
import '../../domain/models.dart';

// ---------------------------------------------------------------------------
// 枚举文案
// ---------------------------------------------------------------------------

/// 账单类型中文标签
String expenseTypeLabel(ExpenseType t) {
  switch (t) {
    case ExpenseType.normal:
      return '支出';
    case ExpenseType.refund:
      return '退款';
    case ExpenseType.prepay:
      return '预付';
  }
}

/// 分摊方式中文标签
String shareModeLabel(ShareMode m) {
  switch (m) {
    case ShareMode.equal:
      return '平均';
    case ShareMode.portions:
      return '按份数';
    case ShareMode.percent:
      return '按百分比';
    case ShareMode.custom:
      return '自定义';
  }
}

// ---------------------------------------------------------------------------
// 团 / 成员 / 分类 / 行程 视图
// ---------------------------------------------------------------------------

/// 旅行团视图
class LedgerGroupView {
  const LedgerGroupView({
    required this.id,
    required this.name,
    required this.icon,
    required this.budgetEnabled,
    this.archived = false,
    this.budgetCents,
    this.kind = 'travel',
  });

  final String id;
  final String name;
  final String icon;
  final bool budgetEnabled;

  /// 团已结束（软归档）：数据保留可改，可随时恢复
  final bool archived;
  final int? budgetCents;

  /// 账本类型（S4）：travel / personal；未知值一律按 travel 处理。
  final String kind;

  /// 是否个人账本（隐藏余额板 / AA 结算 / 公款池入口）。
  bool get isPersonal => kind == 'personal';
}

/// 成员视图：colorIndex 由仓储层轮换分配（%8），UI 只读不写；
/// 数据缺失时用姓名稳定哈希兜底，保证跨会话颜色一致。
class LedgerMemberView {
  const LedgerMemberView({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.archived = false,
  });

  final String id;
  final String name;
  final int colorIndex;

  /// 已移除成员（软删除，S2 G1）：不进选择器，但历史账单照常参与净额。
  final bool archived;

  MemberRecord get record => MemberRecord(id: id, name: name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LedgerMemberView && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 分类视图（内置 7 类锁定 + 自定义）
class CategoryView {
  const CategoryView({
    required this.key,
    required this.name,
    required this.icon,
    required this.builtin,
  });

  final String key;
  final String name;
  final String icon;
  final bool builtin;
}

/// 行程横滑小卡视图（关联行程）
class TripCardView {
  const TripCardView({
    required this.id,
    required this.name,
    required this.destination,
    required this.emoji,
    required this.cover,
    required this.startEpochDay,
    required this.endEpochDay,
    required this.archived,
  });

  final String id;
  final String name;
  final String destination;
  final String emoji;
  final String cover;
  final int startEpochDay;
  final int endEpochDay;
  final bool archived;
}

/// 关联行程下拉的行程安排选项
class TripItemOption {
  const TripItemOption({
    required this.id,
    required this.tripId,
    required this.name,
    required this.dateEpochDay,
    this.costCents,
    this.costCurrency,
  });

  final String id;
  final String tripId;
  final String name;
  final int dateEpochDay;
  final int? costCents;
  final String? costCurrency;
}

// ---------------------------------------------------------------------------
// 结算视图
// ---------------------------------------------------------------------------

/// 一笔待转账
class TransferView {
  const TransferView({
    required this.from,
    required this.to,
    required this.cents,
    required this.done,
  });

  final String from;
  final String to;
  final int cents;
  final bool done;

  TransferView copyWith({bool? done}) =>
      TransferView(from: from, to: to, cents: cents, done: done ?? this.done);
}

/// 结算轮视图（进行中或已完成）
class SettlementView {
  const SettlementView({
    required this.id,
    required this.groupId,
    required this.active,
    required this.roundNo,
    required this.transfers,
    required this.createdAtMs,
    this.completedAtMs,
    this.strategy = 'minTransfers',
  });

  /// true = 进行中；false = 已完成的历史轮次
  final bool active;
  final String id;
  final String groupId;
  final int roundNo;
  final List<TransferView> transfers;
  final int createdAtMs;
  final int? completedAtMs;

  /// 本轮所用结算策略（S9）：minTransfers / minParticipants。
  final String strategy;

  /// 全部转账都已确认
  bool get allDone => transfers.isNotEmpty && transfers.every((t) => t.done);

  /// 已确认笔数
  int get doneCount => transfers.where((t) => t.done).length;
}

// ---------------------------------------------------------------------------
// 统计视图
// ---------------------------------------------------------------------------

/// 成员收支榜一行：paid 已付 / share 应摊 / balance 结余（正=应收）
class MemberStatView {
  const MemberStatView({
    required this.member,
    required this.paidCents,
    required this.shareCents,
    required this.balanceCents,
  });

  final LedgerMemberView member;
  final int paidCents;
  final int shareCents;
  final int balanceCents;
}

/// 分类占比一行
class CategoryShareView {
  const CategoryShareView({
    required this.category,
    required this.cents,
    required this.fraction,
  });

  final CategoryView category;
  final int cents;

  /// 占总支出比例 0.0~1.0
  final double fraction;
}

/// 每日合计
class DailyTotalView {
  const DailyTotalView({required this.epochDay, required this.cents});

  final int epochDay;
  final int cents;
}

/// 预算状态
class BudgetStatusView {
  const BudgetStatusView({
    required this.enabled,
    required this.totalCents,
    required this.spentCents,
    required this.remainingCents,
    required this.percent,
  });

  final bool enabled;

  /// 预算总额（未开启时为 0）
  final int totalCents;
  final int spentCents;
  final int remainingCents;

  /// 已花占预算比例，可 > 1（超支）
  final double percent;

  bool get overBudget => enabled && totalCents > 0 && spentCents > totalCents;
}

/// 币种视图
class CurrencyView {
  const CurrencyView({
    required this.code,
    required this.symbol,
    required this.name,
    required this.defaultRate,
  });

  final String code;
  final String symbol;
  final String name;
  final double defaultRate;
}

// ---------------------------------------------------------------------------
// 记账草稿（新增 / 编辑共用）
// ---------------------------------------------------------------------------

/// 记一笔表单的完整草稿：expense_edit_screen 收集 → providers 落库
class ExpenseDraft {
  ExpenseDraft({
    required this.groupId,
    required this.dateEpochDay,
    required this.title,
    required this.categoryKey,
    required this.type,
    required this.amountCents,
    required this.currency,
    required this.rate,
    required this.payers,
    required this.shares,
    required this.shareMode,
    this.amountForeignCents,
    this.portions,
    this.note,
    this.tripId,
    this.tripItemId,
    this.id,
    this.fundId,
    this.payMethod,
  });

  /// 编辑模式携带已有 id；新增为 null
  final String? id;
  final String groupId;
  final int dateEpochDay;
  final String title;
  final String categoryKey;
  final ExpenseType type;
  final int amountCents;
  final String currency;
  final double rate;
  final int? amountForeignCents;
  final List<ShareEntry> payers;
  final List<ShareEntry> shares;
  final ShareMode shareMode;
  final Map<String, int>? portions;
  final String? note;
  final String? tripId;
  final String? tripItemId;
  final String? fundId;
  final String? payMethod;

  /// 转为不可变记录（新增自动生成 id）
  ExpenseRecord toRecord() => ExpenseRecord(
        id: id ?? newId('expense'),
        groupId: groupId,
        dateEpochDay: dateEpochDay,
        title: title,
        categoryKey: categoryKey,
        type: type,
        amountCents: amountCents,
        currency: currency,
        rate: rate,
        amountForeignCents: amountForeignCents,
        payers: List.unmodifiable(payers),
        shares: List.unmodifiable(shares),
        shareMode: shareMode,
        portions: portions == null ? null : Map.unmodifiable(portions!),
        note: note,
        tripId: tripId,
        tripItemId: tripItemId,
        fundId: fundId,
        payMethod: payMethod,
      );

  /// 从已有记录构造编辑草稿
  factory ExpenseDraft.fromRecord(ExpenseRecord r) => ExpenseDraft(
        id: r.id,
        groupId: r.groupId,
        dateEpochDay: r.dateEpochDay,
        title: r.title,
        categoryKey: r.categoryKey,
        type: r.type,
        amountCents: r.amountCents,
        currency: r.currency,
        rate: r.rate,
        amountForeignCents: r.amountForeignCents,
        payers: List.of(r.payers),
        shares: List.of(r.shares),
        shareMode: r.shareMode,
        portions: r.portions == null ? null : Map.of(r.portions!),
        note: r.note,
        tripId: r.tripId,
        tripItemId: r.tripItemId,
        fundId: r.fundId,
        payMethod: r.payMethod,
      );
}

// ---------------------------------------------------------------------------
// 引用计数（删除拦截提示用）
// ---------------------------------------------------------------------------

/// 统计成员在 payers/shares 中出现的账单笔数
int countMemberReferences(List<ExpenseRecord> expenses, String memberId) => expenses
    .where((e) =>
        e.payers.any((p) => p.memberId == memberId) ||
        e.shares.any((s) => s.memberId == memberId))
    .length;

/// 支付方式分组合计（S11）：[payMethod] 为 null 表示「未标记」。
class PayMethodTotalView {
  const PayMethodTotalView({required this.payMethod, required this.cents});

  final String? payMethod;
  final int cents;
}

/// 支付方式内置取值 → 中文标签（S11）。
const Map<String, String> kPayMethodLabels = {
  'cash': '现金',
  'credit': '信用卡',
  'debit': '储蓄卡',
  'ewallet': '电子钱包',
  'fund': '公费池',
  'other': '其他',
};

/// 支付方式展示文案：null/空 = 未标记；自定义串原样显示。
String payMethodLabel(String? key) =>
    key == null || key.isEmpty ? '未标记' : (kPayMethodLabels[key] ?? key);

/// 公款池视图（S8）：UI 只读，不直接接触 drift 行。
class FundView {
  const FundView({
    required this.id,
    required this.groupId,
    required this.name,
    required this.managerMemberId,
    this.targetCents,
    required this.status,
    required this.createdAtMs,
  });

  final String id;
  final String groupId;
  final String name;

  /// 一池唯一管理人。
  final String managerMemberId;

  /// 计划收款总额（可空，不强制）。
  final int? targetCents;

  /// open | closed
  final String status;
  final int createdAtMs;

  bool get isOpen => status == 'open';
}

/// 收件箱条目视图（S10）。
class InboxItemView {
  const InboxItemView({
    required this.id,
    required this.groupId,
    required this.amountCents,
    this.note,
    required this.capturedAtMs,
    required this.source,
    required this.status,
    this.convertedExpenseId,
  });

  final String id;
  final String groupId;
  final int amountCents;
  final String? note;
  final int capturedAtMs;

  /// manual | quick_action
  final String source;

  /// pending | converted
  final String status;

  /// 归类幂等键：非空表示已转正。
  final String? convertedExpenseId;

  bool get isPending => status == 'pending';
  bool get isConverted => status == 'converted';
}
