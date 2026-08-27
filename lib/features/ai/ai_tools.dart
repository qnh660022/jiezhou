/// AI 助手工具系统：schema 白名单 + 本地执行器。
///
/// 【作用域约束】助手只能通过本文件列出的工具操作应用内数据
/// （记账、行程、预算与少量本地偏好），没有任何联网浏览、通用 HTTP、
/// 文件读写或删除类工具——列表之外的操作模型无从发起。
library;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/date_utils.dart';
import '../../core/uid.dart';
import '../../data/db/database.dart' hide Settlement; // hide to avoid conflict with models.dart
import '../../data/providers.dart';
import '../../data/seed/currencies.dart';
import '../../data/seed/item_types.dart';
import '../../data/services/ai_chat_service.dart';
import '../../domain/models.dart';
import '../ledger/ledger_models.dart';
import '../ledger/ledger_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/theme_provider.dart';

// ---------------------------------------------------------------------------
// 工具 schema 白名单
// ---------------------------------------------------------------------------

final List<AiToolDefinition> kAiTools = [
  const AiToolDefinition(
    name: 'list_members',
    description: '列出当前旅行团的全部成员（含 memberId，用于其他工具的成员参数）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'add_member',
    description: '在当前旅行团新增一名成员。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': '成员名'},
      },
      'required': ['name'],
    },
  ),
  const AiToolDefinition(
    name: 'list_categories',
    description: '列出全部消费分类的 key 与名称（key 用于记账参数）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'query_expenses',
    description: '查询当前团账单流水，可按日期区间 / 分类 / 成员 / 关键词过滤并返回合计。日期一律用 YYYY-MM-DD。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'startDate': {'type': 'string', 'description': '起始日期 YYYY-MM-DD（含）'},
        'endDate': {'type': 'string', 'description': '结束日期 YYYY-MM-DD（含）'},
        'categoryKey': {'type': 'string', 'description': '分类 key'},
        'memberName': {'type': 'string', 'description': '按成员名过滤（付款或分摊包含该成员）'},
        'keyword': {'type': 'string', 'description': '标题关键词'},
      },
    },
  ),
  const AiToolDefinition(
    name: 'get_balances',
    description: '获取当前团各成员已付/应摊/结余（正=应收）以及建议的最少转账方案。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'get_budget_status',
    description: '获取当前团预算开启状态、总额、已花、剩余与百分比。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'set_group_budget',
    description: '设置当前团的预算总额并开启（总金额为人民币元）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'totalYuan': {'type': 'number', 'description': '预算总额（元）'},
        'enabled': {'type': 'boolean', 'description': '是否启用，默认 true'},
      },
      'required': ['totalYuan'],
    },
  ),
  const AiToolDefinition(
    name: 'get_settlement_status',
    description: '查看进行中 AA 结算轮的转账明细及逐笔确认状态。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'add_expense',
    description: '记一笔账单（均摊模式）。payer 必须是当前团真实成员名；shareMembers 缺省为全体成员平摊。金额单位元。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': '账单标题'},
        'amountYuan': {'type': 'number', 'description': '金额（元），退款用负数'},
        'expenseType': {'type': 'string', 'enum': ['normal', 'refund'], 'description': 'normal 支出 / refund 退款，默认 normal'},
        'payerName': {'type': 'string', 'description': '付款人成员名'},
        'shareMembers': {'type': 'array', 'items': {'type': 'string'}, 'description': '参与分摊的成员名列表，缺省全体'},
        'categoryKey': {'type': 'string', 'description': '分类 key，未知时留空按 other'},
        'date': {'type': 'string', 'description': '发生日期 YYYY-MM-DD，缺省今天'},
        'currencyCode': {'type': 'string', 'description': '币种代码如 CNY/JPY，默认 CNY'},
        'note': {'type': 'string', 'description': '备注'},
      },
      'required': ['title', 'amountYuan', 'payerName'],
    },
  ),
  const AiToolDefinition(
    name: 'list_trips',
    description: '列出全部行程（id、名称、目的地、起止日期）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'create_trip',
    description: '创建一个新行程。此操作不依赖旅行团：当前若有旅行团会自动关联，没有则可创建为独立行程。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': '行程名称'},
        'destination': {'type': 'string', 'description': '目的地'},
        'startDate': {'type': 'string', 'description': '开始日期 YYYY-MM-DD'},
        'endDate': {'type': 'string', 'description': '结束日期 YYYY-MM-DD'},
        'emoji': {'type': 'string', 'description': '行程图标 emoji，默认 ✈️'},
        'note': {'type': 'string', 'description': '备注'},
      },
      'required': ['name', 'destination', 'startDate', 'endDate'],
    },
  ),
  const AiToolDefinition(
    name: 'add_trip_item',
    description: '给某行程添加一条安排（景点/餐饮/交通/住宿/备注五类）。tripId 可从 list_trips 获得。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string', 'description': '行程 id'},
        'name': {'type': 'string', 'description': '安排名称'},
        'date': {'type': 'string', 'description': '安排日期 YYYY-MM-DD'},
        'itemType': {'type': 'string', 'enum': ['attraction', 'food', 'transport', 'stay', 'note'], 'description': '类型，默认 attraction'},
        'startTime': {'type': 'string', 'description': '开始时间 HH:mm（24小时制，可省略）'},
        'durationMinutes': {'type': 'integer', 'description': '时长分钟数（可省略）'},
        'costYuan': {'type': 'number', 'description': '预估花费（元，可省略）'},
        'address': {'type': 'string', 'description': '地址（可省略）'},
        'note': {'type': 'string', 'description': '备注（可省略）'},
      },
      'required': ['tripId', 'name', 'date'],
    },
  ),
  const AiToolDefinition(
    name: 'get_trip_schedule',
    description: '查看某行程的全部日程安排（按日期排序）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string', 'description': '行程 id'},
      },
      'required': ['tripId'],
    },
  ),
  const AiToolDefinition(
    name: 'list_checklists',
    description: '查看通用清单，以及每个行程的清单事项（含完成状态）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'add_checklist_item',
    description: '给某个行程的清单，或通用待办清单，添加一项事项。tripId 可从 list_trips 获得；不填 tripId 则加到通用清单。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string', 'description': '行程 id（可省略；省略则加到通用待办清单）'},
        'text': {'type': 'string', 'description': '清单事项内容'},
        'category': {'type': 'string', 'description': '分类，如 证件/衣物/数码/洗漱，默认 other'},
      },
      'required': ['text'],
    },
  ),
  AiToolDefinition(
    name: 'set_app_theme',
    description: '切换应用主题外观。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'themeKey': {'type': 'string', 'enum': ThemeKeys.all, 'description': '主题 key'},
      },
      'required': ['themeKey'],
    },
  ),
  const AiToolDefinition(
    name: 'set_budget_alerts_enabled',
    description: '开关预算预警提醒。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'enabled': {'type': 'boolean'},
      },
      'required': ['enabled'],
    },
  ),
];

