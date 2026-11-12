import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_annotation_repository.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/domain/annotations/image_anchor.dart';
import 'package:pagesage/domain/books/reading_position.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('v4 -> v5', () {
    test(
      'existing highlights become text annotations, none are lost',
      () async {
        final sqlite = sqlite3.openInMemory();

        // Build the current schema, rewind it to v4 by removing the two columns
        // this migration adds, and put a v4-shaped row in.
        final fresh = AppDatabase.forTesting(
          NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
        );
        await fresh.annotationDao.upsertAnnotation(
          AnnotationsCompanion.insert(
            id: 'anno-old',
            bookId: 'book-1',
            locator: ReadingLocator.pdf(page: 7).toJsonText(),
            selectedText: '旧的高亮',
            color: 'yellow',
            style: 'highlight',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        await fresh.close();

        sqlite.execute('ALTER TABLE annotations DROP COLUMN target');
        sqlite.execute('ALTER TABLE annotations DROP COLUMN image_anchor');
        sqlite.execute('PRAGMA user_version = 4');
        sqlite.execute(
          'ALTER TABLE ai_conversations DROP COLUMN context_snapshot',
        );

        final database = AppDatabase.forTesting(
          NativeDatabase.opened(sqlite, closeUnderlyingOnClose: true),
        );
        addTearDown(database.close);

        final rows = await database.annotationDao.getByBook('book-1');

        expect(rows, hasLength(1), reason: 'the migration must not clear data');
        expect(rows.single.selectedText, '旧的高亮');
        // A row written before images existed marks text: no guessing involved.
        expect(rows.single.target, 'text');
        expect(rows.single.imageAnchor, isNull);
      },
    );
  });

  group('image annotations', () {
    late AppDatabase database;
    late DriftAnnotationRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftAnnotationRepository(database.annotationDao);
    });

    tearDown(() => database.close());

    test('round-trip keeps the anchor identity, not just the box', () async {
      const anchor = PdfImageAnchor(
        page: 12,
        ordinal: 3,
        resourceName: 'Im1',
        rect: ReaderRect(x: 0.1, y: 0.2, width: 0.5, height: 0.4),
        region: ReaderRect(x: 0.1, y: 0.1, width: 0.4, height: 0.3),
      );

      await repository.saveAnnotation(
        bookId: 'book-1',
        locator: ReadingLocator.pdf(page: 12),
        selectedText: '图 3',
        color: AnnotationColor.blue,
        imageAnchor: anchor,
      );

      final saved = (await repository.getByBook('book-1')).single;
      expect(saved.target, AnnotationTarget.image);
      final stored = saved.imageAnchor! as PdfImageAnchor;
      expect(stored.page, 12);
      expect(stored.ordinal, 3, reason: 'identity must survive the round trip');
      expect(stored.resourceName, 'Im1');
      expect(stored.rect.x, closeTo(0.1, 1e-9));
      expect(stored.region?.height, closeTo(0.3, 1e-9));
      // Jump-back still works through the ordinary locator.
      expect(saved.locator.page, 12);
    });

    test('a text annotation stores no anchor', () async {
      await repository.saveAnnotation(
        bookId: 'book-1',
        locator: ReadingLocator.pdf(page: 2),
        selectedText: '正文',
      );

      final saved = (await repository.getByBook('book-1')).single;
      expect(saved.target, AnnotationTarget.text);
      expect(saved.imageAnchor, isNull);
    });

    test('an empty box is refused instead of written as invisible', () async {
      // A zero-size anchor has nowhere to paint; saving it would produce a row
      // that never shows up in the reader and cannot be found again.
      expect(
        () => repository.saveAnnotation(
          bookId: 'book-1',
          locator: ReadingLocator.pdf(page: 2),
          selectedText: '',
          imageAnchor: const PdfImageAnchor(
            page: 2,
            rect: ReaderRect(x: 0.2, y: 0.2, width: 0, height: 0),
          ),
        ),
        throwsArgumentError,
      );
    });

    for (final rect in [
      const ReaderRect(x: 0, y: 0, width: 0, height: 0.5),
      const ReaderRect(x: 0, y: 0, width: 0.5, height: 0),
      const ReaderRect(x: 0, y: 0, width: -0.1, height: 0.5),
      const ReaderRect(x: 0, y: 0, width: double.nan, height: 0.5),
      const ReaderRect(x: double.infinity, y: 0, width: 0.5, height: 0.5),
    ]) {
      test('invalid image geometry is rejected: ${rect.toJson()}', () async {
        await expectLater(
          repository.saveAnnotation(
            bookId: 'book-1',
            locator: ReadingLocator.pdf(page: 2),
            selectedText: '',
            imageAnchor: PdfImageAnchor(page: 2, rect: rect),
          ),
          throwsArgumentError,
        );
        expect(await repository.getByBook('book-1'), isEmpty);
      });
    }

    test(
      'updating a text annotation into an image one flips its target',
      () async {
        final first = await repository.saveAnnotation(
          id: 'anno-1',
          bookId: 'book-1',
          locator: ReadingLocator.pdf(page: 2),
          selectedText: '正文',
        );

        await repository.saveAnnotation(
          id: first.id,
          bookId: 'book-1',
          locator: ReadingLocator.pdf(page: 2),
          selectedText: '',
          imageAnchor: const PdfImageAnchor(
            page: 2,
            ordinal: 0,
            rect: ReaderRect(x: 0.1, y: 0.1, width: 0.8, height: 0.6),
          ),
        );

        final saved = (await repository.getByBook('book-1')).single;
        expect(saved.target, AnnotationTarget.image);
        expect(
          saved.createdAt,
          first.createdAt,
          reason: 'update, not a new row',
        );
      },
    );
  });

  group('anchor JSON', () {
    test('a PDF anchor survives text encoding through the column', () async {
      final anchor = const PdfImageAnchor(
        page: 4,
        ordinal: 1,
        rect: ReaderRect(x: 0, y: 0, width: 1, height: 1),
      );
      final decoded = ImageAnchor.fromJson(anchor.toJson());
      expect(decoded, isA<PdfImageAnchor>());
      expect((decoded! as PdfImageAnchor).page, 4);
    });

    test('an EPUB anchor needs a href and an ordinal', () {
      expect(
        ImageAnchor.fromJson({
          'kind': 'epub',
          'href': 'chapter.xhtml',
          'ordinal': 2,
          'rect': {'x': 0.0, 'y': 0.0, 'width': 1.0, 'height': 1.0},
        }),
        isA<EpubImageAnchor>(),
      );
      // No ordinal: the anchor cannot say which image, so it is not usable.
      expect(
        ImageAnchor.fromJson({
          'kind': 'epub',
          'href': 'chapter.xhtml',
          'rect': {'x': 0.0, 'y': 0.0, 'width': 1.0, 'height': 1.0},
        }),
        isNull,
      );
    });

    test('a corrupt anchor decodes to null rather than throwing', () {
      expect(ImageAnchor.fromJson({'kind': 'pdf', 'page': 1}), isNull);
      expect(ImageAnchor.fromJson({'kind': 'nope'}), isNull);
    });
  });
}
