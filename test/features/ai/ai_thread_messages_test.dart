import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/features/ai/data/openai_compatible_provider.dart';

/// A throwaway server that records the request body and answers with one chunk.
final class _CaptureServer {
  _CaptureServer(this._server);

  final HttpServer _server;
  final List<Map<String, Object?>> bodies = [];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<_CaptureServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final capture = _CaptureServer(server);
    capture._listen();
    return capture;
  }

  void _listen() {
    _server.listen((request) async {
      final raw = await utf8.decodeStream(request);
      bodies.add(jsonDecode(raw) as Map<String, Object?>);
      final body = jsonEncode({
        'choices': [
          {
            'message': {'content': '好的'},
          },
        ],
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(body);
      await request.response.close();
    });
  }

  Future<void> close() => _server.close(force: true);
}

/// Runs one request against the server and returns the messages that arrived.
Future<List<Map<String, Object?>>> _messagesFor(AiRequest request) async {
  final server = await _CaptureServer.start();
  addTearDown(server.close);
  final provider = OpenAiCompatibleProvider();
  await provider
      .streamChat(
        request: AiRequest(
          prompt: request.prompt,
          contextText: request.contextText,
          settings: AiSettings(
            model: request.settings.model,
            baseUrl: server.baseUrl,
            systemPrompt: request.settings.systemPrompt,
            streaming: false,
          ),
          history: request.history,
        ),
        apiKey: 'test-key',
      )
      .drain<void>();

  expect(server.bodies, hasLength(1));
  final messages = server.bodies.single['messages'];
  expect(messages, isA<List<Object?>>());
  return (messages! as List<Object?>).cast<Map<String, Object?>>().toList(
    growable: false,
  );
}

void main() {
  const base = AiSettings(model: 'test-model', baseUrl: '');

  test('a first question carries the context once', () async {
    final messages = await _messagesFor(
      const AiRequest(prompt: '解释这段', contextText: '书籍片段', settings: base),
    );

    expect(messages, hasLength(1));
    expect(messages.single['role'], 'user');
    expect(messages.single['content'], contains('书籍片段'));
    expect(messages.single['content'], contains('解释这段'));
  });

  test('a follow-up keeps the context on the opening turn only', () async {
    final messages = await _messagesFor(
      const AiRequest(
        prompt: '再举个例子',
        contextText: '书籍片段',
        settings: base,
        history: [AiThreadTurn(prompt: '解释这段', answer: '这是解释')],
      ),
    );

    expect(messages.map((m) => m['role']), ['user', 'assistant', 'user']);
    // The passage is the expensive part; it must not be repeated per turn.
    expect(
      messages.where((m) => (m['content']! as String).contains('书籍片段')),
      hasLength(1),
    );
    expect(messages.first['content'], contains('解释这段'));
    expect(messages[1]['content'], '这是解释');
    expect(messages.last['content'], '再举个例子');
  });

  test(
    'several turns keep their order and end with the new question',
    () async {
      final messages = await _messagesFor(
        const AiRequest(
          prompt: '第三问',
          contextText: '片段',
          settings: base,
          history: [
            AiThreadTurn(prompt: '第一问', answer: '第一答'),
            AiThreadTurn(prompt: '第二问', answer: '第二答'),
          ],
        ),
      );

      expect(messages.map((m) => m['role']), [
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      expect(messages[1]['content'], '第一答');
      expect(messages[2]['content'], '第二问');
      expect(messages[3]['content'], '第二答');
      expect(messages.last['content'], '第三问');
    },
  );

  test('a custom system prompt stays first', () async {
    final messages = await _messagesFor(
      const AiRequest(
        prompt: '问题',
        contextText: '片段',
        settings: AiSettings(
          model: 'test-model',
          baseUrl: '',
          systemPrompt: ' 你是阅读助手 ',
        ),
        history: [AiThreadTurn(prompt: '旧问', answer: '旧答')],
      ),
    );

    expect(messages.first['role'], 'system');
    expect(messages.first['content'], '你是阅读助手');
    expect(messages[1]['role'], 'user');
  });
}
