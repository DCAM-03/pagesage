import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/native_pdf_page_rasterizer.dart';

void main() {
  final sample = File('poc_pdf_canvas/samples/standard-text.pdf');

  test(
    'reuses a PDF session and remains usable after page-range errors',
    () async {
      final rasterizer = NativePdfPageRasterizer();
      addTearDown(rasterizer.dispose);

      final first = await rasterizer.renderPage(
        filePath: sample.path,
        pageNumber: 1,
        maxEdge: 480,
        maxPixels: 120000,
      );
      await expectLater(
        rasterizer.renderPage(
          filePath: sample.path,
          pageNumber: 9999,
          maxEdge: 480,
          maxPixels: 120000,
        ),
        throwsRangeError,
      );
      final repeated = await rasterizer.renderPage(
        filePath: sample.path,
        pageNumber: 1,
        maxEdge: 480,
        maxPixels: 120000,
      );

      expect(repeated.bytes, isNotEmpty);
      expect(repeated.width, first.width);
      expect(repeated.height, first.height);
    },
  );
}