// ---------------------------------------------------------------------------
// 执行器
// ---------------------------------------------------------------------------

class AiToolExecutor {
  AiToolExecutor(this._ref);

  final Ref _ref;

  /// 执行一次工具调用，返回喂回模型的结果文本（JSON）；失败也以 {"error":...} 回传，
  /// 让模型能向用户解释而不是中断会话。
  Future<String> execute(String name, String argumentsJson) async {
    Map<String, dynamic> args;
    try {
      final decoded = jsonDecodeLoose(argumentsJson);
      args = decoded ?? {};
    } catch (_) {
      return '{"error":"参数不是合法 JSON"}';
    }
    try {
      switch (name) {
        case 'list_members':
          return await _listMembers();
        case 'add_member':
          return await _addMember(args);
        case 'list_categories':
          return await _listCategories();
        case 'query_expenses':
          return await _queryExpenses(args);
        case 'get_balances':
          return await _balances();
        case 'get_budget_status':
          return await _budgetStatus();
        case 'set_group_budget':
          return await _setBudget(args);
        case 'get_settlement_status':
          return await _settlementStatus();
        case 'add_expense':
          return await _addExpense(args);
        case 'list_trips':
          return await _listTrips();
        case 'create_trip':
          return await _createTrip(args);
        case 'add_trip_item':
          return await _addTripItem(args);
        case 'get_trip_schedule':
          return await _tripSchedule(args);
        case 'list_checklists':
          return await _listChecklists();
        case 'add_checklist_item':
          return await _addChecklistItem(args);
        case 'set_app_theme':
          return await _setTheme(args);
        case 'set_budget_alerts_enabled':
          return await _setAlerts(args);
        default:
          return '{"error":"未知工具 $name"}';
      }
    } catch (e) {
      return '{"error":"${_esc(e.toString())}"}';
    }
  }

