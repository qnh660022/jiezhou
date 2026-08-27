/// AI 助手服务抽象接口：OpenAI 兼容的 Chat Completions 客户端。
///
/// 任意提供 `/chat/completions` 的服务商均可接入（DeepSeek、通义千问、
/// Kimi、智谱 GLM、OpenAI 等），连接参数由用户在设置页自行填写。
/// 应用只把消息与工具定义交给本服务，不感知具体厂商。
library;

/// 单条对话消息。
///
/// role 取 OpenAI 约定值：`system` / `user` / `assistant` / `tool`；
/// `tool` 角色必须带 [toolCallId] 回填对应的工具调用结果。
class AiMessage {
  const AiMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.toolName,
  });

  final String role;

  /// 文本内容；assistant 消息在仅发起工具调用时可为空
  final String? content;

  /// assistant 消息携带的工具调用请求
  final List<AiToolCall>? toolCalls;

  /// tool 消息必填：对应的调用 id
  final String? toolCallId;

  /// tool 消息可选：工具名（部分厂商要求）
  final String? toolName;

  Map<String, dynamic> toJson() => {
        'role': role,
        if (content != null) 'content': content,
        if (toolName != null) 'name': toolName,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolCalls != null)
          'tool_calls': [
            for (final t in toolCalls!) t.toJson(),
          ],
      };
}

/// 模型请求的一次工具调用（arguments 为未解析的 JSON 字符串，
/// 解析失败由执行器兜底，避免在传输层丢信息）。
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  final String id;
  final String name;
  final String argumentsJson;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': argumentsJson},
      };
}

/// 工具定义（OpenAI function calling 格式）。
///
/// 白名单式声明：助手能做什么完全由此列表决定，列表之外的操作
/// 模型无从发起，从机制上保证 AI 只能操作应用内功能。
class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  final String name;
  final String description;

  /// JSON Schema 格式的参数描述
  final Map<String, dynamic> parametersSchema;

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parametersSchema,
        },
      };
}

/// 一轮对话请求的结果
class AiChatResult {
  const AiChatResult({this.content, this.toolCalls = const []});

  /// 助手的文本回答；发起了工具调用时可能为 null
  final String? content;

  /// 需要本地执行的工具调用（为空即视为最终回答）
  final List<AiToolCall> toolCalls;

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

abstract class AiChatService {
  /// 发起一轮 Chat Completions 请求。
  ///
  /// [config] 为 {baseUrl, apiKey, model}；网络失败或非 2xx 抛
  /// [AiChatException]，由调用层转成气泡里的错误提示。
  Future<AiChatResult> chat({
    required Map<String, dynamic> config,
    required List<AiMessage> messages,
    List<AiToolDefinition> tools = const [],
    double temperature = 0.4,
  });
}

/// 请求失败异常，message 已提取出可读文案（含服务商返回的错误体）。
class AiChatException implements Exception {
  const AiChatException(this.message);
  final String message;

  @override
  String toString() => message;
}
