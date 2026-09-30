import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:pagesage/renderers/common/renderer_event.dart';
import 'package:pagesage/renderers/common/web_renderer_helpers.dart';

void main() {
  test('parses text selection events from web renderers', () {
    final event = parseRendererEvent({
      'type': 'textSelected',
      'payload': {
        'text': '选中的 PDF 文本',
        'locator': {
          'type': 'pdf',
          'page': 4,
          'scrollOffset': 20,
          'zoom': 1.5,
          'progress': 0.3,
          'excerpt': '选中的 PDF 文本',
          'selectionRects': [
            {'page': 4, 'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.04},
          ],
        },
        'sourceRect': {'x': 120, 'y': 80, 'width': 220, 'height': 28},
        'selectionRects': [
          {'page': 4, 'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.04},
        ],
      },
    });

    expect(event, isA<RendererTextSelected>());
    final selected = event as RendererTextSelected;
    expect(selected.text, '选中的 PDF 文本');
    expect(selected.locator.type, ReadingLocatorType.pdf);
    expect(selected.locator.page, 4);
    expect(selected.locator.excerpt, '选中的 PDF 文本');
    expect(selected.sourceRect?.x, 120);
    expect(selected.selectionRects.single.page, 4);
    expect(selected.locator.selectionRects.single.width, 0.3);
  });

  test('parses PDF location events with total page count', () {
    final event = parseRendererEvent({
      'type': 'locationChanged',
      'payload': {
        'locator': {
          'type': 'pdf',
          'page': 4,
          'scrollOffset': 24,
          'zoom': 1.25,
          'progress': 0.5,
        },
        'progress': 0.5,
        'pageNumber': 4,
        'totalPages': 8,
      },
    });

    expect(event, isA<RendererLocationChanged>());
    final location = event as RendererLocationChanged;
    expect(location.pageNumber, 4);
    expect(location.totalPages, 8);
    expect(location.locator.zoom, 1.25);
  });

  test('parses search result events from web renderers', () {
    final event = parseRendererEvent({
      'type': 'searchResults',
      'payload': {
        'results': [
          {
            'title': '第一章',
            'snippet': '匹配片段',
            'locator': {
              'type': 'epub',
              'href': 'chapter-1.xhtml',
              'chapterIndex': 0,
              'progress': 0.1,
            },
          },
        ],
      },
    });

    expect(event, isA<RendererSearchResults>());
    final results = event as RendererSearchResults;
    expect(results.results, hasLength(1));
    expect(results.results.single.title, '第一章');
    expect(results.results.single.locator.type, ReadingLocatorType.epub);
  });

  test('parses bookmark request events from web renderers', () {
    final event = parseRendererEvent({
      'type': 'bookmarkRequested',
      'payload': {
        'locator': {'type': 'pdf', 'page': 8, 'progress': 0.8},
      },
    });

    expect(event, isA<RendererBookmarkRequested>());
    final bookmark = event as RendererBookmarkRequested;
    expect(bookmark.locator.page, 8);
  });

  test('parses annotation selected events from web renderers', () {
    final event = parseRendererEvent({
      'type': 'annotationSelected',
      'payload': {'annotationId': 'annotation-1'},
    });

    expect(event, isA<RendererAnnotationSelected>());
    expect((event as RendererAnnotationSelected).annotationId, 'annotation-1');
  });

  test('parses PDF outline events from web renderers', () {
    final event = parseRendererEvent({
      'type': 'outlineChanged',
      'payload': {
        'items': [
          {'title': 'Chapter 1', 'page': 2, 'level': 0},
          {'title': 'Section 1.1', 'page': 4, 'level': 1},
        ],
      },
    });

    expect(event, isA<RendererOutlineChanged>());
    final outline = event as RendererOutlineChanged;
    expect(outline.items, hasLength(2));
    expect(outline.items.first.title, 'Chapter 1');
    expect(outline.items.first.page, 2);
    expect(outline.items.last.level, 1);
  });

  test('parses renderer capability events', () {
    final event = parseRendererEvent({
      'type': 'capabilityChanged',
      'payload': {
        'textSelection': false,
        'search': false,
        'reason': '此 PDF 没有文本层，划词、高亮与搜索不可用。可使用「识别本页」提取文字。',
      },
    });

    expect(event, isA<RendererCapabilityChanged>());
    final capability = event as RendererCapabilityChanged;
    expect(capability.textSelection, isFalse);
    expect(capability.search, isFalse);
    expect(capability.reason, '此 PDF 没有文本层，划词、高亮与搜索不可用。可使用「识别本页」提取文字。');
  });

  test('builds renderer command scripts', () {
    expect(
      rendererOpenUrlScript(
        fileUrl: 'http://127.0.0.1/book.pdf',
        settings: const ReaderSettings(),
        locator: ReadingLocator.pdf(page: 3),
      ),
      contains('PageSageRenderer.open'),
    );
    expect(
      rendererGoToScript(ReadingLocator.pdf(page: 4)),
      contains('PageSageRenderer.goTo'),
    );
    expect(rendererSearchScript('alpha'), contains('PageSageRenderer.search'));
    expect(
      rendererClearSearchHighlightsScript(),
      contains('clearSearchHighlights'),
    );
    expect(
      rendererApplyAnnotationsScript(const []),
      contains('applyAnnotations'),
    );
    expect(
      rendererSetTextOptionsScript(
        fontSize: 18,
        lineHeight: 1.6,
        paragraphSpacing: 10,
        pageMargin: 24,
      ),
      contains('applySettings'),
    );
  });
}
