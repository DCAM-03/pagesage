import '../../../domain/ocr/ocr_models.dart';
import 'ocr_page_store.dart';

/// Exposes only durable, signed OCR pages to the search indexer.
final class StoredOcrSearchSource implements OcrSearchSource {
  const StoredOcrSearchSource(this._store);

  final OcrPageStore _store;

  @override
  Future<List<OcrIndexPage>> pagesForBook(
    String bookId, {
    String? sourceRevision,
  }) async {
    final pages = await _store.listPages(bookId);
    return [
      for (final page in pages)
        if (page.result.hasText &&
            page.result.resultState == 'recognized' &&
            page.result.cacheSignature != null &&
            (sourceRevision == null ||
                page.result.sourceRevision == sourceRevision))
          OcrIndexPage(
            pageNumber: page.pageNumber,
            text: page.result.text,
            cacheSignature: page.result.cacheSignature,
            textRevision: page.result.textRevision,
          ),
    ];
  }
}
