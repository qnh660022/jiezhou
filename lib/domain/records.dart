/// 领域记录类型：drift 行对象的稳定内存镜像（UI 与仓储的唯一接口面）。
///
/// 命名约定：数据库行类由 drift 生成为 Trip/TripItem/Group 等短名，
/// 只在 data 层内部流转；跨层一律使用本文件的 *Record 类型，
/// 由仓储负责映射 —— UI 永不直接 import drift 生成物。
library;

import 'models.dart';

/// 旅行团
class GroupRecord {
  const GroupRecord({
    required this.id,
    required this.name,
    required this.icon,
    required this.budgetEnabled,
    this.budgetCents,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// 团图标 emoji
  final String icon;
  final bool budgetEnabled;

  /// 预算（分；未启用时可为 null）
  final int? budgetCents;
  final int createdAt;
}

/// 结算轮状态
enum SettlementStatus {
  /// 进行中
  active,

  /// 已完成（账单已回写 settledRoundId）
  completed,
}

/// 结算单内一笔转账（带逐笔确认状态）
class TransferRecord {
  const TransferRecord({
    required this.from,
    required this.to,
    required this.cents,
    required this.done,
  });

  final String from;
  final String to;

  /// 金额（分，恒为正）
  final int cents;

  /// 是否已人工确认
  final bool done;

  TransferRecord copyWith({bool? done}) =>
      TransferRecord(from: from, to: to, cents: cents, done: done ?? this.done);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferRecord &&
          from == other.from &&
          to == other.to &&
          cents == other.cents &&
          done == other.done;

  @override
  int get hashCode => Object.hash(from, to, cents, done);
}

/// 结算轮（Settlements 表镜像）
class SettlementRecord {
  const SettlementRecord({
    required this.id,
    required this.groupId,
    required this.status,
    required this.transfers,
    required this.expenseIds,
    required this.roundNo,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String groupId;
  final SettlementStatus status;

  /// 转账方案快照
  final List<TransferRecord> transfers;

  /// 本轮覆盖的账单 id 快照
  final List<String> expenseIds;

  /// 第几轮（从 1 起，按团内递增）
  final int roundNo;
  final int createdAt;

  /// 完成时间（ms；未完成为 null）
  final int? completedAt;
}

/// 行程（Trips 表镜像）
class TripRecord {
  const TripRecord({
    required this.id,
    this.groupId,
    required this.name,
    required this.destination,
    required this.emoji,
    required this.cover,
    required this.startEpochDay,
    required this.endEpochDay,
    this.note,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// 绑定旅行团（可空 = 未关联账本）
  final String? groupId;
  final String name;
  final String destination;
  final String emoji;

  /// 封面渐变 key（ocean/sunset/forest/violet/dusk/dawn，指向 tokens 定义）
  final String cover;
  final int startEpochDay;
  final int endEpochDay;
  final String? note;
  final bool archived;
  final int createdAt;
  final int updatedAt;
}

/// 行程安排（TripItems 表镜像）
class TripItemRecord {
  const TripItemRecord({
    required this.id,
    required this.tripId,
    required this.dateEpochDay,
    required this.type,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.photoUri,
    this.startTimeMin,
    this.durationMin,
    this.costCents,
    this.costCurrency,
    this.note,
    this.fromName,
    this.fromAddress,
    this.fromLat,
    this.fromLng,
    this.toName,
    this.toAddress,
    this.toLat,
    this.toLng,
    this.flightNo,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tripId;
  final int dateEpochDay;

  /// attraction|food|transport|stay|note
  final String type;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? photoUri;

  /// 开始时间（当日分钟数 0..1439）
  final int? startTimeMin;
  final int? durationMin;
  final int? costCents;
  final String? costCurrency;
  final String? note;

  /// 交通卡：始发地四件套
  final String? fromName;
  final String? fromAddress;
  final double? fromLat;
  final double? fromLng;

  /// 交通卡：到达地四件套
  final String? toName;
  final String? toAddress;
  final double? toLat;
  final double? toLng;

  /// 航班号（交通安排可选）
  final String? flightNo;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
}

/// 分类（Categories 表镜像）
class CategoryRecord {
  const CategoryRecord({
    required this.key,
    required this.name,
    required this.icon,
    required this.builtin,
  });

  final String key;
  final String name;
  final String icon;

  /// 内置分类不可删除
  final bool builtin;
}

/// 清单项（ChecklistItems 表镜像）
class ChecklistItemRecord {
  const ChecklistItemRecord({
    required this.id,
    required this.scope,
    this.tripId,
    required this.category,
    required this.text,
    required this.done,
    required this.sortOrder,
  });

  final String id;

  /// trip=行李清单 / global=待办清单
  final String scope;

  /// scope==global 时必须为 null
  final String? tripId;
  final String category;
  final String text;
  final bool done;
  final int sortOrder;
}
