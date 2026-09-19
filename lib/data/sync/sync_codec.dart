/// 实体行 ↔ 云端列编解码器（本地 drift 行类 ↔ snake_case 云表 map）。
///
/// 口径（V2.6 §3.3.2）：
/// - `updated_ms`：有 updatedAt 列的实体取 updatedAt；Members/Expenses/Settlements
///   无该列，以 createdAt 承载（合流写回时同步写 createdAt，等效 seq 方案）；
/// - Categories 本地无时间戳列，上行时间戳由入队事件提供（见 outbox）；
/// - `*_json` 字段原样字符串传输，不解析不重组；
/// - 金额 int 分原样上行；下行对 refund 行套 `-abs()` 幂等归一（core/money.dart）。
library;
import 'package:drift/drift.dart' show Value;

import '../../data/db/database.dart' as db;
import 'sync_models.dart';

abstract final class SyncCodec {
  // ===== 业务行 → 云列 map（不含 updated_ms/deleted，由信封补齐） =====

  static Map<String, dynamic> tripToCloud(db.Trip r) => {
        'name': r.name,
        'destination': r.destination,
        'emoji': r.emoji,
        'cover': r.cover,
        'start_epoch_day': r.startEpochDay,
        'end_epoch_day': r.endEpochDay,
        'note': r.note,
        'group_id': r.groupId,
        'archived': r.archived,
        // V2.7.2：装配节奏档（relaxed/standard/tight），随整行 LWW。
        'pace': r.pace,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> tripItemToCloud(db.TripItem r) => {
        'trip_id': r.tripId,
        'date_epoch_day': r.dateEpochDay,
        'type': r.type,
        'name': r.name,
        'address': r.address,
        'lat': r.lat,
        'lng': r.lng,
        'photo_uri': r.photoUri,
        'start_time_min': r.startTimeMin,
        'duration_min': r.durationMin,
        'cost_cents': r.costCents,
        'cost_currency': r.costCurrency,
        'note': r.note,
        'from_name': r.fromName,
        'from_address': r.fromAddress,
        'from_lat': r.fromLat,
        'from_lng': r.fromLng,
        'to_name': r.toName,
        'to_address': r.toAddress,
        'to_lat': r.toLat,
        'to_lng': r.toLng,
        'flight_no': r.flightNo,
        'sort_order': r.sortOrder,
        // V2.7.2：攻略弱关联 / Plan B 备选指向（nullable 透传，null 不省略键）。
        'guide_ref': r.guideRef,
        'backup_of': r.backupOf,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> groupToCloud(db.Group r) => {
        'name': r.name,
        'icon': r.icon,
        'budget_enabled': r.budgetEnabled,
        'budget_cents': r.budgetCents,
        'archived': r.archived,
        'archived_at_ms': r.archivedAtMs,
        'kind': r.kind,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> memberToCloud(db.Member r) => {
        'group_id': r.groupId,
        'name': r.name,
        'color_index': r.colorIndex,
        'archived': r.archived,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> expenseToCloud(db.Expense r) => {
        'group_id': r.groupId,
        'date_epoch_day': r.dateEpochDay,
        'title': r.title,
        'category_key': r.categoryKey,
        'type': r.type,
        'amount_cents': r.amountCents,
        'currency': r.currency,
        'rate': r.rate,
        'amount_foreign_cents': r.amountForeignCents,
        'payers_json': r.payersJson,
        'shares_json': r.sharesJson,
        'share_mode': r.shareMode,
        'portions_json': r.portionsJson,
        'note': r.note,
        'settled_round_id': r.settledRoundId,
        'trip_id': r.tripId,
        'trip_item_id': r.tripItemId,
        'fund_id': r.fundId,
        'pay_method': r.payMethod,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> settlementToCloud(db.Settlement r) => {
        'group_id': r.groupId,
        'status': r.status,
        'transfers_json': r.transfersJson,
        'expense_ids_json': r.expenseIdsJson,
        'round_no': r.roundNo,
        'strategy': r.strategy,
        'created_ms': r.createdAt,
      };

  // ===== V2.7.1 公款池 / 记账收件箱 =====

  static Map<String, dynamic> fundToCloud(db.Fund r) => {
        'group_id': r.groupId,
        'name': r.name,
        'manager_member_id': r.managerMemberId,
        'target_cents': r.targetCents,
        'status': r.status,
        'created_ms': r.createdAt,
        'updated_ms': r.updatedAt,
      };

  static Map<String, dynamic> inboxItemToCloud(db.InboxItem r) => {
        'group_id': r.groupId,
        'amount_cents': r.amountCents,
        'note': r.note,
        'captured_ms': r.capturedAt,
        'source': r.source,
        'status': r.status,
        'converted_expense_id': r.convertedExpenseId,
        'created_ms': r.createdAt,
        'updated_ms': r.updatedAt,
      };

  // ===== V2.8.1 分类子预算（团级；列名与 docs/db_v281.sql 云表对齐） =====

  static Map<String, dynamic> subBudgetToCloud(db.SubBudget r) => {
        'group_id': r.groupId,
        'category_key': r.categoryKey,
        'amount': r.amount, // int 分，原样上行
        'created_ms': r.createdAt,
        'updated_ms': r.updatedAt,
      };

  // ===== V2.7.2 想去池 =====

  static Map<String, dynamic> wishlistItemToCloud(db.WishlistItem r) => {
        'trip_id': r.tripId,
        'city_key': r.cityKey,
        'name': r.name,
        'address': r.address,
        'type': r.type,
        'duration_min': r.durationMin,
        'tag': r.tag,
        'guide_ref': r.guideRef,
        'note': r.note,
        'sort_order': r.sortOrder,
        'created_ms': r.createdAt,
        'updated_ms': r.updatedAt,
      };

  /// 本地 Categories 表无时间戳列，故此处不产出 `created_ms`；
  /// 该列由信封以入队事件时点补齐（SyncEnvelope.toCloudJson，口径见 §3.3.2）。
  static Map<String, dynamic> categoryToCloud(db.Category r) => {
        'name': r.name,
        'icon': r.icon,
        'builtin': r.builtin,
      };

  // ===== V2.6.6.2 旅伴空间三实体 =====

  static Map<String, dynamic> spaceToCloud(db.TravelSpace r) => {
        'name': r.name,
        'trip_id': r.tripId,
        'group_id': r.groupId,
        'created_by': r.createdBy,
        'note': r.note,
        'status': r.status,
        'created_ms': r.createdMs,
      };

  static Map<String, dynamic> spaceMemberToCloud(db.SpaceMember r) => {
        'space_id': r.spaceId,
        'user_id': r.userId,
        'role': r.role,
        'display_name': r.displayName,
        'joined_ms': r.joinedMs,
        'created_ms': r.createdMs,
      };

  /// 动态流是 append-only：`updated_ms` 恒等 `created_ms`，`deleted` 恒 false。
  static Map<String, dynamic> spaceEventToCloud(db.SpaceEvent r) => {
        'space_id': r.spaceId,
        'actor_user': r.actorUser,
        'action': r.action,
        'entity_kind': r.entityKind,
        'entity_id': r.entityId,
        'summary': r.summary,
        'created_ms': r.createdMs,
        'updated_ms': r.updatedMs,
      };

  // ===== 本地行有效 updatedMs（与云端同口径） =====

  static int rowUpdatedMs(SyncEntity entity, dynamic row) {
    // 受邀端镜像表与业务表「列同构但类型不同」（SharedGroup ≠ Group）。
    // 早期实现直接 `row as db.Group`：合流命中镜像行时抛 TypeError → 整页 pull
    // 失败（`SyncPuller.pull` 的 try 包住整页事务），共享账本的更新与软删都下不来。
    // 这里按运行期类型分派，顺带修掉这个潜伏缺陷。
    if (row is db.SharedGroup) return row.updatedAt;
    if (row is db.SharedMember) return row.createdAt;
    if (row is db.SharedExpense) return row.createdAt;
    if (row is db.SharedSettlement) return row.createdAt;
    if (row is db.SharedTrip) return row.updatedAt;
    if (row is db.SharedTripItem) return row.updatedAt;
    if (row is db.SharedWishlistItem) return row.updatedAt;
    if (row is db.WishlistItem) return row.updatedAt;
    if (row is db.TravelSpace) return row.updatedMs;
    if (row is db.SpaceMember) return row.updatedMs;
    if (row is db.SpaceEvent) return row.updatedMs;
    if (row is db.Fund) return row.updatedAt;
    if (row is db.InboxItem) return row.updatedAt;
    if (row is db.SubBudget) return row.updatedAt;
    switch (entity) {
      case SyncEntity.trips:
        return (row as db.Trip).updatedAt;
      case SyncEntity.tripItems:
        return (row as db.TripItem).updatedAt;
      case SyncEntity.wishlistItems:
        return (row as db.WishlistItem).updatedAt;
      case SyncEntity.groups:
        return (row as db.Group).updatedAt;
      case SyncEntity.members:
        return (row as db.Member).createdAt;
      case SyncEntity.funds:
        return (row as db.Fund).updatedAt;
      case SyncEntity.inboxItems:
        return (row as db.InboxItem).updatedAt;
      case SyncEntity.subBudgets:
        return (row as db.SubBudget).updatedAt;
      case SyncEntity.expenses:
        return (row as db.Expense).createdAt;
      case SyncEntity.settlements:
        return (row as db.Settlement).createdAt;
      case SyncEntity.categories:
        return 0; // Categories 无本地时间戳；由 outbox pending 事件时间承担（见 merger）
      case SyncEntity.spaces:
      case SyncEntity.spaceMembers:
      case SyncEntity.spaceEvents:
        return 0; // 上面已按运行期类型分派，走到这里说明是未知行
    }
  }

  // ===== 云端行 → 本地 Companion（下行落库） =====

  static int _ms(Map<String, dynamic> m) => (m['updated_ms'] as num?)?.toInt() ?? 0;

  static db.TripsCompanion tripFromCloud(Map<String, dynamic> m) => db.TripsCompanion.insert(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        destination: Value((m['destination'] as String?) ?? ''),
        emoji: Value((m['emoji'] as String?) ?? '✈️'),
        cover: Value((m['cover'] as String?) ?? 'ocean'),
        startEpochDay: Value((m['start_epoch_day'] as num?)?.toInt() ?? 0),
        endEpochDay: Value((m['end_epoch_day'] as num?)?.toInt() ?? 0),
        note: Value((m['note'] as String?) ?? ''),
        groupId: Value(m['group_id'] as String?),
        archived: Value((m['archived'] as bool?) ?? false),
        pace: Value((m['pace'] as String?) ?? 'standard'),
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  static db.TripItemsCompanion tripItemFromCloud(Map<String, dynamic> m) =>
      db.TripItemsCompanion.insert(
        id: m['id'] as String,
        tripId: (m['trip_id'] as String?) ?? '',
        dateEpochDay: Value((m['date_epoch_day'] as num?)?.toInt() ?? 0),
        type: Value((m['type'] as String?) ?? 'attraction'),
        name: Value((m['name'] as String?) ?? ''),
        address: Value((m['address'] as String?) ?? ''),
        lat: Value((m['lat'] as num?)?.toDouble()),
        lng: Value((m['lng'] as num?)?.toDouble()),
        photoUri: Value(m['photo_uri'] as String?),
        startTimeMin: Value((m['start_time_min'] as num?)?.toInt()),
        durationMin: Value((m['duration_min'] as num?)?.toInt()),
        costCents: Value((m['cost_cents'] as num?)?.toInt()),
        costCurrency: Value((m['cost_currency'] as String?) ?? 'CNY'),
        note: Value((m['note'] as String?) ?? ''),
        fromName: Value((m['from_name'] as String?) ?? ''),
        fromAddress: Value((m['from_address'] as String?) ?? ''),
        fromLat: Value((m['from_lat'] as num?)?.toDouble()),
        fromLng: Value((m['from_lng'] as num?)?.toDouble()),
        toName: Value((m['to_name'] as String?) ?? ''),
        toAddress: Value((m['to_address'] as String?) ?? ''),
        toLat: Value((m['to_lat'] as num?)?.toDouble()),
        toLng: Value((m['to_lng'] as num?)?.toDouble()),
        flightNo: Value(m['flight_no'] as String?),
        sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
        guideRef: Value(m['guide_ref'] as String?),
        backupOf: Value(m['backup_of'] as String?),
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  static db.GroupsCompanion groupFromCloud(Map<String, dynamic> m) => db.GroupsCompanion.insert(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        icon: Value((m['icon'] as String?) ?? '📁'),
        budgetEnabled: Value((m['budget_enabled'] as bool?) ?? false),
        budgetCents: Value((m['budget_cents'] as num?)?.toInt()),
        archived: Value((m['archived'] as bool?) ?? false),
        archivedAtMs: Value((m['archived_at_ms'] as num?)?.toInt()),
        kind: Value((m['kind'] as String?) ?? 'travel'),
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  static db.MembersCompanion memberFromCloud(Map<String, dynamic> m) => db.MembersCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        colorIndex: Value((m['color_index'] as num?)?.toInt() ?? 0),
        archived: Value((m['archived'] as bool?) ?? false),
        createdAt: _ms(m),
      );

  static db.ExpensesCompanion expenseFromCloud(Map<String, dynamic> m) {
    final type = (m['type'] as String?) ?? 'normal';
    final raw = (m['amount_cents'] as num?)?.toInt() ?? 0;
    return db.ExpensesCompanion.insert(
      id: m['id'] as String,
      groupId: (m['group_id'] as String?) ?? '',
      dateEpochDay: Value((m['date_epoch_day'] as num?)?.toInt() ?? 0),
      title: Value((m['title'] as String?) ?? ''),
      categoryKey: Value((m['category_key'] as String?) ?? 'other'),
      type: Value(type),
      amountCents: Value(normalizeAmountCents(raw, type)),
      currency: Value((m['currency'] as String?) ?? 'CNY'),
      rate: Value((m['rate'] as num?)?.toDouble() ?? 1.0),
      amountForeignCents: Value((m['amount_foreign_cents'] as num?)?.toInt()),
      payersJson: Value((m['payers_json'] as String?) ?? '[]'),
      sharesJson: Value((m['shares_json'] as String?) ?? '[]'),
      shareMode: Value((m['share_mode'] as String?) ?? 'equal'),
      portionsJson: Value(m['portions_json'] as String?),
      note: Value((m['note'] as String?) ?? ''),
      settledRoundId: Value(m['settled_round_id'] as String?),
      tripId: Value(m['trip_id'] as String?),
      tripItemId: Value(m['trip_item_id'] as String?),
      fundId: Value(m['fund_id'] as String?),
      payMethod: Value(m['pay_method'] as String?),
      createdAt: _ms(m),
    );
  }

  static db.SettlementsCompanion settlementFromCloud(Map<String, dynamic> m) =>
      db.SettlementsCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        status: Value((m['status'] as String?) ?? 'active'),
        transfersJson: Value((m['transfers_json'] as String?) ?? '[]'),
        expenseIdsJson: Value((m['expense_ids_json'] as String?) ?? '[]'),
        roundNo: Value((m['round_no'] as num?)?.toInt() ?? 1),
        strategy: Value((m['strategy'] as String?) ?? 'minTransfers'),
        createdAt: _ms(m),
      );

  static db.FundsCompanion fundFromCloud(Map<String, dynamic> m) =>
      db.FundsCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '公款池',
        managerMemberId: (m['manager_member_id'] as String?) ?? '',
        targetCents: Value((m['target_cents'] as num?)?.toInt()),
        status: Value((m['status'] as String?) ?? 'open'),
        createdAt: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedAt: _ms(m),
      );

  static db.InboxItemsCompanion inboxItemFromCloud(Map<String, dynamic> m) =>
      db.InboxItemsCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        amountCents: Value((m['amount_cents'] as num?)?.toInt() ?? 0),
        note: Value(m['note'] as String?),
        capturedAt: (m['captured_ms'] as num?)?.toInt() ?? _ms(m),
        source: Value((m['source'] as String?) ?? 'manual'),
        status: Value((m['status'] as String?) ?? 'pending'),
        convertedExpenseId: Value(m['converted_expense_id'] as String?),
        createdAt: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedAt: _ms(m),
      );

  // ===== V2.8.1 分类子预算（下行落库） =====

  static db.SubBudgetsCompanion subBudgetFromCloud(Map<String, dynamic> m) =>
      db.SubBudgetsCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        categoryKey: Value((m['category_key'] as String?) ?? ''),
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        createdAt: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedAt: _ms(m),
      );

  static db.CategoriesCompanion categoryFromCloud(Map<String, dynamic> m) =>
      db.CategoriesCompanion.insert(
        key: m['key'] as String,
        name: Value((m['name'] as String?) ?? ''),
        icon: Value((m['icon'] as String?) ?? '📦'),
        builtin: Value((m['builtin'] as bool?) ?? false),
      );

  // ===== V2.6.6.2 旅伴空间三实体（下行落库） =====

  static db.TravelSpacesCompanion spaceFromCloud(Map<String, dynamic> m) =>
      db.TravelSpacesCompanion.insert(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        tripId: Value(m['trip_id'] as String?),
        groupId: Value(m['group_id'] as String?),
        createdBy: (m['created_by'] as String?) ?? '',
        note: Value(m['note'] as String?),
        status: Value((m['status'] as String?) ?? 'active'),
        createdMs: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedMs: _ms(m),
        deletedMs: Value((m['deleted_ms'] as num?)?.toInt()),
      );

  static db.SpaceMembersCompanion spaceMemberFromCloud(Map<String, dynamic> m) =>
      db.SpaceMembersCompanion.insert(
        id: m['id'] as String,
        spaceId: (m['space_id'] as String?) ?? '',
        userId: (m['user_id'] as String?) ?? '',
        role: Value((m['role'] as String?) ?? 'viewer'),
        displayName: Value((m['display_name'] as String?) ?? '旅伴'),
        joinedMs: (m['joined_ms'] as num?)?.toInt() ?? _ms(m),
        createdMs: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedMs: _ms(m),
        deletedMs: Value((m['deleted_ms'] as num?)?.toInt()),
      );

  static db.SpaceEventsCompanion spaceEventFromCloud(Map<String, dynamic> m) =>
      db.SpaceEventsCompanion.insert(
        id: m['id'] as String,
        spaceId: (m['space_id'] as String?) ?? '',
        actorUser: (m['actor_user'] as String?) ?? '',
        action: (m['action'] as String?) ?? '',
        entityKind: (m['entity_kind'] as String?) ?? 'space',
        entityId: Value(m['entity_id'] as String?),
        summary: Value((m['summary'] as String?) ?? ''),
        createdMs: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedMs: _ms(m),
      );

  // ===== 共享镜像表 Companion（受邀端；列与业务表一致） =====

  static db.SharedGroupsCompanion sharedGroupFromCloud(Map<String, dynamic> m) =>
      db.SharedGroupsCompanion.insert(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        icon: Value((m['icon'] as String?) ?? '📁'),
        budgetEnabled: Value((m['budget_enabled'] as bool?) ?? false),
        budgetCents: Value((m['budget_cents'] as num?)?.toInt()),
        archived: Value((m['archived'] as bool?) ?? false),
        archivedAtMs: Value((m['archived_at_ms'] as num?)?.toInt()),
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  static db.SharedMembersCompanion sharedMemberFromCloud(Map<String, dynamic> m) =>
      db.SharedMembersCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        colorIndex: Value((m['color_index'] as num?)?.toInt() ?? 0),
        createdAt: _ms(m),
      );

  static db.SharedExpensesCompanion sharedExpenseFromCloud(Map<String, dynamic> m) {
    final type = (m['type'] as String?) ?? 'normal';
    final raw = (m['amount_cents'] as num?)?.toInt() ?? 0;
    return db.SharedExpensesCompanion.insert(
      id: m['id'] as String,
      groupId: (m['group_id'] as String?) ?? '',
      dateEpochDay: Value((m['date_epoch_day'] as num?)?.toInt() ?? 0),
      title: Value((m['title'] as String?) ?? ''),
      categoryKey: Value((m['category_key'] as String?) ?? 'other'),
      type: Value(type),
      amountCents: Value(normalizeAmountCents(raw, type)),
      currency: Value((m['currency'] as String?) ?? 'CNY'),
      rate: Value((m['rate'] as num?)?.toDouble() ?? 1.0),
      amountForeignCents: Value((m['amount_foreign_cents'] as num?)?.toInt()),
      payersJson: Value((m['payers_json'] as String?) ?? '[]'),
      sharesJson: Value((m['shares_json'] as String?) ?? '[]'),
      shareMode: Value((m['share_mode'] as String?) ?? 'equal'),
      portionsJson: Value(m['portions_json'] as String?),
      note: Value((m['note'] as String?) ?? ''),
      settledRoundId: Value(m['settled_round_id'] as String?),
      tripId: Value(m['trip_id'] as String?),
      tripItemId: Value(m['trip_item_id'] as String?),
      createdAt: _ms(m),
    );
  }

  static db.SharedSettlementsCompanion sharedSettlementFromCloud(Map<String, dynamic> m) =>
      db.SharedSettlementsCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        status: Value((m['status'] as String?) ?? 'active'),
        transfersJson: Value((m['transfers_json'] as String?) ?? '[]'),
        expenseIdsJson: Value((m['expense_ids_json'] as String?) ?? '[]'),
        roundNo: Value((m['round_no'] as num?)?.toInt() ?? 1),
        createdAt: _ms(m),
      );

  // ===== 受邀协作行程镜像（他人的行程 / 行程项，列与业务表一致） =====

  static db.SharedTripsCompanion sharedTripFromCloud(Map<String, dynamic> m) =>
      db.SharedTripsCompanion.insert(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        destination: Value((m['destination'] as String?) ?? ''),
        emoji: Value((m['emoji'] as String?) ?? '✈️'),
        cover: Value((m['cover'] as String?) ?? 'ocean'),
        startEpochDay: Value((m['start_epoch_day'] as num?)?.toInt() ?? 0),
        endEpochDay: Value((m['end_epoch_day'] as num?)?.toInt() ?? 0),
        note: Value((m['note'] as String?) ?? ''),
        groupId: Value(m['group_id'] as String?),
        archived: Value((m['archived'] as bool?) ?? false),
        pace: Value((m['pace'] as String?) ?? 'standard'),
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  static db.SharedTripItemsCompanion sharedTripItemFromCloud(Map<String, dynamic> m) =>
      db.SharedTripItemsCompanion.insert(
        id: m['id'] as String,
        tripId: (m['trip_id'] as String?) ?? '',
        dateEpochDay: Value((m['date_epoch_day'] as num?)?.toInt() ?? 0),
        type: Value((m['type'] as String?) ?? 'attraction'),
        name: Value((m['name'] as String?) ?? ''),
        address: Value((m['address'] as String?) ?? ''),
        lat: Value((m['lat'] as num?)?.toDouble()),
        lng: Value((m['lng'] as num?)?.toDouble()),
        photoUri: Value(m['photo_uri'] as String?),
        startTimeMin: Value((m['start_time_min'] as num?)?.toInt()),
        durationMin: Value((m['duration_min'] as num?)?.toInt()),
        costCents: Value((m['cost_cents'] as num?)?.toInt()),
        costCurrency: Value((m['cost_currency'] as String?) ?? 'CNY'),
        note: Value((m['note'] as String?) ?? ''),
        fromName: Value((m['from_name'] as String?) ?? ''),
        fromAddress: Value((m['from_address'] as String?) ?? ''),
        fromLat: Value((m['from_lat'] as num?)?.toDouble()),
        fromLng: Value((m['from_lng'] as num?)?.toDouble()),
        toName: Value((m['to_name'] as String?) ?? ''),
        toAddress: Value((m['to_address'] as String?) ?? ''),
        toLat: Value((m['to_lat'] as num?)?.toDouble()),
        toLng: Value((m['to_lng'] as num?)?.toDouble()),
        flightNo: Value(m['flight_no'] as String?),
        sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
        guideRef: Value(m['guide_ref'] as String?),
        backupOf: Value(m['backup_of'] as String?),
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  // ===== V2.7.2 想去池（下行落库：业务表 + 受邀端镜像表） =====

  static db.WishlistItemsCompanion wishlistItemFromCloud(Map<String, dynamic> m) =>
      db.WishlistItemsCompanion.insert(
        id: m['id'] as String,
        tripId: (m['trip_id'] as String?) ?? '',
        cityKey: Value((m['city_key'] as String?) ?? ''),
        name: Value((m['name'] as String?) ?? ''),
        address: Value((m['address'] as String?) ?? ''),
        type: Value((m['type'] as String?) ?? 'attraction'),
        durationMin: Value((m['duration_min'] as num?)?.toInt()),
        tag: Value(m['tag'] as String?),
        guideRef: Value(m['guide_ref'] as String?),
        note: Value((m['note'] as String?) ?? ''),
        sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
        createdAt: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedAt: _ms(m),
      );

  static db.SharedWishlistItemsCompanion sharedWishlistItemFromCloud(
          Map<String, dynamic> m) =>
      db.SharedWishlistItemsCompanion.insert(
        id: m['id'] as String,
        tripId: (m['trip_id'] as String?) ?? '',
        cityKey: Value((m['city_key'] as String?) ?? ''),
        name: Value((m['name'] as String?) ?? ''),
        address: Value((m['address'] as String?) ?? ''),
        type: Value((m['type'] as String?) ?? 'attraction'),
        durationMin: Value((m['duration_min'] as num?)?.toInt()),
        tag: Value(m['tag'] as String?),
        guideRef: Value(m['guide_ref'] as String?),
        note: Value((m['note'] as String?) ?? ''),
        sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
        createdAt: (m['created_ms'] as num?)?.toInt() ?? _ms(m),
        updatedAt: _ms(m),
      );

  /// 金额下行归一：refund 一律 `-abs()`（幂等）；其余保持原值（正常账单正数）。
  static int normalizeAmountCents(int cents, String type) =>
      type == 'refund' ? -cents.abs() : cents;
}
