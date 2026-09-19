/// 同步层基础模型：实体枚举、outbox 操作、上行信封。
///
/// 数据口径契约（V2.6 §3.11）：
/// - 金额一律 int 分（refund 为负）；JSON 字段原样字符串；时间戳 int 毫秒；
/// - `updatedMs` 与本地 `updatedAt/createdAt` 同源（无 updatedAt 列的实体以
///   createdAt 承载，见 sync_merger.dart 头注）。
library;

/// 同步实体（含受邀端共享镜像）。云表名见 [cloudTable]。
enum SyncEntity {
  // ===== V2.6.6.2 旅伴空间（父实体先行：spaces → spaceMembers → spaceEvents） =====
  spaces('spaces_sync'),
  spaceMembers('space_members_sync'),
  spaceEvents('space_events_sync'),
  // ===== V2.6 账本/行程域 =====
  trips('trips_sync'),
  tripItems('trip_items_sync'),
  groups('groups_sync'),
  members('members_sync'),
  // V2.7.1：公款池 / 记账收件箱（均随团开关，父实体 group/members 先行）
  funds('funds_sync'),
  inboxItems('inbox_items_sync'),
  expenses('expenses_sync'),
  settlements('settlements_sync'),
  // V2.8.1：分类子预算（团级账本域，随团开关；非协作镜像，无 Shared 变体）
  subBudgets('sub_budgets_sync'),
  // V2.7.2：想去池（随行程开关，父实体 trips/tripItems 先行）
  wishlistItems('wishlist_items_sync'),
  categories('categories_sync');

  const SyncEntity(this.cloudTable);
  final String cloudTable;

  /// 固定拉取顺序（父实体先行）：空间域 → 账本域 → 行程域 → 字典。
  ///
  /// 空间域排最前是有意的：`shared_trips` / `shared_trip_items` 的分流判定依赖
  /// 本轮协作上下文（`list_my_spaces`），先落空间行能让「刚加入就拉行程」的
  /// 同一轮里 trip/trip_item 有归属可依。
  static const List<SyncEntity> pullOrder = [
    SyncEntity.spaces,
    SyncEntity.spaceMembers,
    SyncEntity.spaceEvents,
    SyncEntity.groups,
    SyncEntity.members,
    // V2.7.1：funds 先于 expenses（expenses.fund_id 引用 funds 行），
    // inbox_items 与 funds 同级，均属账本域。
    SyncEntity.funds,
    SyncEntity.inboxItems,
    SyncEntity.expenses,
    SyncEntity.settlements,
    // V2.8.1：分类子预算属团级账本域，拉取序放团域尾部（settlements 之后、
    // trips 之前）：行内 group_id 引用团，需在团/成员之后落库。
    SyncEntity.subBudgets,
    SyncEntity.trips,
    SyncEntity.tripItems,
    // V2.7.2：想去池在行程项之后拉（行内 trip_id 引用行程，LWW 无外键强约束，
    // 但保持父先子后的一致读序）
    SyncEntity.wishlistItems,
    SyncEntity.categories,
  ];

  /// 该实体的本地行 id 列名（categories 主键是 key）。
  String get idColumn => this == SyncEntity.categories ? 'key' : 'id';

  /// 本地实体键（snake_case）：发件箱 `entity` 列、`sync_meta` 游标键、
  /// 仓库层 `SyncOutboxService.notifyWrite(...)`、上云开关判定 **一律**用此键。
  ///
  /// ⚠️ 不要用 [name] 当本地键：Dart 枚举名取自标识符，`tripItems` 的 [name]
  /// 是 `tripItems`，而全仓库（仓储写路径 / db_access / 引擎闸门 / 同步中心
  /// 计数）都写 `trip_items`。历史 bug H10：上行装配 `_resolveEntity` 按
  /// [name] 匹配 → `trip_items` 匹配失败 → 该行被当作脏数据静默清理，
  /// **行程安排永远上不了云**（且没有任何报错，用户只看到数据不同步）。
  ///
  /// V2.6.6.2 同理：本地表名是 `travel_spaces` / `space_members` /
  /// `space_events`，而枚举名是 `spaces` / `spaceMembers` / `spaceEvents`，
  /// 必须在这里显式映射（并由 test/sync/space_entity_key_test.dart 断言钉死）。
  String get localKey => switch (this) {
        SyncEntity.tripItems => 'trip_items',
        SyncEntity.spaces => 'travel_spaces',
        SyncEntity.spaceMembers => 'space_members',
        SyncEntity.spaceEvents => 'space_events',
        // V2.7.1 显式映射，不做隐式依赖：inboxItems 的枚举名是 `inboxItems`
        // 而全仓本地键是 `inbox_items`（H10 同款静默丢数据风险）；funds 的
        // name 恰为 'funds'，仍显式写出以钉死契约。
        SyncEntity.inboxItems => 'inbox_items',
        SyncEntity.funds => 'funds',
        // V2.7.2：枚举名是 `wishlistItems`，本地表名/全仓写路径键是
        // `wishlist_items`——不映射将复现 H10 同款静默丢数据。
        SyncEntity.wishlistItems => 'wishlist_items',
        // V2.8.1：枚举名是 `subBudgets`，本地表名/全仓写路径键是
        // `sub_budgets`——不映射将复现 H10 同款静默丢数据。
        SyncEntity.subBudgets => 'sub_budgets',
        _ => name,
      };

  /// 由本地键反查实体；未知键返回 null（脏数据 / 迁移残留）。
  static SyncEntity? byLocalKey(String key) {
    for (final s in SyncEntity.values) {
      // 兼容 [name]：修复 H10 之前合流层曾用 `tripItems` 入队，
      // 旧库可能残留该键的行，按 name 也认出来避免被当脏数据丢弃。
      if (s.localKey == key || s.name == key) return s;
    }
    return null;
  }

  /// 该实体是否走「受邀协作镜像表」（拉下来的行不属于我，落镜像而非业务表）。
  /// V2.7.2：wishlistItems 与 trips/tripItems 同走受邀镜像（SharedWishlistItems）。
  bool get isCollabMirror =>
      this == SyncEntity.trips ||
      this == SyncEntity.tripItems ||
      this == SyncEntity.wishlistItems;
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
    final payload = Map<String, dynamic>.from(row);
    // `created_ms` 在所有云表都是 not null（无默认值），漏传会被 PostgREST 以
    // 23502 拒绝（"null value in column ... violates not-null constraint"），
    // 进而该实体整批失败、8 次后退化成死信——历史 bug：Categories 本地表
    // 无任何时间戳列，`categoryToCloud` 也就漏了这一列，分类同步长期卡死。
    // 兜底口径与 §3.3.2 一致：本地无创建时间的实体，用**入队事件时点**充当
    // 创建时间（行内已有 created_ms 的实体保持原值，不被覆盖）。
    payload.putIfAbsent('created_ms', () => updatedMs);
    return {
      ...payload,
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
