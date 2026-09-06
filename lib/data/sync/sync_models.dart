/// 同步层基础模型：实体枚举、outbox 操作、上行信封。
///
/// 数据口径契约（V2.6 §3.11）：
/// - 金额一律 int 分（refund 为负）；JSON 字段原样字符串；时间戳 int 毫秒；
/// - `updatedMs` 与本地 `updatedAt/createdAt` 同源（无 updatedAt 列的实体以
///   createdAt 承载，见 sync_merger.dart 头注）。
library;

/// 同步实体（含受邀端共享镜像）。云表名见 [cloudTable]。
enum SyncEntity {
  trips('trips_sync'),
  tripItems('trip_items_sync'),
  groups('groups_sync'),
  members('members_sync'),
  expenses('expenses_sync'),
  settlements('settlements_sync'),
  categories('categories_sync');

  const SyncEntity(this.cloudTable);
  final String cloudTable;

  /// 固定拉取顺序（父实体先行）：账本域 → 行程域 → 字典。
  static const List<SyncEntity> pullOrder = [
    SyncEntity.groups,
    SyncEntity.members,
    SyncEntity.expenses,
    SyncEntity.settlements,
    SyncEntity.trips,
    SyncEntity.tripItems,
    SyncEntity.categories,
  ];

  /// 该实体的本地行 id 列名（categories 主键是 key）。
  String get idColumn => this == SyncEntity.categories ? 'key' : 'id';
}

/// 上行操作语义：本地行当前存在 → upsert；已被删除 → delete（云端标 deleted=true）。
enum SyncOutboxOp { upsert, delete }

/// 上行单行信封：与云表列对齐的 map + 事件时点时间戳。
class SyncEnvelope {
  SyncEnvelope({
    required this.entity,
    required this.rowId,
    required this.op,
    required this.updatedMs,
    this.row = const {},
  });

  final SyncEntity entity;
  final String rowId;
  final SyncOutboxOp op;

  /// 事件时点（入队时刻），push 时作为 updated_ms 上行，不重读时钟。
  final int updatedMs;

  /// 业务列（snake_case，与云表列对齐）；op=delete 时可省略。
  final Map<String, dynamic> row;

  /// 发往云端的最终权重：delete 只带 id/updated_ms/deleted。
  Map<String, dynamic> toCloudJson() {
    if (op == SyncOutboxOp.delete) {
      return {
        entity.idColumn: rowId,
        'updated_ms': updatedMs,
        'deleted': true,
      };
    }
    return {
      ...row,
      entity.idColumn: rowId,
      'updated_ms': updatedMs,
      'deleted': false,
    };
  }
}

/// 同步状态机（V2.6 §3.8）：unconfigured → signedOut → syncing → idle/offline。
enum SyncStatusKind { unconfigured, signedOut, syncing, idle, offline }

class SyncStatus {
  const SyncStatus({
    required this.kind,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.lastError,
    this.lastErrorAt,
  });

  final SyncStatusKind kind;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastErrorAt;

  SyncStatus copyWith({
    SyncStatusKind? kind,
    DateTime? lastSyncedAt,
    int? pendingCount,
    String? lastError,
    DateTime? lastErrorAt,
    bool clearError = false,
  }) =>
      SyncStatus(
        kind: kind ?? this.kind,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pendingCount: pendingCount ?? this.pendingCount,
        lastError: clearError ? null : (lastError ?? this.lastError),
        lastErrorAt: clearError ? null : (lastErrorAt ?? this.lastErrorAt),
      );
}
