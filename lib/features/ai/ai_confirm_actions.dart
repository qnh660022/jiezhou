/// AI 确认卡「确认后」的本地落库注册表：不发任何 AI 请求、零 token。
///
/// 敏感操作（删除/改账单/改预算/改日期/批量建行程/删成员/应用模板）由执行器
/// 产出 `action_confirm` 确认卡，用户点确认后统一走 [commitAiAction]。
library;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/uid.dart';
import '../../data/db/database.dart' hide Settlement;
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../ledger/ledger_models.dart';
import '../ledger/ledger_providers.dart';
import '../trips/trip_template_store.dart';
import 'ai_tools.dart' show epochDayFromArg, hhmmToMin, findTripItemTypeOf;

/// 确认卡动作分发：返回 null 表示成功，否则为错误文案。
Future<String?> commitAiAction(
  WidgetRef ref,
  String action,
  Map<String, dynamic> args,
) async {
  switch (action) {
    case 'delete_expense':
      return _deleteExpense(ref, args);
    case 'update_expense':
      return _updateExpense(ref, args);
    case 'delete_trip_item':
      return _deleteTripItem(ref, args);
    case 'remove_member':
      return _removeMember(ref, args);
    case 'set_group_budget':
      return _setGroupBudget(ref, args);
    case 'update_trip_dates':
      return _updateTripDates(ref, args);
    case 'create_trip_plan':
      return _createTripPlan(ref, args);
    case 'apply_trip_template':
      return _applyTripTemplate(ref, args);
    default:
      return '未知的确认动作：$action';
  }
}

// ---------------------------------------------------------------------------
// 账单
// ---------------------------------------------------------------------------

Future<String?> _deleteExpense(WidgetRef ref, Map<String, dynamic> args) async {
  final id = args['expenseId'] as String? ?? '';
  if (id.isEmpty) return '缺少账单 id';
  await ref.read(ledgerRepoProvider).deleteExpense(id);
  ref.invalidate(expensesProvider);
  return null;
}

Future<String?> _updateExpense(WidgetRef ref, Map<String, dynamic> args) async {
  final id = args['expenseId'] as String? ?? '';
  if (id.isEmpty) return '缺少账单 id';
  final record = (ref.read(expensesProvider).value ?? const <ExpenseRecord>[])
      .where((e) => e.id == id)
      .firstOrNull;
  if (record == null) return '找不到原账单，请刷新后重试';

  // 先解析出各字段的新值（与确认卡展示的 patch 一致）
  final newTitle = (args['title'] as String?)?.trim();
  final hasTitle = newTitle != null && newTitle.isNotEmpty;
  final hasNote = args.containsKey('note');
  final newNote = (args['note'] as String?)?.trim();

  String? newCatKey;
  final catKey = (args['categoryKey'] as String?)?.trim();
  if (catKey != null && catKey.isNotEmpty) {
    final cats = ref.read(categoriesProvider).value ?? const <CategoryView>[];
    final hit = cats.where((x) => x.key == catKey || x.name == catKey).toList();
    newCatKey = hit.isEmpty ? 'other' : hit.first.key;
  }
  final newDay = epochDayFromArg(args['date']);

  var amountCents = record.amountCents;
  final yuan = (args['amountYuan'] as num?)?.toDouble();
  final hasAmount = yuan != null && yuan != 0;
  if (hasAmount) {
    amountCents =
        record.amountCents < 0 ? -(yuan.abs() * 100).round() : (yuan.abs() * 100).round();
  }

  String? newPayerId;
  final payerName = (args['payerName'] as String?)?.trim();
  if (payerName != null && payerName.isNotEmpty) {
    final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
    final hit = members.where((m) => m.name == payerName).toList();
    if (hit.length != 1) return '找不到付款人「$payerName」';
    newPayerId = hit.first.id;
  }

  if (!hasTitle &&
      !hasNote &&
      newCatKey == null &&
      newDay == null &&
      !hasAmount &&
      newPayerId == null) {
    return '没有可应用的修改';
  }

  final c = ExpensesCompanion(
    title: hasTitle ? Value(newTitle) : const Value.absent(),
    note: hasNote ? Value(newNote ?? '') : const Value.absent(),
    categoryKey: newCatKey == null ? const Value.absent() : Value(newCatKey),
    dateEpochDay: newDay == null ? const Value.absent() : Value(newDay),
    amountCents: hasAmount ? Value(amountCents) : const Value.absent(),
    // 金额变化：保持原付款人与分摊成员，按新金额均摊重算
    sharesJson: hasAmount
        ? Value(jsonEncode([
            for (final s in computeSplit(
                totalCents: amountCents,
                memberIds: record.shares.map((s) => s.memberId).toList(),
                mode: ShareMode.equal))
              {'memberId': s.memberId, 'cents': s.cents},
          ]))
        : const Value.absent(),
    payersJson: newPayerId == null
        ? const Value.absent()
        : Value(jsonEncode([
            {'memberId': newPayerId, 'cents': amountCents},
          ])),
  );

  await ref.read(ledgerRepoProvider).updateExpense(id, c);
  ref.invalidate(expensesProvider);
  return null;
}

