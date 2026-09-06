/// AI 助手会话状态：消息列表 + 工具调用循环 + 卡片直出。
///
/// 【缓存友好】消息序列为 [静态系统提示, 动态上下文, ...历史]：
/// 静态段永不变化；动态上下文在数据无变化时逐字节一致；历史只追加、
/// 按用户消息边界裁剪——三者共同保证服务端前缀缓存尽量命中。
/// 【token 策略】查询工具的完整数据直接渲染成卡片（AiTurn.cardData），
/// 喂回模型的只有精简摘要。
library;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/services/ai_chat_service.dart';
import 'ai_tools.dart';

// ---------------------------------------------------------------------------
// 展示模型
// ---------------------------------------------------------------------------

/// 一条聊天气泡。AI 回复可携带 [actions]（工具动作标签）与
/// [cardType]/[cardData]（工具结果直出的原生卡片）。
class AiTurn {
  const AiTurn({
    required this.isUser,
    required this.text,
    this.actions = const [],
    this.isError = false,
    this.cardType,
    this.cardData,
  });

  final bool isUser;
  final String text;
  final List<String> actions;
  final bool isError;

  /// 非空时该轮渲染为原生卡片而非文本气泡
  final String? cardType;
  final Map<String, dynamic>? cardData;
}

class AiChatState {
  const AiChatState({this.turns = const [], this.busy = false});

  final List<AiTurn> turns;
  final bool busy;

  AiChatState copyWith({List<AiTurn>? turns, bool? busy}) =>
      AiChatState(turns: turns ?? this.turns, busy: busy ?? this.busy);
}

// ---------------------------------------------------------------------------
// 控制器
// ---------------------------------------------------------------------------