  // ---- 上下文快照 ----

  LedgerGroupView? get _group => _ref.read(activeGroupProvider).value;

  List<LedgerMemberView> get _members =>
      _ref.read(membersProvider).value ?? const [];

  List<ExpenseRecord> get _expenses =>
      _ref.read(expensesProvider).value ?? const [];

  List<CategoryView> get _categories =>
      _ref.read(categoriesProvider).value ?? const [];

  List<TripCardView> get _trips =>
      _ref.read(allTripsProvider).value ?? const [];

  /// 成员名精确匹配优先，其次模糊；命中唯一才返回
  LedgerMemberView? _resolveMember(String raw) {
    final q = raw.trim();
    final exact = _members.where((m) => m.name == q).toList();
    if (exact.length == 1) return exact.first;
    final fuzzy =
        _members.where((m) => m.name.contains(q) || q.contains(m.name)).toList();
    return fuzzy.length == 1 ? fuzzy.first : null;
  }

  // ---- 查询类 ----

  Future<String> _listMembers() async {
    if (_members.isEmpty) return '{"members":[],"hint":"当前团还没有成员"}';
    return jsonStr({
      'groupId': _group?.id,
      'groupName': _group?.name,
      'members': [
        for (final m in _members) {'id': m.id, 'name': m.name},
      ],
    });
  }

  Future<String> _addMember(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return '{"error":"尚未选择旅行团"}';
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return '{"error":"成员名不能为空"}';
    await _ref.read(ledgerRepoProvider).addMember(gid, name);
    return '{"ok":true,"message":"已添加成员 $name"}';
  }

  Future<String> _listCategories() async => jsonStr({
        'categories': [
          for (final c in _categories)
            {'key': c.key, 'name': c.name},
        ],
      });

  Iterable<ExpenseRecord> _filtered(Map<String, dynamic> args) sync* {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    final cat = args['categoryKey'] as String?;
    final kw = (args['keyword'] as String? ?? '').trim();
    final memberName = (args['memberName'] as String? ?? '').trim();
    LedgerMemberView? member;
    if (memberName.isNotEmpty) member = _resolveMember(memberName);
    final memberId = member?.id;
    for (final e in _expenses) {
      if (start != null && e.dateEpochDay < start) continue;
      if (end != null && e.dateEpochDay > end) continue;
      if (cat != null && e.categoryKey != cat) continue;
      if (kw.isNotEmpty && !e.title.contains(kw) && !(e.note ?? '').contains(kw)) {
        continue;
      }
      if (memberId != null &&
          !e.payers.any((p) => p.memberId == memberId) &&
          !e.shares.any((p) => p.memberId == memberId)) {
        continue;
      }
      yield e;
    }
  }

