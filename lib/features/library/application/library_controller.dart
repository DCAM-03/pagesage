import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/books/book.dart';
import 'library_providers.dart';

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

enum LibraryGridSize {
  /// maxCrossAxisExtent targets — wider steps so size changes are obvious.
  small('小', 112),
  medium('中', 156),
  large('大', 220);

  const LibraryGridSize(this.label, this.minTileWidth);

  final String label;
  final double minTileWidth;
}

final class LibraryState {
  const LibraryState({
    this.sort = LibrarySort.recent,
    this.viewMode = LibraryViewMode.grid,
    this.gridSize = LibraryGridSize.medium,
    this.systemFilter = LibrarySystemFilter.all,
    this.format,
    this.categoryId,
    this.tagId,
    this.hasNotesOnly = false,
    this.hasBookmarksOnly = false,
    this.selectedBookId,
  });

  final LibrarySort sort;
  final LibraryViewMode viewMode;
  final LibraryGridSize gridSize;
  final LibrarySystemFilter systemFilter;
  final BookFormat? format;
  final String? categoryId;
  final String? tagId;
  final bool hasNotesOnly;
  final bool hasBookmarksOnly;
  final String? selectedBookId;

  LibraryState copyWith({
    LibrarySort? sort,
    LibraryViewMode? viewMode,
    LibraryGridSize? gridSize,
    LibrarySystemFilter? systemFilter,
    Object? format = _sentinel,
    Object? categoryId = _sentinel,
    Object? tagId = _sentinel,
    bool? hasNotesOnly,
    bool? hasBookmarksOnly,
    Object? selectedBookId = _sentinel,
  }) {
    return LibraryState(
      sort: sort ?? this.sort,
      viewMode: viewMode ?? this.viewMode,
      gridSize: gridSize ?? this.gridSize,
      systemFilter: systemFilter ?? this.systemFilter,
      format: identical(format, _sentinel)
          ? this.format
          : format as BookFormat?,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as String?,
      tagId: identical(tagId, _sentinel) ? this.tagId : tagId as String?,
      hasNotesOnly: hasNotesOnly ?? this.hasNotesOnly,
      hasBookmarksOnly: hasBookmarksOnly ?? this.hasBookmarksOnly,
      selectedBookId: identical(selectedBookId, _sentinel)
          ? this.selectedBookId
          : selectedBookId as String?,
    );
  }
}

const Object _sentinel = Object();

final class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  void setSort(LibrarySort sort) {
    state = state.copyWith(sort: sort);
  }

  void setViewMode(LibraryViewMode viewMode) {
    state = state.copyWith(viewMode: viewMode);
  }

  void setGridSize(LibraryGridSize gridSize) {
    state = state.copyWith(gridSize: gridSize, viewMode: LibraryViewMode.grid);
  }

  void setSystemFilter(LibrarySystemFilter filter) {
    // Status filters are independent of category (AND). Selecting a status
    // does not clear category — but "全部" only resets status.
    state = state.copyWith(systemFilter: filter);
  }

  void setFormat(BookFormat? format) {
    state = state.copyWith(format: format);
  }

  void setCategory(String? categoryId) {
    // Category selection is its own dimension; never mix with system "未分类".
    state = state.copyWith(categoryId: categoryId);
  }

  void browseAll() {
    state = state.copyWith(
      systemFilter: LibrarySystemFilter.all,
      categoryId: null,
    );
  }

  void setTag(String? tagId) {
    state = state.copyWith(tagId: tagId);
  }

  void setHasNotesOnly(bool value) {
    state = state.copyWith(hasNotesOnly: value);
  }

  void setHasBookmarksOnly(bool value) {
    state = state.copyWith(hasBookmarksOnly: value);
  }

  void selectBook(String? bookId) {
    state = state.copyWith(selectedBookId: bookId);
  }

  void clearFilters() {
    state = state.copyWith(
      systemFilter: LibrarySystemFilter.all,
      format: null,
      categoryId: null,
      tagId: null,
      hasNotesOnly: false,
      hasBookmarksOnly: false,
    );
  }
}