class AiChatController extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  /// 喂给模型的完整消息序列（user/assistant/tool），工具调用轮保留保证上下文连贯
  final List<AiMessage> _history = [];

  static const _maxToolRounds = 8;

  /// 历史上限（条）；超出后从最早的用户消息边界裁剪
  static const _maxHistoryMessages = 20;

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.busy) return;

    // 未配置拦截
    final config = await ref.read(aiConfigProvider.future);
    if ((config['baseUrl'] as String? ?? '').trim().isEmpty) {
      state = state.copyWith(
        turns: [
          ...state.turns,
          AiTurn(isUser: true, text: text),
          const AiTurn(
              isUser: false,
              isError: true,
              text: '还没有配置 AI 服务。点右上角 ⚙️ 填写接口地址、API Key 和模型名即可开始使用。'),
        ],
      );
      return;
    }

    _history.add(AiMessage(role: 'user', content: text));
    state = state.copyWith(
      turns: [...state.turns, AiTurn(isUser: true, text: text)],
      busy: true,
    );

    try {
      await _runLoop(config);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> clear() async {
    _history.clear();
    _streamIdx = null;
    _streamBuf = '';
    state = const AiChatState();
  }

  // ---- 流式输出状态 ----

  /// 当前流式气泡在 turns 中的下标（null = 本轮尚未吐出增量）
  int? _streamIdx;
  String _streamBuf = '';
  DateTime _lastStreamFlush = DateTime.fromMillisecondsSinceEpoch(0);

  /// 流式增量：首次出现时插入占位气泡，之后按 ~60ms 节流刷新
  void _onStreamDelta(String delta, List<String> actions) {
    _streamBuf += delta;
    final now = DateTime.now();
    if (_streamIdx == null) {
      _streamIdx = state.turns.length;
      state = state.copyWith(
        turns: [
          ...state.turns,
          AiTurn(isUser: false, text: _streamBuf, actions: List.of(actions)),
        ],
      );
      _lastStreamFlush = now;
      return;
    }
    if (now.difference(_lastStreamFlush).inMilliseconds < 60) return;
    _lastStreamFlush = now;
    _flushStreamTurn(actions);
  }

  void _flushStreamTurn(List<String> actions) {
    final idx = _streamIdx;
    if (idx == null || idx >= state.turns.length) return;
    final turns = [...state.turns];
    turns[idx] = AiTurn(isUser: false, text: _streamBuf, actions: List.of(actions));
    state = state.copyWith(turns: turns);
  }

  /// 结束流式：已有占位气泡则用最终全文定格（防尾部增量丢失），否则补一条完整气泡
  void _finalizeStreamTurn(String text, List<String> actions) {
    final idx = _streamIdx;
    if (idx == null) {
      if (text.isNotEmpty) {
        state = state.copyWith(
          turns: [...state.turns, AiTurn(isUser: false, text: text, actions: List.of(actions))],
        );
      }
    } else {
      _streamBuf = text;
      _flushStreamTurn(actions);
    }
    _streamIdx = null;
    _streamBuf = '';
  }

  Future<void> _runLoop(Map<String, dynamic> config) async {
    final service = ref.read(aiChatServiceProvider);
    final executor = AiToolExecutor(ref);

    // 静态提示 + 动态上下文快照：本轮所有轮次复用同一份，保证多轮工具
    // 调用时请求前缀稳定（利于服务端缓存）；跨请求内容不变时同样命中。
    final staticSys = buildStaticSystemPrompt();
    final dynamicCtx = await buildDynamicContext(ref);

    final actions = <String>[];
    for (var round = 0; round < _maxToolRounds; round++) {
      final result = await service.chat(
        config: config,
        messages: [
          AiMessage(role: 'system', content: staticSys),
          AiMessage(role: 'system', content: dynamicCtx),
          ..._trimmedHistory(),
        ],
        tools: kAiTools,
        maxTokens: 4096,
        onContentDelta: (d) => _onStreamDelta(d, actions),
      );

      // 兜底：个别模型不返回原生 tool_calls，而是把工具调用打成
      // <tool_call>…</tool_call> 纯文本。识别到就当作本轮的工具调用执行。
      var toolCalls = result.toolCalls;
      if (!result.hasToolCalls && result.content?.contains('<tool_call>') == true) {
        toolCalls = parseLegacyToolCalls(result.content!);
      }

      if (toolCalls.isEmpty) {
        final text = result.content?.trim().isEmpty == true
            ? '（AI 没有返回内容）'
            : result.content!.trim();
        _finalizeStreamTurn(text, actions);
        return;
      }

      // 流式气泡已把模型前言显示出来了；释放引用，后续轮次另起气泡
      _finalizeStreamTurn(result.content ?? '', actions);

      // 记录 assistant 的工具调用请求，并逐个本地执行回填结果
      _history.add(
          AiMessage(role: 'assistant', content: result.content, toolCalls: toolCalls));
      for (final call in toolCalls) {
        actions.add(_actionLabel(call));
        final outcome = await executor.execute(call.name, call.argumentsJson);
        // 查询类结果直出卡片，用户立即看到数据
        if (outcome.cardType != null && outcome.cardData != null) {
          state = state.copyWith(
            turns: [
              ...state.turns,
              AiTurn(
                isUser: false,
                text: '',
                cardType: outcome.cardType,
                cardData: outcome.cardData,
              ),
            ],
          );
        }
        _history.add(AiMessage(
          role: 'tool',
          content: outcome.modelText,
          toolCallId: call.id,
          toolName: call.name,
        ));
      }
    }
    state = state.copyWith(
      turns: [
        ...state.turns,
        AiTurn(
            isUser: false,
            isError: true,
            text: '这个任务执行步骤太多，为安全起见我停下来了，你可以拆成几步来做。',
            actions: List.of(actions)),
      ],
    );
  }

  /// 裁剪历史：保留最近 N 条，且首条必须是 user（不能把 assistant 的
  /// 工具调用和它的 tool 结果拆开，否则请求会被服务商拒绝）。
  /// 旧轮次的 tool 结果再瘦身：超过 120 字符的替换为一句话省略标记
  /// （保留 assistant↔tool 配对结构），只留最近一轮工具结果全文。
  List<AiMessage> _trimmedHistory() {
    var list = _history;
    if (list.length > _maxHistoryMessages) {
      list = list.sublist(list.length - _maxHistoryMessages);
      while (list.isNotEmpty &&
          (list.first.role == 'tool' ||
              (list.first.role == 'assistant' && list.first.toolCalls != null))) {
        list = list.sublist(1);
      }
    }
    var sawUser = false;
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].role == 'user') {
        sawUser = true;
        continue;
      }
      if (sawUser &&
          list[i].role == 'tool' &&
          (list[i].content?.length ?? 0) > 120) {
        list[i] = AiMessage(
          role: 'tool',
          content: '{"omitted":true,"note":"早期工具结果已省略，如需请重新查询"}',
          toolCallId: list[i].toolCallId,
          toolName: list[i].toolName,
        );
      }
    }
    return list;
  }

  /// 工具调用 → 用户可读的动作标签
  String _actionLabel(AiToolCall call) {
    Map<String, dynamic>? args;
    try {
      args = jsonArgs(call.argumentsJson);
    } catch (_) {}
    switch (call.name) {
      case 'add_expense':
        final title = args?['title'] ?? '';
        final yuan = args?['amountYuan'];
        return '已记账：$title${yuan == null ? '' : ' ¥$yuan'}';
      case 'create_trip':
        return '已创建行程：${args?['name'] ?? ''}';
      case 'update_trip_dates':
        return '待确认：调整行程日期';
      case 'add_trip_item':
        return '已添加安排：${args?['name'] ?? ''}';
      case 'delete_trip_item':
        return '待确认：删除安排';
      case 'add_member':
        return '已添加成员：${args?['name'] ?? ''}';
      case 'remove_member':
        return '待确认：移除成员 ${args?['memberName'] ?? ''}';
      case 'create_group':
        return '已创建旅行团：${args?['name'] ?? ''}';
      case 'add_checklist_item':
        return '已添加清单项：${args?['text'] ?? ''}';
      case 'toggle_checklist_item':
        return '已更新清单：${args?['text'] ?? ''}';
      case 'set_group_budget':
        return '待确认：设置预算';
      case 'set_app_theme':
        return '已切换主题';
      case 'set_budget_alerts_enabled':
        return '已更新预警开关';
      case 'update_expense':
        return '待确认：修改账单';
      case 'delete_expense':
        return '待确认：删除账单';
      case 'get_expense_stats':
        return '统计了账单';
      case 'list_groups':
        return '查看了旅行团';
      case 'switch_group':
        return '已切换旅行团';
      case 'rename_group':
        return '已重命名旅行团';
      case 'query_expenses':
        return '查询了账单';
      case 'get_balances':
        return '查询了成员余额';
      case 'get_budget_status':
        return '查询了预算';
      case 'get_settlement_status':
        return '查询了结算进度';
      case 'get_trip_schedule':
        return '查看了日程';
      case 'query_checklist':
        return '查看了清单';
      case 'list_members':
        return '查看了成员';
      case 'list_categories':
        return '查看了分类';
      case 'list_trips':
        return '查看了行程';
      case 'create_trip_plan':
        return '待确认：生成完整行程';
      case 'apply_trip_template':
        return '待确认：应用行程模板';
      default:
        return '已执行 ${call.name}';
    }
  }
}

/// 从模型返回的 arguments 中截取首个 JSON 对象并解析（容忍前后杂质）
Map<String, dynamic>? jsonArgs(String s) {
  var text = s.trim();
  try {
    final v = jsonDecode(text);
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    final v = jsonDecode(text.substring(start, end + 1));
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  throw FormatException('bad args: $s');
}

final aiChatProvider =
    NotifierProvider<AiChatController, AiChatState>(AiChatController.new);
