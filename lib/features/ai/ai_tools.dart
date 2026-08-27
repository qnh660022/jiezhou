/// AI 助手工具系统：schema 白名单 + 本地执行器 + 卡片数据产出。
///
/// 【作用域约束】助手只能通过本文件列出的工具操作应用内数据
/// （记账、行程、清单、预算与少量本地偏好），没有任何联网浏览、通用 HTTP、
/// 文件读写或删除类工具——列表之外的操作模型无从发起。
///
/// 【token 策略】查询类工具的完整数据以卡片直出给 UI（cardData），
/// 喂回模型的只有精简摘要（modelText）；模型需要明细时带 detail:true 重查。
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
import '../../data/seed/checklist_templates.dart';
import '../../data/services/ai_chat_service.dart';
import '../../domain/models.dart';
import '../ledger/ledger_models.dart';
import '../ledger/ledger_providers.dart';
import '../trips/trip_template_store.dart';
import '../../theme/tokens.dart';
import '../../theme/theme_provider.dart';

// ---------------------------------------------------------------------------
// 工具执行结果
// ---------------------------------------------------------------------------

/// 一次工具执行的结果。
///
/// * [modelText] —— 喂回模型的文本（精简摘要或完整 JSON）；
/// * [cardType] / [cardData] —— 非空时 UI 直接渲染原生卡片，
///   模型无需（也不应）在回答里复述这些数据。
class AiToolOutcome {
  const AiToolOutcome(this.modelText, {this.cardType, this.cardData});

  final String modelText;
  final String? cardType;
  final Map<String, dynamic>? cardData;
}

// ---------------------------------------------------------------------------
// 工具 schema 白名单
// ---------------------------------------------------------------------------

