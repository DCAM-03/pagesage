import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/search/search_indexer.dart';
import 'package:pagesage/core/tasks/task_cancellation.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/book_repository.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/domain/search/search_models.dart';

void main() {
  test('indexes PDF text chunks with page locators', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_pdf_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sample.pdf');
    await file.writeAsBytes(_buildTextPdf(['Hello PageSage PDF']));

    final searchRepository = _FakeSearchRepository();
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = _book(file.path, BookFormat.pdf);

    await indexer.indexBook(book);

    expect(bookRepository.statuses, ['running', 'done']);
    expect(searchRepository.deletedBookIds, [book.id]);
    expect(
      searchRepository.entries.any(
        (entry) =>
            entry.sourceId == '${book.id}:pdf:1:0' &&
            entry.text == 'Hello PageSage PDF' &&
            entry.locator?.type == ReadingLocatorType.pdf &&
            entry.locator?.page == 1 &&
            entry.locator?.excerpt == 'Hello PageSage PDF',
      ),
      isTrue,
    );
  });

  test('indexes EPUB text chunks with chapter offsets and excerpts', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_epub_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sample.epub');
    await file.writeAsBytes(
      await _buildMinimalEpub(
        chapterText:
            'Alpha paragraph one.\n\nBeta paragraph two that is later in the chapter.',
      ),
    );

    final searchRepository = _FakeSearchRepository();
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = _book(file.path, BookFormat.epub);

    await indexer.indexBook(book);

    final contentEntries = searchRepository.entries
        .where((entry) => entry.sourceId.startsWith('${book.id}:epub:'))
        .toList(growable: false);
    expect(contentEntries, isNotEmpty);
    final first = contentEntries.first;
    expect(first.locator?.type, ReadingLocatorType.epub);
    expect(first.locator?.chapterIndex, isNotNull);
    expect(first.locator?.chapterOffset, isNotNull);
    expect(first.locator?.excerpt, isNotNull);
    expect(first.locator!.excerpt!, isNotEmpty);
    expect(first.text, contains('Alpha'));
  });

  test('marks scan PDF without body text as no_text', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_pdf_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/image-only.pdf');
    await file.writeAsBytes(_buildEmptyTextPdf());

    final searchRepository = _FakeSearchRepository();
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = _book(file.path, BookFormat.pdf);

    await indexer.indexBook(book);

    expect(bookRepository.statuses, ['running', 'no_text']);
    expect(
      searchRepository.entries.any(
        (entry) => entry.sourceId == book.id && entry.title == book.title,
      ),
      isTrue,
    );
    expect(
      searchRepository.entries.any(
        (entry) => entry.sourceId.startsWith('${book.id}:pdf:'),
      ),
      isFalse,
    );
  });

  test(
    'indexes signed OCR cache for pages without a native text layer',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'pagesage_pdf_ocr_index_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/image-only.pdf');
      await file.writeAsBytes(_buildEmptyTextPdf());

      final searchRepository = _FakeSearchRepository();
      final bookRepository = _FakeBookRepository();
      final indexer = SearchIndexer(
        searchRepository: searchRepository,
        bookRepository: bookRepository,
        ocrSearchSource: _FakeOcrSearchSource([
          const OcrIndexPage(
            pageNumber: 2,
            text: '扫描页识别出来的中文正文',
            textRevision: 'text-revision',
          ),
        ]),
      );
      final book = _book(file.path, BookFormat.pdf);

      await indexer.indexBook(book);

      expect(bookRepository.statuses, ['running', 'done']);
      final ocr = searchRepository.entries.singleWhere(
        (entry) => entry.sourceId == '${book.id}:pdf:2:ocr:0',
      );
      expect(ocr.textOrigin, 'ocr');
      expect(ocr.text, '扫描页识别出来的中文正文');
      expect(ocr.title, contains('识别文本'));
      expect(ocr.locator?.type, ReadingLocatorType.pdf);
      expect(ocr.locator?.page, 2);
      expect(ocr.textRevision, 'text-revision');
    },
  );

  test('native text wins over OCR on the same PDF page', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_pdf_native_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/text.pdf');
    await file.writeAsBytes(_buildTextPdf(['Native body']));

    final searchRepository = _FakeSearchRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: _FakeBookRepository(),
      ocrSearchSource: _FakeOcrSearchSource([
        const OcrIndexPage(pageNumber: 1, text: 'OCR duplicate'),
      ]),
    );
    final book = _book(file.path, BookFormat.pdf);

    await indexer.indexBook(book);

    expect(
      searchRepository.entries.any((entry) => entry.sourceId.contains(':ocr:')),
      isFalse,
    );
    expect(
      searchRepository.entries.any((entry) => entry.text == 'Native body'),
      isTrue,
    );
  });

  test('cancels PDF indexing and removes partial search entries', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_pdf_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sample.pdf');
    await file.writeAsBytes(_buildTextPdf(['Hello PageSage PDF']));

    final token = TaskCancelToken();
    final searchRepository = _FakeSearchRepository(onIndexText: token.cancel);
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = _book(file.path, BookFormat.pdf);

    await expectLater(
      indexer.indexBook(book, cancelToken: token),
      throwsA(isA<TaskCancelledException>()),
    );

    expect(bookRepository.statuses, ['running', 'pending']);
    expect(searchRepository.deletedBookIds, [book.id, book.id]);
  });

  test('reports progress while indexing PDF', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_pdf_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sample.pdf');
    await file.writeAsBytes(_buildTextPdf(['Hello PageSage PDF']));

    final searchRepository = _FakeSearchRepository();
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = _book(file.path, BookFormat.pdf);
    final reports = <double>[];

    await indexer.indexBook(
      book,
      onProgress: (progress, {message}) {
        reports.add(progress);
      },
    );

    expect(reports, isNotEmpty);
    expect(reports.first, lessThanOrEqualTo(0.2));
    expect(reports.last, greaterThanOrEqualTo(0.9));
    for (var i = 1; i < reports.length; i += 1) {
      expect(reports[i], greaterThanOrEqualTo(reports[i - 1] - 0.001));
    }
  });

  test(
    'publishes a new generation without deleting the old index first',
    () async {
      final dir = await Directory.systemTemp.createTemp('pagesage_md_index_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/note.md');
      await file.writeAsString('# 笔记\n\n新版正文内容。');

      final searchRepository = _GenerationSearchRepository();
      final bookRepository = _FakeBookRepository();
      final indexer = SearchIndexer(
        searchRepository: searchRepository,
        bookRepository: bookRepository,
      );
      final book = _book(file.path, BookFormat.markdown);

      await indexer.indexBook(book);

      expect(searchRepository.deletedBookIds, isEmpty);
      expect(searchRepository.beginCalls, 1);
      expect(searchRepository.publishCalls, 1);
      expect(searchRepository.discardCalls, 0);
      expect(
        searchRepository.entries.any(
          (entry) => entry.text?.contains('新版正文内容') == true,
        ),
        isTrue,
      );
    },
  );

  test('a cancelled generation is discarded and the old index stays', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_md_index_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/note.md');
    await file.writeAsString('# 笔记\n\n会被取消的正文。');

    final token = TaskCancelToken();
    final searchRepository = _GenerationSearchRepository(onWrite: token.cancel);
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = _book(file.path, BookFormat.markdown);

    await expectLater(
      indexer.indexBook(book, cancelToken: token),
      throwsA(isA<TaskCancelledException>()),
    );

    expect(searchRepository.deletedBookIds, isEmpty);
    expect(searchRepository.publishCalls, 0);
    expect(searchRepository.discardCalls, 1);
    expect(bookRepository.statuses, ['running', 'pending']);
  });

  test('indexes a Markdown folder per file', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_md_index_');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/a.md').writeAsString('# 甲\n\n共同关键词在甲。');
    final sub = Directory('${dir.path}/sub')..createSync();
    await File('${sub.path}/b.md').writeAsString('# 乙\n\n共同关键词在乙。');

    final searchRepository = _FakeSearchRepository();
    final bookRepository = _FakeBookRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
    );
    final book = Book(
      id: 'book-1',
      title: '笔记库',
      format: BookFormat.markdown,
      libraryFilePath: dir.path,
      fileHash: 'hash',
      fileSize: 1,
      createdAt: 1,
      updatedAt: 1,
    );

    await indexer.indexBook(book);

    final content = searchRepository.entries
        .where((entry) => entry.sourceId.startsWith('${book.id}:md:'))
        .toList(growable: false);
    expect(content, hasLength(2));
    final second = content.singleWhere(
      (entry) => entry.locator?.href == 'sub/b.md',
    );
    expect(second.locator?.type, ReadingLocatorType.markdown);
    expect(second.locator?.folderFileLocal, isTrue);
    expect(second.locator?.chapterIndex, 0);
    expect(second.locator?.progress, greaterThan(0));
    expect(second.text, contains('共同关键词在乙'));
  });

  test('indexes Markdown headings as parent boundaries', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_md_parent_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/structured.md');
    await file.writeAsString('''
# 书

总述。

## 条件

条件正文。

## 结论

结论正文。
''');

    final searchRepository = _FakeSearchRepository();
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: _FakeBookRepository(),
    );
    final book = _book(file.path, BookFormat.markdown);

    await indexer.indexBook(book);

    final content = searchRepository.entries
        .where((entry) => entry.sourceId.startsWith('${book.id}:md:'))
        .toList(growable: false);
    expect(content, isNotEmpty);
    expect(content.every((entry) => entry.parentId != null), isTrue);
    final parents = <String, _IndexedEntry>{};
    for (final entry in content) {
      parents.putIfAbsent(entry.parentId!, () => entry);
    }
    expect(parents.values.map((entry) => entry.parentTitle), [
      '书',
      '书 › 条件',
      '书 › 结论',
    ]);
    expect(
      parents.values.map((entry) => entry.parentText).join(),
      allOf(contains('总述'), contains('条件正文'), contains('结论正文')),
    );
  });
}

