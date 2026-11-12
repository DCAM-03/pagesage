import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_annotation_repository.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:pagesage/domain/books/reading_position.dart';

void main() {
  late AppDatabase database;
  late DriftAnnotationRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftAnnotationRepository(database.annotationDao);
    await database.bookDao.insertBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: '测试书',
        format: BookFormat.epub.value,
        libraryFilePath: '/tmp/book-1.epub',
        fileHash: 'hash-book-1',
        fileSize: 100,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'updates style while preserving creation time and linked note',
    () async {
      final annotation = await repository.saveAnnotation(
        bookId: 'book-1',
        locator: ReadingLocator.epub(chapterIndex: 1),
        selectedText: '原文',
        color: AnnotationColor.yellow,
        style: AnnotationStyle.highlight,
      );
      await repository.linkNote(annotationId: annotation.id, noteId: 'note-1');

      final updated = await repository.saveAnnotation(
        id: annotation.id,
        bookId: annotation.bookId,
        locator: annotation.locator,
        selectedText: annotation.selectedText,
        color: AnnotationColor.blue,
        style: AnnotationStyle.underline,
      );

      expect(updated.createdAt, annotation.createdAt);
      expect(updated.noteId, 'note-1');
      expect(updated.color, AnnotationColor.blue);
      expect(updated.style, AnnotationStyle.underline);
    },
  );

  test('round-trips PDF annotation locator selection rects', () async {
    final annotation = await repository.saveAnnotation(
      bookId: 'book-1',
      locator: ReadingLocator.pdf(
        page: 3,
        progress: 0.2,
        selectionRects: const [
          ReaderRect(page: 3, x: 0.12, y: 0.34, width: 0.22, height: 0.03),
        ],
      ),
      selectedText: 'PDF text',
      color: AnnotationColor.green,
      style: AnnotationStyle.highlight,
    );

    final restored = (await repository.getByBook(
      'book-1',
    )).singleWhere((item) => item.id == annotation.id);

    expect(restored.locator.type, ReadingLocatorType.pdf);
    expect(restored.locator.selectionRects, hasLength(1));
    expect(restored.locator.selectionRects.single.y, 0.34);
  });

  test('unlinking a note keeps the annotation and clears note_id', () async {
    final annotation = await repository.saveAnnotation(
      bookId: 'book-1',
      locator: ReadingLocator.epub(chapterIndex: 2),
      selectedText: 'keep this mark',
    );
    await repository.linkNote(annotationId: annotation.id, noteId: 'note-1');

    await repository.unlinkNote(annotationId: annotation.id);

    final restored = (await repository.getByBook('book-1')).single;
    expect(restored.id, annotation.id);
    expect(restored.selectedText, 'keep this mark');
    expect(restored.noteId, isNull);
  });

  test('returns all annotations for export', () async {
    await repository.saveAnnotation(
      bookId: 'book-1',
      locator: ReadingLocator.epub(
        href: 'chapter.xhtml',
        chapterIndex: 0,
        chapterOffset: 12,
        chapterEndOffset: 18,
      ),
      selectedText: 'export me',
      color: AnnotationColor.purple,
      style: AnnotationStyle.highlight,
    );

    final annotations = await repository.getAll();

    expect(annotations, hasLength(1));
    expect(annotations.single.locator.chapterOffset, 12);
  });
}