final List<AiToolDefinition> kAiTools = [
  const AiToolDefinition(
    name: 'list_members',
    description: '列出当前旅行团全部成员（其他工具的成员参数用名字即可）。',
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
    name: 'create_group',
    description: '新建一个旅行团（记账分组）并立即切换为当前团。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': '团名'},
        'icon': {'type': 'string', 'description': '图标 emoji，默认 📁'},
      },
      'required': ['name'],
    },
  ),
  const AiToolDefinition(
    name: 'list_categories',
    description: '列出全部消费分类的 key 与名称。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'query_expenses',
    description:
        '查询当前团账单并自动以卡片展示给用户。默认只返回汇总（足以回答总额/大头/均值问题）；用户要看具体条目时传 detail:true。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'startDate': {'type': 'string', 'description': '起始日期 YYYY-MM-DD（含）'},
        'endDate': {'type': 'string', 'description': '结束日期 YYYY-MM-DD（含）'},
        'categoryKey': {'type': 'string', 'description': '分类 key'},
        'memberName': {'type': 'string', 'description': '按成员名过滤'},
        'keyword': {'type': 'string', 'description': '标题关键词'},
        'detail': {'type': 'boolean', 'description': 'true 时返回完整条目列表'},
      },
    },
  ),
  const AiToolDefinition(
    name: 'get_balances',
    description: '获取各成员已付/应摊/结余（同时以卡片展示），并返回建议转账方案。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'get_budget_status',
    description: '获取当前团预算总额/已花/剩余/百分比（同时以卡片展示）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'set_group_budget',
    description: '设置当前团预算总额并开启（单位元）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'totalYuan': {'type': 'number', 'description': '预算总额（元）'},
        'enabled': {'type': 'boolean', 'description': '默认 true'},
      },
      'required': ['totalYuan'],
    },
  ),
  const AiToolDefinition(
    name: 'get_settlement_status',
    description: '查看进行中 AA 结算轮的转账与确认进度（同时以卡片展示）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'add_expense',
    description:
        '记一笔账单（均摊）。不会立即落库，而是给用户出示一张确认卡，用户在卡片上点确认后由本地记账（模型无需再做任何事）。payer 必须是真实成员名；shareMembers 缺省全体平摊；退款用 expenseType=refund 且金额为正数。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'amountYuan': {'type': 'number', 'description': '金额（元）'},
        'expenseType': {'type': 'string', 'enum': ['normal', 'refund']},
        'payerName': {'type': 'string', 'description': '付款人成员名'},
        'shareMembers': {'type': 'array', 'items': {'type': 'string'}, 'description': '缺省全体'},
        'categoryKey': {'type': 'string', 'description': '未知时留空按 other'},
        'date': {'type': 'string', 'description': 'YYYY-MM-DD，缺省今天'},
        'currencyCode': {'type': 'string', 'description': '默认 CNY'},
        'note': {'type': 'string'},
      },
      'required': ['title', 'amountYuan', 'payerName'],
    },
  ),
  const AiToolDefinition(
    name: 'list_trips',
    description: '列出全部行程（含 tripId；add_trip_item 等需要）。同时以卡片展示。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'create_trip',
    description: '创建新行程并关联当前旅行团。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'destination': {'type': 'string'},
        'startDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'endDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'emoji': {'type': 'string', 'description': '默认 ✈️'},
        'note': {'type': 'string'},
      },
      'required': ['name', 'destination', 'startDate', 'endDate'],
    },
  ),
  const AiToolDefinition(
    name: 'update_trip_dates',
    description: '修改某行程的起止日期（行程内安排自动夹紧到新区间）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string'},
        'startDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'endDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
      },
      'required': ['tripId', 'startDate', 'endDate'],
    },
  ),
  const AiToolDefinition(
    name: 'add_trip_item',
    description: '给行程添加一条安排（attraction/food/transport/stay/note 五类）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string'},
        'name': {'type': 'string'},
        'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'itemType': {'type': 'string', 'enum': ['attraction', 'food', 'transport', 'stay', 'note']},
        'startTime': {'type': 'string', 'description': 'HH:mm，可省略'},
        'durationMinutes': {'type': 'integer'},
        'costYuan': {'type': 'number'},
        'address': {'type': 'string'},
        'note': {'type': 'string'},
      },
      'required': ['tripId', 'name', 'date'],
    },
  ),
  const AiToolDefinition(
    name: 'get_trip_schedule',
    description: '查看行程全部日程（同时以卡片展示）；默认汇总，detail:true 返回明细。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string'},
        'detail': {'type': 'boolean'},
      },
      'required': ['tripId'],
    },
  ),
  const AiToolDefinition(
    name: 'add_checklist_item',
    description:
        '添加清单项。带 tripId 加入行程行李清单，否则加入全局待办。category 可选 docs/clothes/electronics/toiletries/medicine/other。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': '条目内容'},
        'tripId': {'type': 'string', 'description': '缺省为全局清单'},
        'category': {'type': 'string', 'enum': ['docs', 'clothes', 'electronics', 'toiletries', 'medicine', 'other']},
      },
      'required': ['text'],
    },
  ),
  const AiToolDefinition(
    name: 'toggle_checklist_item',
    description: '按条目文字勾选/取消清单项（指定行程或全局清单中模糊匹配）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': '条目文字（支持部分匹配）'},
        'tripId': {'type': 'string', 'description': '缺省查全局清单'},
        'done': {'type': 'boolean', 'description': '缺省取反'},
      },
      'required': ['text'],
    },
  ),
  const AiToolDefinition(
    name: 'query_checklist',
    description: '查看清单完成情况（同时以卡片展示）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string', 'description': '缺省查全局清单'},
      },
    },
  ),
  const AiToolDefinition(
    name: 'create_trip_plan',
    description:
        '一键生成完整行程：创建行程并批量写入多日安排（一次调用完成，不要再逐条调用 add_trip_item）。items[].type 取 attraction/food/transport/stay/note。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'destination': {'type': 'string'},
        'startDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'endDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'emoji': {'type': 'string', 'description': '默认 ✈️'},
        'days': {
          'type': 'array',
          'description': '按天组织安排；day 为 1 起始的天序号（相对 startDate）',
          'items': {
            'type': 'object',
            'properties': {
              'day': {'type': 'integer'},
              'items': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string'},
                    'type': {'type': 'string'},
                    'startTime': {'type': 'string', 'description': 'HH:mm 可省略'},
                    'costYuan': {'type': 'number'},
                    'address': {'type': 'string'},
                    'note': {'type': 'string'},
                  },
                  'required': ['name'],
                },
              },
            },
            'required': ['day', 'items'],
          },
        },
      },
      'required': ['name', 'destination', 'startDate', 'endDate', 'days'],
    },
  ),
  const AiToolDefinition(
    name: 'save_trip_template',
    description: '把某个现有行程保存为行程模板（供用户在「行程模板库」复用）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string'},
      },
      'required': ['tripId'],
    },
  ),
  const AiToolDefinition(
    name: 'list_trip_templates',
    description: '列出已保存的行程模板（含 templateId；apply_trip_template 需要）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'apply_trip_template',
    description: '用行程模板创建新行程（安排内容照搬，日期按新起止平铺）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'templateId': {'type': 'string'},
        'startDate': {'type': 'string', 'description': '新行程开始日期 YYYY-MM-DD'},
      },
      'required': ['templateId', 'startDate'],
    },
  ),
  const AiToolDefinition(
    name: 'set_app_theme',
    description: '切换应用主题外观。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'themeKey': {'type': 'string', 'enum': ThemeKeys.all},
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

  /// 执行一次工具调用；失败以 {"error":...} 回传，让模型能向用户解释而不是中断会话。
  Future<AiToolOutcome> execute(String name, String argumentsJson) async {
    Map<String, dynamic> args;
    try {
      args = jsonDecodeLoose(argumentsJson) ?? {};
    } catch (_) {
      return AiToolOutcome('{"error":"参数不是合法 JSON"}');
    }
    try {
      switch (name) {
        case 'list_members':
          return await _listMembers();
        case 'add_member':
          return await _addMember(args);
        case 'create_group':
          return await _createGroup(args);
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
        case 'update_trip_dates':
          return await _updateTripDates(args);
        case 'add_trip_item':
          return await _addTripItem(args);
        case 'create_trip_plan':
          return await _createTripPlan(args);
        case 'save_trip_template':
          return await _saveTripTemplate(args);
        case 'list_trip_templates':
          return await _listTripTemplates();
        case 'apply_trip_template':
          return await _applyTripTemplate(args);
        case 'get_trip_schedule':
          return await _tripSchedule(args);
        case 'add_checklist_item':
          return await _addChecklistItem(args);
        case 'toggle_checklist_item':
          return await _toggleChecklistItem(args);
        case 'query_checklist':
          return await _queryChecklist(args);
        case 'set_app_theme':
          return await _setTheme(args);
        case 'set_budget_alerts_enabled':
          return await _setAlerts(args);
        default:
          return AiToolOutcome('{"error":"未知工具 $name"}');
      }
    } catch (e) {
      return AiToolOutcome('{"error":"${_esc(e.toString())}"}');
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
      _ref.read(tripsInGroupProvider).value ?? const [];

  bool _detail(Map<String, dynamic> args) => args['detail'] == true;

  /// 成员名精确匹配优先，其次模糊；命中唯一才返回
  LedgerMemberView? _resolveMember(String raw) {
    final q = raw.trim();
    final exact = _members.where((m) => m.name == q).toList();
    if (exact.length == 1) return exact.first;
    final fuzzy =
        _members.where((m) => m.name.contains(q) || q.contains(m.name)).toList();
    return fuzzy.length == 1 ? fuzzy.first : null;
  }

  LedgerMemberView? _resolveMemberById(String id) {
    for (final m in _members) {
      if (m.id == id) return m;
    }
    return null;
  }

  String _memberName(String id) => _resolveMemberById(id)?.name ?? id;

  /// 分类 key 解析：给定的 key 必须存在，否则回落 other
  String _categoryKeyOf(String? given) {
    if (given == null || given.trim().isEmpty) return 'other';
    final hit = _categories.where((c) => c.key == given.trim()).toList();
    return hit.isEmpty ? 'other' : hit.first.key;
  }

  /// 分类显示名（确认卡展示用）
  String _categoryNameOf(String? given) {
    if (given == null || given.trim().isEmpty) return '其他';
    return _categories.where((c) => c.key == given.trim()).firstOrNull?.name ?? given;
  }

  // ---- 成员 / 团 / 分类 ----

  Future<AiToolOutcome> _listMembers() async {
    if (_members.isEmpty) {
      return AiToolOutcome('{"members":[],"hint":"当前团还没有成员"}');
    }
    return AiToolOutcome(jsonStr({
      'members': [for (final m in _members) m.name],
    }));
  }

  Future<AiToolOutcome> _addMember(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return AiToolOutcome('{"error":"尚未选择旅行团"}');
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"成员名不能为空"}');
    await _ref.read(ledgerRepoProvider).addMember(gid, name);
    return AiToolOutcome('{"ok":true,"message":"已添加成员 $name"}');
  }

  Future<AiToolOutcome> _createGroup(Map<String, dynamic> args) async {
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"缺少团名"}');
    final icon = (args['icon'] as String? ?? '').trim();
    final created =
        await _ref.read(ledgerRepoProvider).addGroup(name, icon.isEmpty ? '📁' : icon);
    await _ref.read(ledgerRepoProvider).setActiveGroup(created.id);
    return AiToolOutcome('{"ok":true,"groupId":"${created.id}","message":"旅行团「$name」已创建并切换为当前团"}');
  }

  Future<AiToolOutcome> _listCategories() async => AiToolOutcome(jsonStr({
        'categories': [
          for (final c in _categories)
            {'key': c.key, 'name': c.name},
        ],
      }));

  // ---- 账单查询（卡片直出） ----

  Iterable<ExpenseRecord> _filtered(Map<String, dynamic> args) sync* {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    final cat = args['categoryKey'] as String?;
    final kw = (args['keyword'] as String? ?? '').trim();
    final memberName = (args['memberName'] as String? ?? '').trim();
    final memberId = memberName.isEmpty ? null : _resolveMember(memberName)?.id;
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

  Future<AiToolOutcome> _queryExpenses(Map<String, dynamic> args) async {
    final rows = _filtered(args).toList()
      ..sort((a, b) => a.dateEpochDay.compareTo(b.dateEpochDay));
    var total = 0, prepay = 0;
    final byCat = <String, int>{};
    for (final e in rows) {
      total += e.amountCents;
      if (e.type == ExpenseType.prepay) prepay += e.amountCents;
      byCat[e.categoryKey] = (byCat[e.categoryKey] ?? 0) + e.amountCents;
    }
    final topCat = (byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .firstOrNull;
    String catName(String key) =>
        _categories.where((c) => c.key == key).firstOrNull?.name ?? key;

    final data = {
      'items': [
        for (final e in rows)
          {
            'date': fmtIsoDate(epochDayToDate(e.dateEpochDay)),
            'title': e.title,
            'type': e.type.name,
            'yuan': e.amountCents / 100,
            'payer': e.payers.map((p) => _memberName(p.memberId)).join('、'),
            'category': catName(e.categoryKey),
          },
      ],
      'totalYuan': total / 100,
      'prepayYuan': prepay / 100,
    };

    if (_detail(args)) {
      return AiToolOutcome(jsonStr({
        'count': rows.length,
        ...data,
      }));
    }
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'expense_list',
        'count': rows.length,
        'totalYuan': total / 100,
        'prepayYuan': prepay / 100,
        'topCategory': topCat == null
            ? null
            : '${catName(topCat.key)} ¥${topCat.value / 100}',
        'hint': '明细已以卡片展示给用户，回答给结论与简短解读即可，不要复述列表；用户要看具体条目时带 detail:true 重查',
      }),
      cardType: 'expense_list',
      cardData: data,
    );
  }

  // ---- 余额 / 预算 / 结算 ----

  Future<AiToolOutcome> _balances() async {
    if (_members.isEmpty) return AiToolOutcome('{"error":"当前团还没有成员"}');
    final board = _ref.read(memberBoardProvider).value ?? const <MemberStatView>[];
    final net = netBalanceMap(
        _members, _expenses.where((e) => e.settledRoundId == null).toList());
    final plans = transferPlanOf(net);
    final data = {
      'board': [
        for (final b in board)
          {
            'member': b.member.name,
            'paidYuan': b.paidCents / 100,
            'shareYuan': b.shareCents / 100,
            'balanceYuan': b.balanceCents / 100,
          },
      ],
      'suggestTransfers': [
        for (final t in plans)
          {
            'from': _memberName(t.from),
            'to': _memberName(t.to),
            'yuan': t.cents / 100,
          },
      ],
    };
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'balances',
        'memberCount': board.length,
        'suggestTransfers': data['suggestTransfers'],
        'hint': '余额明细已以卡片展示；回答"谁欠谁多少"直接引用建议转账即可',
      }),
      cardType: 'balances',
      cardData: data,
    );
  }

  Future<AiToolOutcome> _budgetStatus() async {
    final b = _ref.read(budgetStatusProvider).value;
    if (b == null) return AiToolOutcome('{"error":"预算状态尚未加载"}');
    final data = {
      'enabled': b.enabled,
      'totalYuan': b.totalCents / 100,
      'spentYuan': b.spentCents / 100,
      'remainingYuan': b.remainingCents / 100,
      'percent': b.percent,
    };
    return AiToolOutcome(
      jsonStr({
        ...data,
        'renderedCard': 'budget',
        'hint': '预算已以卡片展示，回答只需一句结论',
      }),
      cardType: 'budget',
      cardData: data,
    );
  }

  Future<AiToolOutcome> _setBudget(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return AiToolOutcome('{"error":"尚未选择旅行团"}');
    final yuan = (args['totalYuan'] as num?)?.toDouble();
    if (yuan == null || yuan <= 0) return AiToolOutcome('{"error":"预算金额必须大于 0"}');
    final enabled = args['enabled'] is bool ? args['enabled'] as bool : true;
    await _ref
        .read(ledgerRepoProvider)
        .setBudget(gid, enabled: enabled, budgetCents: (yuan * 100).round());
    return AiToolOutcome('{"ok":true,"message":"预算已设置为 ¥$yuan"}');
  }

  Future<AiToolOutcome> _settlementStatus() async {
    final all = _ref.read(settlementsProvider).value ?? const <SettlementView>[];
    final active = all.where((s) => s.active).toList();
    final rounds = [
      for (final s in active)
        {
          'roundNo': s.roundNo,
          'transfers': [
            for (final t in s.transfers)
              {
                'from': _memberName(t.from),
                'to': _memberName(t.to),
                'yuan': t.cents / 100,
                'confirmed': t.done,
              },
          ],
        },
    ];
    var unconfirmed = 0;
    for (final r in rounds) {
      for (final t in (r['transfers'] as List).cast<Map>()) {
        if (t['confirmed'] != true) unconfirmed++;
      }
    }
    return AiToolOutcome(
      jsonStr({
        'hasActive': active.isNotEmpty,
        'unconfirmedCount': unconfirmed,
        'renderedCard': 'settlements',
        'hint': '转账明细已以卡片展示；结算确认需用户在结算页手动完成',
      }),
      cardType: 'settlements',
      cardData: {'rounds': rounds, 'hasActive': active.isNotEmpty},
    );
  }

  // ---- 记账 ----

  /// add_expense：不落库，出示确认卡（用户点确认 → commitExpenseDraft 本地落库，零 token）。
  Future<AiToolOutcome> _addExpense(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return AiToolOutcome('{"error":"尚未选择旅行团，无法记账"}');
    if (_members.isEmpty) return AiToolOutcome('{"error":"当前团没有成员，请先添加成员"}');

    final title = (args['title'] as String? ?? '').trim();
    final amountYuan = (args['amountYuan'] as num?)?.toDouble();
    if (title.isEmpty) return AiToolOutcome('{"error":"缺少账单标题"}');
    if (amountYuan == null || amountYuan == 0) return AiToolOutcome('{"error":"金额不能为 0"}');

    final expenseType = args['expenseType'] == 'refund' ? 'refund' : 'normal';
    final payer = _resolveMember(args['payerName'] as String? ?? '');
    if (payer == null) {
      return AiToolOutcome(
          '{"error":"找不到付款人「${args['payerName']}」，现有成员：${_members.map((m) => m.name).join('、')}"}');
    }

    final shareNames = (args['shareMembers'] as List?)
        ?.whereType<Object>()
        .map((e) => e.toString())
        .toList();
    final shareList = (shareNames == null || shareNames.isEmpty)
        ? [for (final m in _members) m.name]
        : [
            for (final n in shareNames)
              if (_resolveMember(n) != null) _resolveMember(n)!.name,
          ];

    final catKey = _categoryKeyOf(args['categoryKey'] as String?);
    final catName = _categoryNameOf(args['categoryKey'] as String?);
    final day = _epochDay(args['date']) ?? todayEpochDay();

    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'expense_confirm',
        'hint': '已向用户出示记账确认卡，等待用户点确认，本地会自动落库；回答一句话说明即可，不要重复账单内容',
      }),
      cardType: 'expense_confirm',
      cardData: {
        'args': {
          'title': title,
          'amountYuan': amountYuan,
          'expenseType': expenseType,
          'payerName': payer.name,
          'shareMembers': shareList,
          'categoryKey': catKey,
          'categoryName': catName,
          'date': fmtIsoDate(epochDayToDate(day)),
          'currencyCode': (args['currencyCode'] as String? ?? 'CNY').trim().toUpperCase(),
          'note': (args['note'] as String?)?.trim() ?? '',
        },
      },
    );
  }

  // ---- 行程 ----

  Future<AiToolOutcome> _listTrips() async {
    final data = {
      'trips': [
        for (final t in _trips)
          {
            'id': t.id,
            'emoji': t.emoji,
            'name': t.name,
            'destination': t.destination,
            'start': fmtIsoDate(epochDayToDate(t.startEpochDay)),
            'end': fmtIsoDate(epochDayToDate(t.endEpochDay)),
          },
      ],
    };
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'trip_list',
        'count': _trips.length,
        // id 必须带给模型（add_trip_item / update_trip_dates 需要）
        'trips': [
          for (final t in _trips)
            {
              'id': t.id,
              'name': t.name,
              'start': fmtIsoDate(epochDayToDate(t.startEpochDay)),
              'end': fmtIsoDate(epochDayToDate(t.endEpochDay)),
            },
        ],
        'hint': '行程已以卡片展示；回答无需复述列表',
      }),
      cardType: 'trip_list',
      cardData: data,
    );
  }

  Future<AiToolOutcome> _createTrip(Map<String, dynamic> args) async {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    if (end < start) return AiToolOutcome('{"error":"结束日期早于开始日期"}');
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"缺少行程名称"}');
    final emoji = (args['emoji'] as String? ?? '').trim();
    final id = await _ref.read(tripsRepoProvider).createTrip(
          name: name,
          dest: (args['destination'] as String? ?? '').trim(),
          emoji: emoji.isEmpty ? '✈️' : emoji,
          cover: 'ocean',
          start: start,
          end: end,
          note: (args['note'] as String? ?? '').trim(),
          groupId: _group?.id,
        );
    return AiToolOutcome(jsonStr({'ok': true, 'tripId': id, 'message': '行程「$name」已创建'}));
  }

  Future<AiToolOutcome> _updateTripDates(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = await _ref.read(tripsRepoProvider).getById(tripId ?? '');
    if (trip == null) return AiToolOutcome('{"error":"找不到行程 id=$tripId"}');
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    if (end < start) return AiToolOutcome('{"error":"结束日期早于开始日期"}');
    await _ref.read(tripsRepoProvider).updateDates(trip.id, start, end);
    return AiToolOutcome(jsonStr({
      'ok': true,
      'message': '「${trip.name}」日期已改为 ${args['startDate']} ~ ${args['endDate']}',
    }));
  }

  Future<AiToolOutcome> _addTripItem(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = await _ref.read(tripsRepoProvider).getById(tripId ?? '');
    if (trip == null) {
      final all = [
        for (final t in _trips)
          {'id': t.id, 'name': t.name},
      ];
      return AiToolOutcome('{"error":"找不到行程 id=$tripId，可用行程：${jsonStr({'trips': all})}"}');
    }
    final day = _epochDay(args['date']);
    if (day == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');

    final type = findTripItemType(args['itemType'] as String? ?? 'attraction').key;
    final startMin = _hhmmToMin(args['startTime'] as String?);
    final costYuan = (args['costYuan'] as num?)?.toDouble();
    final items = await _ref.read(tripsRepoProvider).getItems(trip.id);
    final sameDayCount = items.where((i) => i.dateEpochDay == day).length;

    await _ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
          id: Value(newId('item')),
          tripId: Value(trip.id),
          dateEpochDay: Value(day),
          type: Value(type),
          name: Value((args['name'] as String? ?? '').trim()),
          address: Value((args['address'] as String? ?? '').trim()),
          startTimeMin: Value(startMin),
          durationMin: Value(
              args['durationMinutes'] is int ? args['durationMinutes'] as int : null),
          costCents:
              costYuan == null ? const Value(null) : Value((costYuan * 100).round()),
          note: Value((args['note'] as String? ?? '').trim()),
          sortOrder: Value(sameDayCount),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
    return AiToolOutcome(jsonStr({
      'ok': true,
      'message': '已在「${trip.name}」添加安排：${args['name']}（$type）',
    }));
  }

  Future<AiToolOutcome> _tripSchedule(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = await _ref.read(tripsRepoProvider).getById(tripId ?? '');
    if (trip == null) return AiToolOutcome('{"error":"找不到行程 id=$tripId"}');
    final items = await _ref.read(tripsRepoProvider).getItems(trip.id);
    final sorted = [...items]..sort((a, b) {
        final byDay = a.dateEpochDay.compareTo(b.dateEpochDay);
        if (byDay != 0) return byDay;
        return (a.startTimeMin ?? 9999).compareTo(b.startTimeMin ?? 9999);
      });

    final detailRows = [
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
    ];
    final byDay = <String, int>{};
    for (final i in sorted) {
      final k = fmtIsoDate(epochDayToDate(i.dateEpochDay));
      byDay[k] = (byDay[k] ?? 0) + 1;
    }

    final data = {'trip': trip.name, 'items': detailRows};
    if (_detail(args)) {
      return AiToolOutcome(jsonStr({'count': sorted.length, ...data}));
    }
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'schedule',
        'count': sorted.length,
        'byDay': byDay,
        'hint': '日程已以卡片展示；用户要看某天细节时带 detail:true 重查',
      }),
      cardType: 'schedule',
      cardData: data,
    );
  }

  /// 一键生成整包行程：建行程 + 批量写安排，一次调用完成。
  Future<AiToolOutcome> _createTripPlan(Map<String, dynamic> args) async {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    if (end < start) return AiToolOutcome('{"error":"结束日期早于开始日期"}');
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"缺少行程名称"}');
    final daysRaw = args['days'];
    if (daysRaw is! List || daysRaw.isEmpty) return AiToolOutcome('{"error":"days 不能为空"}');

    final emoji = (args['emoji'] as String? ?? '').trim();
    final tripId = await _ref.read(tripsRepoProvider).createTrip(
          name: name,
          dest: (args['destination'] as String? ?? '').trim(),
          emoji: emoji.isEmpty ? '✈️' : emoji,
          cover: 'ocean',
          start: start,
          end: end,
          note: '',
          groupId: _group?.id,
        );

    // 同一天的安排按出现顺序排 sortOrder
    final perDayCount = <int, int>{};
    var inserted = 0;
    final skipped = <String>[];
    final totalDays = end - start + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final dayEntry in daysRaw) {
      if (dayEntry is! Map) continue;
      final dayNo = (dayEntry['day'] as num?)?.toInt() ?? 0;
      final itemsRaw = dayEntry['items'];
      if (dayNo < 1 || dayNo > totalDays || itemsRaw is! List) {
        skipped.add('day $dayNo');
        continue;
      }
      for (final itemRaw in itemsRaw) {
        if (itemRaw is! Map) continue;
        final itemName = (itemRaw['name'] as String? ?? '').trim();
        if (itemName.isEmpty) continue;
        final idx = perDayCount[dayNo] ?? 0;
        perDayCount[dayNo] = idx + 1;
        final costYuan = (itemRaw['costYuan'] as num?)?.toDouble();
        await _ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
              id: Value(newId('item')),
              tripId: Value(tripId),
              dateEpochDay: Value(start + dayNo - 1),
              type: Value(findTripItemType(itemRaw['type'] as String? ?? 'attraction').key),
              name: Value(itemName),
              address: Value((itemRaw['address'] as String? ?? '').trim()),
              startTimeMin: Value(_hhmmToMin(itemRaw['startTime'] as String?)),
              costCents:
                  costYuan == null ? const Value(null) : Value((costYuan * 100).round()),
              note: Value((itemRaw['note'] as String? ?? '').trim()),
              sortOrder: Value(idx * 10),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
        inserted++;
      }
    }

    // 顺手存成模板，供「行程模板库」复用
    await saveTemplate(TripTemplate(
      id: newId('tpl'),
      name: name,
      destination: (args['destination'] as String? ?? '').trim(),
      emoji: emoji.isEmpty ? '✈️' : emoji,
      createdAtMs: now,
      items: [
        for (final dayEntry in daysRaw)
          if (dayEntry is Map && (dayEntry['day'] as num?)!.toInt() >= 1 && dayEntry['items'] is List)
            for (final itemRaw in (dayEntry['items'] as List).cast<Map>())
              if ((itemRaw['name'] as String? ?? '').trim().isNotEmpty)
                TripTemplateItem(
                  day: (dayEntry['day'] as num).toInt(),
                  name: (itemRaw['name'] as String).trim(),
                  type: findTripItemType(itemRaw['type'] as String? ?? 'attraction').key,
                  startTimeMin: _hhmmToMin(itemRaw['startTime'] as String?),
                  costCents: itemRaw['costYuan'] == null
                      ? null
                      : ((itemRaw['costYuan'] as num).toDouble() * 100).round(),
                  address: (itemRaw['address'] as String? ?? '').trim(),
                  note: (itemRaw['note'] as String? ?? '').trim(),
                ),
      ],
    ));

    return AiToolOutcome(jsonStr({
      'ok': true,
      'tripId': tripId,
      'message': '行程「$name」已创建，写入 $inserted 条安排${skipped.isEmpty ? '' : '（越界的 ${skipped.join('、')} 被忽略）'}，并已存为同名模板',
    }));
  }

  Future<AiToolOutcome> _saveTripTemplate(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = await _ref.read(tripsRepoProvider).getById(tripId ?? '');
    if (trip == null) return AiToolOutcome('{"error":"找不到行程 id=$tripId"}');
    final items = await _ref.read(tripsRepoProvider).getItems(trip.id);
    if (items.isEmpty) return AiToolOutcome('{"error":"行程「${trip.name}」没有安排，存模板没意义"}');
    final start = trip.startEpochDay;
    await saveTemplate(TripTemplate(
      id: newId('tpl'),
      name: trip.name,
      destination: trip.destination,
      emoji: trip.emoji,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      items: [
        for (final i in items)
          TripTemplateItem(
            day: (i.dateEpochDay - start) + 1,
            name: i.name,
            type: i.type,
            startTimeMin: i.startTimeMin,
            costCents: i.costCents,
            address: i.address,
            note: i.note,
          ),
      ],
    ));
    return AiToolOutcome('{"ok":true,"message":"行程「${trip.name}」已存为模板（${items.length} 条安排）"}');
  }

  Future<AiToolOutcome> _listTripTemplates() async {
    final templates = await loadTemplates();
    if (templates.isEmpty) return AiToolOutcome('{"templates":[],"hint":"还没有行程模板"}');
    return AiToolOutcome(jsonStr({
      'templates': [
        for (final t in templates)
          {
            'templateId': t.id,
            'name': t.name,
            'destination': t.destination,
            'days': t.dayCount,
            'items': t.items.length,
          },
      ],
      'hint': 'apply_trip_template 需要 templateId 与新开始日期',
    }));
  }

  Future<AiToolOutcome> _applyTripTemplate(Map<String, dynamic> args) async {
    final templateId = args['templateId'] as String?;
    final templates = await loadTemplates();
    TripTemplate? template;
    for (final t in templates) {
      if (t.id == templateId) template = t;
    }
    if (template == null) {
      return AiToolOutcome(
          '{"error":"找不到模板 id=$templateId，可用模板：${[for (final t in templates) {'id': t.id, 'name': t.name}]}"}');
    }
    final start = _epochDay(args['startDate']);
    if (start == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    final end = start + (template.dayCount - 1).clamp(0, 365);
    final gid = _group?.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    final tripId = await _ref.read(tripsRepoProvider).createTrip(
          name: template.name,
          dest: template.destination,
          emoji: template.emoji,
          cover: 'ocean',
          start: start,
          end: end,
          groupId: gid,
        );
    final perDayCount = <int, int>{};
    for (final i in template.items) {
      final idx = perDayCount[i.day] ?? 0;
      perDayCount[i.day] = idx + 1;
      await _ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
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
    return AiToolOutcome(jsonStr({
      'ok': true,
      'tripId': tripId,
      'message': '已用模板「${template.name}」创建行程，写入 ${template.items.length} 条安排',
    }));
  }

  // ---- 清单 ----

  Future<AiToolOutcome> _addChecklistItem(Map<String, dynamic> args) async {
    final text = (args['text'] as String? ?? '').trim();
    if (text.isEmpty) return AiToolOutcome('{"error":"缺少条目内容"}');
    final tripId = args['tripId'] as String?;
    if (tripId != null) {
      final trip = await _ref.read(tripsRepoProvider).getById(tripId);
      if (trip == null) return AiToolOutcome('{"error":"找不到行程 id=$tripId"}');
    }
    final scope = tripId == null ? 'global' : 'trip';
    var category = (args['category'] as String? ?? '').trim();
    if (!kChecklistCategories.any((c) => c.key == category)) category = 'other';
    final existing =
        await _ref.read(checklistRepoProvider).getAllByScope(scope, tripId: tripId);
    final maxOrder = existing.isEmpty
        ? 0
        : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);
    await _ref
        .read(checklistRepoProvider)
        .addItem(tripId, scope, category, text, maxOrder + 10);
    return AiToolOutcome(jsonStr({
      'ok': true,
      'message': tripId == null ? '已添加全局待办：$text' : '已添加行程清单项：$text',
    }));
  }

  Future<AiToolOutcome> _toggleChecklistItem(Map<String, dynamic> args) async {
    final text = (args['text'] as String? ?? '').trim();
    if (text.isEmpty) return AiToolOutcome('{"error":"缺少条目文字"}');
    final tripId = args['tripId'] as String?;
    final scope = tripId == null ? 'global' : 'trip';
    final items =
        await _ref.read(checklistRepoProvider).getAllByScope(scope, tripId: tripId);
    final hit =
        items.where((i) => i.label.contains(text) || text.contains(i.label)).toList();
    if (hit.isEmpty) return AiToolOutcome('{"error":"找不到清单项「$text」"}');
    if (hit.length > 1) {
      return AiToolOutcome(
          '{"error":"匹配到 ${hit.length} 条（${hit.map((h) => h.label).join('、')}），请提供更精确的文字"}');
    }
    final target = hit.first;
    final done = args['done'] is bool ? args['done'] as bool : !target.done;
    await _ref.read(checklistRepoProvider).toggleDone(target.id, done);
    return AiToolOutcome(jsonStr({
      'ok': true,
      'message': '「${target.label}」已标记为${done ? '已备好' : '未备好'}',
    }));
  }

  Future<AiToolOutcome> _queryChecklist(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final scope = tripId == null ? 'global' : 'trip';
    final items =
        await _ref.read(checklistRepoProvider).getAllByScope(scope, tripId: tripId);
    final data = {
      'items': [
        for (final i in items)
          {
            'label': i.label,
            'category': i.category,
            'done': i.done,
          },
      ],
    };
    final undone = items.where((i) => !i.done).map((i) => i.label).toList();
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'checklist',
        'total': items.length,
        'undone': undone.length,
        'undoneLabels': undone.take(10).toList(),
        'hint': '清单已以卡片展示；回答"还缺什么"引用未完成项即可',
      }),
      cardType: 'checklist',
      cardData: data,
    );
  }

  // ---- 设置类 ----

  Future<AiToolOutcome> _setTheme(Map<String, dynamic> args) async {
    final key = args['themeKey'] as String?;
    if (key == null || !ThemeKeys.all.contains(key)) {
      return AiToolOutcome('{"error":"无效的主题 key"}');
    }
    await _ref.read(themeProvider.notifier).setTheme(key);
    return AiToolOutcome('{"ok":true,"message":"主题已切换为 ${ThemeKeys.labels[key]}"}');
  }

  Future<AiToolOutcome> _setAlerts(Map<String, dynamic> args) async {
    final enabled = args['enabled'];
    if (enabled is! bool) return AiToolOutcome('{"error":"enabled 必须是布尔值"}');
    await _ref.read(prefsRepoProvider).setBudgetAlertsEnabled(enabled);
    _ref.invalidate(budgetAlertsEnabledProvider);
    return AiToolOutcome('{"ok":true,"message":"预算预警已${enabled ? '开启' : '关闭'}"}');
  }
}