Book _book(String path, BookFormat format) {
  return Book(
    id: 'book-1',
    title: 'Sample',
    format: format,
    libraryFilePath: path,
    fileHash: 'hash',
    fileSize: File(path).lengthSync(),
    createdAt: 1,
    updatedAt: 1,
  );
}

Future<List<int>> _buildMinimalEpub({required String chapterText}) async {
  final paragraphs = chapterText
      .split(RegExp(r'\n\s*\n+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map((part) => '<p>$part</p>')
      .join();
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('META-INF/container.xml', '''
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        '''),
    )
    ..addFile(
      ArchiveFile.string('OEBPS/content.opf', '''
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <manifest>
            <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="chapter1"/>
          </spine>
        </package>
        '''),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/chapter1.xhtml',
        '<html><head><title>One</title></head><body><h1>Chapter One</h1>$paragraphs</body></html>',
      ),
    );
  return ZipEncoder().encode(archive);
}

Uint8List _buildTextPdf(List<String> texts) {
  final operations = texts
      .map((text) => 'BT /F1 12 Tf 72 720 Td (${_escapePdfText(text)}) Tj ET')
      .join('\n');
  return _buildPdfWithContentStream(operations);
}

/// One blank page with no text operators — extractor reports hasText=false.
Uint8List _buildEmptyTextPdf() {
  const operations = 'q Q';
  return _buildPdfWithContentStream(operations);
}

