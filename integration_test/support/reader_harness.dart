import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/features/reader/presentation/reader_page.dart';

/// Hosts the real reader against an in-memory database on the Linux desktop.
///
/// The integration tests exist to exercise what widget tests cannot: the real
/// GTK window, real pointer input through the platform layer, and the real
/// host widget that positions menus. Everything the reader needs is the
/// production implementation; only durable storage is swapped for an in-memory
/// Drift database so a test run cannot touch the user's library.
final class ReaderHarness {
  ReaderHarness._(this.database);

  final AppDatabase database;

  /// Root of the writer's widget tree, used by [capture].
  final GlobalKey _captureKey = GlobalKey();

  static Future<ReaderHarness> create({
    required Iterable<Book> books,
    Map<String, ReadingProgressSnapshot> progress = const {},
  }) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final harness = ReaderHarness._(database);

    for (final book in books) {
      await database.bookDao.insertBook(
        BooksCompanion.insert(
          id: book.id,
          title: book.title,
          format: book.format.value,
          originalFormat: Value(book.format.value),
          originalFilePath: Value(book.libraryFilePath),
          libraryFilePath: book.libraryFilePath,
          fileHash: book.fileHash,
          fileSize: book.fileSize,
          createdAt: book.createdAt,
          updatedAt: book.updatedAt,
        ),
      );
    }
    for (final entry in progress.entries) {
      await database.progressDao.saveProgress(
        ReadingProgressCompanion.insert(
          bookId: entry.key,
          locator: entry.value.locator.toJsonText(),
          progress: Value(entry.value.progress),
          pageNumber: Value(entry.value.locator.page),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    return harness;
  }

  /// Wires the harness into the widget tree and opens [bookId]'s reader.
  Future<void> pumpReader(
    WidgetTester tester,
    String bookId, {
    ReadingLocator? initialLocator,
    Size? size,
    ReaderSettings? settings,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
    }
    // Settings live in the same in-memory database the reader already reads,
    // so seeding them here exercises the production settings stream rather
    // than a test-only override.
    if (settings != null) {
      await database.settingsDao.setValue(
        'reader.settings',
        settings.toJsonText(),
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: ReaderPage(bookId: bookId, initialLocator: initialLocator),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Unmounts the reader, the way leaving the route does.
  ///
  /// Integration tests share one process, so a reader left mounted keeps its
  /// location timer and save debounce alive into the next test. `dispose`
  /// also flushes pending progress, which is what "exit the reader" means for
  /// persistence.
  Future<void> closeReader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Writes what the real window is showing to `build/integration-captures/`.
  ///
  /// The live test binding paints "Test starting..." over the window between
  /// tests, so a screenshot taken by hand or by the desktop rarely catches the
  /// reader mid-test. This grabs the frame the assertions just ran against,
  /// which is what makes a passing integration test reviewable after the fact
  /// rather than only reported as a check mark.
  Future<File?> capture(String name) async {
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return null;
    final dir = Directory('build/integration-captures')
      ..createSync(recursive: true);
    return File('${dir.path}/$name.png')
      ..writeAsBytesSync(bytes.buffer.asUint8List());
  }

  /// Pumps for real time so the renderer's location timer (120 ms) and the
  /// session save debounce (700 ms) actually fire.
  Future<void> settle(WidgetTester tester, {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> dispose() => database.close();
}

/// Resolves a sample PDF relative to the repository root.
///
/// Integration tests run from the project root, but the live binding may
/// report a different current directory on some launchers, so resolve against
/// this file's location first.
File samplePdf(String name) {
  final candidates = [
    File('poc_pdf_canvas/samples/$name'),
    File('${Directory.current.path}/poc_pdf_canvas/samples/$name'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file.absolute;
  }
  throw StateError(
    'Missing sample $name. Run `dart run tool/generate_manual_samples.dart` '
    'or restore poc_pdf_canvas/samples.',
  );
}

Book sampleBook({required String id, required String sample, String? title}) {
  final file = samplePdf(sample);
  final stat = file.statSync();
  return Book(
    id: id,
    title: title ?? sample,
    format: BookFormat.pdf,
    libraryFilePath: file.path,
    fileHash: 'hash-$id',
    fileSize: stat.size,
    createdAt: stat.modified.millisecondsSinceEpoch,
    updatedAt: stat.modified.millisecondsSinceEpoch,
  );
}