// ---------------------------------------------------------------------------
// System Prompt：静态段（固定不变，命中前缀缓存）+ 动态段（每次发送重建，放在末尾）
// ---------------------------------------------------------------------------

/// 静态系统提示词：内容固定不变，保证每次请求的前缀缓存命中。
String buildStaticSystemPrompt() =>
    '你是「旅途助手」App 的内置 AI 管家，帮用户管理旅行团、AA 记账、行程、清单与应用设置。\n'
    '规则：\n'
    '1. 只能通过提供的工具操作本应用数据，无法触达应用之外的任何功能。\n'
    '2. 没有删除类工具；删除、结算确认等操作引导用户到对应页面手动完成。\n'
    '3. 金额单位为元，日期格式 YYYY-MM-DD；不要臆造 memberId/tripId/分类 key，信息不足先向用户确认。\n'
    '4. 查询类工具的结果会以卡片直接展示给用户：回答只给结论与简短解读，不要复述列表数据；确需明细时带 detail:true 重查。\n'
    '5. 用简体中文，回答尽量简短（通常 1~3 句）；执行写入操作后用一句话报告结果。';

/// 动态上下文：当前日期 / 团 / 成员 / 分类 / 行程。放在消息序列末尾（最新 user 之前），
/// 不破坏静态前缀；内容无变化时整段可被服务端前缀缓存复用。
Future<String> buildDynamicContext(Ref ref) async {
  final group = ref.read(activeGroupProvider).value;
  final members = ref.read(membersProvider).value ?? const [];
  final categories = ref.read(categoriesProvider).value ?? const [];
  final trips = ref.read(tripsInGroupProvider).value ?? const [];

  final sb = StringBuffer();
  sb.write('【当前上下文】今天是');
  sb.write(fmtFullDateOfEpoch(todayEpochDay()));
  sb.write('。');
  if (group == null) {
    sb.write('当前未选择旅行团，记账/预算相关操作会失败，请提醒用户先到「账本」页建团。');
  } else {
    sb.write('当前团「${group.name}」（预算${group.budgetEnabled ? '已开启' : '未开启'}）。');
  }
  if (members.isEmpty) {
    sb.write('还没有成员。');
  } else {
    sb.write('成员：${members.map((m) => m.name).join('、')}。');
  }
  if (categories.isNotEmpty) {
    sb.write('分类：${categories.map((c) => '${c.key}(${c.name})').join('、')}。');
  }
  if (trips.isEmpty) {
    sb.write('当前团无关联行程。');
  } else {
    sb.write('行程：');
    sb.write(trips
        .map((t) =>
            '${t.name}(id=${t.id},${fmtIsoDate(epochDayToDate(t.startEpochDay))}~${fmtIsoDate(epochDayToDate(t.endEpochDay))})')
        .join('、'));
    sb.write('。');
  }
  return sb.toString();
}

