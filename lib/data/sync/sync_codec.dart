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
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> groupToCloud(db.Group r) => {
        'name': r.name,
        'icon': r.icon,
        'budget_enabled': r.budgetEnabled,
        'budget_cents': r.budgetCents,
        'archived': r.archived,
        'archived_at_ms': r.archivedAtMs,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> memberToCloud(db.Member r) => {
        'group_id': r.groupId,
        'name': r.name,
        'color_index': r.colorIndex,
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
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> settlementToCloud(db.Settlement r) => {
        'group_id': r.groupId,
        'status': r.status,
        'transfers_json': r.transfersJson,
        'expense_ids_json': r.expenseIdsJson,
        'round_no': r.roundNo,
        'created_ms': r.createdAt,
      };

  static Map<String, dynamic> categoryToCloud(db.Category r) => {
        'name': r.name,
        'icon': r.icon,
        'builtin': r.builtin,
      };

  // ===== 本地行有效 updatedMs（与云端同口径） =====

  static int rowUpdatedMs(SyncEntity entity, dynamic row) {
    switch (entity) {
      case SyncEntity.trips:
        return (row as db.Trip).updatedAt;
      case SyncEntity.tripItems:
        return (row as db.TripItem).updatedAt;
      case SyncEntity.groups:
        return (row as db.Group).updatedAt;
      case SyncEntity.members:
        return (row as db.Member).createdAt;
      case SyncEntity.expenses:
        return (row as db.Expense).createdAt;
      case SyncEntity.settlements:
        return (row as db.Settlement).createdAt;
      case SyncEntity.categories:
        return 0; // Categories 无本地时间戳；由 outbox pending 事件时间承担（见 merger）
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
        createdAt: _ms(m),
        updatedAt: _ms(m),
      );

  static db.MembersCompanion memberFromCloud(Map<String, dynamic> m) => db.MembersCompanion.insert(
        id: m['id'] as String,
        groupId: (m['group_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        colorIndex: Value((m['color_index'] as num?)?.toInt() ?? 0),
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
        createdAt: _ms(m),
      );

  static db.CategoriesCompanion categoryFromCloud(Map<String, dynamic> m) =>
      db.CategoriesCompanion.insert(
        key: m['key'] as String,
        name: Value((m['name'] as String?) ?? ''),
        icon: Value((m['icon'] as String?) ?? '📦'),
        builtin: Value((m['builtin'] as bool?) ?? false),
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

  /// 金额下行归一：refund 一律 `-abs()`（幂等）；其余保持原值（正常账单正数）。
  static int normalizeAmountCents(int cents, String type) =>
      type == 'refund' ? -cents.abs() : cents;
}
