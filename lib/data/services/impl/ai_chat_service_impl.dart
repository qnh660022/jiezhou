/// AI 助手实现：dio → OpenAI 兼容 /chat/completions。
/// 支持 SSE 流式（文字增量实时回调）与非流式两种模式；
/// 流式失败且未吐出任何增量时自动降级为非流式重试一次。
library;
import "dart:async";
import "dart:convert";
import "dart:typed_data";

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
    int? maxTokens,
    void Function(String delta)? onContentDelta,
  }) async {
    final baseUrl = (config['baseUrl'] as String? ?? '').trim();
    final apiKey = (config['apiKey'] as String? ?? '').trim();
    final model = (config['model'] as String? ?? '').trim();
    if (baseUrl.isEmpty) {
      throw const AiChatException('尚未配置 AI 接口地址');
    }
    final body = {
      'model': model,
      'messages': [for (final m in messages) m.toJson()],
      'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (tools.isNotEmpty) 'tools': [for (final t in tools) t.toJson()],
    };
    final headers = {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };

    if (onContentDelta == null) {
      return _chatNonStream(baseUrl, headers, body);
    }

    // 流式：一旦吐过增量就无法安全重试（会重复显示），只有
    // 尚无任何增量时（如服务端不支持 SSE、首包就报错）才降级非流式。
    var emitted = false;
    try {
      return await _chatStream(
        baseUrl, headers, body,
        (delta) {
          emitted = true;
          onContentDelta(delta);
        },
      );
    } catch (e) {
      if (emitted) rethrow;
      return _chatNonStream(baseUrl, headers, body);
    }
  }

  // ---- 非流式 ----

  Future<AiChatResult> _chatNonStream(
    String baseUrl,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await _dio.post(
        resolveEndpoint(baseUrl),
        options: Options(
          sendTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: headers,
        ),
        data: {...body, 'stream': false},
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

  // ---- SSE 流式 ----

  Future<AiChatResult> _chatStream(
    String baseUrl,
    Map<String, String> headers,
    Map<String, dynamic> body,
    void Function(String delta) onDelta,
  ) async {
    try {
      final resp = await _dio.post<ResponseBody>(
        resolveEndpoint(baseUrl),
        options: Options(
          sendTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          responseType: ResponseType.stream,
          headers: headers,
        ),
        data: {...body, 'stream': true},
      );
      final streamBody = resp.data;
      if (streamBody == null) throw const AiChatException('AI 返回为空');

      final contentBuf = StringBuffer();
      final calls = <int, _StreamedToolCall>{};
      final pending = <int>[];

      await for (final chunk in streamBody.stream) {
        pending.addAll(chunk);
        while (true) {
          final nl = pending.indexOf(10); // '\n'
          if (nl < 0) break;
          final lineBytes = pending.sublist(0, nl);
          pending.removeRange(0, nl + 1);
          final line = utf8.decode(lineBytes, allowMalformed: true).trimRight();
          _handleSseLine(
            line,
            onDelta,
            contentBuf,
            calls,
          );
        }
      }
      // 流结束后缓冲里可能还残留最后一行（无换行结尾）
      if (pending.isNotEmpty) {
        final line = utf8.decode(pending, allowMalformed: true).trimRight();
        _handleSseLine(line, onDelta, contentBuf, calls);
      }

      final toolCalls = <AiToolCall>[
        for (final idx in calls.keys.toList()..sort())
          if (calls[idx]!.name.isNotEmpty)
            AiToolCall(
              id: calls[idx]!.id.isEmpty ? 'call_$idx' : calls[idx]!.id,
              name: calls[idx]!.name,
              argumentsJson: calls[idx]!.args.isEmpty ? '{}' : calls[idx]!.args,
            ),
      ];
      final content = contentBuf.toString();
      return AiChatResult(
        content: content.isEmpty ? null : content,
        toolCalls: toolCalls,
      );
    } on AiChatException {
      rethrow;
    } on DioException catch (e) {
      throw AiChatException(_describe(e));
    } catch (e) {
      throw AiChatException('AI 流式请求失败：$e');
    }
  }

  void _handleSseLine(
    String line,
    void Function(String) onDelta,
    StringBuffer contentBuf,
    Map<int, _StreamedToolCall> calls,
  ) {
    if (!line.startsWith('data:')) return;
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') return;
    final dynamic obj;
    try {
      obj = jsonDecode(payload);
    } catch (_) {
      return; // 忽略心跳/注释等非 JSON 行
    }
    if (obj is! Map) return;
    final choices = obj['choices'];
    if (choices is! List || choices.isEmpty) return;
    final first = choices.first;
    if (first is! Map) return;
    final delta = first['delta'];
    if (delta is! Map) return;

    final c = delta['content'];
    if (c is String && c.isNotEmpty) {
      contentBuf.write(c);
      onDelta(c);
    }

    final tcs = delta['tool_calls'];
    if (tcs is List) {
      for (final tc in tcs) {
        if (tc is! Map) continue;
        final idx = (tc['index'] as num?)?.toInt() ?? 0;
        final buf = calls.putIfAbsent(idx, () => _StreamedToolCall());
        final id = tc['id'];
        if (id is String && id.isNotEmpty) buf.id = id;
        final fn = tc['function'];
        if (fn is Map) {
          final n = fn['name'];
          if (n is String && n.isNotEmpty) buf.nameBuf.write(n);
          final a = fn['arguments'];
          if (a is String) buf.argsBuf.write(a);
        }
      }
    }
  }

  // ---- 解析与错误 ----

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
    // 注：流式模式下错误体是 ResponseBody（异步流），此处不解析——
    // 未吐增量时的失败会走非流式降级重试，由那条请求带回完整错误体。
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

/// 流式 tool_calls 增量的累积缓冲（按 index 分组）
class _StreamedToolCall {
  String id = '';
  final StringBuffer nameBuf = StringBuffer();
  final StringBuffer argsBuf = StringBuffer();

  String get name => nameBuf.toString();
  String get args => argsBuf.toString();
}
