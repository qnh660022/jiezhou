/// AI 助手会话状态：消息列表 + 工具调用循环。
///
/// 会话保存在内存（Notifier 常驻），退出应用即清空；
/// OpenAI 消息历史与气泡展示分离——工具调用过程对用户呈现为轻量动作标签。
library;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/services/ai_chat_service.dart';
import 'ai_tools.dart';

// ---------------------------------------------------------------------------
// 展示模型
// ---------------------------------------------------------------------------

/// 一条聊天气泡。[isUser]=false 时为 AI 回复；[actions] 是本轮触发的工具标签。
class AiTurn {
  const AiTurn({required this.isUser, required this.text, this.actions = const [], this.isError = false});

  final bool isUser;
  final String text;

  /// 本轮工具活动（如「已记账：午餐 ¥45」）
  final List<String> actions;
  final bool isError;
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

  /// 喂给模型的完整消息序列（system + 历史），工具调用轮也保留以保证上下文连贯
  final List<AiMessage> _history = [];

  static const _maxToolRounds = 8;

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
    state = const AiChatState();
  }

  Future<void> _runLoop(Map<String, dynamic> config) async {
    final service = ref.read(aiChatServiceProvider);
    final executor = AiToolExecutor(ref);
    final systemPrompt = await buildSystemPrompt(ref);

    final actions = <String>[];
    for (var round = 0; round < _maxToolRounds; round++) {
      final result = await service.chat(
        config: config,
        messages: [
          AiMessage(role: 'system', content: systemPrompt),
          ..._trimmedHistory(),
        ],
        tools: kAiTools,
      );

      if (!result.hasToolCalls) {
        state = state.copyWith(
          turns: [
            ...state.turns,
            AiTurn(
                isUser: false,
                text: result.content?.trim().isEmpty == true ? '（AI 没有返回内容）' : result.content!.trim(),
                actions: List.of(actions)),
          ],
        );
        return;
      }

      // 记录 assistant 的工具调用请求，并逐个本地执行回填结果
      _history.add(AiMessage(role: 'assistant', content: result.content, toolCalls: result.toolCalls));
      for (final call in result.toolCalls) {
        actions.add(_actionLabel(call));
        final output =
            await executor.execute(call.name, call.argumentsJson);
        _history.add(AiMessage(
          role: 'tool',
          content: output,
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

  /// 控制上下文长度：保留最近 40 条真实消息（system 单独注入）
  List<AiMessage> _trimmedHistory() =>
      _history.length <= 40 ? _history : _history.sublist(_history.length - 40);

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
      case 'add_trip_item':
        return '已添加安排：${args?['name'] ?? ''}';
      case 'add_member':
        return '已添加成员：${args?['name'] ?? ''}';
      case 'set_group_budget':
        return '已设置预算';
      case 'set_app_theme':
        return '已切换主题';
      case 'set_budget_alerts_enabled':
        return '已更新预警开关';
      case 'query_expenses':
        return '查询了账单';
      case 'get_balances':
        return '查询了成员余额';
      case 'get_budget_status':
        return '查询了预算';
      case 'get_settlement_status':
        return '查询了结算进度';
      case 'list_members':
        return '查看了成员';
      case 'list_categories':
        return '查看了分类';
      case 'list_trips':
        return '查看了行程';
      case 'get_trip_schedule':
        return '查看了日程';
      case 'list_checklists':
        return '查看了清单';
      case 'add_checklist_item':
        return '已添加清单项：${args?['text'] ?? ''}';
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
