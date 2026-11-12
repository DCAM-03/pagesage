import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/linux_tesseract_ocr_engine.dart';
import 'package:pagesage/core/ocr/native_pdf_page_rasterizer.dart';

void main() {
  final pdfPath = Platform.environment['PAGESAGE_OCR_PIPELINE_PDF'];
  final enabled = Platform.isLinux && pdfPath != null;

  test(
    'measures the production Linux PDF rasterizer and OCR engine',
    () async {
      final pdf = File(pdfPath!);
      final pages =
          (Platform.environment['PAGESAGE_OCR_PIPELINE_PAGES'] ??
                  '20,23,33,42,49')
              .split(',')
              .map(int.parse)
              .toList(growable: false);
      final rasterizer = NativePdfPageRasterizer();
      addTearDown(rasterizer.dispose);
      final engine = LinuxTesseractOcrEngine();
      expect(await engine.isAvailable(), isTrue);
      final before = await _currentRssMiB();
      var peak = before;
      var sampling = true;
      final sampler = () async {
        while (sampling) {
          final current = await _currentRssMiB();
          if (current > peak) peak = current;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }();
      final rows = <Map<String, Object?>>[];
      try {
        for (final page in pages) {
          final rasterWatch = Stopwatch()..start();
          final image = await rasterizer.renderPage(
            filePath: pdf.path,
            pageNumber: page,
          );
          rasterWatch.stop();
          final ocrWatch = Stopwatch()..start();
          final result = await engine.recognize(
            imageBytes: image.bytes,
            languageHint: 'zh-Hans',
          );
          ocrWatch.stop();
          rows.add({
            'page': page,
            'displayWidthPoints': image.width,
            'displayHeightPoints': image.height,
            'imageBytes': image.bytes.length,
            'rasterizeMs': rasterWatch.elapsedMilliseconds,
            'ocrMs': ocrWatch.elapsedMilliseconds,
            'textCharacters': result.text.runes.length,
            'ocrBlocks': result.blocks.length,
            'hasGeometry': result.hasGeometry,
          });
        }
      } finally {
        sampling = false;
        await sampler;
      }
      final after = await _currentRssMiB();
      // ignore: avoid_print
      print(
        'PAGESAGE_OCR_PIPELINE_METRICS=${jsonEncode({'pdfBytes': await pdf.length(), 'pages': rows, 'processRssBeforeMiB': before, 'processRssPeakMiB': peak, 'processRssAfterMiB': after, 'processRssPeakDeltaMiB': peak - before})}',
      );
      expect(rows, hasLength(pages.length));
      expect(rows.every((row) => row['textCharacters'] as int > 0), isTrue);
      expect(rows.every((row) => row['hasGeometry'] == true), isTrue);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<double> _currentRssMiB() async {
  final status = await File('/proc/self/status').readAsLines();
  final line = status.firstWhere((value) => value.startsWith('VmRSS:'));
  final kibibytes = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
  return kibibytes / 1024;
}