  Future<String> _queryExpenses(Map<String, dynamic> args) async {
    final rows = _filtered(args).toList()
      ..sort((a, b) => a.dateEpochDay.compareTo(b.dateEpochDay));
    var total = 0;
    for (final e in rows) {
      total += e.amountCents;
    }
    final names = {for (final m in _members) m.id: m.name};
    return jsonStr({
      'count': rows.length,
      'totalCents': total,
      'items': [
        for (final e in rows)
          {
            'id': e.id,
            'date': fmtIsoDate(epochDayToDate(e.dateEpochDay)),
            'title': e.title,
            'type': e.type.name,
            'cents': e.amountCents,
            'currency': e.currency,
            'categoryKey': e.categoryKey,
            'payer': e.payers.map((p) => names[p.memberId] ?? p.memberId).join('、'),
            'note': e.note,
          },
      ],
    });
  }

  Future<String> _balances() async {
    if (_members.isEmpty) return '{"error":"当前团还没有成员"}';
    final board = _ref.read(memberBoardProvider).value ?? const <MemberStatView>[];
    final net = netBalanceMap(_members,
        _expenses.where((e) => e.settledRoundId == null).toList());
    final plans = transferPlanOf(net);
    final names = {for (final m in _members) m.id: m.name};
    return jsonStr({
      'board': [
        for (final b in board)
          {
            'member': b.member.name,
            'paidYuan': b.paidCents / 100,
            'shareYuan': b.shareCents / 100,
            'balanceYuan': b.balanceCents / 100,
            'balanceMeaning': '正数代表别人应补给 TA，负数代表 TA 应补给别人',
          },
      ],
      'suggestTransfers': [
        for (final t in plans)
          {
            'from': names[t.from] ?? t.from,
            'to': names[t.to] ?? t.to,
            'yuan': t.cents / 100,
          },
      ],
    });
  }

  Future<String> _budgetStatus() async {
    final b = _ref.read(budgetStatusProvider).value;
    if (b == null) return '{"error":"预算状态尚未加载"}';
    return jsonStr({
      'enabled': b.enabled,
      'totalYuan': b.totalCents / 100,
      'spentYuan': b.spentCents / 100,
      'remainingYuan': b.remainingCents / 100,
      'percent': b.percent,
    });
  }

  Future<String> _setBudget(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return '{"error":"尚未选择旅行团"}';
    final yuan = (args['totalYuan'] as num?)?.toDouble();
    if (yuan == null || yuan <= 0) return '{"error":"预算金额必须大于 0"}';
    final enabled = args['enabled'] is bool ? args['enabled'] as bool : true;
    await _ref
        .read(ledgerRepoProvider)
        .setBudget(gid, enabled: enabled, budgetCents: (yuan * 100).round());
    return '{"ok":true,"message":"预算已设置为 ¥$yuan"}';
  }

  Future<String> _settlementStatus() async {
    final all = _ref.read(settlementsProvider).value ?? const <SettlementView>[];
    final active = all.where((s) => s.active).toList();
    final names = {for (final m in _members) m.id: m.name};
    return jsonStr({
      'activeRounds': [
        for (final s in active)
          {
            'roundNo': s.roundNo,
            'transfers': [
              for (final t in s.transfers)
                {
                  'from': names[t.from] ?? t.from,
                  'to': names[t.to] ?? t.to,
                  'yuan': t.cents / 100,
                  'confirmed': t.done,
                },
            ],
          },
      ],
      'hasActive': active.isNotEmpty,
    });
  }

  // ---- 记账 ----

