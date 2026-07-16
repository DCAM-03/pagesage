import 'dart:io';

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

final class PdfTextExtractorService {
  const PdfTextExtractorService();

  Future<PdfTextDocument> extract(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument.open(bytes);
    final pages = <PdfTextPage>[];

    for (var i = 0; i < document.pageCount; i += 1) {
      final page = PdfTextExtractor.reflowPage(document, i);
      final text = page.text.trim();
      if (text.isEmpty) {
        continue;
      }
      pages.add(PdfTextPage(pageNumber: i + 1, text: text));
    }

    return PdfTextDocument(pages: List.unmodifiable(pages));
  }
}