// ---------------------------------------------------------------------------
// 行程
// ---------------------------------------------------------------------------

Future<String?> _deleteTripItem(WidgetRef ref, Map<String, dynamic> args) async {
  final id = args['itemId'] as String? ?? '';
  if (id.isEmpty) return '缺少安排 id';
  await ref.read(tripsRepoProvider).deleteItem(id);
  return null;
}

Future<String?> _updateTripDates(WidgetRef ref, Map<String, dynamic> args) async {
  final tripId = args['tripId'] as String? ?? '';
  final start = epochDayFromArg(args['startDate']);
  final end = epochDayFromArg(args['endDate']);
  if (start == null || end == null) return '日期格式应为 YYYY-MM-DD';
  if (end < start) return '结束日期早于开始日期';
  await ref.read(tripsRepoProvider).updateDates(tripId, start, end);
  return null;
}

/// 批量建行程（create_trip_plan 确认后）。执行器已校验过参数，
/// 这里只负责写库；days 里单个条目不合法时跳过。
Future<String?> _createTripPlan(WidgetRef ref, Map<String, dynamic> args) async {
  final start = epochDayFromArg(args['startDate']);
  final end = epochDayFromArg(args['endDate']);
  if (start == null || end == null) return '日期格式错误';
  final name = (args['name'] as String? ?? '').trim();
  if (name.isEmpty) return '缺少行程名称';
  final daysRaw = args['days'];
  if (daysRaw is! List || daysRaw.isEmpty) return 'days 不能为空';
  final totalDays = end - start + 1;
  final now = DateTime.now().millisecondsSinceEpoch;
  final emoji = ((args['emoji'] as String? ?? '').trim().isEmpty)
      ? '✈️'
      : (args['emoji'] as String).trim();

  final perDayCount = <int, int>{};
  final templateItems = <TripTemplateItem>[];
  final tripId = await ref.read(tripsRepoProvider).createTrip(
        name: name,
        dest: (args['destination'] as String? ?? '').trim(),
        emoji: emoji,
        cover: 'ocean',
        start: start,
        end: end,
        note: '',
        groupId: ref.read(activeGroupProvider).value?.id,
      );
  for (final dayEntry in daysRaw) {
    if (dayEntry is! Map) continue;
    final dayNo = (dayEntry['day'] as num?)?.toInt() ?? 0;
    final itemsRaw = dayEntry['items'];
    if (dayNo < 1 || dayNo > totalDays || itemsRaw is! List) continue;
    for (final itemRaw in itemsRaw) {
      if (itemRaw is! Map) continue;
      final itemName = (itemRaw['name'] as String? ?? '').trim();
      if (itemName.isEmpty) continue;
      final idx = perDayCount[dayNo] ?? 0;
      perDayCount[dayNo] = idx + 1;
      final costYuan = (itemRaw['costYuan'] as num?)?.toDouble();
      await ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
            id: Value(newId('item')),
            tripId: Value(tripId),
            dateEpochDay: Value(start + dayNo - 1),
            type: Value(findTripItemTypeOf(itemRaw['type'] as String? ?? 'attraction')),
            name: Value(itemName),
            address: Value((itemRaw['address'] as String? ?? '').trim()),
            startTimeMin: Value(hhmmToMin(itemRaw['startTime'] as String?)),
            costCents:
                costYuan == null ? const Value(null) : Value((costYuan * 100).round()),
            note: Value((itemRaw['note'] as String? ?? '').trim()),
            sortOrder: Value(idx * 10),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));
      templateItems.add(TripTemplateItem(
        day: dayNo,
        name: itemName,
        type: findTripItemTypeOf(itemRaw['type'] as String? ?? 'attraction'),
        startTimeMin: hhmmToMin(itemRaw['startTime'] as String?),
        costCents: costYuan == null ? null : (costYuan * 100).round(),
        address: (itemRaw['address'] as String? ?? '').trim(),
        note: (itemRaw['note'] as String? ?? '').trim(),
      ));
    }
  }
  await saveTemplate(TripTemplate(
    id: newId('tpl'),
    name: name,
    destination: (args['destination'] as String? ?? '').trim(),
    emoji: emoji,
    createdAtMs: now,
    items: templateItems,
  ));
  return null;
}

