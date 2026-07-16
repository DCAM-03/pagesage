import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../domain/ai/ai_models.dart';

final class OpenAiCompatibleProvider implements AiProvider {
  const OpenAiCompatibleProvider();

  @override
  Stream<AiChunk> streamChat({
    required AiRequest request,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async* {
    final settings = request.settings;
    final base = settings.baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final client = HttpClient();
    cancelToken?.bind(() => client.close(force: true));

    try {
      final httpRequest = await client.postUrl(uri);
      _writeHeaders(httpRequest, apiKey);
      httpRequest.write(
        jsonEncode({
          'model': settings.model,
          'temperature': settings.temperature,
          'max_tokens': settings.maxTokens,
          'stream': settings.streaming,
          'messages': _messages(request),
        }),
      );

      final response = await httpRequest.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        throw AiChatException(_mapHttpError(response.statusCode, body));
      }

      if (!settings.streaming) {
        final body = await utf8.decodeStream(response);
        final content = _contentFromCompletion(body);
        if (content.isNotEmpty) {
          yield AiChunk(content);
        }
        return;
      }

      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (cancelToken?.isCancelled == true) {
          throw const AiChatCancelledException();
        }
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) {
          continue;
        }
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') {
          return;
        }
        final content = _contentFromDelta(data);
        if (content.isNotEmpty) {
          yield AiChunk(content);
        }
      }
    } on AiChatCancelledException {
      rethrow;
    } on AiChatException {
      rethrow;
    } on SocketException {
      if (cancelToken?.isCancelled == true) {
        throw const AiChatCancelledException();
      }
      throw const AiChatException('网络连接失败，请检查 Provider 地址');
    } on HttpException {
      if (cancelToken?.isCancelled == true) {
        throw const AiChatCancelledException();
      }
      throw const AiChatException('Provider 连接已中断');
    } on FormatException {
      throw const AiChatException('AI 响应格式不正确');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AiProviderStatus> testConnection({
    required AiSettings settings,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async {
    if (settings.baseUrl.trim().isEmpty || settings.model.trim().isEmpty) {
      return AiProviderStatus.missingConfiguration;
    }
    if (apiKey.trim().isEmpty) {
      return AiProviderStatus.missingApiKey;
    }
    try {
      await streamChat(
        request: AiRequest(
          prompt: '请回复 OK',
          contextText: '连接测试，不包含书籍正文。',
          settings: settings.copyWith(streaming: false, maxTokens: 8),
        ),
        apiKey: apiKey,
        cancelToken: cancelToken,
      ).drain<void>();
      return AiProviderStatus.ready;
    } on Object {
      return AiProviderStatus.unavailable;
    }
  }

  void _writeHeaders(HttpClientRequest request, String apiKey) {
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
  }

  List<Map<String, String>> _messages(AiRequest request) {
    return [
      if (request.settings.systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': request.settings.systemPrompt.trim()},
      {
        'role': 'user',
        'content':
            '上下文范围：用户手动提供的文本\n\n上下文：\n${request.contextText}\n\n问题：${request.prompt}',
      },
    ];
  }

  String _contentFromCompletion(String body) {
    final json = jsonDecode(body) as Map<String, Object?>;
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiChatException('AI 响应为空');
    }
    final first = choices.first;
    if (first is! Map<String, Object?>) {
      throw const AiChatException('AI 响应格式不正确');
    }
    final message = first['message'];
    if (message is! Map<String, Object?>) {
      throw const AiChatException('AI 响应缺少正文');
    }
    return message['content']?.toString().trim() ?? '';
  }

  String _contentFromDelta(String data) {
    final json = jsonDecode(data) as Map<String, Object?>;
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final first = choices.first;
    if (first is! Map<String, Object?>) {
      return '';
    }
    final delta = first['delta'];
    if (delta is! Map<String, Object?>) {
      return '';
    }
    return delta['content']?.toString() ?? '';
  }

  String _mapHttpError(int statusCode, String body) {
    final providerMessage = _providerMessage(body);
    final suffix = providerMessage == null ? '' : '：$providerMessage';
    return switch (statusCode) {
      400 => 'AI 请求格式不被 Provider 接受$suffix',
      401 || 403 => 'API Key 无效或无权限$suffix',
      404 => '模型不存在或接口地址不正确$suffix',
      408 => 'AI 请求超时$suffix',
      413 => '上下文过长，请缩小发送范围$suffix',
      429 => 'Provider 限流，请稍后重试$suffix',
      >= 500 => 'Provider 暂不可用$suffix',
      _ => 'AI 请求失败：HTTP $statusCode$suffix',
    };
  }

  String? _providerMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, Object?>) {
        final error = json['error'];
        if (error is Map<String, Object?>) {
          final message = error['message']?.toString().trim();
          return message?.isEmpty == false ? message : null;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }
}
