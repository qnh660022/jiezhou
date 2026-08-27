/// AI 助手实现：dio → OpenAI 兼容 /chat/completions，非流式。
library;
import "package:dio/dio.dart";

import "../ai_chat_service.dart";

class AiChatServiceImpl implements AiChatService {
  AiChatServiceImpl([Dio? dio]) : _dio = dio ?? Dio();
  final Dio _dio;

  static const _connectTimeout = Duration(seconds: 15);
  // 大模型生成较慢，读超时放宽到 2 分钟
  static const _receiveTimeout = Duration(seconds: 120);

  /// 兼容用户把完整 endpoint 或带尾斜杠的 baseUrl 填进来
  static String resolveEndpoint(String baseUrl) {
    var url = baseUrl.trim();
    if (url.endsWith('/chat/completions')) return url;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return '$url/chat/completions';
  }

  @override
  Future<AiChatResult> chat({
    required Map<String, dynamic> config,
    required List<AiMessage> messages,
    List<AiToolDefinition> tools = const [],
    double temperature = 0.4,
  }) async {
    final baseUrl = (config['baseUrl'] as String? ?? '').trim();
    final apiKey = (config['apiKey'] as String? ?? '').trim();
    final model = (config['model'] as String? ?? '').trim();
    if (baseUrl.isEmpty) {
      throw const AiChatException('尚未配置 AI 接口地址');
    }
    try {
      final resp = await _dio.post(
        resolveEndpoint(baseUrl),
        options: Options(
          sendTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
        ),
        data: {
          'model': model,
          'messages': [for (final m in messages) m.toJson()],
          'temperature': temperature,
          'stream': false,
          if (tools.isNotEmpty)
            'tools': [for (final t in tools) t.toJson()],
        },
      );
      return _parse(resp.data);
    } on AiChatException {
      rethrow;
    } on DioException catch (e) {
      throw AiChatException(_describe(e));
    } catch (e) {
      throw AiChatException('AI 请求失败：$e');
    }
  }

  AiChatResult _parse(dynamic data) {
    if (data is! Map || data['choices'] is! List || (data['choices'] as List).isEmpty) {
      throw const AiChatException('AI 返回格式异常（缺少 choices）');
    }
    final message = (data['choices'] as List).first['message'];
    if (message is! Map) throw const AiChatException('AI 返回格式异常（缺少 message）');

    String content = '';
    final rawContent = message['content'];
    if (rawContent is String) {
      content = rawContent;
    } else if (rawContent is List) {
      // 部分兼容服务把 content 拆成多段 {type:text,text:...}
      content = [
        for (final seg in rawContent)
          if (seg is Map && seg['text'] != null) seg['text'].toString(),
      ].join();
    }

    final calls = <AiToolCall>[];
    final rawCalls = message['tool_calls'];
    if (rawCalls is List) {
      for (final c in rawCalls) {
        if (c is! Map) continue;
        final fn = c['function'];
        if (fn is! Map) continue;
        calls.add(AiToolCall(
          id: (c['id'] ?? 'call_${calls.length}') as String,
          name: (fn['name'] ?? '') as String,
          argumentsJson: (fn['arguments'] ?? '{}') as String,
        ));
      }
    }
    return AiChatResult(content: content.isEmpty ? null : content, toolCalls: calls);
  }

  String _describe(DioException e) {
    final code = e.response?.statusCode;
    final body = e.response?.data;
    String detail = '';
    if (body is Map) {
      // OpenAI 风格 {"error":{"message":...}}；DeepSeek/GLM 等同构
      final err = body['error'];
      if (err is Map && err['message'] != null) detail = err['message'].toString();
    } else if (body is String && body.isNotEmpty) {
      detail = body.length > 200 ? body.substring(0, 200) : body;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接 AI 服务超时，请检查网络或接口地址';
      case DioExceptionType.badResponse:
        return detail.isEmpty
            ? 'AI 服务返回错误${code == null ? '' : ' ($code)'}'
            : 'AI 服务返回错误$code：$detail';
      default:
        return detail.isEmpty ? '无法连接 AI 服务：${e.message ?? e.type.name}' : detail;
    }
  }
}