Uint8List _buildPdfWithContentStream(String operations) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R '
        '/Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${operations.length} >>\nstream\n$operations\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i += 1) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xrefOffset = buffer.length;
  buffer
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

String _escapePdfText(String text) {
  return text
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

final class _IndexedEntry {
  const _IndexedEntry({
    required this.sourceType,
    required this.sourceId,
    this.bookId,
    this.title,
    this.text,
    this.locator,
    this.sortOrder = 0,
    this.parentId,
    this.parentTitle,
    this.parentText,
    this.parentLocator,
    this.parentSortOrder = 0,
    this.textOrigin = 'native',
    this.textRevision,
  });

  final String sourceType;
  final String sourceId;
  final String? bookId;
  final String? title;
  final String? text;
  final ReadingLocator? locator;
  final int sortOrder;
  final String? parentId;
  final String? parentTitle;
  final String? parentText;
  final ReadingLocator? parentLocator;
  final int parentSortOrder;
  final String textOrigin;
  final String? textRevision;
}

final class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.onIndexText});

  final entries = <_IndexedEntry>[];
  final deletedBookIds = <String>[];
  final void Function()? onIndexText;

  @override
  Future<void> deleteByBook(String bookId) async {
    deletedBookIds.add(bookId);
  }

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) async {}

  @override
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async => const [];

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) async {
    entries.add(
      _IndexedEntry(
        sourceType: 'book',
        sourceId: bookId,
        bookId: bookId,
        title: title,
        text: [title, author, description].whereType<String>().join('\n'),
      ),
    );
  }

  @override
  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  }) async {
    onIndexText?.call();
    entries.add(
      _IndexedEntry(
        sourceType: sourceType,
        sourceId: sourceId,
        bookId: bookId,
        title: title,
        text: text,
        locator: locator,
        sortOrder: sortOrder,
      ),
    );
  }

  @override
  Future<void> indexTexts(List<SearchIndexEntry> entries) async {
    for (final entry in entries) {
      onIndexText?.call();
      this.entries.add(
        _IndexedEntry(
          sourceType: entry.sourceType,
          sourceId: entry.sourceId,
          bookId: entry.bookId,
          title: entry.title,
          text: entry.text,
          locator: entry.locator,
          sortOrder: entry.sortOrder,
          parentId: entry.parentId,
          parentTitle: entry.parentTitle,
          parentText: entry.parentText,
          parentLocator: entry.parentLocator,
          parentSortOrder: entry.parentSortOrder,
          textOrigin: entry.textOrigin,
          textRevision: entry.textRevision,
        ),
      );
    }
  }

  @override
  Future<List<SearchResult>> search(SearchQuery query) async => const [];
}

