import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_note_repository.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/domain/ai/ai_models.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/notes/note.dart';
import 'package:pagesage/features/ai/application/ai_chat_service.dart';
import 'package:pagesage/features/ai/application/ai_providers.dart';
import 'package:pagesage/features/ai/presentation/ai_panel.dart';
import 'package:pagesage/features/reader/presentation/reader_chrome.dart';
import 'package:pagesage/features/settings/application/ai_settings_providers.dart';
import 'package:pagesage/features/settings/application/settings_providers.dart';
import 'package:pagesage/app/theme/app_theme.dart';

import '../../support/reader_workbench_capture.dart';

final class _RecordingProvider implements AiProvider {
  final requests = <AiRequest>[];
  bool failNext = false;

  @override
  Stream<AiChunk> streamChat({
    required AiRequest request,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async* {
    requests.add(request);
    if (failNext) {
      failNext = false;
      throw const AiChatException('连接失败，请重试');
    }
    yield AiChunk('回答${requests.length}');
  }

  @override
  Future<AiProviderStatus> testConnection({
    required AiSettings settings,
    required String apiKey,
    AiCancelToken? cancelToken,
  }) async => AiProviderStatus.ready;
}

/// Keeps what was saved; the panel reads the thread id back off the result.
final class _MemoryConversations implements AiConversationRepository {
  final saved = <AiConversation>[];
  final noteLinks = <String, String>{};
  Object? watchError;
  bool failLink = false;

  @override
  Future<AiConversation> saveConversation({
    String? id,
    String? bookId,
    ReadingLocator? locator,
    required String provider,
    required String model,
    required String prompt,
    String? contextText,
    required String answer,
    String? sourceText,
    String? threadId,
    AiContextSnapshot? contextSnapshot,
  }) async {
    final conversation = AiConversation(
      id: id ?? 'conv-${saved.length + 1}',
      bookId: bookId,
      locator: locator,
      provider: provider,
      model: model,
      prompt: prompt,
      contextText: contextText,
      answer: answer,
      sourceText: sourceText,
      threadId: threadId,
      contextSnapshot: contextSnapshot,
      createdAt: saved.length + 1,
    );
    saved.removeWhere((item) => item.id == conversation.id);
    saved.add(conversation);
    return conversation;
  }

  @override
  Future<void> clearAll() async => saved.clear();

  @override
  Future<List<AiConversation>> getConversations() async =>
      List.of(saved.reversed);

  @override
  Future<void> linkNote({
    required String conversationId,
    required String noteId,
  }) async {
    if (failLink) throw StateError('injected link failure');
    noteLinks[conversationId] = noteId;
  }

  @override
  Stream<List<AiConversation>> watchConversations() => watchError == null
      ? Stream.value(List.of(saved.reversed))
      : Stream.error(watchError!);
}

const _settings = AiSettings(
  enabled: true,
  baseUrl: 'http://localhost:11434',
  model: 'test-model',
  hasApiKey: true,
);

final class _Settings implements AiSettingsRepository {
  const _Settings();

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<AiSettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}

  @override
  Stream<AiSettings> watchSettings() => Stream.value(_settings);
}

final class _GatedSettings implements AiSettingsRepository {
  Completer<void>? gate;
  int reads = 0;

  @override
  Future<AiSettings> getSettings() async {
    reads++;
    await gate?.future;
    return _settings;
  }

  @override
  Stream<AiSettings> watchSettings() => Stream.value(_settings);

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<void> saveSettings(AiSettings settings, {String? apiKey}) async {}
}

Widget _panel({
  required _RecordingProvider provider,
  required _MemoryConversations conversations,
  String selection = '选中的句子',
  Widget? app,
  bool embedded = false,
  NoteRepository? notes,
  AiSettingsRepository settings = const _Settings(),
  bool dark = false,
  double textScale = 1,
  List<AiProfile> profiles = const [],
}) {
  final service = AiChatService(
    settingsRepository: settings,
    conversationRepository: conversations,
    secureStore: SecureStore(),
    provider: provider,
    readSecret: (_) async => 'test-key',
  );
  return ProviderScope(
    overrides: [
      aiChatServiceProvider.overrideWithValue(service),
      aiSettingsRepositoryProvider.overrideWithValue(settings),
      aiProfilesProvider.overrideWith((ref) => Stream.value(profiles)),
      readerSettingsProvider.overrideWith(
        (ref) => Stream.value(const ReaderSettings()),
      ),
      aiConversationRepositoryProvider.overrideWithValue(conversations),
      if (notes != null) noteRepositoryProvider.overrideWithValue(notes),
    ],
    child: RepaintBoundary(
      key: workbenchCaptureKey,
      child:
          app ??
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: AiPanel(
                bookId: 'book-1',
                bookPath: null,
                format: BookFormat.epub,
                locator: ReadingLocator.epub(
                  href: 'OEBPS/chapter1.xhtml',
                  chapterIndex: 0,
                  chapterOffset: 0,
                  progress: 0,
                ),
                initialContext: selection,
                embedded: embedded,
              ),
            ),
          ),
    ),
  );
}