  Future<String> _addExpense(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return '{"error":"尚未选择旅行团，无法记账"}';
    if (_members.isEmpty) return '{"error":"当前团没有成员，请先添加成员"}';

    final title = (args['title'] as String? ?? '').trim();
    final amountYuan = (args['amountYuan'] as num?)?.toDouble();
    if (title.isEmpty) return '{"error":"缺少账单标题"}';
    if (amountYuan == null || amountYuan == 0) return '{"error":"金额不能为 0"}';

    var expenseType = ExpenseType.normal;
    final typeArg = args['expenseType'] as String?;
    if (typeArg == 'refund') expenseType = ExpenseType.refund;

    final payer = _resolveMember(args['payerName'] as String? ?? '');
    if (payer == null) {
      return '{"error":"找不到付款人「${args['payerName']}」，现有成员：${_members.map((m) => m.name).join('、')}"}';
    }

    final shareNames = (args['shareMembers'] as List?)
        ?.whereType<Object>()
        .map((e) => e.toString())
        .toList();
    final shareIds = <String>[];
    if (shareNames == null || shareNames.isEmpty) {
      shareIds.addAll(_members.map((m) => m.id));
    } else {
      for (final n in shareNames) {
        final m = _resolveMember(n);
        if (m == null) {
          return '{"error":"找不到分摊成员「$n」"}';
        }
        if (!shareIds.contains(m.id)) shareIds.add(m.id);
      }
    }

    final cents = (amountYuan.abs() * 100).round();
    final signed = expenseType == ExpenseType.refund ? -cents : cents;
    final shares = computeSplit(totalCents: signed, memberIds: shareIds, mode: ShareMode.equal);

    // 分类：给定的 key 必须存在，否则回落 other
    var catKey = 'other';
    final givenCat = args['categoryKey'] as String?;
    if (givenCat != null && givenCat.trim().isNotEmpty) {
      final hit = _categories.where((c) => c.key == givenCat.trim()).toList();
      catKey = hit.isEmpty ? 'other' : hit.first.key;
    }

    // 币种：非 CNY 用种子默认汇率折算
    var currency = 'CNY';
    var rate = 1.0;
    final code = (args['currencyCode'] as String? ?? 'CNY').trim().toUpperCase();
    for (final c in kCurrencies) {
      if (c.code.toUpperCase() == code) {
        currency = c.code;
        rate = c.rate;
        break;
      }
    }

    final day = _epochDay(args['date']) ?? todayEpochDay();

    final draft = ExpenseDraft(
      groupId: gid,
      dateEpochDay: day,
      title: title,
      categoryKey: catKey,
      type: expenseType,
      amountCents: signed,
      currency: currency,
      rate: rate,
      payers: [ShareEntry(memberId: payer.id, cents: signed)],
      shares: shares,
      shareMode: ShareMode.equal,
      note: (args['note'] as String?)?.trim(),
    );
    await _ref.read(ledgerRepoProvider).addExpense(_draftToCompanion(draft));
    return jsonStr({
      'ok': true,
      'message': '已记账：$title ¥${signed / 100}',
      'payer': payer.name,
      'cents': signed,
      'sharedBy': [
        for (final s in shares) _resolveMemberById(s.memberId)?.name ?? s.memberId,
      ],
    });
  }

  LedgerMemberView? _resolveMemberById(String id) {
    for (final m in _members) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ---- 行程 ----

  Future<String> _listTrips() async {
    final trips = _trips;
    return jsonStr({
      'trips': [
        for (final t in trips)
          {
            'id': t.id,
            'name': t.name,
            'destination': t.destination,
            'emoji': t.emoji,
            'start': fmtIsoDate(epochDayToDate(t.startEpochDay)),
            'end': fmtIsoDate(epochDayToDate(t.endEpochDay)),
          },
      ],
    });
  }

  Future<String> _createTrip(Map<String, dynamic> args) async {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) {
      return '{"error":"日期格式应为 YYYY-MM-DD"}';
    }
    if (end < start) return '{"error":"结束日期早于开始日期"}';
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return '{"error":"缺少行程名称"}';
    final id = await _ref.read(tripsRepoProvider).createTrip(
          name: name,
          dest: (args['destination'] as String? ?? '').trim(),
          emoji: (args['emoji'] as String? ?? '').trim().isEmpty
              ? '✈️'
              : args['emoji'].toString().trim(),
          cover: 'ocean',
          start: start,
          end: end,
          note: (args['note'] as String? ?? '').trim(),
          groupId: _group?.id,
        );
    return jsonStr({'ok': true, 'tripId': id, 'message': '行程「$name」已创建'});
  }