/// 应用行程模板（确认后建行程 + 写安排）
Future<String?> _applyTripTemplate(WidgetRef ref, Map<String, dynamic> args) async {
  final templateId = args['templateId'] as String? ?? '';
  final start = epochDayFromArg(args['startDate']);
  if (start == null) return '日期格式错误';
  final templates = await loadTemplates();
  TripTemplate? template;
  for (final t in templates) {
    if (t.id == templateId) template = t;
  }
  if (template == null) return '找不到模板';
  final end = start + (template.dayCount - 1).clamp(0, 365);
  final now = DateTime.now().millisecondsSinceEpoch;
  final tripId = await ref.read(tripsRepoProvider).createTrip(
        name: template.name,
        dest: template.destination,
        emoji: template.emoji,
        cover: 'ocean',
        start: start,
        end: end,
        groupId: ref.read(activeGroupProvider).value?.id,
      );
  final perDayCount = <int, int>{};
  for (final i in template.items) {
    final idx = perDayCount[i.day] ?? 0;
    perDayCount[i.day] = idx + 1;
    await ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
          id: Value(newId('item')),
          tripId: Value(tripId),
          dateEpochDay: Value(start + i.day - 1),
          type: Value(i.type),
          name: Value(i.name),
          address: Value(i.address),
          startTimeMin: Value(i.startTimeMin),
          costCents: Value(i.costCents),
          note: Value(i.note),
          sortOrder: Value(idx * 10),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
  }
  return null;
}

// ---------------------------------------------------------------------------
// 团 / 成员
// ---------------------------------------------------------------------------

Future<String?> _setGroupBudget(WidgetRef ref, Map<String, dynamic> args) async {
  final gid = ref.read(activeGroupProvider).value?.id;
  if (gid == null) return '尚未选择旅行团';
  final yuan = (args['totalYuan'] as num?)?.toDouble();
  if (yuan == null || yuan <= 0) return '预算金额必须大于 0';
  final enabled = args['enabled'] is bool ? args['enabled'] as bool : true;
  await ref
      .read(ledgerRepoProvider)
      .setBudget(gid, enabled: enabled, budgetCents: (yuan * 100).round());
  return null;
}

Future<String?> _removeMember(WidgetRef ref, Map<String, dynamic> args) async {
  final memberId = args['memberId'] as String? ?? '';
  if (memberId.isEmpty) return '缺少成员 id';
  await ref.read(ledgerRepoProvider).deleteMember(memberId);
  ref.invalidate(membersProvider);
  return null;
}
