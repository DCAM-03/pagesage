import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/features/reader/presentation/reader_desktop_toc_pane.dart';
import 'package:pagesage/features/reader/presentation/reader_epub_toc_sheet.dart';
import 'package:pagesage/features/reader/presentation/reader_pdf_toc_sheet.dart';
import 'package:pagesage/features/reader/presentation/reader_settings_sheet.dart';
import 'package:pagesage/renderers/common/book_document_loader.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/epub/epub_document.dart';
import 'package:pagesage/renderers/markdown/markdown_document_loader.dart';
import 'package:pagesage/renderers/markdown/markdown_folder.dart';

void main() {
  testWidgets('folder outline reloads after editing the same active file', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('pagesage_outline_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/note.md')
      ..writeAsStringSync('# Old heading\n\nOriginal body.');
    const loader = MarkdownFolderLoader();
    final location = ValueNotifier<RendererLocationChanged?>(null);
    addTearDown(location.dispose);
    final book = Book(
      id: 'folder-outline',
      title: 'Folder',
      format: BookFormat.markdown,
      libraryFilePath: directory.path,
      fileHash: 'fixture',
      fileSize: 1,
      createdAt: 1,
      updatedAt: 1,
    );

    Future<void> settle() => tester.runAsync(() async {
      for (var round = 0; round < 10; round++) {
        await tester.pump(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    Future<void> mount() async {
      final manifest = await tester.runAsync(
        () => loader.loadManifest(directory.path),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopTocPane(
              book: book,
              documentLoader: const MarkdownDocumentLoader(),
              folderManifest: manifest,
              activeFolderFile: 'note.md',
              onFolderFileSelected: (_) {},
              pdfOutline: const [],
              totalPages: null,
              currentLocator: null,
              locationListenable: location,
              onSelected: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await settle();
    }

    await mount();
    await tester.tap(find.text('大纲'));
    await settle();
    expect(find.text('Old heading'), findsOneWidget);
    file.writeAsStringSync('# Updated heading\n\nExternally saved body.');
    await mount();
    expect(find.text('Updated heading'), findsOneWidget);
    expect(find.text('Old heading'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings presets debounce saves and preserve other settings', (
    tester,
  ) async {
    const initial = ReaderSettings(
      appThemeMode: ThemeMode.dark,
      readerMode: ReaderMode.paged,
      pdfScale: 2,
      pdfZoomMode: PdfZoomMode.custom,
      desktopContextTab: ReaderContextTab.ai,
      desktopTocWidth: 340,
    );
    final repository = _RecordingSettingsRepository(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: ReaderSettingsSheet(initialSettings: initial)),
        ),
      ),
    );

    await tester.ensureVisible(find.text('长时间阅读'));
    await tester.tap(find.text('长时间阅读'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('高密度'));
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.saved, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));

    expect(repository.saved, hasLength(1));
    expect(
      repository.saved.single.toJsonText(),
      initial
          .copyWith(
            fontSize: 16,
            lineHeight: 1.45,
            paragraphSpacing: 8,
            pageMargin: 18,
            themePreset: ReaderThemePreset.day,
          )
          .toJsonText(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings recovery keeps app chrome and flushes its save', (
    tester,
  ) async {
    const initial = ReaderSettings(
      appThemeMode: ThemeMode.dark,
      fontSize: 26,
      themePreset: ReaderThemePreset.green,
      reduceMotion: true,
      desktopContextTab: ReaderContextTab.ai,
      desktopTocWidth: 340,
    );
    final repository = _RecordingSettingsRepository(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(body: ReaderSettingsSheet(initialSettings: initial)),
        ),
      ),
    );

    await tester.tap(find.text('恢复阅读默认'));
    await tester.pump();
    expect(repository.saved, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.saved, hasLength(1));
    expect(
      repository.saved.single.toJsonText(),
      const ReaderSettings(
        appThemeMode: ThemeMode.dark,
        reduceMotion: true,
        desktopContextTab: ReaderContextTab.ai,
        desktopTocWidth: 340,
      ).toJsonText(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.saved, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop outline expands, filters and retains exact destinations',
    (tester) async {
      final loader = _MemoryDocumentLoader();
      final location = ValueNotifier<RendererLocationChanged?>(null);
      addTearDown(location.dispose);
      final selected = <ReadingLocator>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopTocPane(
              book: _book,
              documentLoader: loader,
              folderManifest: null,
              activeFolderFile: null,
              onFolderFileSelected: (_) {},
              pdfOutline: const [],
              totalPages: null,
              currentLocator: ReadingLocator.epub(chapterIndex: 0),
              locationListenable: location,
              onSelected: selected.add,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
      await tester.tap(find.byTooltip('展开'));
      await tester.pump();
      expect(find.text('Details'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Details');
      await tester.pump(const Duration(milliseconds: 119));
      expect(find.text('Intro'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Intro'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Details'));

      expect(selected, hasLength(1));
      expect(selected.single.type, ReadingLocatorType.epub);
      expect(selected.single.href, 'second.xhtml#details');
      expect(selected.single.chapterIndex, 1);
      expect(selected.single.chapterOffset, 4);
      expect(selected.single.progress, 0.7);
      expect(loader.paths, [_book.libraryFilePath]);

      await tester.tap(find.byTooltip('清空'));
      await tester.pump();
      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'pending');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile outline expands the current chapter ancestry', (
    tester,
  ) async {
    final selected = <EpubTocItem>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubTocSheet(
            document: _document,
            currentChapterIndex: 1,
            onSelected: selected.add,
          ),
        ),
      ),
    );

    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Details'));
    expect(selected.single.href, 'second.xhtml#details');
    expect(selected.single.chapterOffset, 4);
    await tester.tap(find.byTooltip('折叠'));
    await tester.pump();
    expect(find.text('Details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile PDF outline returns the page and heading offset', (
    tester,
  ) async {
    ReadingLocator? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showModalBottomSheet<ReadingLocator>(
                  context: context,
                  builder: (_) => const PdfTocSheet(
                    outline: [
                      RendererOutlineItem(
                        title: 'PDF heading',
                        page: 3,
                        offsetFraction: 0.4,
                      ),
                    ],
                    totalPages: 5,
                    currentPage: 1,
                  ),
                );
              },
              child: const Text('Open outline'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open outline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF heading'));
    await tester.pumpAndSettle();

    expect(selected?.type, ReadingLocatorType.pdf);
    expect(selected?.page, 3);
    expect(selected?.progress, 0.5);
    expect(selected?.pageOffsetFraction, 0.4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF outline marks only the heading at the page top', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PdfTocSheet(
            outline: [
              RendererOutlineItem(title: '第 2 章', page: 28),
              RendererOutlineItem(
                title: '2.1 概览',
                page: 28,
                offsetFraction: 0.18,
              ),
              RendererOutlineItem(
                title: '2.1.1 集群',
                page: 28,
                offsetFraction: 0.42,
              ),
            ],
            totalPages: 100,
            currentPage: 28,
          ),
        ),
      ),
    );

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect(rows.map((row) => row.selected), [true, false, false]);
  });

  testWidgets('PDF outline keeps the last heading before the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PdfTocSheet(
            outline: [
              RendererOutlineItem(title: '第 2 章', page: 28),
              RendererOutlineItem(title: '2.2 节点', page: 31),
            ],
            totalPages: 100,
            currentPage: 30,
          ),
        ),
      ),
    );

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect(rows.map((row) => row.selected), [true, false]);
  });

  testWidgets('mobile PDF outline follows the within-page position', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PdfTocSheet(
            outline: [
              RendererOutlineItem(title: '第 2 章', page: 28),
              RendererOutlineItem(
                title: '2.1 概览',
                page: 28,
                offsetFraction: 0.18,
              ),
              RendererOutlineItem(
                title: '2.1.1 集群',
                page: 28,
                offsetFraction: 0.42,
              ),
            ],
            totalPages: 100,
            currentPage: 28,
            currentPageOffsetFraction: 0.2,
          ),
        ),
      ),
    );

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect(rows.map((row) => row.selected), [false, true, false]);
  });

  testWidgets('desktop PDF outline highlights one heading within the page', (
    tester,
  ) async {
    final location = ValueNotifier<RendererLocationChanged?>(
      RendererLocationChanged(
        locator: ReadingLocator.pdf(
          page: 28,
          progress: 0.27,
          pageOffsetFraction: 0.2,
        ),
        progress: 0.27,
        pageNumber: 28,
        totalPages: 100,
      ),
    );
    addTearDown(location.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopTocPane(
            book: _pdfBook,
            documentLoader: _MemoryDocumentLoader(),
            folderManifest: null,
            activeFolderFile: null,
            onFolderFileSelected: (_) {},
            pdfOutline: const [
              RendererOutlineItem(title: '第 2 章', page: 28),
              RendererOutlineItem(
                title: '2.1 概览',
                page: 28,
                offsetFraction: 0.18,
              ),
              RendererOutlineItem(
                title: '2.1.1 集群',
                page: 28,
                offsetFraction: 0.42,
              ),
            ],
            totalPages: 100,
            currentLocator: ReadingLocator.pdf(page: 28),
            locationListenable: location,
            onSelected: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect(rows.map((row) => row.selected), [false, true, false]);
  });
}

const _book = Book(
  id: 'panels-book',
  title: 'Panel fixture',
  format: BookFormat.epub,
  libraryFilePath: '/library/panels.epub',
  fileHash: 'panels-fixture',
  fileSize: 20,
  createdAt: 1,
  updatedAt: 1,
);

const _document = EpubDocument(
  chapters: [
    EpubChapter(
      index: 0,
      href: 'first.xhtml',
      title: 'Intro',
      text: 'abcdefghij',
    ),
    EpubChapter(
      index: 1,
      href: 'second.xhtml',
      title: 'Details',
      text: '0123456789',
    ),
  ],
  toc: [
    EpubTocItem(
      title: 'Intro',
      href: 'first.xhtml',
      chapterIndex: 0,
      children: [
        EpubTocItem(
          title: 'Details',
          href: 'second.xhtml#details',
          chapterIndex: 1,
          chapterOffset: 4,
        ),
      ],
    ),
  ],
);

const _pdfBook = Book(
  id: 'pdf-panels-book',
  title: 'PDF panel fixture',
  format: BookFormat.pdf,
  libraryFilePath: '/library/panels.pdf',
  fileHash: 'pdf-panels-fixture',
  fileSize: 20,
  createdAt: 1,
  updatedAt: 1,
);

final class _MemoryDocumentLoader implements BookDocumentLoader {
  final paths = <String>[];

  @override
  Future<EpubDocument> load(String filePath) async {
    paths.add(filePath);
    return _document;
  }
}

final class _RecordingSettingsRepository implements SettingsRepository {
  _RecordingSettingsRepository(this.settings);

  ReaderSettings settings;
  final saved = <ReaderSettings>[];

  @override
  Future<ReaderSettings> getReaderSettings() async => settings;

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {
    this.settings = settings;
    saved.add(settings);
  }

  @override
  Stream<ReaderSettings> watchReaderSettings() => Stream.value(settings);
}