  Future<String> _addTripItem(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final matches = _trips.where((t) => t.id == tripId).toList();
    if (matches.isEmpty) {
      final all = await _listTrips();
      return '{"error":"找不到行程 id=$tripId，可用行程：$all"}';
    }
    final trip = matches.first;
    final day = _epochDay(args['date']);
    if (day == null) return '{"error":"日期格式应为 YYYY-MM-DD"}';

    var type = 'attraction';
    final typeArg = args['itemType'] as String?;
    if (typeArg != null) {
      type = findTripItemType(typeArg).key;
    }
    final startMin = _hhmmToMin(args['startTime'] as String?);
    final costYuan = (args['costYuan'] as num?)?.toDouble();
    final items =
        await _ref.read(tripsRepoProvider).getItems(trip.id);
    final sameDayCount =
        items.where((i) => i.dateEpochDay == day).length;

    await _ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
          id: Value(newId('item')),
          tripId: Value(trip.id),
          dateEpochDay: Value(day),
          type: Value(type),
          name: Value((args['name'] as String? ?? '').trim()),
          address: Value((args['address'] as String? ?? '').trim()),
          startTimeMin: Value(startMin),
          durationMin: Value(args['durationMinutes'] is int
              ? args['durationMinutes'] as int
              : null),
          costCents: costYuan == null ? const Value(null) : Value((costYuan * 100).round()),
          note: Value((args['note'] as String? ?? '').trim()),
          sortOrder: Value(sameDayCount),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
    return jsonStr({
      'ok': true,
      'message': '已在「${trip.name}」添加安排：${args['name']}（$type）',
    });
  }

  Future<String> _tripSchedule(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = _trips.where((t) => t.id == tripId).toList();
    if (trip.isEmpty) return '{"error":"找不到行程 id=$tripId"}';
    final items =
        await _ref.read(tripsRepoProvider).getItems(trip.first.id);
    final sorted = [...items]..sort((a, b) {
        final byDay = a.dateEpochDay.compareTo(b.dateEpochDay);
        if (byDay != 0) return byDay;
        return (a.startTimeMin ?? 9999).compareTo(b.startTimeMin ?? 9999);
      });
    return jsonStr({
      'trip': trip.first.name,
      'schedule': [
        for (final i in sorted)
          {
            'date': fmtIsoDate(epochDayToDate(i.dateEpochDay)),
            'time': i.startTimeMin == null
                ? null
                : '${i.startTimeMin! ~/ 60}:${(i.startTimeMin! % 60).toString().padLeft(2, '0')}',
            'name': i.name,
            'type': i.type,
            'costYuan': i.costCents == null ? null : i.costCents! / 100,
            'note': i.note,
          },
      ],
    });
  }

  // ---- 清单 ----

  Future<String> _listChecklists() async {
    final repo = _ref.read(checklistRepoProvider);
    final global = await repo.getAllByScope('global');
    final tripLists = <Map<String, dynamic>>[];
    for (final t in _trips) {
      final items = await repo.getAllByScope('trip', tripId: t.id);
      tripLists.add({
        'tripId': t.id,
        'tripName': t.name,
        'items': [
          for (final i in items)
            {'id': i.id, 'label': i.label, 'category': i.category, 'done': i.done},
        ],
      });
    }
    return jsonStr({
      'globalItems': [
        for (final i in global)
          {'id': i.id, 'label': i.label, 'category': i.category, 'done': i.done},
      ],
      'tripItems': tripLists,
    });
  }

