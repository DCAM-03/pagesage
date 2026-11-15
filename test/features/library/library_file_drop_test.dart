import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/file_providers.dart';
import 'package:pagesage/core/files/metadata_extractor.dart';
import 'package:pagesage/core/platform/platform_providers.dart';
import 'package:pagesage/core/platform/window_drop_import_service.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/features/import/application/import_providers.dart';
import 'package:pagesage/features/import/application/import_result.dart';
import 'package:pagesage/features/library/presentation/library_file_drop_target.dart';
import 'package:pagesage/features/library/presentation/library_page.dart';
import 'package:path/path.dart' as p;

import '../../support/reader_workbench_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pagesage/test_library_drop');
  late AppDatabase database;
  late ProviderContainer container;
  late WindowDropImportService drops;
  late GoRouter router;
  late Directory temporary;
  late File source;
  late List<bool> enabled;
  Completer<void>? coverBarrier;
  Completer<void>? coverStarted;

  setUpAll(() async {
    if (captureWorkbench) {
      await loadWorkbenchCaptureFonts();
    }
  });

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pagesage_drop_');
    source = await File(
      'poc_pdf_canvas/samples/standard-text.pdf',
    ).copy(p.join(temporary.path, '微信文件 线性代数.PDF'));
    database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final paths = AppPaths(
      overrideRoot: Directory(p.join(temporary.path, 'library-data')),
    );
    enabled = [];
    coverBarrier = null;
    coverStarted = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setEnabled') {
            enabled.add(call.arguments as bool);
          }
          return null;
        });
    drops = WindowDropImportService(channel: channel);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPathsProvider.overrideWithValue(paths),
        metadataExtractorProvider.overrideWithValue(
          MetadataExtractor(
            appPaths: paths,
            pdfCoverPainter: (_) async {
              final started = coverStarted;
              if (started != null && !started.isCompleted) {
                started.complete();
              }
              await coverBarrier?.future;
              return null;
            },
          ),
        ),
        windowDropImportServiceProvider.overrideWithValue(drops),
      ],
    );
    router = GoRouter(
      initialLocation: '/library',
      routes: [
        GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
        GoRoute(
          path: '/reader/:bookId',
          name: 'reader',
          builder: (_, state) =>
              Scaffold(body: Text('Reader: ${state.pathParameters['bookId']}')),
        ),
        GoRoute(
          path: '/elsewhere',
          builder: (_, _) => const Scaffold(body: Text('Elsewhere')),
        ),
      ],
    );
  });

  Future<void> emit(String method, [Object? arguments]) async {
    final completed = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) => completed.complete(),
        );
    await completed.future;
  }

  Future<void> waitForIndexing() async {
    for (var attempt = 0; attempt < 200; attempt++) {
      final tasks = await container.read(taskRepositoryProvider).getTasks();
      if (!tasks.any(
        (task) => {
          PageSageTaskStatus.queued,
          PageSageTaskStatus.running,
          PageSageTaskStatus.indexing,
        }.contains(task.status),
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Background import indexing did not finish');
  }

  Future<Result> completeWithFrames<Result>(
    WidgetTester tester,
    Future<Result> pending,
  ) async {
    var finished = false;
    final trackedFuture = pending.whenComplete(() => finished = true);
    for (var round = 0; round < 300 && !finished; round++) {
      await tester.pump(const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(finished, isTrue, reason: 'External file operation did not finish');
    return await trackedFuture;
  }

  void dropTest(
    String name,
    Future<void> Function(WidgetTester) body, {
    Size size = const Size(1280, 900),
    bool dark = false,
    double textScale = 1,
  }) {
    testWidgets(name, (tester) async {
      await tester.binding.setSurfaceSize(size);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: workbenchCaptureKey,
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  routerConfig: router,
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => container.read(bookRepositoryProvider).getLibrary(),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LibraryPage), findsOneWidget);
        await body(tester);
        expect(tester.takeException(), isNull);
      } finally {
        final barrier = coverBarrier;
        if (barrier != null && !barrier.isCompleted) {
          barrier.complete();
        }
        await tester.runAsync(
          () => completeWithFrames(tester, waitForIndexing()),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        drops.dispose();
        await tester.pump();
        await tester.runAsync(database.close);
        await tester.runAsync(() => temporary.delete(recursive: true));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await tester.binding.setSurfaceSize(null);
      }
    }, timeout: const Timeout(Duration(seconds: 45)));
  }

  Future<void> dropFiles(WidgetTester tester, List<String> paths) async {
    await tester.runAsync(
      () => completeWithFrames(tester, emit('filesDropped', paths)),
    );
    await tester.pumpAndSettle();
  }

  dropTest('single external PDF is copied and automatically opens its reader', (
    tester,
  ) async {
    await dropFiles(tester, [source.path]);
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    final book = rows!.single;
    expect(
      router.routeInformationProvider.value.uri.path,
      '/reader/${book.id}',
    );
    expect(book.libraryFilePath, isNot(source.path));
    expect(book.originalFilePath, source.path);
    await tester.runAsync(() async {
      expect(await source.exists(), isTrue);
      final expected = await source.readAsBytes();
      await source.delete();
      expect(await File(book.libraryFilePath).readAsBytes(), expected);
    });
    expect(enabled, containsAllInOrder([true, false]));
    expect(find.byType(AlertDialog), findsNothing);
  });

  dropTest('dropping an existing book opens it without a duplicate prompt', (
    tester,
  ) async {
    final result = await tester.runAsync(
      () => completeWithFrames(
        tester,
        container.read(importUseCaseProvider).importPath(source.path),
      ),
    );
    final existing = (result! as ImportBookSuccess).book;
    await dropFiles(tester, [source.path]);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/reader/${existing.id}',
    );
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    expect(rows, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });

  dropTest('multiple files import once each and remain on the shelf', (
    tester,
  ) async {
    final markdown = await tester.runAsync(
      () => File(
        p.join(temporary.path, '笔记.md'),
      ).writeAsString('# Notes\n\nText'),
    );
    await dropFiles(tester, [source.path, source.path, markdown!.path]);
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    expect(rows, hasLength(2));
    expect(router.routeInformationProvider.value.uri.path, '/library');
    expect(find.text('导入完成：成功 2，重复 0，失败 0'), findsOneWidget);
  });

  dropTest('mixed unsupported files retain the import summary on the shelf', (
    tester,
  ) async {
    await dropFiles(tester, [
      source.path,
      p.join(temporary.path, 'photo.png'),
      p.join(temporary.path, 'archive.zip'),
    ]);
    expect(router.routeInformationProvider.value.uri.path, '/library');
    expect(find.text('导入完成：成功 1，重复 0，失败 2'), findsOneWidget);
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    expect(rows, hasLength(1));
  });

  dropTest('folders and unreadable files do not navigate or create books', (
    tester,
  ) async {
    await dropFiles(tester, [temporary.path]);
    expect(find.text('请拖入 EPUB、PDF 或 Markdown 文件'), findsOneWidget);
    await dropFiles(tester, [p.join(temporary.path, 'missing.pdf')]);
    expect(router.routeInformationProvider.value.uri.path, '/library');
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    expect(rows, isEmpty);
    expect(find.text('文件不可访问'), findsOneWidget);
  });

  dropTest('a second drop while importing gets feedback and does not race', (
    tester,
  ) async {
    coverBarrier = Completer<void>();
    coverStarted = Completer<void>();
    await tester.runAsync(() async {
      final pending = emit('filesDropped', [source.path]);
      await completeWithFrames(tester, coverStarted!.future);
      await emit('filesDropped', [source.path]);
      await tester.pump();
      expect(find.text('正在导入，请完成后再拖入文件'), findsOneWidget);
      coverBarrier!.complete();
      await completeWithFrames(tester, pending);
    });
    await tester.pumpAndSettle();
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    expect(rows, hasLength(1));
    expect(
      router.routeInformationProvider.value.uri.path,
      startsWith('/reader/'),
    );
  });

  dropTest(
    'leaving during import does not navigate back or import later files',
    (tester) async {
      coverBarrier = Completer<void>();
      coverStarted = Completer<void>();
      await tester.runAsync(() async {
        final pending = emit('filesDropped', [
          source.path,
          p.join(temporary.path, 'later.pdf'),
        ]);
        await completeWithFrames(tester, coverStarted!.future);
        router.go('/elsewhere');
        await tester.pumpAndSettle();
        coverBarrier!.complete();
        await completeWithFrames(tester, pending);
      });
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/elsewhere');
      final rows = await tester.runAsync(
        () => database.select(database.books).get(),
      );
      expect(rows, hasLength(1));
      expect(enabled.last, isFalse);
    },
  );

  dropTest('leaving while hovering disables drops outside the library', (
    tester,
  ) async {
    await emit('dragEntered');
    await tester.pump();
    expect(drops.dragging.value, isTrue);
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(drops.dragging.value, isFalse);
    expect(enabled.last, isFalse);
    await dropFiles(tester, [source.path]);
    expect(router.routeInformationProvider.value.uri.path, '/elsewhere');
    final rows = await tester.runAsync(
      () => database.select(database.books).get(),
    );
    expect(rows, isEmpty);
  });

  for (final dark in [false, true]) {
    dropTest(
      'drag feedback follows the native lifecycle in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await emit('dragEntered');
        await tester.pump();
        final target = find.byType(LibraryFileDropTarget);
        expect(
          find.descendant(of: target, matching: find.text('松开即可导入阅读')),
          findsOneWidget,
        );
        await captureWorkbenchWidget(
          tester,
          'library-file-drop-${dark ? 'dark' : 'light'}',
        );
        await emit('dragExited');
        await tester.pump();
        expect(find.text('松开即可导入阅读'), findsNothing);
        expect(find.byType(LibraryPage), findsOneWidget);
      },
      dark: dark,
      size: dark ? const Size(900, 800) : const Size(1280, 900),
      textScale: dark ? 1.5 : 1,
    );
  }
}