Future<void> _ask(WidgetTester tester, String prompt) async {
  await tester.enterText(find.byType(TextField).last, prompt);
  await tester.pumpAndSettle();
  await tester.tap(find.text('发送'));
  await tester.pumpAndSettle();
}

Future<void> _enableSourceQuestion(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('ai-source-question-mode')),
  );
  await tester.tap(find.byKey(const ValueKey('ai-source-question-mode')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('short mobile sheet keeps the composer above the keyboard', (
    tester,
  ) async {
    if (captureWorkbench) await tester.runAsync(loadWorkbenchCaptureFonts);
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      _panel(
        provider: _RecordingProvider(),
        conversations: _MemoryConversations(),
        app: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => const ReaderBottomSheetFrame(
                    child: AiPanel(
                      bookId: 'book-1',
                      locator: null,
                      initialContext: '原文',
                      format: BookFormat.epub,
                    ),
                  ),
                ),
                child: const Text('打开助手'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开助手'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding(
      bottom: 260 * tester.view.devicePixelRatio,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomRight(find.text('发送')).dy, lessThanOrEqualTo(380));
    expect(
      find.byKey(const ValueKey('ai-prompt')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byTooltip('上下文范围').hitTestable(), findsOneWidget);
    await captureWorkbenchWidget(tester, 'ai-short-keyboard');
  });

  testWidgets('AI settings opens directly and returning retains the question', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _panel(
        provider: _RecordingProvider(),
        conversations: _MemoryConversations(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ai-prompt')), '尚未发送的问题');
    await tester.tap(find.byTooltip('AI 设置'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-base-url')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
          .controller!
          .text,
      '尚未发送的问题',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard send, retry and new conversation preserve correct history',
    (tester) async {
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations();
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ai-prompt')), '第一问');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(provider.requests, hasLength(1));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-prompt')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(provider.requests, hasLength(2));
      expect(conversations.saved, hasLength(1));
      expect(provider.requests.last.prompt, '第一问');
      expect(provider.requests.last.history, isEmpty);
      await _ask(tester, '第二问');
      expect(provider.requests.last.history.single.answer, '回答2');
      await tester.tap(find.byTooltip('新对话'));
      await tester.pumpAndSettle();
      await _ask(tester, '新问题');
      expect(provider.requests.last.history, isEmpty);
      expect(provider.requests.last.contextText, contains('选中的句子'));
      expect(
        conversations.saved.last.threadId,
        isNot(conversations.saved.first.threadId),
      );
    },
  );

  testWidgets('failed request retries directly without losing the question', (
    tester,
  ) async {
    final provider = _RecordingProvider()..failNext = true;
    await tester.pumpWidget(
      _panel(provider: provider, conversations: _MemoryConversations()),
    );
    await tester.pumpAndSettle();
    await _ask(tester, '请解释');
    expect(find.text('连接失败，请重试'), findsOneWidget);
    await tester.ensureVisible(find.text('重新发送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新发送'));
    await tester.pumpAndSettle();
    expect(provider.requests.map((request) => request.prompt), ['请解释', '请解释']);
    expect(find.text('连接失败，请重试'), findsNothing);
  });

  testWidgets(
    'preflight excludes duplicate sends and ignores a disposed panel',
    (tester) async {
      final settings = _GatedSettings();
      final provider = _RecordingProvider();
      await tester.pumpWidget(
        _panel(
          provider: provider,
          conversations: _MemoryConversations(),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      settings.gate = Completer<void>();
      final send = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '发送'))
          .onPressed!;
      send();
      send();
      await tester.pump();
      expect(settings.reads, 1);
      expect(provider.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.gate!.complete();
      await tester.pumpAndSettle();
      expect(provider.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source question follow-ups and retries keep the serialized snapshot',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations();
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations),
      );
      await tester.pumpAndSettle();
      await _enableSourceQuestion(tester);
      await _ask(tester, '原文说了什么？');
      expect(provider.requests, hasLength(1));
      final first = provider.requests.single.contextText;
      provider.failNext = true;
      await _ask(tester, '还能得到什么结论？');
      expect(provider.requests, hasLength(2));
      expect(provider.requests.last.contextText, first);
      await tester.ensureVisible(find.text('重新发送'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新发送'));
      await tester.pumpAndSettle();
      expect(provider.requests, hasLength(3));
      expect(provider.requests.last.contextText, first);
      expect(
        conversations.saved.last.contextSnapshot?.toJsonText(),
        conversations.saved.first.contextSnapshot?.toJsonText(),
      );
    },
  );

  for (final scenario in [
    (width: 420.0, height: 860.0, scale: 1.0, dark: false),
    (width: 390.0, height: 780.0, scale: 1.5, dark: true),
  ]) {
    testWidgets('AI workflow fits $scenario', (tester) async {
      if (captureWorkbench) await tester.runAsync(loadWorkbenchCaptureFonts);
      await tester.binding.setSurfaceSize(
        Size(scenario.width, scenario.height),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      await tester.pumpWidget(
        _panel(
          provider: provider,
          conversations: _MemoryConversations(),
          embedded: true,
          dark: scenario.dark,
          textScale: scenario.scale,
          profiles: const [
            AiProfile(id: 'reading', name: '本地阅读助手', model: 'reader-model'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await captureWorkbenchWidget(tester, 'ai-compose-${scenario.dark}');
      await _ask(tester, '解释这段内容');
      await tester.ensureVisible(find.text('笔记'));
      await tester.pumpAndSettle();
      await captureWorkbenchWidget(tester, 'ai-answer-${scenario.dark}');
      expect(provider.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'source questions use citation protocol without provider output',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations();
      await tester.pumpWidget(
        _panel(
          provider: provider,
          conversations: conversations,
          selection: '园艺笔记',
        ),
      );
      await tester.pumpAndSettle();
      await _enableSourceQuestion(tester);
      await tester.enterText(find.byType(TextField).last, '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();

      expect(provider.requests, isEmpty);
      expect(conversations.saved, isEmpty);
      expect(find.textContaining('请输入上下文和问题'), findsOneWidget);
    },
  );

  testWidgets(
    'history resumes all same-book turns with structured references',
    (tester) async {
      if (captureWorkbench) await tester.runAsync(loadWorkbenchCaptureFonts);
      await tester.binding.setSurfaceSize(const Size(520, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations();
      final snapshot = AiContextSnapshot(
        range: 'folder',
        references: [
          const AiContextReference(id: 'ref-2', title: '甲书片段', text: '本书原文'),
          AiContextReference(
            id: 'ref-8',
            title: '第 42 页',
            text: '跨书原文',
            bookTitle: '乙书',
            bookId: 'book-b',
            locator: ReadingLocator.pdf(page: 42),
            sourceKey: 'book-b:42',
            startOffset: 10,
            endOffset: 14,
          ),
        ],
      );
      conversations.saved.addAll([
        _storedTurn(
          'first',
          '第一问',
          '第一答',
          snapshot: snapshot,
          locator: ReadingLocator.epub(href: 'old.xhtml', chapterIndex: 3),
        ),
        _storedTurn(
          'second',
          '第二问',
          '第二答',
          snapshot: snapshot,
          locator: ReadingLocator.epub(href: 'old.xhtml', chapterIndex: 3),
        ),
        _storedTurn(
          'foreign',
          '其他书的问题',
          '不能串入',
          bookId: 'book-b',
          snapshot: snapshot,
        ),
        _storedTurn(
          'other-thread',
          '其他会话',
          '也不能串入',
          threadId: 'thread-b',
          snapshot: snapshot,
        ),
      ]);
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('第一问'));
      await tester.tap(find.text('第一问'));
      await tester.pumpAndSettle();
      expect(provider.requests, isEmpty);
      expect(find.text('此前 1 轮对话'), findsOneWidget);
      expect(find.text('乙书 · 第 42 页'), findsOneWidget);
      expect(find.text('文件夹关联'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        isEmpty,
      );
      await captureWorkbenchWidget(tester, 'ai-restored-sources');
      if (captureWorkbench) {
        await tester.binding.setSurfaceSize(const Size(420, 860));
        await tester.pumpWidget(
          _panel(
            provider: provider,
            conversations: conversations,
            embedded: true,
          ),
        );
        await tester.pumpAndSettle();
        await captureWorkbenchWidget(tester, 'ai-restored-rail');
      }
      await _ask(tester, '第三问');
      final request = provider.requests.single;
      expect(request.history.map((turn) => turn.prompt), ['第一问', '第二问']);
      expect(request.history.map((turn) => turn.answer), ['第一答', '第二答']);
      expect(request.contextText, joinContextReferences(snapshot.references));
      expect(conversations.saved.last.threadId, 'thread-a');
      expect(conversations.saved.last.locator?.href, 'old.xhtml');
      expect(conversations.saved.last.locator?.chapterIndex, 3);
      expect(
        conversations.saved.last.contextSnapshot?.toJsonText(),
        snapshot.toJsonText(),
      );
    },
  );

  testWidgets(
    'legacy history stays honest and keeps its first turn when continued',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations();
      conversations.saved.add(
        _storedTurn('legacy', '旧问题', '旧回答', threadId: null),
      );
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧问题'));
      await tester.pumpAndSettle();
      expect(find.text('旧版上下文（未记录分段来源）'), findsOneWidget);
      await _ask(tester, '续问');
      expect(provider.requests.single.history.single.prompt, '旧问题');
      expect(conversations.saved.last.threadId, 'legacy');
      expect(conversations.saved.last.locator, isNull);
      expect(provider.requests.single.contextText, '历史上下文');
      final restored = await AiChatService(
        settingsRepository: const _Settings(),
        conversationRepository: conversations,
        secureStore: SecureStore(),
      ).restoreThread(conversations.saved.first);
      expect(restored.map((turn) => turn.prompt), ['旧问题', '续问']);
    },
  );

  testWidgets('restored sibling reference opens its own book and page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final conversations = _MemoryConversations();
    conversations.saved.add(
      _storedTurn(
        'saved',
        '跨书问题',
        '跨书回答',
        snapshot: AiContextSnapshot(
          range: 'folder',
          references: [
            AiContextReference(
              id: 'ref-7',
              title: '第 42 页',
              text: '跨书原文',
              bookId: 'book-b',
              bookTitle: '乙书',
              locator: ReadingLocator.pdf(page: 42),
            ),
          ],
        ),
      ),
    );
    final provider = _RecordingProvider();
    final router = GoRouter(
      initialLocation: '/book/book-1/reader',
      routes: [
        GoRoute(
          path: '/book/:bookId/reader',
          builder: (context, state) {
            if (state.pathParameters['bookId'] == 'book-b') {
              return Scaffold(
                body: Text(
                  'book-b page ${(state.extra as ReadingLocator).page}',
                ),
              );
            }
            return Scaffold(
              body: AiPanel(
                bookId: 'book-1',
                locator: ReadingLocator.pdf(page: 1),
                initialContext: '当前选区',
                format: BookFormat.pdf,
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _panel(
        provider: provider,
        conversations: conversations,
        app: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跨书问题'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('回到这段原文'));
    await tester.pumpAndSettle();
    expect(find.text('book-b page 42'), findsOneWidget);
    expect(provider.requests, isEmpty);
  });

  testWidgets(
    'history read failure is visible instead of claiming no history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations()
        ..watchError = const FormatException('unsupported snapshot');
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      expect(find.text('无法读取 AI 历史'), findsOneWidget);
      expect(find.text('还没有当前书籍的 AI 历史'), findsNothing);
      conversations.watchError = null;
      await tester.tap(find.text('重新加载历史'));
      await tester.pumpAndSettle();
      expect(find.text('还没有当前书籍的 AI 历史'), findsOneWidget);
      expect(provider.requests, isEmpty);
    },
  );

  testWidgets(
    'saving restored answer keeps its original locator and conversation link',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final notes = DriftNoteRepository(
        database.noteDao,
        DriftSearchRepository(database.searchDao),
      );
      final conversations = _MemoryConversations();
      conversations.saved.add(
        _storedTurn(
          'restored',
          '历史问题',
          '历史回答',
          locator: ReadingLocator.epub(href: 'old.xhtml', chapterIndex: 3),
        ),
      );
      final provider = _RecordingProvider();
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations, notes: notes),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史问题'));
      await tester.pumpAndSettle();
      conversations.failLink = true;
      await tester.tap(find.widgetWithText(OutlinedButton, '笔记'));
      await tester.pumpAndSettle();
      expect(find.text('保存笔记失败，回答已保留'), findsOneWidget);
      expect(await tester.runAsync(notes.getNotes), hasLength(1));
      conversations.failLink = false;
      final save = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '笔记'))
          .onPressed!;
      save();
      save();
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(notes.getNotes);
      expect(saved, hasLength(1));
      final note = saved!.single;
      expect(note.locator?.href, 'old.xhtml');
      expect(note.locator?.chapterIndex, 3);
      expect(note.content, '历史回答');
      expect(note.title, '历史问题');
      expect(note.sourceText, '历史上下文');
      expect(conversations.noteLinks['restored'], note.id);
      expect(find.text('已存笔记'), findsOneWidget);
      expect(provider.requests, isEmpty);
    },
  );

  testWidgets(
    'editing a reference starts a new thread and clears stale answer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _RecordingProvider();
      final conversations = _MemoryConversations();
      await tester.pumpWidget(
        _panel(provider: provider, conversations: conversations),
      );
      await tester.pumpAndSettle();
      await _ask(tester, '第一问');
      await tester.tap(find.byTooltip('编辑文本'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '编辑后的原文');
      await tester.pumpAndSettle();
      expect(find.textContaining('回答1'), findsNothing);
      await _ask(tester, '新问题');
      expect(provider.requests.last.history, isEmpty);
      expect(provider.requests.last.contextText, '编辑后的原文');
      expect(
        conversations.saved.last.threadId,
        isNot(conversations.saved.first.threadId),
      );
    },
  );

  testWidgets('a follow-up question carries the earlier turn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = _RecordingProvider();
    final conversations = _MemoryConversations();
    await tester.pumpWidget(
      _panel(provider: provider, conversations: conversations),
    );
    await tester.pumpAndSettle();

    await _ask(tester, '第一问');
    expect(provider.requests.single.history, isEmpty);

    await _ask(tester, '第二问');
    final second = provider.requests.last;
    expect(second.history, hasLength(1));
    expect(second.history.single.prompt, '第一问');
    expect(second.history.single.answer, '回答1');

    // Both turns belong to one thread, so the history view can regroup them.
    expect(conversations.saved, hasLength(2));
    expect(conversations.saved[0].threadId, isNotNull);
    expect(conversations.saved[1].threadId, conversations.saved[0].threadId);
  });

  testWidgets('a new selection starts a new thread', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = _RecordingProvider();
    final conversations = _MemoryConversations();
    await tester.pumpWidget(
      _panel(provider: provider, conversations: conversations),
    );
    await tester.pumpAndSettle();
    await _ask(tester, '第一问');

    // The reader selects different text; the old answer discussed a passage
    // the next question will not carry.
    await tester.pumpWidget(
      _panel(
        provider: provider,
        conversations: conversations,
        selection: '另一段话',
      ),
    );
    await tester.pumpAndSettle();
    await _ask(tester, '第二问');

    expect(provider.requests.last.history, isEmpty);
    expect(
      conversations.saved.last.threadId,
      isNot(conversations.saved.first.threadId),
    );
  });
}

AiConversation _storedTurn(
  String id,
  String prompt,
  String answer, {
  String bookId = 'book-1',
  String? threadId = 'thread-a',
  AiContextSnapshot? snapshot,
  ReadingLocator? locator,
}) => AiConversation(
  id: id,
  bookId: bookId,
  locator: locator,
  provider: 'local',
  model: 'm',
  prompt: prompt,
  answer: answer,
  createdAt: 1,
  threadId: threadId,
  contextText: snapshot == null
      ? '历史上下文'
      : joinContextReferences(snapshot.references),
  contextSnapshot: snapshot,
);