  Future<String> _addChecklistItem(Map<String, dynamic> args) async {
    final text = (args['text'] as String? ?? '').trim();
    if (text.isEmpty) return '{"error":"清单事项内容不能为空"}';
    final tripId = (args['tripId'] as String? ?? '').trim();
    String? tripName;
    String scope;
    if (tripId.isNotEmpty) {
      final matches = _trips.where((t) => t.id == tripId).toList();
      if (matches.isEmpty) {
        final all = await _listTrips();
        return '{"error":"找不到行程 id=$tripId，可用行程：$all"}';
      }
      tripName = matches.first.name;
      scope = 'trip';
    } else {
      scope = 'global';
    }
    var category = (args['category'] as String? ?? '').trim();
    if (category.isEmpty) category = 'other';
    final repo = _ref.read(checklistRepoProvider);
    final existing = await repo.getAllByScope(scope, tripId: tripId.isEmpty ? null : tripId);
    await repo.addItem(tripId.isEmpty ? null : tripId, scope, category, text, existing.length);
    final where = tripName == null ? '通用清单' : '行程「$tripName」的清单';
    return jsonStr({'ok': true, 'message': '已添加到$where：$text', 'scope': scope});
  }

  // ---- 设置类 ----

  Future<String> _setTheme(Map<String, dynamic> args) async {
    final key = args['themeKey'] as String?;
    if (key == null || !ThemeKeys.all.contains(key)) {
      return '{"error":"无效的主题 key"}';
    }
    await _ref.read(themeProvider.notifier).setTheme(key);
    return '{"ok":true,"message":"主题已切换为 ${ThemeKeys.labels[key]}"}';
  }

  Future<String> _setAlerts(Map<String, dynamic> args) async {
    final enabled = args['enabled'];
    if (enabled is! bool) return '{"error":"enabled 必须是布尔值"}';
    await _ref.read(prefsRepoProvider).setBudgetAlertsEnabled(enabled);
    _ref.invalidate(budgetAlertsEnabledProvider);
    return '{"ok":true,"message":"预算预警已${enabled ? '开启' : '关闭'}"}';
  }

  /// 把记账草稿转成数据库行（与 ledger_providers.saveExpense 同一落库约定，
  /// 但使用非 WidgetRef 的 Ref，供 Notifier 环境调用）
  ExpensesCompanion _draftToCompanion(ExpenseDraft draft) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ExpensesCompanion(
      id: Value(draft.id ?? newId('expense')),
      groupId: Value(draft.groupId),
      dateEpochDay: Value(draft.dateEpochDay),
      title: Value(draft.title),
      categoryKey: Value(draft.categoryKey),
      type: Value(draft.type.name),
      amountCents: Value(draft.amountCents),
      currency: Value(draft.currency),
      rate: Value(draft.rate),
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
      createdAt: Value(now),
    );
  }
}

// ---------------------------------------------------------------------------
// System Prompt
// ---------------------------------------------------------------------------

