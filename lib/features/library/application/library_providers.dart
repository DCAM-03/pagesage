import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/books/book.dart';
import '../../../domain/books/category.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/books/tag.dart';

enum LibrarySort {
  recent('最近阅读'),
  created('导入时间'),
  title('标题'),
  author('作者'),
  progress('阅读进度'),
  fileSize('文件大小'),
  format('格式');

  const LibrarySort(this.label);

  final String label;
}

enum LibrarySystemFilter {
  all('全部'),
  recent('最近阅读'),
  favorite('收藏'),
  unread('未读'),
  reading('阅读中'),
  finished('已读');

  const LibrarySystemFilter(this.label);

  final String label;
}

enum LibraryViewMode {
  grid('网格'),
  list('列表'),
  compact('紧凑');

  const LibraryViewMode(this.label);

  final String label;
}

final libraryBooksProvider = StreamProvider<List<LibraryBook>>((ref) {
  return ref.watch(bookRepositoryProvider).watchLibrary();
});

final categoriesProvider = StreamProvider<List<BookCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

final tagsProvider = StreamProvider<List<BookTag>>((ref) {
  return ref.watch(tagRepositoryProvider).watchTags();
});

/// Shared bookId → tags map for list rendering and filters (no per-row queries).
final bookTagsByBookIdProvider = StreamProvider<Map<String, List<BookTag>>>((
  ref,
) {
  return ref.watch(tagRepositoryProvider).watchTagsByBookId();
});

List<LibraryBook> sortLibraryBooks(List<LibraryBook> books, LibrarySort sort) {
  final sorted = [...books];
  switch (sort) {
    case LibrarySort.recent:
      sorted.sort((a, b) {
        final aTime = a.book.lastOpenedAt ?? a.book.createdAt;
        final bTime = b.book.lastOpenedAt ?? b.book.createdAt;
        return bTime.compareTo(aTime);
      });
    case LibrarySort.title:
      sorted.sort((a, b) => a.book.title.compareTo(b.book.title));
    case LibrarySort.created:
      sorted.sort((a, b) => b.book.createdAt.compareTo(a.book.createdAt));
    case LibrarySort.author:
      sorted.sort(
        (a, b) => (a.book.author ?? '').compareTo(b.book.author ?? ''),
      );
    case LibrarySort.progress:
      sorted.sort(
        (a, b) =>
            (b.progress?.progress ?? 0).compareTo(a.progress?.progress ?? 0),
      );
    case LibrarySort.fileSize:
      sorted.sort((a, b) => b.book.fileSize.compareTo(a.book.fileSize));
    case LibrarySort.format:
      sorted.sort((a, b) => a.book.format.value.compareTo(b.book.format.value));
  }
  return sorted;
}

List<LibraryBook> filterLibraryBooks(
  List<LibraryBook> books, {
  LibrarySystemFilter systemFilter = LibrarySystemFilter.all,
  String? categoryId,
  BookFormat? format,
}) {
  return books
      .where((item) {
        final book = item.book;
        final matchesSystem = switch (systemFilter) {
          LibrarySystemFilter.all => true,
          LibrarySystemFilter.recent => book.lastOpenedAt != null,
          LibrarySystemFilter.favorite => book.isFavorite,
          LibrarySystemFilter.unread => book.readStatus == ReadStatus.unread,
          LibrarySystemFilter.reading => book.readStatus == ReadStatus.reading,
          LibrarySystemFilter.finished =>
            book.readStatus == ReadStatus.finished,
        };
        if (!matchesSystem) {
          return false;
        }
        if (categoryId != null) {
          if (categoryId == '__uncategorized__') {
            if (book.categoryId != null) {
              return false;
            }
          } else if (book.categoryId != categoryId) {
            return false;
          }
        }
        if (format != null && book.format != format) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

String formatBookFormat(BookFormat format) {
  return switch (format) {
    BookFormat.epub => 'EPUB',
    BookFormat.pdf => 'PDF',
    BookFormat.markdown => 'MD',
  };
}

/// The format a book shows, including that it is a folder rather than a file.
///
/// A folder book is read where the writer keeps it; saying so on the card is
/// the only place the reader can see the difference between one note and a
/// folder of notes.
String bookFormatLabel(Book book) {
  final label = formatBookFormat(book.format);
  return book.isFolderBook ? '$label · 文件夹' : label;
}
