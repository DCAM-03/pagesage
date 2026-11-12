import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_book_repository.dart';
import 'package:pagesage/core/database/drift_search_repository.dart';
import 'package:pagesage/core/search/search_indexer.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ocr/application/ocr_page_store.dart';
import 'package:pagesage/features/ocr/application/stored_ocr_search_source.dart';

void main() {
  late AppDatabase database;
  late DriftBookRepository bookRepository;
  late DriftSearchRepository searchRepository;
  late DriftOcrPageStore pageStore;
  late Directory tempDirectory;
  late Book book;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    bookRepository = DriftBookRepository(
      bookDao: database.bookDao,
      progressDao: database.progressDao,
      searchDao: database.searchDao,
      ocrPageDao: database.ocrPageDao,
    );
    searchRepository = DriftSearchRepository(database.searchDao);
    pageStore = DriftOcrPageStore(database.ocrPageDao);
    tempDirectory = await Directory.systemTemp.createTemp(
      'pagesage_ocr_search_',
    );
    final pdf = File('${tempDirectory.path}/scan.pdf');
    final bytes = _buildEmptyPdf();
    await pdf.writeAsBytes(bytes);
    book = await bookRepository.createImportedBook(
      NewBookDraft(
        id: 'book-ocr-search',
        title: '扫描搜索书',
        format: BookFormat.pdf,
        originalFilePath: pdf.path,
        libraryFilePath: pdf.path,
        fileHash: 'hash-ocr-search',
        fileSize: bytes.length,
        createdAt: 1,
      ),
    );
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('signed OCR page is searchable with a page-only locator', () async {
    await pageStore.putPage(
      bookId: book.id,
      pageNumber: 3,
      result: const OcrPageResult(
        text: '可搜索的扫描识别文本',
        language: 'zh-Hans',
        engine: 'fake',
      ),
      sourceRevision: book.fileHash,
      cacheSignature: 'cache-signature',
      textRevision: 'text-revision',
      resultState: 'recognized',
    );
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      ocrSearchSource: StoredOcrSearchSource(pageStore),
    );

    await indexer.indexBook(book);

    final results = await searchRepository.search(
      const SearchQuery(query: '可搜索的扫描识别文本'),
    );
    final result = results.singleWhere(
      (item) => item.sourceId?.contains(':ocr:') == true,
    );
    expect(result.type, SearchResultType.content);
    expect(result.textOrigin, 'ocr');
    expect(result.precision, SearchMatchPrecision.pageOnly);
    expect(result.locator?.type, ReadingLocatorType.pdf);
    expect(result.locator?.page, 3);
  });

  test('OCR from another source revision is not indexed', () async {
    await pageStore.putPage(
      bookId: book.id,
      pageNumber: 1,
      result: const OcrPageResult(
        text: '旧版本识别文本',
        language: 'zh-Hans',
        engine: 'fake',
      ),
      sourceRevision: 'old-hash',
      cacheSignature: 'cache-signature',
      textRevision: 'text-revision',
      resultState: 'recognized',
    );
    final indexer = SearchIndexer(
      searchRepository: searchRepository,
      bookRepository: bookRepository,
      ocrSearchSource: StoredOcrSearchSource(pageStore),
    );

    await indexer.indexBook(book);

    final results = await searchRepository.search(
      const SearchQuery(query: '旧版本识别文本'),
    );
    expect(results, isEmpty);
    expect((await bookRepository.getBook(book.id))?.indexingStatus, 'no_text');
  });
}

Uint8List _buildEmptyPdf() {
  const operations = 'q Q';
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
  for (var index = 0; index < objects.length; index += 1) {
    offsets.add(buffer.length);
    buffer.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
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
