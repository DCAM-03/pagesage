import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_content_repositories.dart';

void main() {
  group('DriftCategoryRepository', () {
    late AppDatabase database;
    late DriftCategoryRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftCategoryRepository(database.categoryDao);
    });

    tearDown(() async {
      await database.close();
    });

    test('trims names and rejects empty or duplicate category names', () async {
      final category = await repository.saveCategory(name: ' 小说 ');

      expect(category.name, '小说');
      await expectLater(
        repository.saveCategory(name: '   '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.saveCategory(name: '小说'),
        throwsA(isA<FormatException>()),
      );
    });

    test('renames existing category without changing createdAt', () async {
      final category = await repository.saveCategory(id: 'cat-1', name: '小说');

      final renamed = await repository.saveCategory(
        id: category.id,
        name: '非虚构',
      );

      expect(renamed.id, category.id);
      expect(renamed.name, '非虚构');
      expect(renamed.createdAt, category.createdAt);
      expect(await repository.getCategories(), hasLength(1));
    });

    test(
      'assigns new categories stable sort orders and reads by sort order',
      () async {
        final first = await repository.saveCategory(id: 'cat-1', name: '第一');
        final second = await repository.saveCategory(id: 'cat-2', name: '第二');

        expect(second.sortOrder, greaterThan(first.sortOrder));

        await repository.saveCategory(
          id: first.id,
          name: first.name,
          sortOrder: 2048,
        );
        await repository.saveCategory(
          id: second.id,
          name: second.name,
          sortOrder: 1024,
        );

        final categories = await repository.getCategories();
        expect(categories.map((category) => category.id), ['cat-2', 'cat-1']);
      },
    );

    test(
      'deleting a category moves books to uncategorized and keeps children',
      () async {
        final parent = await repository.saveCategory(id: 'cat-1', name: '工作');
        final child = await repository.saveCategory(
          id: 'cat-2',
          parentId: parent.id,
          name: '论文',
        );
        await database.bookDao.insertBook(
          BooksCompanion.insert(
            id: 'book-1',
            title: 'Sample',
            format: 'epub',
            libraryFilePath: '/tmp/sample.epub',
            fileHash: 'hash-1',
            fileSize: 100,
            categoryId: Value(parent.id),
            createdAt: 1,
            updatedAt: 1,
          ),
        );

        await repository.deleteCategory(parent.id);

        final book = await database.bookDao.getBook('book-1');
        final categories = await repository.getCategories();
        expect(book?.categoryId, isNull);
        expect(categories.single.id, child.id);
        expect(categories.single.parentId, isNull);
      },
    );

    test('deleting a category can move books to another category', () async {
      final source = await repository.saveCategory(id: 'cat-1', name: '来源');
      final target = await repository.saveCategory(id: 'cat-2', name: '目标');
      await database.bookDao.insertBook(
        BooksCompanion.insert(
          id: 'book-1',
          title: 'Sample',
          format: 'epub',
          libraryFilePath: '/tmp/sample.epub',
          fileHash: 'hash-1',
          fileSize: 100,
          categoryId: Value(source.id),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      await repository.deleteCategory(
        source.id,
        moveBooksToCategoryId: target.id,
      );

      final book = await database.bookDao.getBook('book-1');
      expect(book?.categoryId, target.id);
      expect(
        (await repository.getCategories()).map((category) => category.id),
        [target.id],
      );
    });
  });

  group('DriftTagRepository', () {
    late AppDatabase database;
    late DriftTagRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftTagRepository(database.tagDao);
    });

    tearDown(() async {
      await database.close();
    });

    test('trims names and rejects empty or duplicate tag names', () async {
      final tag = await repository.saveTag(name: ' 重要 ', color: '#1F6F64');

      expect(tag.name, '重要');
      await expectLater(
        repository.saveTag(name: '   '),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.saveTag(name: '重要'),
        throwsA(isA<FormatException>()),
      );
    });

    test('renames tag and keeps existing book and note associations', () async {
      final tag = await repository.saveTag(
        id: 'tag-1',
        name: '旧标签',
        color: '#1F6F64',
      );
      await repository.setBookTags('book-1', [tag.id]);
      await repository.setNoteTags('note-1', [tag.id]);

      final renamed = await repository.saveTag(
        id: tag.id,
        name: '新标签',
        color: '#0047B3',
      );

      final bookTags = await repository.getTagsForBook('book-1');
      final noteTags = await repository.getTagsForNote('note-1');
      expect(renamed.createdAt, tag.createdAt);
      expect(bookTags.single.name, '新标签');
      expect(bookTags.single.color, '#0047B3');
      expect(noteTags.single.name, '新标签');
    });

    test('deleting a tag removes book and note associations', () async {
      final tag = await repository.saveTag(id: 'tag-1', name: '待删');
      await repository.setBookTags('book-1', [tag.id]);
      await repository.setNoteTags('note-1', [tag.id]);

      await repository.deleteTag(tag.id);

      expect(await repository.getTags(), isEmpty);
      expect(await repository.getTagsForBook('book-1'), isEmpty);
      expect(await repository.getTagsForNote('note-1'), isEmpty);
    });

    test(
      'watchTagsByBookId and getBookIdsWithTag avoid per-book polling',
      () async {
        final tech = await repository.saveTag(id: 'tag-tech', name: '技术');
        final fiction = await repository.saveTag(id: 'tag-fic', name: '小说');
        await repository.setBookTags('book-a', [tech.id, fiction.id]);
        await repository.setBookTags('book-b', [fiction.id]);

        final map = await repository.watchTagsByBookId().first;
        expect(map['book-a']!.map((tag) => tag.name), ['小说', '技术']);
        expect(map['book-b']!.single.name, '小说');
        expect(await repository.getBookIdsWithTag(fiction.id), {
          'book-a',
          'book-b',
        });
        expect(await repository.getBookIdsWithTag(tech.id), {'book-a'});
      },
    );
  });
}