final class _FakeOcrSearchSource implements OcrSearchSource {
  const _FakeOcrSearchSource(this.pages);

  final List<OcrIndexPage> pages;

  @override
  Future<List<OcrIndexPage>> pagesForBook(
    String bookId, {
    String? sourceRevision,
  }) async => pages;
}

final class _GenerationSearchRepository
    implements SearchRepository, SearchGenerationRepository {
  _GenerationSearchRepository({this.onWrite});

  final void Function()? onWrite;
  final entries = <_IndexedEntry>[];
  final deletedBookIds = <String>[];
  var beginCalls = 0;
  var publishCalls = 0;
  var discardCalls = 0;
  String? _generationId;

  @override
  Future<SearchIndexGeneration> beginBookGeneration(String bookId) async {
    beginCalls += 1;
    _generationId = 'gen-$beginCalls';
    return SearchIndexGeneration(
      id: _generationId!,
      bookId: bookId,
      unitId: 'unit-$bookId',
    );
  }

  @override
  Future<void> indexGenerationTexts(
    String generationId,
    List<SearchIndexEntry> entries,
  ) async {
    expect(generationId, _generationId);
    for (final entry in entries) {
      onWrite?.call();
      this.entries.add(
        _IndexedEntry(
          sourceType: entry.sourceType,
          sourceId: entry.sourceId,
          bookId: entry.bookId,
          title: entry.title,
          text: entry.text,
          locator: entry.locator,
          sortOrder: entry.sortOrder,
          parentId: entry.parentId,
          parentTitle: entry.parentTitle,
          parentText: entry.parentText,
          parentLocator: entry.parentLocator,
          parentSortOrder: entry.parentSortOrder,
        ),
      );
    }
  }

  @override
  Future<void> publishBookGeneration(String generationId) async {
    publishCalls += 1;
  }

  @override
  Future<void> discardBookGeneration(String generationId) async {
    discardCalls += 1;
  }

  @override
  Future<void> deleteByBook(String bookId) async {
    deletedBookIds.add(bookId);
  }

  @override
  Future<void> deleteBySource(String sourceType, String? sourceId) async {}

  @override
  Future<List<SearchBookChunks>> bookChunks({
    Iterable<String> bookIds = const [],
    String? categoryId,
  }) async => const [];

  @override
  Future<void> indexBookMetadata({
    required String bookId,
    required String title,
    String? author,
    String? description,
  }) async {
    throw StateError('generation indexing must not use the legacy path');
  }

  @override
  Future<void> indexText({
    required String sourceType,
    required String sourceId,
    String? bookId,
    String? title,
    String? text,
    ReadingLocator? locator,
    int sortOrder = 0,
  }) async {
    throw StateError('generation indexing must not use the legacy path');
  }

  @override
  Future<void> indexTexts(List<SearchIndexEntry> entries) async {
    throw StateError('generation indexing must not use the legacy path');
  }

  @override
  Future<List<SearchResult>> search(SearchQuery query) async => const [];
}

final class _FakeBookRepository implements BookRepository {
  final statuses = <String>[];

  @override
  Future<Book> createImportedBook(NewBookDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<Book?> findByHash(String fileHash) async => null;

  @override
  Future<Book?> getBook(String id) async => null;

  @override
  Future<List<LibraryBook>> getLibrary() async => const [];

  @override
  Future<ReadingProgressSnapshot?> getProgress(String bookId) async => null;

  @override
  Future<void> markOpened(String bookId) async {}

  @override
  Future<void> saveProgress({
    required String bookId,
    required ReadingLocator locator,
    required double progress,
    String? chapterTitle,
    int? pageNumber,
  }) async {}

  @override
  Future<void> toggleFavorite(String bookId, bool isFavorite) async {}

  @override
  Future<void> updateCategory(String bookId, String? categoryId) async {}

  @override
  Future<void> updateIndexingStatus(
    String bookId,
    String indexingStatus,
  ) async {
    statuses.add(indexingStatus);
  }

  @override
  Future<void> updateMetadata({
    required String bookId,
    String? title,
    String? author,
    String? description,
    String? coverPath,
  }) async {}

  @override
  Future<void> updateReadStatus(String bookId, ReadStatus readStatus) async {}

  @override
  Stream<List<LibraryBook>> watchLibrary() => Stream.value(const []);
}
