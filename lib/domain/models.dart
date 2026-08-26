/// 领域层纯数据模型：与 drift 表结构一一对应的内存镜像。
///
/// drift 生成的行类只在数据层内部流转，进入领域算法/UI 前先转为本文件
/// 的不可变模型 —— 保证 lib/domain 纯 Dart、无 IO、可直接单测。
///
/// 【全局约定】金额一律 int 分且带符号：
/// * normal/prepay 的 amountCents 为正；
/// * refund 的 amountCents 为负数；
/// * payers/shares 中每个成员的 cents 同样带符号。
library;

/// 账单类型
enum ExpenseType {
  /// 正常支出
  normal,

  /// 退款（存储为负数金额）
  refund,

  /// 预付款（不进日常合计，单独统计）
  prepay,
}

/// 分摊方式
enum ShareMode {
  /// 平均分摊（余数按序每人 +1）
  equal,

  /// 按份数最大余数法
  portions,

  /// 自定义每人口径（要求总额守恒）
  custom,
}

/// 团成员（Members 表镜像的最小集）
class MemberRecord {
  const MemberRecord({required this.id, required this.name, this.colorIndex = 0});

  final String id;
  final String name;
  final int colorIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MemberRecord && id == other.id && name == other.name && colorIndex == other.colorIndex;

  @override
  int get hashCode => Object.hash(id, name, colorIndex);

  @override
  String toString() => 'MemberRecord($id, $name, colorIndex=$colorIndex)';
}

/// 一条付款/分摊记录（payersJson 与 sharesJson 的元素同构）
class ShareEntry {
  const ShareEntry({required this.memberId, required this.cents});

  final String memberId;

  /// 该成员实付/应摊金额（分，带符号）
  final int cents;

  ShareEntry copyWith({String? memberId, int? cents}) => ShareEntry(
        memberId: memberId ?? this.memberId,
        cents: cents ?? this.cents,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareEntry && memberId == other.memberId && cents == other.cents;

  @override
  int get hashCode => Object.hash(memberId, cents);

  @override
  String toString() => 'ShareEntry($memberId, $cents)';
}

/// 账单（Expenses 表镜像）
class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
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
    this.shareMode = ShareMode.equal,
    this.amountForeignCents,
    this.portions,
    this.note,
    this.settledRoundId,
    this.tripId,
    this.tripItemId,
  });

  final String id;
  final String groupId;

  /// 记账日期（epochDay，见 core/date_utils.dart）
  final int dateEpochDay;
  final String title;
  final String categoryKey;
  final ExpenseType type;

  /// 折算人民币后的总额（分，带符号；refund 为负）
  final int amountCents;
  final String currency;

  /// 汇率：1 外币 = rate 元
  final double rate;

  /// 外币原始金额（分，可空）
  final int? amountForeignCents;

  /// 多人付款明细（每人实付，带符号）
  final List<ShareEntry> payers;

  /// 分摊明细（每人应摊，带符号；保存时由 splitShares 固化）
  final List<ShareEntry> shares;
  final ShareMode shareMode;

  /// 按份数模式的份数表（memberId -> 份数；仅 shareMode==portions 有意义）
  final Map<String, int>? portions;

  final String? note;

  /// 所属结算轮 id；非空表示该笔已参与某轮完成的结算
  final String? settledRoundId;

  /// 关联行程（可空）
  final String? tripId;

  /// 关联行程安排（可空）
  final String? tripItemId;

  ExpenseRecord copyWith({
    String? id,
    String? groupId,
    int? dateEpochDay,
    String? title,
    String? categoryKey,
    ExpenseType? type,
    int? amountCents,
    String? currency,
    double? rate,
    int? amountForeignCents,
    Object? payers = _sentinel,
    Object? shares = _sentinel,
    ShareMode? shareMode,
    Object? portions = _sentinel,
    Object? note = _sentinel,
    Object? settledRoundId = _sentinel,
    Object? tripId = _sentinel,
    Object? tripItemId = _sentinel,
  }) =>
      ExpenseRecord(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        dateEpochDay: dateEpochDay ?? this.dateEpochDay,
        title: title ?? this.title,
        categoryKey: categoryKey ?? this.categoryKey,
        type: type ?? this.type,
        amountCents: amountCents ?? this.amountCents,
        currency: currency ?? this.currency,
        rate: rate ?? this.rate,
        amountForeignCents: amountForeignCents ?? this.amountForeignCents,
        payers: identical(_sentinel, payers) ? this.payers : payers as List<ShareEntry>,
        shares: identical(_sentinel, shares) ? this.shares : shares as List<ShareEntry>,
        shareMode: shareMode ?? this.shareMode,
        portions: identical(_sentinel, portions) ? this.portions : portions as Map<String, int>?,
        note: identical(_sentinel, note) ? this.note : note as String?,
        settledRoundId:
            identical(_sentinel, settledRoundId) ? this.settledRoundId : settledRoundId as String?,
        tripId: identical(_sentinel, tripId) ? this.tripId : tripId as String?,
        tripItemId:
            identical(_sentinel, tripItemId) ? this.tripItemId : tripItemId as String?,
      );

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseRecord &&
          id == other.id &&
          groupId == other.groupId &&
          dateEpochDay == other.dateEpochDay &&
          title == other.title &&
          categoryKey == other.categoryKey &&
          type == other.type &&
          amountCents == other.amountCents &&
          currency == other.currency &&
          rate == other.rate &&
          amountForeignCents == other.amountForeignCents &&
          _listEq(payers, other.payers) &&
          _listEq(shares, other.shares) &&
          shareMode == other.shareMode &&
          _mapEq(portions, other.portions) &&
          note == other.note &&
          settledRoundId == other.settledRoundId &&
          tripId == other.tripId &&
          tripItemId == other.tripItemId;

  @override
  int get hashCode => Object.hash(
      id, groupId, dateEpochDay, title, categoryKey, type, amountCents);

  @override
  String toString() => 'ExpenseRecord($id, $title, $amountCents, $type)';
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (a[k] != b[k]) return false;
  }
  return true;
}


/// 结算状态
enum SettlementStatus { active, completed }

/// 转账记录
class TransferRecord {
  const TransferRecord({required this.from, required this.to, required this.cents, this.done = false});
  final String from, to;
  final int cents;
  final bool done;
}

/// 结算轮
class Settlement {
  const Settlement({required this.id, required this.groupId, required this.status, this.transfers = const [], required this.roundNo, required this.createdAt, this.completedAt});
  final String id, groupId;
  final SettlementStatus status;
  final List<TransferRecord> transfers;
  final int roundNo;
  final int createdAt;
  final int? completedAt;
}

/// 币种（独立定义，兼容 kCurrencies/CurrencyInfo 同构）
class Currency {
  const Currency({required this.code, required this.symbol, required this.name, required this.rate});
  final String code, symbol, name;
  final double rate;
}

/// 导入报告
class ImportReport {
  const ImportReport({this.groups=0, this.members=0, this.expenses=0, this.settlements=0, this.trips=0, this.tripItems=0, this.reusedCategories=0, this.warnings=const []});
  final int groups, members, expenses, settlements, trips, tripItems, reusedCategories;
  final List<String> warnings;
}

