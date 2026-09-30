import 'dart:io';
import 'dart:isolate';

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

final class PdfTextPage {
  const PdfTextPage({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

final class PdfTextDocument {
  const PdfTextDocument({required this.pages});

  final List<PdfTextPage> pages;

  bool get hasText => pages.any((page) => page.text.trim().isNotEmpty);
}

/// Extracts PDF text **off the UI isolate**.
///
/// `PdfDocument.open` + per-page reflow is CPU-heavy and previously ran on the
/// main isolate after `readAsBytes`, freezing mobile during import indexing.
final class PdfTextExtractorService {
  const PdfTextExtractorService();

  Future<PdfTextDocument> extract(String filePath) async {
    final rawPages = await Isolate.run(() => extractPdfTextPages(filePath));
    final pages = rawPages
        .map(
          (page) => PdfTextPage(pageNumber: page.pageNumber, text: page.text),
        )
        .toList(growable: false);
    return PdfTextDocument(pages: pages);
  }
}

/// Top-level / isolate-safe PDF text extraction.
///
/// Returns plain maps so the isolate message is sendable without custom types.
List<({int pageNumber, String text})> extractPdfTextPages(String filePath) {
  final bytes = File(filePath).readAsBytesSync();
  final document = PdfDocument.open(bytes);
  final pages = <({int pageNumber, String text})>[];

  for (var i = 0; i < document.pageCount; i += 1) {
    final page = PdfTextExtractor.reflowPage(document, i);
    final text = page.text.trim();
    if (text.isEmpty) {
      continue;
    }
    pages.add((pageNumber: i + 1, text: text));
  }
  return pages;
}
