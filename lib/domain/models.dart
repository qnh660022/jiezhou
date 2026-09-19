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

  /// 按百分比（S3）：portionsJson 语义重载为万分比 bp 整数表（Σ 恒 10000），
  /// 自动归一（Σ≠100% 时按比例缩放，不报错）。
  percent,

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

/// 想去池条目（WishlistItems 表镜像，V2.7.2 S1 登记 10）。
///
/// 条目**无日期**——这是与 Plan B 备选卡（已挂日期）的唯一分界线；
/// 落卡即从池中移除，不存在两边同时持有。
class WishlistRecord {
  const WishlistRecord({
    required this.id,
    required this.tripId,
    this.cityKey = '',
    this.name = '',
    this.address = '',
    this.type = 'attraction',
    this.durationMin,
    this.tag,
    this.guideRef,
    this.note = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tripId;

  /// 攻略城 key；手动条目为 ''
  final String cityKey;
  final String name;
  final String address;

  /// attraction|food|transport|stay|note（五类同 TripItems）
  final String type;

  /// null = 未估时（参与装配前需补时长）
  final int? durationMin;

  /// 必去/经典/小众/亲子（可空）
  final String? tag;

  /// 攻略弱关联 "<cityKey>#<栏>#<序号>"（可空）
  final String? guideRef;
  final String note;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  WishlistRecord copyWith({
    String? cityKey,
    String? name,
    String? address,
    String? type,
    int? durationMin,
    Object? tag = _unset,
    Object? guideRef = _unset,
    String? note,
    int? sortOrder,
    int? updatedAt,
  }) =>
      WishlistRecord(
        id: id,
        tripId: tripId,
        cityKey: cityKey ?? this.cityKey,
        name: name ?? this.name,
        address: address ?? this.address,
        type: type ?? this.type,
        durationMin: durationMin ?? this.durationMin,
        tag: tag == _unset ? this.tag : tag as String?,
        guideRef: guideRef == _unset ? this.guideRef : guideRef as String?,
        note: note ?? this.note,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WishlistRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 分类子预算（SubBudgets 表镜像，V2.8.1 S8 全量同步登记）。
///
/// 团级实体（与公款池同级），独立于总预算口径（groups.budget_cents）；
/// 金额 int 分，LWW 以 updatedAt 为准。
class SubBudgetRecord {
  const SubBudgetRecord({
    required this.id,
    required this.groupId,
    this.categoryKey = '',
    required this.amountCents,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String groupId;

  /// 内置分类 key 或自定义分类 id；空串兜底按「其他」处理
  final String categoryKey;

  /// 子预算金额（分，恒为正整数）
  final int amountCents;
  final int createdAt;
  final int updatedAt;

  SubBudgetRecord copyWith({
    String? categoryKey,
    int? amountCents,
    int? updatedAt,
  }) =>
      SubBudgetRecord(
        id: id,
        groupId: groupId,
        categoryKey: categoryKey ?? this.categoryKey,
        amountCents: amountCents ?? this.amountCents,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubBudgetRecord &&
          other.id == id &&
          other.groupId == groupId &&
          other.categoryKey == categoryKey &&
          other.amountCents == amountCents &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, groupId, categoryKey, amountCents, createdAt, updatedAt);

  @override
  String toString() =>
      'SubBudgetRecord($id, $groupId, $categoryKey, amountCents=$amountCents)';
}

const Object _unset = Object();

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
    this.fundId,
    this.payMethod,
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

  /// 所属公款池 id（S8；非空即属池）
  final String? fundId;

  /// 支付方式纯标签（S11；NULL = 未标记，不参与净额与分摊）
  final String? payMethod;

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
    Object? fundId = _sentinel,
    Object? payMethod = _sentinel,
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
        fundId: identical(_sentinel, fundId) ? this.fundId : fundId as String?,
        payMethod: identical(_sentinel, payMethod) ? this.payMethod : payMethod as String?,
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
          tripItemId == other.tripItemId &&
          fundId == other.fundId &&
          payMethod == other.payMethod;

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
  const Settlement({required this.id, required this.groupId, required this.status, this.transfers = const [], required this.roundNo, required this.createdAt, this.completedAt, this.strategy = 'minTransfers'});
  final String id, groupId;
  final SettlementStatus status;
  final List<TransferRecord> transfers;
  final int roundNo;
  final int createdAt;
  final int? completedAt;

  /// 本轮所用结算策略（S9）：minTransfers / minParticipants。
  final String strategy;
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

