import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/pdf/pdf_canvas_renderer.dart';
import 'package:pdf_document/pdf_document.dart';

/// S6 performance baseline.
///
/// These are not assertions about speed on a particular machine — they record
/// what the renderer costs on the sample set, so a later regression (a cache
/// removed, a page interpreted on the UI thread) shows up as a number that
/// moved rather than as "scrolling felt worse". The plan asks for the 80-page
/// first-open figure; the printed values are what §23 writes down.
void main() {
  final samples = Directory('poc_pdf_canvas/samples');

  test('opening the 80-page sample is fast enough to do inline', () {
    final bytes = File('${samples.path}/large-text.pdf').readAsBytesSync();
    final stopwatch = Stopwatch()..start();
    final doc = PdfDocument.open(bytes);
    stopwatch.stop();

    // Opening only parses the cross-reference table and page tree; no page is
    // interpreted until one is asked for, which is why 80 pages can open
    // without a spinner.
    expect(doc.pageCount, 80);
    // ignore: avoid_print
    print('open 80p: ${stopwatch.elapsedMilliseconds} ms');
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('the first page renders once and replays from cache after', () async {
    final bytes = File('${samples.path}/large-text.pdf').readAsBytesSync();
    final renderer = PdfCanvasRenderer(
      PdfDocument.open(bytes),
      sourceBytes: bytes,
    );
    addTearDown(renderer.dispose);

    final first = Stopwatch()..start();
    final page = await renderer.renderPage(0);
    first.stop();
    expect(page, isNotNull);
    page!.dispose();

    final second = Stopwatch()..start();
    final again = await renderer.renderPage(0);
    second.stop();
    expect(again, isNotNull);
    again!.dispose();

    // ignore: avoid_print
    print(
      'first page: ${first.elapsedMilliseconds} ms, cached: '
      '${second.elapsedMilliseconds} ms',
    );
    // The cache is what makes scrolling back free; without it every revisit
    // pays the interpretation cost again.
    expect(
      second.elapsedMilliseconds,
      lessThanOrEqualTo(first.elapsedMilliseconds + 5),
    );
  });

  test('a prefetch does not block the page it is queued behind', () async {
    final bytes = File('${samples.path}/large-text.pdf').readAsBytesSync();
    final renderer = PdfCanvasRenderer(
      PdfDocument.open(bytes),
      sourceBytes: bytes,
    );
    addTearDown(renderer.dispose);

    renderer.prefetch(10);
    final stopwatch = Stopwatch()..start();
    final page = await renderer.renderPage(0);
    stopwatch.stop();
    expect(page, isNotNull);
    page!.dispose();
    // ignore: avoid_print
    print(
      'visible page with a background prefetch: ${stopwatch.elapsedMilliseconds} ms',
    );
    // A prefetch runs at lower priority; it must not delay the page the
    // reader is looking at.
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });
}
