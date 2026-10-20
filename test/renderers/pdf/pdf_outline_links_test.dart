import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/pdf/pdf_links.dart';
import 'package:pagesage/renderers/pdf/pdf_outline.dart';

/// S4 turns two document features the canvas renderer never read into reader
/// controls: the `/Outlines` tree and `/Link` annotations. Both are pure
/// functions over a parsed document, so they are pinned here against the
/// hand-built `outline-link.pdf` sample rather than through a widget.
void main() {
  final sample = File('poc_pdf_canvas/samples/outline-link.pdf');

  PdfDocument open() => PdfDocument.open(sample.readAsBytesSync());

  group('outline', () {
    test('flattens the tree with levels and page numbers', () {
      final doc = open();
      final entries = pdfOutlineEntries(
        PdfOutline.of(doc),
        pageHeight: (page) => 792,
      );

      expect(entries.map((e) => e.title), [
        'Chapter One',
        'Chapter Two',
        'Section 2.1',
      ]);
      expect(entries.map((e) => e.page), [1, 2, 2]);
      // A child heading is one level in, which is what the TOC indent uses.
      expect(entries.map((e) => e.level), [0, 0, 1]);
    });

    test('keeps the destination position as a fraction from the top', () {
      final entries = pdfOutlineEntries(
        PdfOutline.of(open()),
        pageHeight: (page) => 792,
      );

      // /XYZ 72 730 names a y coordinate 730 points up from the page's bottom;
      // the reader scrolls down from the top, so it is near the top.
      expect(entries.first.offsetFraction, closeTo((792 - 730) / 792, 0.001));
      // Section 2.1 sits lower on its page than Chapter Two does.
      expect(
        entries[2].offsetFraction,
        greaterThan(entries[1].offsetFraction!),
      );
    });

    test('falls back to a page number for an untitled item', () {
      // A /Title is optional in the spec; an empty row would be unclickable
      // text, so the entry names where it goes instead.
      final entries = pdfOutlineEntries(
        const _FakeOutline([_FakeItem(pageIndex: 4, title: '   ')]),
        pageHeight: (page) => 792,
      );
      expect(entries.single.title, '第 5 页');
    });

    test('drops items without a resolvable destination', () {
      // An entry with no /Dest (or a broken action) cannot jump; the host
      // renders outline rows as jumps, so a dead row must not appear.
      final entries = pdfOutlineEntries(
        const _FakeOutline([_FakeItem(pageIndex: null, title: 'Broken')]),
        pageHeight: (page) => 792,
      );
      expect(entries, isEmpty);
    });

    test('a fit with no position leaves the fraction null', () {
      final entries = pdfOutlineEntries(
        const _FakeOutline([_FakeItem(pageIndex: 0, title: 'Fit')]),
        pageHeight: (page) => 792,
      );
      expect(entries.single.offsetFraction, isNull);
    });

    test('reports the outline as renderer items', () {
      final entries = pdfOutlineEntries(
        PdfOutline.of(open()),
        pageHeight: (page) => 792,
      );
      final items = [for (final e in entries) e.toRendererItem()];

      expect(items, hasLength(3));
      expect(items.first, isA<RendererOutlineItem>());
      expect(items.first.title, 'Chapter One');
      expect(items.last.level, 1);
    });
  });

  group('links', () {
    test('reads an in-document GoTo target', () {
      final links = PdfDocumentLink.of(open().page(0));

      expect(links, hasLength(1));
      final link = links.single;
      expect(link.isExternal, isFalse);
      expect(link.destinationPage, 3);
      expect(link.destinationTop, 730);
      // The rect is carried in page space so the page can project it with its
      // own rotation-aware geometry.
      expect(link.rect.left, 70);
      expect(link.rect.top, 750);
    });

    test('reads an external URI', () {
      final links = PdfDocumentLink.of(open().page(1));

      expect(links, hasLength(1));
      expect(links.single.isExternal, isTrue);
      expect(links.single.uri, 'https://example.com/pagesage');
      expect(links.single.destinationPage, isNull);
    });

    test('ignores a hidden link', () {
      // Page 2 carries a second /URI link with /F 2. A hidden annotation is
      // not clickable in any viewer, and offering it would put an invisible
      // button over the text.
      final links = PdfDocumentLink.of(open().page(1));
      expect(
        links.map((l) => l.uri),
        isNot(contains('https://example.com/hidden')),
      );
    });

    test('a page with no annotations reports no links', () {
      expect(PdfDocumentLink.of(open().page(2)), isEmpty);
    });

    test('refuses to hand out an unsafe scheme', () {
      // App-defined schemes can drive a host app; a document is untrusted
      // input, so only schemes a browser or mail client owns are surfaced.
      final page = open().page(1);
      expect(
        PdfDocumentLink.of(page).every(
          (l) => l.uri == null || Uri.parse(l.uri!).scheme.startsWith('http'),
        ),
        isTrue,
      );
    });
  });
}

/// Minimal stand-ins for the library's outline types.
///
/// `PdfOutlineItem` has a private constructor, so the edge cases (no
/// destination, blank title) are exercised through the shape the flattener
/// actually reads.
final class _FakeOutline implements PdfOutline {
  const _FakeOutline(this.items);

  @override
  final List<PdfOutlineItem> items;

  @override
  bool get isEmpty => items.isEmpty;
}

final class _FakeItem implements PdfOutlineItem {
  const _FakeItem({required this.pageIndex, required this.title});

  final int? pageIndex;

  @override
  final String title;

  @override
  PdfDestination? get destination => pageIndex == null
      ? null
      : PdfDestination(pageIndex: pageIndex!, fit: 'Fit', params: const []);

  @override
  bool get open => true;

  @override
  bool get bold => false;

  @override
  bool get italic => false;

  @override
  List<double>? get color => null;

  @override
  List<PdfOutlineItem> get children => const [];
}
