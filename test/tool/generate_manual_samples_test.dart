import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/search/pdf_text_extractor.dart';
import 'package:pagesage/renderers/epub/epub_document_loader.dart';

import '../../tool/generate_manual_samples.dart';

void main() {
  test('generates local EPUB and PDF manual validation samples', () async {
    final dir = await Directory.systemTemp.createTemp('pagesage_samples_');
    addTearDown(() => dir.delete(recursive: true));

    final samples = await generateManualSamples(outputPath: dir.path);

    expect(samples.map((sample) => sample.fileName), contains('standard.epub'));
    expect(
      samples.map((sample) => sample.fileName),
      contains('long-text.epub'),
    );
    expect(
      samples.map((sample) => sample.fileName),
      contains('standard-text.pdf'),
    );
    expect(
      samples.map((sample) => sample.fileName),
      contains('image-only.pdf'),
    );
    expect(samples.map((sample) => sample.fileName), contains('broken.pdf'));

    final epub = await const EpubDocumentLoader().load(
      File('${dir.path}/standard.epub').path,
    );
    expect(epub.chapters, hasLength(2));
    expect(epub.toc, isNotEmpty);
    expect(epub.chapters.first.text, contains('PageSage'));

    final longTextEpub = await const EpubDocumentLoader().load(
      File('${dir.path}/long-text.epub').path,
    );
    expect(longTextEpub.chapters.first.text, contains('LongUnbrokenToken'));

    final noTocEpub = await const EpubDocumentLoader().load(
      File('${dir.path}/no-toc.epub').path,
    );
    expect(noTocEpub.toc.map((item) => item.title), ['无目录第一章', '无目录第二章']);

    final pdf = File('${dir.path}/standard-text.pdf');
    expect(await pdf.readAsString(), startsWith('%PDF-1.4'));
    final pdfText = await const PdfTextExtractorService().extract(pdf.path);
    expect(pdfText.pages, hasLength(3));
    expect(pdfText.pages.first.text, contains('local-first'));

    final imageOnlyPdf = await const PdfTextExtractorService().extract(
      File('${dir.path}/image-only.pdf').path,
    );
    expect(imageOnlyPdf.hasText, isFalse);

    await expectLater(
      const PdfTextExtractorService().extract(
        File('${dir.path}/broken.pdf').path,
      ),
      throwsA(anything),
    );

    expect(File('${dir.path}/README.md').existsSync(), isTrue);
  });
}