// ---------------------------------------------------------------------------
// 小工具
// ---------------------------------------------------------------------------

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
    final v = const JsonDecoder().convert(text);
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final inner = const JsonDecoder().convert(text.substring(start, end + 1));
      if (inner is Map) return Map<String, dynamic>.from(inner);
    } catch (_) {}
  }
  throw FormatException('bad json: $s');
}

String _esc(String raw) =>
    raw.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ');

/// 供测试 / 非 widget 环境获取执行器
final aiToolExecutorProvider = Provider<AiToolExecutor>((r) => AiToolExecutor(r));

// ---------------------------------------------------------------------------
// 确认卡落库（点「确认记账」时本地执行，不发任何 AI 请求）
// ---------------------------------------------------------------------------

/// 把确认卡携带的草稿参数解析成完整账单并落库。
///
/// 返回 null 表示成功；否则返回错误文案（找不到成员等），卡片上展示。
/// [args] 为确认卡 cardData['args']（名字已解析成显示名，此处转回 id）。
Future<String?> commitExpenseDraft(WidgetRef ref, Map<String, dynamic> args) async {
  final gid = ref.read(activeGroupProvider).value?.id;
  if (gid == null) return '尚未选择旅行团';
  final members = ref.read(membersProvider).value ?? const [];
  final categories = ref.read(categoriesProvider).value ?? const [];
  if (members.isEmpty) return '当前团没有成员';

  LedgerMemberView? byName(String n) {
    final exact = members.where((m) => m.name == n).toList();
    if (exact.length == 1) return exact.first;
    final fuzzy = members.where((m) => m.name.contains(n) || n.contains(m.name)).toList();
    return fuzzy.length == 1 ? fuzzy.first : null;
  }

  final payer = byName((args['payerName'] as String? ?? '').trim());
  if (payer == null) return '找不到付款人「${args['payerName']}」';

  final shareIds = <String>[];
  final shareNames = (args['shareMembers'] as List?)
          ?.whereType<Object>()
          .map((e) => e.toString())
          .toList() ??
      const [];
  if (shareNames.isEmpty) {
    shareIds.addAll(members.map((m) => m.id));
  } else {
    for (final n in shareNames) {
      final m = byName(n);
      if (m == null) return '找不到分摊成员「$n」';
      if (!shareIds.contains(m.id)) shareIds.add(m.id);
    }
  }

  final amountYuan = (args['amountYuan'] as num?)?.toDouble() ?? 0;
  if (amountYuan == 0) return '金额不能为 0';
  final isRefund = args['expenseType'] == 'refund';
  final cents = (amountYuan.abs() * 100).round();
  final signed = isRefund ? -cents : cents;
  final shares =
      computeSplit(totalCents: signed, memberIds: shareIds, mode: ShareMode.equal);

  var catKey = 'other';
  final givenCat = (args['categoryKey'] as String? ?? '').trim();
  if (givenCat.isNotEmpty) {
    final hit = categories.where((c) => c.key == givenCat || c.name == givenCat).toList();
    catKey = hit.isEmpty ? 'other' : hit.first.key;
  }

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

  final day = _epochDayPublic(args['date']) ?? todayEpochDay();
  final draft = ExpenseDraft(
    groupId: gid,
    dateEpochDay: day,
    title: (args['title'] as String? ?? '').trim(),
    categoryKey: catKey,
    type: isRefund ? ExpenseType.refund : ExpenseType.normal,
    amountCents: signed,
    currency: currency,
    rate: rate,
    payers: [ShareEntry(memberId: payer.id, cents: signed)],
    shares: shares,
    shareMode: ShareMode.equal,
    note: (args['note'] as String?)?.trim(),
  );

  final now = DateTime.now().millisecondsSinceEpoch;
  await ref.read(ledgerRepoProvider).addExpense(ExpensesCompanion(
        id: Value(newId('expense')),
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
        note: Value(draft.note ?? ''),
        createdAt: Value(now),
      ));
  return null;
}

/// 与执行器内部同源的日期解析（公开别名，供确认卡落库用）
int? _epochDayPublic(dynamic v) => _epochDay(v);
