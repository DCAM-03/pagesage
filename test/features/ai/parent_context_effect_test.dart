import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/search/structure_chunker.dart';
import 'package:pagesage/domain/search/search_models.dart';
import 'package:pagesage/features/ai/application/context_retriever.dart';

void main() {
  test('recovers evidence split at the old hard chunk boundary', () {
    final text = _boundaryDocument();
    expect(text.length, greaterThan(1200));

    final baseline = const ContextRetriever().retrieve(
      books: [
        SearchBookChunks(bookId: 'book-old', chunks: _hardChunks(text, 1200)),
      ],
      query: '关键术语',
      limit: 1,
    );
    final structured = const ContextRetriever().retrieve(
      books: [
        SearchBookChunks(bookId: 'book-new', chunks: _parentChildChunks(text)),
      ],
      query: '关键术语',
      limit: 1,
    );

    expect(baseline, hasLength(1));
    expect(baseline.single.text, contains('关键术语'));
    expect(
      baseline.single.text,
      isNot(contains('完整答案就在这里')),
      reason: 'the fixed 1200-character baseline loses the continuation',
    );
    expect(structured, hasLength(1));
    expect(structured.single.text, contains('关键术语'));
    expect(structured.single.text, contains('完整答案就在这里'));
    expect(
      structured.single.text.length,
      lessThanOrEqualTo(ContextRetriever.maxBlockChars),
    );
  });
}

String _boundaryDocument() {
  final buffer = StringBuffer();
  while (buffer.length < 1120) {
    buffer.write('这一段用于铺垫上下文。');
  }
  buffer.write('关键术语在这里出现。');
  while (buffer.length < 1220) {
    buffer.write('中间还有一小段过渡说明。');
  }
  buffer.write('完整答案就在这里。');
  return buffer.toString();
}

List<SearchChunk> _hardChunks(String text, int size) {
  final chunks = <SearchChunk>[];
  for (var offset = 0; offset < text.length; offset += size) {
    final end = (offset + size).clamp(0, text.length);
    chunks.add(
      SearchChunk(
        id: 'old-$offset',
        bookId: 'book-old',
        title: '旧索引',
        text: text.substring(offset, end),
        sortOrder: offset,
      ),
    );
  }
  return chunks;
}

List<SearchChunk> _parentChildChunks(String text) {
  final document = const StructureAwareChunker().chunk(
    text: text,
    chapterTitle: '边界样本',
  );
  final chunks = <SearchChunk>[];
  var order = 0;
  for (final parent in document.parents) {
    final parentId = 'book-new:p${parent.ordinal}';
    for (final child in parent.children) {
      chunks.add(
        SearchChunk(
          id: 'new-$order',
          bookId: 'book-new',
          title: parent.titlePath,
          text: child.text,
          sortOrder: order,
          parentId: parentId,
          parentTitle: parent.titlePath,
          parentText: parent.text,
        ),
      );
      order += 1;
    }
  }
  return chunks;
}
