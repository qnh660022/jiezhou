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
import '../../data/guide/guide_ai_draft.dart';
import '../../data/guide/guide_models.dart';
import '../../data/guide/guide_providers.dart'
    show guideDraftKeyProvider, guideServiceProvider;
import '../../data/guide/guide_service.dart' show GuideService;
import '../../data/providers.dart';
import '../../data/seed/currencies.dart';
import '../../data/seed/item_types.dart';
import '../../data/seed/checklist_templates.dart';
import '../../data/services/ai_chat_service.dart';
import '../../domain/models.dart';
import '../ledger/ledger_models.dart';
import '../ledger/ledger_providers.dart';
import '../trips/trip_template_store.dart';
import '../../shared/copy_tokens.dart';
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
    description: '查询当前团账单并以卡片展示。默认返回汇总即可答总额/大头/均值；要看条目时传 detail:true。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'startDate': {'type': 'string', 'description': 'YYYY-MM-DD（含）'},
        'endDate': {'type': 'string', 'description': 'YYYY-MM-DD（含）'},
        'categoryKey': {'type': 'string'},
        'memberName': {'type': 'string'},
        'keyword': {'type': 'string'},
        'detail': {'type': 'boolean', 'description': 'true 返回条目列表'},
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
        '记一笔账（均摊）。不直接落库，先出确认卡，用户点确认后本地落库。payer 必须是真实成员名；shareMembers 缺省全体平摊；退款 expenseType=refund，金额填正数。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'amountYuan': {'type': 'number', 'description': '元'},
        'expenseType': {'type': 'string', 'enum': ['normal', 'refund']},
        'payerName': {'type': 'string', 'description': '付款人成员名'},
        'shareMembers': {'type': 'array', 'items': {'type': 'string'}, 'description': '缺省全体'},
        'categoryKey': {'type': 'string', 'description': '未知留空按 other'},
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
        '一键生成行程：建行程+批量写入多日安排，一次调用完成（不要逐条 add_trip_item）。items[].type 取 attraction/food/transport/stay/note。',
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
          'description': '按天组织，day 从 1 起（相对 startDate）',
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
    name: 'create_travel_pack',
    description:
        '一键旅行包：建团+成员+预算+行程+每日安排+清单+样例账单，预览卡确认后一次落库。\n'
        '用户一句话提需求即调用本工具，不要分步调用其他工具。\n'
        'days/checklist/sampleExpenses 可按需精简；只需简述方案，不要复述完整清单。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'groupName': {'type': 'string', 'description': '缺省用目的地命名'},
        'memberNames': {'type': 'array', 'items': {'type': 'string'}},
        'budgetYuan': {'type': 'number', 'description': '元'},
        'tripName': {'type': 'string'},
        'destination': {'type': 'string'},
        'startDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'endDate': {'type': 'string', 'description': 'YYYY-MM-DD，天数=end-start+1'},
        'days': {
          'type': 'array',
          'description': '按天排日程，day 从 1 起',
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
                    'type': {'type': 'string', 'enum': ['attraction', 'food', 'transport', 'stay', 'note']},
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
        'checklist': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string'},
              'category': {'type': 'string', 'enum': ['docs', 'clothes', 'electronics', 'toiletries', 'medicine', 'other']},
            },
            'required': ['text'],
          },
        },
        'sampleExpenses': {
          'type': 'array',
          'description': '样例账单，均摊到全体成员、关联行程',
          'items': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string'},
              'amountYuan': {'type': 'number'},
              'payerName': {'type': 'string', 'description': 'memberNames 之一'},
              'categoryKey': {'type': 'string'},
              'date': {'type': 'string', 'description': '缺省同行程开始日'},
              'expenseType': {'type': 'string', 'enum': ['normal', 'refund']},
            },
            'required': ['title', 'amountYuan', 'payerName'],
          },
        },
      },
      'required': ['tripName', 'destination', 'startDate', 'endDate', 'days'],
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
  const AiToolDefinition(
    name: 'update_expense',
    description: '修改账单。expenseId 必须来自 query_expenses(detail:true) 的返回；只传要改的字段，确认卡展示改动后由用户确认。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'expenseId': {'type': 'string'},
        'title': {'type': 'string'},
        'amountYuan': {'type': 'number', 'description': '元'},
        'payerName': {'type': 'string'},
        'categoryKey': {'type': 'string'},
        'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'note': {'type': 'string'},
      },
      'required': ['expenseId'],
    },
  ),
  const AiToolDefinition(
    name: 'delete_expense',
    description: '删除账单（需用户在确认卡上确认）。expenseId 来自 query_expenses(detail:true)。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'expenseId': {'type': 'string'},
      },
      'required': ['expenseId'],
    },
  ),
  const AiToolDefinition(
    name: 'get_expense_stats',
    description: '按分类/付款成员/日期统计账单金额并以统计卡展示。回答"钱都花哪了/谁花得多"用这个。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'groupBy': {'type': 'string', 'enum': ['category', 'member', 'day']},
        'startDate': {'type': 'string', 'description': 'YYYY-MM-DD（含）'},
        'endDate': {'type': 'string', 'description': 'YYYY-MM-DD（含）'},
        'categoryKey': {'type': 'string'},
        'memberName': {'type': 'string'},
      },
      'required': ['groupBy'],
    },
  ),
  const AiToolDefinition(
    name: 'delete_trip_item',
    description: '删除行程中的一条安排（需用户确认）。tripId 必填；itemId 来自 get_trip_schedule(detail:true)，或用 name 模糊匹配（可带 date 缩小范围）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'tripId': {'type': 'string'},
        'itemId': {'type': 'string', 'description': '与 name 二选一'},
        'name': {'type': 'string', 'description': '安排名模糊匹配'},
        'date': {'type': 'string', 'description': 'YYYY-MM-DD，配合 name 缩小范围'},
      },
      'required': ['tripId'],
    },
  ),
  const AiToolDefinition(
    name: 'list_groups',
    description: '列出全部旅行团（含 id 与是否当前团）。切换团前先调用。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'switch_group',
    description: '切换当前旅行团（可逆，直接执行）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'groupName': {'type': 'string'},
      },
      'required': ['groupName'],
    },
  ),
  const AiToolDefinition(
    name: 'rename_group',
    description: '重命名当前旅行团（直接执行）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
      'required': ['name'],
    },
  ),
  const AiToolDefinition(
    name: 'remove_member',
    description: '从当前旅行团移除一名成员（需用户在确认卡上确认）。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'memberName': {'type': 'string'},
      },
      'required': ['memberName'],
    },
  ),
  // ===== 目的地攻略生成（2026-09 需求 5；内容由用户确认后本地导入） =====
  const AiToolDefinition(
    name: 'guide_list_cities',
    description:
        '列出「目的地攻略」里已有的城市（含 key）。生成攻略前先用它核对城市，'
        '不要自己造 key——key 不对会导致导入的内容挂不到城市上。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'guide_prepare',
    description:
        '开始为一座城市生成攻略。必须最先调用。之后用 guide_add_section 逐栏提交内容，'
        '最后用 guide_finish 出确认卡。一次只做一座城市。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': '城市中文名，如「杭州」'},
      },
      'required': ['city'],
    },
  ),
  const AiToolDefinition(
    name: 'guide_add_section',
    description:
        '提交攻略某一栏的内容（同一栏可多次调用追加）。严格按各栏字段结构给，不要自创字段名。'
        '字数建议：prep 每条 120-220 字、spots 200-350 字、food 150-280 字、'
        'transport 100-200 字、tips 100-200 字；六栏合计目标 5500 字以上。'
        '字段：prep=[{title,detail}]；spots=[{name,addr,tag,timeText,note}]（tag 限 '
        '必去/经典/小众/亲子）；food=[{name,area,note}]；transport=[{mode,line,note}]；'
        'tips=[{title,detail}]；budget=[{item,rangeText}]。'
        '票价/时间/预约规则必须写「（参考）」或「以官方公告为准」，不确定的宁可不写、不许编造。',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'section': {
          'type': 'string',
          'enum': ['prep', 'spots', 'food', 'transport', 'tips', 'budget'],
          'description': 'prep 行前准备 / spots 景点 / food 美食 / '
              'transport 交通 / tips 避坑 / budget 预算',
        },
        'items': {
          'type': 'array',
          'description': '条目数组，元素结构随 section 变化',
          'items': {'type': 'object'},
        },
      },
      'required': ['section', 'items'],
    },
  ),
  const AiToolDefinition(
    name: 'guide_status',
    description: '查看当前攻略草稿的进度（各栏条数、总字数、还差什么）。',
    parametersSchema: {'type': 'object', 'properties': {}},
  ),
  const AiToolDefinition(
    name: 'guide_finish',
    description:
        '结束生成并出「导入攻略」确认卡。用户点确认后内容才写入本机并成为该城攻略。'
        '内容明显不足时先别调用，用 guide_add_section 补齐。',
    parametersSchema: {'type': 'object', 'properties': {}},
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
      return AiToolOutcome(
          '{"error":"参数不是合法 JSON（疑似模型输出被截断），请用完整且合规的 JSON 参数重新调用一次"}');
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
          return await _setBudgetDraft(args);
        case 'get_settlement_status':
          return await _settlementStatus();
        case 'add_expense':
          return await _addExpense(args);
        case 'update_expense':
          return await _updateExpenseDraft(args);
        case 'delete_expense':
          return await _deleteExpenseDraft(args);
        case 'get_expense_stats':
          return await _expenseStats(args);
        case 'list_trips':
          return await _listTrips();
        case 'create_trip':
          return await _createTrip(args);
        case 'update_trip_dates':
          return await _updateTripDatesDraft(args);
        case 'add_trip_item':
          return await _addTripItem(args);
        case 'delete_trip_item':
          return await _deleteTripItemDraft(args);
        case 'create_trip_plan':
          return await _createTripPlanDraft(args);
        case 'save_trip_template':
          return await _saveTripTemplate(args);
        case 'list_trip_templates':
          return await _listTripTemplates();
        case 'apply_trip_template':
          return await _applyTripTemplateDraft(args);
        case 'create_travel_pack':
          return await _createTravelPack(args);
        case 'get_trip_schedule':
          return await _tripSchedule(args);
        case 'add_checklist_item':
          return await _addChecklistItem(args);
        case 'toggle_checklist_item':
          return await _toggleChecklistItem(args);
        case 'query_checklist':
          return await _queryChecklist(args);
        case 'list_groups':
          return await _listGroups();
        case 'switch_group':
          return await _switchGroup(args);
        case 'rename_group':
          return await _renameGroup(args);
        case 'remove_member':
          return await _removeMemberDraft(args);
        case 'set_app_theme':
          return await _setTheme(args);
        case 'set_budget_alerts_enabled':
          return await _setAlerts(args);
        // ===== 目的地攻略生成 =====
        case 'guide_list_cities':
          return await _guideListCities();
        case 'guide_prepare':
          return await _guidePrepare(args);
        case 'guide_add_section':
          return await _guideAddSection(args);
        case 'guide_status':
          return await _guideStatus(args);
        case 'guide_finish':
          return await _guideFinish(args);
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

  /// 敏感操作统一产出 action_confirm 确认卡：模型只收到一句提示，
  /// 真正落库由用户点「确认」后 ai_confirm_actions.dart 本地完成（零 token）。
  AiToolOutcome _confirmCard({
    required String action,
    required String title,
    required List<List<String>> rows,
    required Map<String, dynamic> args,
    bool danger = false,
    String? note,
  }) {
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'action_confirm',
        'hint': '已向用户出示「$title」确认卡，等待用户在卡片上点确认后本地自动执行；'
            '回答一句话说明即可，不要复述卡片内容',
      }),
      cardType: 'action_confirm',
      cardData: {
        'action': action,
        'title': title,
        'danger': danger,
        if (note != null) 'note': note,
        'rows': [
          for (final r in rows)
            {'label': r[0], 'value': r[1]},
        ],
        'args': args,
      },
    );
  }

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
            'id': e.id, // update_expense / delete_expense 需要
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
      // 明细喂给模型设上限，防止大团整月账单撑爆上下文
      const maxDetail = 100;
      final items = (data['items'] as List);
      return AiToolOutcome(jsonStr({
        'count': rows.length,
        'items': items.length > maxDetail ? items.take(maxDetail).toList() : items,
        if (items.length > maxDetail)
          'note': '明细过长，仅返回前 $maxDetail 条，其余请缩小日期或分类范围重查',
        'totalYuan': total / 100,
        'prepayYuan': prepay / 100,
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

  /// 设置预算：资金类操作，先出确认卡
  Future<AiToolOutcome> _setBudgetDraft(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return AiToolOutcome('{"error":"尚未选择旅行团"}');
    final yuan = (args['totalYuan'] as num?)?.toDouble();
    if (yuan == null || yuan <= 0) {
      return AiToolOutcome('{"error":"预算金额必须大于 0"}');
    }
    final enabled = args['enabled'] is bool ? args['enabled'] as bool : true;
    return _confirmCard(
      action: 'set_group_budget',
      title: '设置预算',
      rows: [
        ['旅行团', _group!.name],
        ['预算总额', '¥${yuan.toStringAsFixed(yuan % 1 == 0 ? 0 : 2)}'],
        ['预警开关', enabled ? '开启' : '关闭'],
      ],
      args: {'totalYuan': yuan, 'enabled': enabled},
    );
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

  // ---- 账单编辑 / 删除（均需确认卡） ----

  ExpenseRecord? _expenseById(String? id) =>
      id == null ? null : _expenses.where((e) => e.id == id).firstOrNull;

  String _expenseDateOf(ExpenseRecord e) => fmtIsoDate(epochDayToDate(e.dateEpochDay));

  /// 修改账单：确认卡展示修改前后对照
  Future<AiToolOutcome> _updateExpenseDraft(Map<String, dynamic> args) async {
    final e = _expenseById(args['expenseId'] as String?);
    if (e == null) {
      return AiToolOutcome(
          '{"error":"找不到账单（expenseId），请先用 query_expenses detail:true 查询获取 id"}');
    }
    final rows = <List<String>>[];
    final patch = <String, dynamic>{'expenseId': e.id};

    final title = (args['title'] as String?)?.trim();
    if (title != null && title.isNotEmpty && title != e.title) {
      rows.add(['标题', '${e.title} → $title']);
      patch['title'] = title;
    }
    final yuan = (args['amountYuan'] as num?)?.toDouble();
    if (yuan != null && yuan != 0 && (yuan * 100).round() != e.amountCents.abs()) {
      rows.add(['金额', '¥${e.amountCents.abs() / 100} → ¥$yuan']);
      patch['amountYuan'] = yuan;
    }
    final payerName = (args['payerName'] as String?)?.trim();
    if (payerName != null && payerName.isNotEmpty) {
      final payer = _resolveMember(payerName);
      if (payer == null) {
        return AiToolOutcome(
            '{"error":"找不到新付款人「$payerName」，现有成员：${_members.map((m) => m.name).join('、')}"}');
      }
      final oldPayer = e.payers.map((p) => _memberName(p.memberId)).join('、');
      if (payer.name != oldPayer) {
        rows.add(['付款人', '$oldPayer → ${payer.name}']);
        patch['payerName'] = payer.name;
      }
    }
    final catGiven = (args['categoryKey'] as String?)?.trim();
    if (catGiven != null && catGiven.isNotEmpty && catGiven != e.categoryKey) {
      rows.add(['分类', '${_categoryNameOf(e.categoryKey)} → ${_categoryNameOf(catGiven)}']);
      patch['categoryKey'] = _categoryKeyOf(catGiven);
    }
    final day = _epochDay(args['date']);
    if (day != null && day != e.dateEpochDay) {
      rows.add(['日期', '${_expenseDateOf(e)} → ${args['date']}']);
      patch['date'] = args['date'];
    }
    final note = args['note'] as String?;
    if (note != null && note.trim() != (e.note ?? '')) {
      rows.add(['备注', '${e.note ?? '（无）'} → ${note.trim().isEmpty ? '（清空）' : note.trim()}']);
      patch['note'] = note.trim();
    }
    if (rows.isEmpty) {
      return AiToolOutcome('{"error":"没有检测到任何字段变化，请确认要修改的内容"}');
    }
    return _confirmCard(
      action: 'update_expense',
      title: '修改账单',
      rows: rows,
      args: patch,
    );
  }

  /// 删除账单：危险操作，确认卡红色警示
  Future<AiToolOutcome> _deleteExpenseDraft(Map<String, dynamic> args) async {
    final e = _expenseById(args['expenseId'] as String?);
    if (e == null) {
      return AiToolOutcome(
          '{"error":"找不到账单（expenseId），请先用 query_expenses detail:true 查询获取 id"}');
    }
    return _confirmCard(
      action: 'delete_expense',
      title: '删除账单',
      danger: true,
      note: '删除后无法恢复，账单将从统计与结算中移除',
      rows: [
        ['标题', e.title],
        ['日期', _expenseDateOf(e)],
        ['金额', '¥${e.amountCents / 100}'],
        ['付款人', e.payers.map((p) => _memberName(p.memberId)).join('、')],
      ],
      args: {'expenseId': e.id},
    );
  }

  // ---- 统计报表 ----

  /// 分类/成员/日期维度统计，卡片直出（省 token）
  Future<AiToolOutcome> _expenseStats(Map<String, dynamic> args) async {
    final groupBy = (args['groupBy'] as String? ?? 'category').trim();
    if (!const {'category', 'member', 'day'}.contains(groupBy)) {
      return AiToolOutcome('{"error":"groupBy 只支持 category / member / day"}');
    }
    final rows = _filtered(args).toList();
    if (rows.isEmpty) {
      return AiToolOutcome(jsonStr({
        'rows': [],
        'hint': '区间内没有账单',
      }));
    }

    final sums = <String, int>{};
    var totalSpend = 0; // 正向消费合计（退款为负不计入占比基数）
    for (final e in rows) {
      final key = switch (groupBy) {
        'member' => e.payers.isEmpty ? '未知' : _memberName(e.payers.first.memberId),
        'day' => fmtIsoDate(epochDayToDate(e.dateEpochDay)),
        _ => _categoryNameOf(e.categoryKey),
      };
      sums[key] = (sums[key] ?? 0) + e.amountCents;
      if (e.amountCents > 0) totalSpend += e.amountCents;
    }
    final sortedEntries = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const topN = 12;
    final top = sortedEntries.take(topN).toList();
    final restSum =
        sortedEntries.skip(topN).fold<int>(0, (acc, e) => acc + e.value);

    String label = switch (groupBy) {
      'member' => '付款成员',
      'day' => '日期',
      _ => '分类',
    };
    final statRows = [
      for (final e in top)
        {
          'label': e.key,
          'yuan': e.value / 100,
          'percent': totalSpend > 0 ? (e.value / totalSpend).clamp(0.0, 1.0) : 0.0,
        },
      if (restSum != 0)
        {
          'label': '其他',
          'yuan': restSum / 100,
          'percent': totalSpend > 0 ? (restSum / totalSpend).clamp(0.0, 1.0) : 0.0,
        },
    ];
    final topSummary = [
      for (final e in top.take(3)) '${e.key} ¥${e.value / 100}',
    ].join('、');
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'expense_stats',
        'count': rows.length,
        'totalYuan': rows.fold<int>(0, (a, e) => a + e.amountCents) / 100,
        'top3': topSummary,
        'hint': '统计已以卡片展示；回答给结论即可，不要复述完整列表',
      }),
      cardType: 'expense_stats',
      cardData: {
        'groupBy': groupBy,
        'label': label,
        'rows': statRows,
        'totalYuan': rows.fold<int>(0, (a, e) => a + e.amountCents) / 100,
      },
    );
  }

  // ---- 团 / 成员管理 ----

  Future<AiToolOutcome> _listGroups() async {
    final groups = _ref.read(groupsProvider).value ?? const <LedgerGroupView>[];
    final activeId = _group?.id;
    return AiToolOutcome(jsonStr({
      'groups': [
        for (final g in groups)
          {
            'id': g.id,
            'name': g.name,
            'icon': g.icon,
            'isCurrent': g.id == activeId,
          },
      ],
      if (groups.isEmpty) 'hint': '还没有任何旅行团',
    }));
  }

  Future<AiToolOutcome> _switchGroup(Map<String, dynamic> args) async {
    final name = (args['groupName'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"缺少团名"}');
    final groups = _ref.read(groupsProvider).value ?? const <LedgerGroupView>[];
    final exact = groups.where((g) => g.name == name).toList();
    final fuzzy =
        groups.where((g) => g.name.contains(name) || name.contains(g.name)).toList();
    final hit = exact.isNotEmpty ? exact : fuzzy;
    if (hit.isEmpty) {
      return AiToolOutcome(
          '{"error":"找不到旅行团「$name」，现有：${groups.map((g) => g.name).join('、')}"}');
    }
    if (hit.length > 1) {
      return AiToolOutcome(
          '{"error":"匹配到多个团（${hit.map((g) => g.name).join('、')}），请用完整团名"}');
    }
    if (hit.first.id == _group?.id) {
      return AiToolOutcome('{"ok":true,"message":"「${hit.first.name}」本来就是当前团"}');
    }
    await _ref.read(ledgerRepoProvider).setActiveGroup(hit.first.id);
    return AiToolOutcome('{"ok":true,"message":"已切换到旅行团「${hit.first.name}」"}');
  }

  Future<AiToolOutcome> _renameGroup(Map<String, dynamic> args) async {
    final gid = _group?.id;
    if (gid == null) return AiToolOutcome('{"error":"尚未选择旅行团"}');
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"缺少新团名"}');
    await _ref.read(ledgerRepoProvider).updateGroup(gid, name, _group!.icon);
    return AiToolOutcome('{"ok":true,"message":"旅行团已重命名为「$name」"}');
  }

  /// 移除成员：影响关联账单，先出确认卡
  Future<AiToolOutcome> _removeMemberDraft(Map<String, dynamic> args) async {
    final member = _resolveMember(args['memberName'] as String? ?? '');
    if (member == null) {
      return AiToolOutcome(
          '{"error":"找不到成员「${args['memberName']}」，现有成员：${_members.map((m) => m.name).join('、')}"}');
    }
    return _confirmCard(
      action: 'remove_member',
      title: '移除成员',
      danger: true,
      note: '该成员相关的历史账单记录会保留，但后续结算将不包含此人',
      rows: [
        ['成员', member.name],
        ['旅行团', _group?.name ?? '-'],
      ],
      args: {'memberId': member.id, 'memberName': member.name},
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

  /// 修改行程日期：会移动/夹紧日程，先出确认卡
  Future<AiToolOutcome> _updateTripDatesDraft(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = await _ref.read(tripsRepoProvider).getById(tripId ?? '');
    if (trip == null) return AiToolOutcome('{"error":"找不到行程 id=$tripId"}');
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    if (end < start) return AiToolOutcome('{"error":"结束日期早于开始日期"}');
    return _confirmCard(
      action: 'update_trip_dates',
      title: '调整行程日期',
      rows: [
        ['行程', trip.name],
        ['原日期', '${fmtIsoDate(epochDayToDate(trip.startEpochDay))} ~ ${fmtIsoDate(epochDayToDate(trip.endEpochDay))}'],
        ['新日期', '${args['startDate']} ~ ${args['endDate']}'],
        ['影响', '行程内安排将自动夹紧到新区间'],
      ],
      args: {'tripId': trip.id, 'startDate': args['startDate'], 'endDate': args['endDate']},
    );
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
          'id': i.id, // delete_trip_item 需要
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

  /// 删除行程安排：危险操作，先出确认卡。
  /// 支持 itemId 精确删除，或 name（+date）在行程内模糊匹配。
  Future<AiToolOutcome> _deleteTripItemDraft(Map<String, dynamic> args) async {
    final tripId = args['tripId'] as String?;
    final trip = await _ref.read(tripsRepoProvider).getById(tripId ?? '');
    if (trip == null) return AiToolOutcome('{"error":"找不到行程 id=$tripId"}');
    final items = await _ref.read(tripsRepoProvider).getItems(trip.id);

    List<TripItem> hits;
    final itemId = (args['itemId'] as String?)?.trim();
    if (itemId != null && itemId.isNotEmpty) {
      hits = items.where((i) => i.id == itemId).toList();
    } else {
      final name = (args['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        return AiToolOutcome('{"error":"请提供 itemId 或 name 来定位要删除的安排"}');
      }
      hits = items.where((i) => i.name.contains(name) || name.contains(i.name)).toList();
      final day = _epochDay(args['date']);
      if (day != null && hits.length > 1) {
        hits = hits.where((i) => i.dateEpochDay == day).toList();
      }
    }
    if (hits.isEmpty) {
      return AiToolOutcome(
          '{"error":"在「${trip.name}」找不到匹配的安排，可先 get_trip_schedule detail:true 查看全部安排"}');
    }
    if (hits.length > 1) {
      return AiToolOutcome(
          '{"error":"匹配到 ${hits.length} 条安排（${hits.take(5).map((h) => h.name).join('、')}…），请提供更精确的名称或 itemId"}');
    }
    final target = hits.first;
    final timeStr = target.startTimeMin == null
        ? ''
        : ' ${target.startTimeMin! ~/ 60}:${(target.startTimeMin! % 60).toString().padLeft(2, '0')}';
    return _confirmCard(
      action: 'delete_trip_item',
      title: '删除安排',
      danger: true,
      note: '从「${trip.name}」中删除该条安排，删除后无法恢复',
      rows: [
        ['安排', '${target.name}$timeStr'],
        ['日期', fmtIsoDate(epochDayToDate(target.dateEpochDay))],
        ['类型', target.type],
      ],
      args: {'itemId': target.id},
    );
  }

  /// 一键生成整包行程：批量写入属于"覆盖级"操作，先全量校验并出示确认卡，
  /// 用户确认后由 commitAiAction('create_trip_plan') 本地落库（零 token）。
  Future<AiToolOutcome> _createTripPlanDraft(Map<String, dynamic> args) async {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    if (end < start) return AiToolOutcome('{"error":"结束日期早于开始日期"}');
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return AiToolOutcome('{"error":"缺少行程名称"}');
    final daysRaw = args['days'];
    if (daysRaw is! List || daysRaw.isEmpty) {
      return AiToolOutcome('{"error":"days 不能为空，需为按天分组的安排数组"}');
    }
    final totalDays = end - start + 1;

    // 全量校验：统计合法条目数，便于确认卡展示与提前报错
    var itemCount = 0;
    for (final dayEntry in daysRaw) {
      if (dayEntry is! Map) continue;
      final dayNo = (dayEntry['day'] as num?)?.toInt() ?? 0;
      final itemsRaw = dayEntry['items'];
      if (dayNo < 1 || dayNo > totalDays || itemsRaw is! List) continue;
      for (final itemRaw in itemsRaw) {
        if (itemRaw is! Map) continue;
        if ((itemRaw['name'] as String? ?? '').trim().isNotEmpty) itemCount++;
      }
    }
    if (itemCount == 0) {
      return AiToolOutcome(
          '{"error":"days 里没有任何合法条目（检查 day 是否在 1~$totalDays、items 是否非空且带 name），修正后重新调用"}');
    }

    return _confirmCard(
      action: 'create_trip_plan',
      title: '生成完整行程',
      rows: [
        ['行程', name],
        ['目的地', (args['destination'] as String? ?? '').trim()],
        ['日期', '${args['startDate']} ~ ${args['endDate']}（$totalDays 天）'],
        ['安排', '$itemCount 条'],
        ['内容', '创建行程 + 写入每日安排 + 存为模板'],
      ],
      args: {
        'name': name,
        'destination': (args['destination'] as String? ?? '').trim(),
        'startDate': args['startDate'],
        'endDate': args['endDate'],
        'emoji': (args['emoji'] as String? ?? '').trim(),
        'days': daysRaw,
      },
    );
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

  /// 应用行程模板：批量创建，先出确认卡
  Future<AiToolOutcome> _applyTripTemplateDraft(Map<String, dynamic> args) async {
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
    return _confirmCard(
      action: 'apply_trip_template',
      title: '应用行程模板',
      rows: [
        ['模板', template.name],
        ['目的地', template.destination],
        ['内容', '${template.dayCount} 天 · ${template.items.length} 条安排'],
        ['新日期', '${args['startDate']} ~ ${fmtIsoDate(epochDayToDate(end))}'],
      ],
      args: {'templateId': template.id, 'startDate': args['startDate']},
    );
  }

  // ---- 一键旅行包 ----

  /// create_travel_pack：出示「旅行包预览卡」，用户点「一键生成」才由
  /// commitTravelPack 本地全部落库（建团+成员+预算+行程+日程+清单+样例账单）。
  Future<AiToolOutcome> _createTravelPack(Map<String, dynamic> args) async {
    final start = _epochDay(args['startDate']);
    final end = _epochDay(args['endDate']);
    if (start == null || end == null) {
      return AiToolOutcome('{"error":"日期格式应为 YYYY-MM-DD"}');
    }
    final members = (args['memberNames'] as List?)
            ?.whereType<Object>()
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    if (members.isEmpty) {
      return AiToolOutcome('{"error":"请至少提供一名成员（memberNames）"}');
    }
    final daysRaw = args['days'];
    if (daysRaw is! List || daysRaw.isEmpty) {
      return AiToolOutcome('{"error":"days 不能为空"}');
    }
    var itemCount = 0;
    for (final d in daysRaw.whereType<Map>()) {
      itemCount += ((d['items'] as List?)?.length ?? 0);
    }
    final plan = <String, dynamic>{
      'groupName': (args['groupName'] as String? ?? '').trim(),
      'memberNames': members,
      'budgetYuan': (args['budgetYuan'] as num?)?.toDouble(),
      'tripName': (args['tripName'] as String? ?? '').trim(),
      'destination': (args['destination'] as String? ?? '').trim(),
      'startDate': fmtIsoDate(epochDayToDate(start)),
      'endDate': fmtIsoDate(epochDayToDate(end)),
      'days': daysRaw,
      'checklist': (args['checklist'] as List?) ?? const [],
      'sampleExpenses': (args['sampleExpenses'] as List?) ?? const [],
    };
    final itemCountStr = itemCount.toString();
    final memberStr = members.length.toString();
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'travel_pack',
        'groupName': plan['groupName'],
        'memberCount': members.length,
        'tripName': plan['tripName'],
        'itemCount': itemCount,
        'hint': '已为「${plan['tripName']}」组好旅行包预览（$memberStr 人、$itemCountStr 条安排、预算¥${plan['budgetYuan'] ?? '-'}），点卡片「一键生成」即全部落库；回答一句话介绍方案即可，不要复述完整清单',
      }),
      cardType: 'travel_pack',
      cardData: {'plan': plan},
    );
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

  // ---- 目的地攻略生成（2026-09 需求 5） ----
  //
  // 为什么按栏分多次工具调用：模型单次输出上限（本项目 maxTokens=4096）不可能
  // 一次吐出 6000 字中文，所以设计成
  //   guide_prepare → guide_add_section ×N（逐栏） → guide_finish（出确认卡）
  // 草稿落在 SharedPreferences，跨轮次累积；用户点确认后才真正成为该城攻略。

  GuideService get _guide => _ref.read(guideServiceProvider);

  Future<AiToolOutcome> _guideListCities() async {
    final cities = await _guide.allCities();
    final withArea = cities.where((c) => c.area.isNotEmpty).toList();
    return AiToolOutcome(jsonStr({
      'total': cities.length,
      'featured': withArea.length,
      'cities': [
        for (final c in cities) {'key': c.key, 'name': c.name},
      ],
      'hint': '生成攻略请用上面的 name 与 key；一次只生成一座城市',
    }));
  }

  Future<AiToolOutcome> _guidePrepare(Map<String, dynamic> args) async {
    final city = (args['city'] as String? ?? '').trim();
    if (city.isEmpty) return AiToolOutcome('{"error":"缺少城市名"}');
    final cities = await _guide.allCities();
    final hit = cities.where((c) => c.name == city).firstOrNull ??
        cities.where((c) => c.name.contains(city)).firstOrNull ??
        cities.where((c) => c.key == city.toLowerCase()).firstOrNull;
    if (hit == null) {
      return AiToolOutcome(jsonStr({
        'error': '攻略库里没有「$city」。请先用 guide_list_cities 看可用城市，'
            '或换成最接近的城市名',
      }));
    }
    await GuideAiDraft.start(
        cityKey: hit.key, cityName: hit.name, area: hit.area);
    _ref.read(guideDraftKeyProvider.notifier).state = hit.key;
    return AiToolOutcome(jsonStr({
      'ok': true,
      'key': hit.key,
      'name': hit.name,
      'alreadyImported': await _guide.hasCityOverride(hit.key),
      'next': '用 guide_add_section 依次提交 prep / spots / food / transport / tips / budget',
      'targets': {
        'prep': '8-10 条（预约、季节、交通卡、住宿选址、节奏）',
        'spots': '14-18 条（必去/经典/小众/亲子，每条 200-350 字）',
        'food': '10-14 条（招牌菜与老字号，每条 150-280 字）',
        'transport': '7-9 条（机场/高铁/市内/周边）',
        'tips': '8-12 条（排队、黄牛、闭馆日、天气）',
        'budget': '6-8 条（住宿/餐饮/门票/交通/体验，区间写「（参考）」）',
      },
    }));
  }

  Future<AiToolOutcome> _guideAddSection(Map<String, dynamic> args) async {
    final section = (args['section'] as String? ?? '').trim();
    final raw = args['items'];
    if (!GuideCity.sectionKeys.contains(section)) {
      return AiToolOutcome(jsonStr({
        'error': 'section 必须是 ${GuideCity.sectionKeys.join("/")} 之一',
      }));
    }
    if (raw is! List || raw.isEmpty) {
      return AiToolOutcome('{"error":"items 必须是非空数组"}');
    }
    final draft = await _currentDraft();
    if (draft == null) {
      return AiToolOutcome('{"error":"还没有开始生成，请先调用 guide_prepare"}');
    }
    final count = draft.putSection(section, raw);
    await draft.save();
    return AiToolOutcome(jsonStr({
      'ok': true,
      'section': section,
      'sectionLabel': GuideCity.sectionLabels[section],
      'count': count,
      'totalChars': draft.textChars,
      'remaining': draft.gaps(),
    }));
  }

  Future<AiToolOutcome> _guideStatus(Map<String, dynamic> args) async {
    final draft = await _currentDraft();
    if (draft == null) {
      return AiToolOutcome('{"error":"还没有草稿，请先调用 guide_prepare"}');
    }
    return AiToolOutcome(jsonStr({
      'key': draft.cityKey,
      'name': draft.cityName,
      'counts': {
        for (final k in GuideCity.sectionKeys)
          k: (draft.sections[k] ?? const []).length,
      },
      'totalChars': draft.textChars,
      'remaining': draft.gaps(),
    }));
  }

  Future<AiToolOutcome> _guideFinish(Map<String, dynamic> args) async {
    final draft = await _currentDraft();
    if (draft == null) {
      return AiToolOutcome('{"error":"还没有草稿，请先调用 guide_prepare"}');
    }
    if (draft.itemCount == 0) {
      return AiToolOutcome('{"error":"草稿是空的，先用 guide_add_section 提交内容"}');
    }
    final city = draft.toCityJson();
    return AiToolOutcome(
      jsonStr({
        'renderedCard': 'guide_import_confirm',
        'hint': '已出示「导入攻略」确认卡；用户点确认后才会写入本机。'
            '回答一句话说明即可，不要复述卡片内容',
      }),
      cardType: 'guide_import_confirm',
      cardData: {
        'title': copy('guide.aiImportTitle'),
        'cityKey': draft.cityKey,
        'cityName': draft.cityName,
        'rows': [
          for (final r in draft.summaryRows()) {'label': r[0], 'value': r[1]},
        ],
        'textChars': draft.textChars,
        'readingMinutes': GuideCity.readingMinutes(draft.textChars),
        'gaps': draft.gaps(),
        'city': city,
      },
    );
  }

  /// 取当前草稿：城市 key 存在 provider 里，跨工具调用传递。
  Future<GuideAiDraft?> _currentDraft() async {
    final key = _ref.read(guideDraftKeyProvider);
    if (key == null) return null;
    return GuideAiDraft.load(key);
  }
}

// ---------------------------------------------------------------------------
// System Prompt：静态段（固定不变，命中前缀缓存）+ 动态段（每次发送重建，放在末尾）
// ---------------------------------------------------------------------------

/// 静态系统提示词：内容固定不变，保证每次请求的前缀缓存命中。
String buildStaticSystemPrompt() =>
    '你是「芥舟」App 的内置 AI 管家，帮用户管理旅行团、AA 记账、行程、清单与应用设置。\n'
    '规则：\n'
    '1. 只能通过提供的工具操作本应用数据，无法触达应用之外的任何功能。\n'
    '2. 记账、改预算、改行程日期、删除账单/安排/成员、批量生成行程、应用模板等敏感操作'
    '不会直接执行，而是先给用户出示确认卡，用户在卡片上点确认后本地自动落库；'
    '你只需一句话说明即可，不要在文本里复述卡片内容，也不要重复调用同一工具。\n'
    '3. 金额单位为元，日期格式 YYYY-MM-DD；不要臆造 memberId/tripId/expenseId/分类 key，'
    '信息不足先查询或向用户确认。\n'
    '4. 查询类工具的结果会以卡片直接展示给用户：回答只给结论与简短解读，不要复述列表数据；'
    '确需明细时带 detail:true 重查。\n'
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

/// 参数解析兼容模型偶发的非严格 JSON（截取首个完整对象）；
/// 还能修复被 maxTokens 截断的 JSON（自动补全未闭合的字符串与括号）。
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
  // 截断修复：create_travel_pack 等大参数容易被 maxTokens 截断，
  // 补全未闭合的引号/括号后再试一次（days 缺尾项远好于整次调用报废）。
  final repaired = _repairTruncatedJson(text);
  if (repaired != null) {
    try {
      final v = const JsonDecoder().convert(repaired);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
  }
  throw FormatException('bad json: $s');
}

/// 把被截断的 JSON 文本补全成可解析形态：闭合未结束的字符串，
/// 去掉尾部悬挂的键/冒号/逗号，再按相反顺序补全未闭合的 `{`/`[`。
String? _repairTruncatedJson(String s) {
  final start = s.indexOf('{');
  if (start < 0) return null;
  final text = s.substring(start);
  var inStr = false, esc = false;
  final stack = <String>[];
  final sb = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inStr) {
      sb.write(c);
      if (esc) {
        esc = false;
      } else if (c == r'\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
      sb.write(c);
    } else if (c == '{') {
      stack.add('}');
      sb.write(c);
    } else if (c == '[') {
      stack.add(']');
      sb.write(c);
    } else if (c == '}' || c == ']') {
      if (stack.isEmpty) return null; // 结构已坏，放弃修复
      stack.removeLast();
      sb.write(c);
    } else {
      sb.write(c);
    }
  }
  var out = sb.toString();
  if (inStr) out += '"';
  // 去掉尾部悬挂片段：悬空冒号/逗号、只有键名没有值。
  // 注意悬空键只可能出现在对象上下文（栈顶为'}'）——数组里的
  // 合法尾串不能误删。
  for (var guard = 0; guard < 6; guard++) {
    out = out.trimRight();
    if (out.endsWith(':') || out.endsWith(',')) {
      out = out.substring(0, out.length - 1);
      continue;
    }
    final inObject = stack.isNotEmpty && stack.last == '}';
    // ,"被截断的键名" —— 闭合后形成无值键，回删整段
    if (inObject) {
      final danglingKey = RegExp(r',\s*"(?:[^"\\]|\\.)*"$').firstMatch(out);
      if (danglingKey != null) {
        out = out.substring(0, danglingKey.start);
        continue;
      }
    }
    break;
  }
  while (stack.isNotEmpty) {
    out += stack.removeLast();
  }
  return out;
}

String _esc(String raw) =>
    raw.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ');

/// 把模型偶然输出的 `<tool_call><function=xxx><parameter=name>值</parameter>…</tool_call>`
/// 文本格式解析为原生 [AiToolCall]。原样函数调用走正规 tool_calls，这里只兜底。
///
/// 返回空表示不象工具调用（保持原文本回答）。可解析多条调用。
List<AiToolCall> parseLegacyToolCalls(String content) {
  final calls = <AiToolCall>[];
  final blocks = RegExp(r'<tool_call>([\s\S]*?)</tool_call>')
      .allMatches(content)
      .map((m) => m.group(1) ?? '')
      .toList();
  if (blocks.isEmpty && content.trimLeft().startsWith('<tool_call>')) {
    // 模型省略了闭合标签：取到内容末尾
    final rest = content.substring(content.indexOf('<tool_call>') + 11);
    blocks.add(rest);
  }
  if (blocks.isEmpty) return calls;
  for (final block in blocks) {
    final fnMatch = RegExp(r'<function=([a-zA-Z_0-9]+)\s*>?').firstMatch(block);
    if (fnMatch == null) continue;
    final name = fnMatch.group(1)!;
    final args = <String, dynamic>{};
    // <parameter=key>value</parameter>（值可含换行），兼容缺闭合标签的截断
    for (final pm in RegExp(r'<parameter=([a-zA-Z_0-9]+)>([\s\S]*?)(?:</parameter>|(?=<parameter=)|$)')
        .allMatches(block)) {
      final key = pm.group(1)!;
      var value = (pm.group(2) ?? '').trim();
      if (value.startsWith('[')) {
        // 数组参数：尝试按行解析，丢无法解析的元素
        final arr = <dynamic>[];
        for (final line in value.split(RegExp(r'[\r\n]+'))) {
          final t = line.trim().replaceAll(RegExp(r'^[-*\d]+[.、)\s]*'), '');
          if (t.isEmpty) continue;
          arr.add(_coerceScalar(t));
        }
        args[key] = arr;
      } else if (value.startsWith('{')) {
        try {
          args[key] = jsonDecodeLoose(value) ?? <String, dynamic>{};
        } catch (_) {
          args[key] = value;
        }
      } else {
        args[key] = _coerceScalar(value);
      }
    }
    calls.add(AiToolCall(
      id: 'legacy_${name}_${calls.length}',
      name: name,
      argumentsJson: jsonStr(args),
    ));
  }
  return calls;
}

dynamic _coerceScalar(String s) {
  final num = double.tryParse(s);
  if (num != null) return num % 1 == 0 ? num.toInt() : num;
  if (s == 'true') return true;
  if (s == 'false') return false;
  return s;
}

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
  // 退款 = 收到的钱：按「退款为负」约定入账，结算/统计才会正确冲减
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

/// 公开别名（供 ai_confirm_actions 等文件复用）
int? epochDayFromArg(dynamic v) => _epochDay(v);
int? hhmmToMin(String? s) => _hhmmToMin(s);
String findTripItemTypeOf(String key) => findTripItemType(key).key;

// ---------------------------------------------------------------------------
// 旅行包落库（本地零 token）
// ---------------------------------------------------------------------------

/// 把旅行包预览卡的 plan 全部落库：建团 + 成员 + 预算 + 行程 + 日程 + 清单 + 样例账单。
/// 返回成功文案（SnackBar 等展示）；失败时返回具体错误文案。
Future<String?> commitTravelPack(WidgetRef ref, Map<String, dynamic> plan) async {
  final repo = ref.read(ledgerRepoProvider);
  final tripsRepo = ref.read(tripsRepoProvider);
  final checklistRepo = ref.read(checklistRepoProvider);
  final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];

  final groupName = ((plan['groupName'] as String? ?? '').trim().isEmpty
      ? '${plan['tripName']}之团'
      : plan['groupName'] as String) ?? '旅行团';
  final memberNames = (plan['memberNames'] as List?)?.cast<String>() ?? const <String>[];
  final budgetYuan = (plan['budgetYuan'] as num?)?.toDouble();
  final start = _epochDayPublic(plan['startDate']);
  final end = _epochDayPublic(plan['endDate']);
  final daysRaw = (plan['days'] as List?) ?? const [];
  final checklist = (plan['checklist'] as List?) ?? const [];
  final sampleExpenses = (plan['sampleExpenses'] as List?) ?? const [];
  final now = DateTime.now().millisecondsSinceEpoch;

  if (memberNames.isEmpty) return '没有成员，旅行包无法创建';
  if (start == null || end == null) return '日期格式错误';

  try {
    // 1) 建团并设为当前团
    final group = await repo.addGroup(groupName, memberNames.length <= 4 ? '👨‍👩‍👧‍👦' : '👥');
    await repo.setActiveGroup(group.id);

    // 2) 添加成员
    final memberIdMap = <String, String>{};
    for (final name in memberNames) {
      final id = await repo.addMember(group.id, name);
      memberIdMap[name] = id;
    }
    final allIds = memberIdMap.values.toList();

    // 3) 设置预算
    if (budgetYuan != null && budgetYuan > 0) {
      await repo.setBudget(group.id, enabled: true, budgetCents: (budgetYuan * 100).round());
    }

    // 4) 创建行程（关联旅行团）
    final tripName = (plan['tripName'] as String? ?? '').trim();
    final dest = (plan['destination'] as String? ?? '').trim();
    final tripId = await tripsRepo.createTrip(
      name: tripName,
      dest: dest,
      emoji: '✈️',
      cover: 'ocean',
      start: start,
      end: end,
      groupId: group.id,
    );

    // 5) 写入每日安排
    final perDayCount = <int, int>{};
    for (final dayEntry in daysRaw) {
      if (dayEntry is! Map) continue;
      final dayNo = (dayEntry['day'] as num?)?.toInt() ?? 0;
      final itemsRaw = dayEntry['items'];
      if (dayNo < 1 || itemsRaw is! List) continue;
      for (final itemRaw in itemsRaw) {
        if (itemRaw is! Map) continue;
        final itemName = (itemRaw['name'] as String? ?? '').trim();
        if (itemName.isEmpty) continue;
        final idx = perDayCount[dayNo] ?? 0;
        perDayCount[dayNo] = idx + 1;
        final costYuan = (itemRaw['costYuan'] as num?)?.toDouble();
        await tripsRepo.insertItem(TripItemsCompanion(
          id: Value(newId('item')),
          tripId: Value(tripId),
          dateEpochDay: Value(start + dayNo - 1),
          type: Value(findTripItemType(itemRaw['type'] as String? ?? 'attraction').key),
          name: Value(itemName),
          address: Value((itemRaw['address'] as String? ?? '').trim()),
          startTimeMin: Value(_hhmmToMin(itemRaw['startTime'] as String?)),
          costCents: costYuan == null ? const Value(null) : Value((costYuan * 100).round()),
          note: Value((itemRaw['note'] as String? ?? '').trim()),
          sortOrder: Value(idx * 10),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    }

    // 6) 写入行李清单
    for (final chk in checklist) {
      if (chk is! Map) continue;
      final text = (chk['text'] as String? ?? '').trim();
      if (text.isEmpty) continue;
      var cat = (chk['category'] as String? ?? '').trim();
      if (!const {'docs','clothes','electronics','toiletries','medicine','other'}.contains(cat)) {
        cat = 'other';
      }
      final existing = await checklistRepo.getAllByScope('trip', tripId: tripId);
      final maxOrder = existing.isEmpty ? 0 : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);
      await checklistRepo.addItem(tripId, 'trip', cat, text, maxOrder + 10);
    }

    // 7) 写入样例账单
    for (final se in sampleExpenses) {
      if (se is! Map) continue;
      final title = (se['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      final amountYuan = (se['amountYuan'] as num?)?.toDouble();
      if (amountYuan == null || amountYuan == 0) continue;
      final payerName = (se['payerName'] as String? ?? '').trim();
      final payerId = memberIdMap[payerName];
      if (payerId == null) continue;
      final isRefund = (se['expenseType'] as String?) == 'refund';
      final cents = (amountYuan.abs() * 100).round();
      final signed = isRefund ? -cents : cents; // 退款为负，结算/统计正确冲减
      final shares = computeSplit(totalCents: signed, memberIds: allIds, mode: ShareMode.equal);
      var catKey = (se['categoryKey'] as String? ?? '').trim();
      if (catKey.isNotEmpty) {
        final hit = categories.where((c) => c.key == catKey || c.name == catKey).toList();
        catKey = hit.isEmpty ? 'other' : hit.first.key;
      } else {
        catKey = 'other';
      }
      final day = _epochDayPublic(se['date']) ?? start;
      await repo.addExpense(ExpensesCompanion(
        id: Value(newId('expense')),
        groupId: Value(group.id),
        dateEpochDay: Value(day),
        title: Value(title),
        categoryKey: Value(catKey),
        type: Value(isRefund ? 'refund' : 'normal'),
        amountCents: Value(signed),
        currency: Value('CNY'),
        rate: Value(1.0),
        payersJson: Value(jsonEncode([{'memberId': payerId, 'cents': signed}])),
        sharesJson: Value(jsonEncode(
          [for (final s in shares) {'memberId': s.memberId, 'cents': s.cents}],
        )),
        shareMode: Value('equal'),
        tripId: Value(tripId),
        createdAt: Value(now),
      ));
    }

    // 刷新
    ref.invalidate(expensesProvider);
    ref.invalidate(groupsProvider);
    ref.invalidate(membersProvider);
    return null; // 成功
  } catch (e) {
    return '创建旅行包失败：${e.toString().replaceAll('"', "'")}';
  }
}