/// 组装系统提示词：能力边界 + 注入实时上下文（成员/分类/行程等），
/// 让模型能把用户口中的姓名解析成工具需要的 id。
Future<String> buildSystemPrompt(Ref ref) async {
  final today = todayEpochDay();
  final group = ref.read(activeGroupProvider).value;
  final members = ref.read(membersProvider).value ?? const [];
  final categories = ref.read(categoriesProvider).value ?? const [];
  final trips = ref.read(allTripsProvider).value ?? const [];

  final sb = StringBuffer();
  sb.writeln('你是「旅途助手」App 内置的 AI 管家，负责帮用户管理旅行团、AA 记账、行程安排与应用偏好。');
  sb.writeln();
  sb.writeln('【能力边界（必须遵守）】');
  sb.writeln('1. 你只能通过提供的工具操作本应用的数据，绝无权限触达应用之外的任何功能（无联网浏览、无法发消息、无法操作系统）。');
  sb.writeln('2. 没有删除类工具；涉及删除或结算确认等敏感操作时，引导用户去相应页面手动完成。');
  sb.writeln('3. 涉及金额、付款人、日期等关键信息不明确时先向用户确认，不要臆造 memberId / tripId / 分类 key。');
  sb.writeln('4. 你可以创建行程（create_trip）并给行程添加日程（add_trip_item）与清单事项（add_checklist_item），也能往通用待办清单加事项；需要行程 id 时先调用 list_trips 查询。');
  sb.writeln('5. 回答使用简体中文，简洁自然；执行了写入操作后用一句话告诉用户结果。');
  sb.writeln();
  sb.writeln('【当前上下文】');
  sb.writeln('今天是 ${fmtFullDateOfEpoch(today)}。');
  if (group == null) {
    sb.writeln('当前未选择任何旅行团。注意：创建行程（create_trip）、查看/添加日程（add_trip_item、get_trip_schedule）、往通用清单或行程清单添加事项（add_checklist_item、list_checklists）这些【不依赖旅行团】的操作依然可用；只有记账/查账/结算/预算等团内数据操作会因无团而失败。');
  } else {
    sb.writeln('当前旅行团：「${group.name}」（id=${group.id}），预算${group.budgetEnabled ? '已开启' : '未开启'}。');
  }
  if (members.isEmpty) {
    sb.writeln('当前团还没有成员。');
  } else {
    sb.writeln('成员名单（记账时分摊人用名字即可，工具会自动解析）：');
    for (final m in members) {
      sb.writeln('- ${m.name}（id=${m.id}）');
    }
  }
  if (categories.isNotEmpty) {
    sb.write('消费分类 key：');
    sb.write(categories.map((c) => '${c.key}(${c.name})').join('、'));
    sb.writeln();
  }
  if (trips.isNotEmpty) {
    sb.writeln('关联行程：');
    for (final t in trips) {
      sb.writeln('- ${t.name}（id=${t.id}，目的地 ${t.destination}，'
          '${fmtIsoDate(epochDayToDate(t.startEpochDay))} ~ '
          '${fmtIsoDate(epochDayToDate(t.endEpochDay))}${t.archived ? '，已归档' : ''}）');
    }
  } else {
    sb.writeln('当前还没有任何行程。');
  }
  return sb.toString();
}

// ---------------------------------------------------------------------------
// 小工具
// ---------------------------------------------------------------------------

/// 把 [epochDay] 以外的日期参数（YYYY-MM-DD / YYYY/M/D）解析为 epochDay
int? _epochDay(dynamic v) {
  if (v is int) return v;
  final s = (v ?? '').toString().trim().replaceAll('/', '-');
  if (s.isEmpty) return null;
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
    return null;
  }
  return dateToEpochDay(DateTime(y, m, d));
}

/// 'HH:mm' → 当日分钟数
int? _hhmmToMin(String? s) {
  final text = (s ?? '').trim();
  if (text.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})[:：](\d{2})$').firstMatch(text);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// 帮助函数：Map → JSON 字符串（模型回读）
String jsonStr(Map<String, dynamic> map) {
  try {
    return const JsonEncoder.withIndent('').convert(map);
  } catch (_) {
    return '{}';
  }
}

/// 参数解析兼容模型偶发的非严格 JSON（截取首个完整对象）
Map<String, dynamic>? jsonDecodeLoose(String s) {
  var text = s.trim();
  try {
    final v = jsonDecodeNormal(text);
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    final inner = jsonDecodeNormal(text.substring(start, end + 1));
    if (inner is Map) return Map<String, dynamic>.from(inner);
  }
  throw FormatException('bad json: $s');
}

dynamic jsonDecodeNormal(String s) => const JsonDecoder().convert(s);

/// JSON 字符串内嵌转义
String _esc(String raw) =>
    raw.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ');
