import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/responsive/app_breakpoints.dart';
import '../../../app/widgets/app_chrome.dart';
import '../../../core/database/database_providers.dart';
import '../../../domain/books/category.dart';
import '../../../domain/books/reading_position.dart';
import '../../../domain/notes/note.dart';
import '../../../domain/books/locator_excerpt.dart';
import '../../library/application/library_providers.dart';

final notesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchNotes();
});

enum _NoteSort { updatedDesc, updatedAsc, createdDesc }

final class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

final class _NotesPageState extends ConsumerState<NotesPage> {
  NoteType? _typeFilter;
  String? _categoryFilterId;
  String? _bookFilterId;
  bool _unlinkedOnly = false;
  String? _tagFilterId;
  _NoteSort _sort = _NoteSort.updatedDesc;
  String? _selectedNoteId;
  Future<List<Note>>? _filteredFuture;
  String? _filterKey;

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final books = ref.watch(libraryBooksProvider);
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(tagsProvider);
    final isCompact = context.appBreakpoint.isCompact;
    return Scaffold(
      body: notes.when(
        data: (items) {
          _ensureFilteredFuture(
            items,
            books.value ?? const [],
            categories.value ?? const [],
          );
          return FutureBuilder<List<Note>>(
            key: ValueKey(_filterKey),
            future: _filteredFuture,
            builder: (context, snapshot) {
              final filtered = snapshot.data;
              return Column(
                children: [
                  AppPageHeader(
                    title: '笔记',
                    subtitle: '管理书签、摘录、手写笔记和 AI 记录',
                    showThemeMode: true,
                    actions: [
                      if (!isCompact)
                        FilledButton.icon(
                          onPressed: () => _showNoteEditor(context),
                          icon: const Icon(Icons.add),
                          label: const Text('新建笔记'),
                        ),
                    ],
                  ),
                  _NotesFilters(
                    typeFilter: _typeFilter,
                    categoryFilterId: _categoryFilterId,
                    bookFilterId: _bookFilterId,
                    tagFilterId: _tagFilterId,
                    sort: _sort,
                    books: books.value ?? const [],
                    categories: categories.value ?? const [],
                    tags: tags.value ?? const [],
                    onTypeChanged: (value) => setState(() {
                      _typeFilter = value;
                      _selectedNoteId = null;
                      _filterKey = null;
                    }),
                    onBookChanged: (value) => setState(() {
                      _bookFilterId = value;
                      _categoryFilterId = null;
                      _unlinkedOnly = false;
                      _selectedNoteId = null;
                      _filterKey = null;
                    }),
                    onCategoryChanged: (value) => setState(() {
                      _categoryFilterId = value;
                      _bookFilterId = null;
                      _unlinkedOnly = false;
                      _selectedNoteId = null;
                      _filterKey = null;
                    }),
                    onTagChanged: (value) => setState(() {
                      _tagFilterId = value;
                      _selectedNoteId = null;
                      _filterKey = null;
                    }),
                    onSortChanged: (value) => setState(() {
                      _sort = value;
                      _filterKey = null;
                    }),
                    onClear: () => setState(() {
                      _typeFilter = null;
                      _categoryFilterId = null;
                      _bookFilterId = null;
                      _unlinkedOnly = false;
                      _tagFilterId = null;
                      _sort = _NoteSort.updatedDesc;
                      _selectedNoteId = null;
                      _filterKey = null;
                    }),
                  ),
                  Expanded(
                    child: filtered == null
                        ? const Center(child: CircularProgressIndicator())
                        : _buildNotesContent(
                            context,
                            items,
                            filtered,
                            books.value ?? const [],
                            categories.value ?? const [],
                          ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Column(
          children: [
            AppPageHeader(title: '笔记', subtitle: '正在读取本地笔记'),
            Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
        error: (error, stackTrace) => Column(
          children: [
            const AppPageHeader(title: '笔记', subtitle: '本地 Notebook'),
            Expanded(
              child: AppEmptyState(
                icon: Icons.error_outline,
                title: '无法读取笔记',
                message: '请稍后重试，或检查本地数据库是否可用。',
                action: FilledButton(
                  onPressed: () => ref.invalidate(notesProvider),
                  child: const Text('重试'),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              tooltip: '新建笔记',
              onPressed: () => _showNoteEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('新建'),
            )
          : null,
    );
  }

  void _ensureFilteredFuture(
    List<Note> items,
    List<LibraryBook> books,
    List<BookCategory> categories,
  ) {
    // Hash every note so mid-list edits (type/book/title) invalidate the cache,
    // not only length + first/last updatedAt.
    final contentRevision = Object.hashAll([
      for (final note in items)
        Object.hash(
          note.id,
          note.updatedAt,
          note.bookId,
          note.noteType,
          note.title,
          note.content.length,
        ),
    ]);
    final key =
        '$_typeFilter|$_categoryFilterId|$_bookFilterId|$_unlinkedOnly|$_tagFilterId|${_sort.name}|$contentRevision|'
        '${Object.hashAll(books.map((item) => Object.hash(item.book.id, item.book.categoryId)))}|'
        '${Object.hashAll(categories.map((category) => Object.hash(category.id, category.parentId, category.name)))}';
    if (_filterKey == key && _filteredFuture != null) {
      return;
    }
    _filterKey = key;
    _filteredFuture = _filterByTag(_applyFilters(items));
  }

  Widget _buildNotesContent(
    BuildContext context,
    List<Note> allNotes,
    List<Note> notes,
    List<LibraryBook> books,
    List<BookCategory> categories,
  ) {
    if (notes.isEmpty && (!context.supportsSidePanel || allNotes.isEmpty)) {
      final hasFilters =
          _typeFilter != null ||
          _categoryFilterId != null ||
          _bookFilterId != null ||
          _unlinkedOnly ||
          _tagFilterId != null;
      return AppEmptyState(
        icon: Icons.edit_note_outlined,
        illustrationAsset: hasFilters
            ? null
            : 'assets/images/empty-states/empty-notes.png',
        title: hasFilters ? '没有符合条件的笔记' : '还没有笔记',
        message: hasFilters ? '试试清除筛选，或换一组类型/书籍条件。' : '在阅读器里保存摘录，或在这里新建一条手写笔记。',
        action: hasFilters
            ? OutlinedButton(
                onPressed: () => setState(() {
                  _typeFilter = null;
                  _categoryFilterId = null;
                  _bookFilterId = null;
                  _unlinkedOnly = false;
                  _tagFilterId = null;
                  _sort = _NoteSort.updatedDesc;
                  _selectedNoteId = null;
                  _filterKey = null;
                }),
                child: const Text('清除筛选'),
              )
            : FilledButton.icon(
                onPressed: () => _showNoteEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('新建笔记'),
              ),
      );
    }
    if (context.supportsSidePanel) {
      final categoryIds = _categoryFilterId == null
          ? null
          : _categoryAndDescendantIds(categories, _categoryFilterId!);
      final scopedBookIds = categoryIds == null
          ? null
          : books
                .where((item) => categoryIds.contains(item.book.categoryId))
                .map((item) => item.book.id)
                .toSet();
      final scopedNotes = notes
          .where((note) {
            final bookId = _bookFilterId;
            if (bookId != null && note.bookId != bookId) return false;
            if (_unlinkedOnly && note.bookId != null) return false;
            return scopedBookIds == null || scopedBookIds.contains(note.bookId);
          })
          .toList(growable: false);
      final displayedNote = scopedNotes.isEmpty
          ? null
          : scopedNotes.any((note) => note.id == _selectedNoteId)
          ? scopedNotes.firstWhere((note) => note.id == _selectedNoteId)
          : scopedNotes.first;
      return Row(
        children: [
          SizedBox(
            width: 250,
            child: _NotesCollectionSidebar(
              notes: allNotes,
              books: books,
              categories: categories,
              selectedCategoryId: _categoryFilterId,
              selectedBookId: _bookFilterId,
              unlinkedOnly: _unlinkedOnly,
              onAll: () => setState(() {
                _categoryFilterId = null;
                _bookFilterId = null;
                _unlinkedOnly = false;
                _selectedNoteId = null;
                _filterKey = null;
              }),
              onUnlinked: () => setState(() {
                _categoryFilterId = null;
                _bookFilterId = null;
                _unlinkedOnly = true;
                _selectedNoteId = null;
                _filterKey = null;
              }),
              onCategorySelected: (id) => setState(() {
                _categoryFilterId = id;
                _bookFilterId = null;
                _unlinkedOnly = false;
                _selectedNoteId = null;
                _filterKey = null;
              }),
              onBookSelected: (id) => setState(() {
                _bookFilterId = id;
                _categoryFilterId = null;
                _unlinkedOnly = false;
                _selectedNoteId = null;
                _filterKey = null;
              }),
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 340,
            child: _NotesList(
              notes: scopedNotes,
              books: books,
              selectedNoteId: displayedNote?.id,
              onSelected: (note) => setState(() => _selectedNoteId = note.id),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: displayedNote == null
                ? const Center(child: Text('该分类下没有笔记'))
                : _NotePreview(
                    note: displayedNote,
                    onEdit: () => _showNoteEditor(context, note: displayedNote),
                    onDelete: () => _deleteNote(context, displayedNote),
                    onJump: displayedNote.canJump
                        ? () => _jumpToSource(context, displayedNote)
                        : null,
                  ),
          ),
        ],
      );
    }
    final selectedNoteId = _selectedNoteId;
    Note? detail;
    if (selectedNoteId != null) {
      for (final note in notes) {
        if (note.id == selectedNoteId) {
          detail = note;
          break;
        }
      }
    }
    final selectedDetail = detail;
    if (selectedDetail != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _selectedNoteId = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回笔记列表'),
            ),
          ),
          Expanded(
            child: _NotePreview(
              note: selectedDetail,
              onEdit: () => _showNoteEditor(context, note: selectedDetail),
              onDelete: () => _deleteNote(context, selectedDetail),
              onJump: selectedDetail.canJump
                  ? () => _jumpToSource(context, selectedDetail)
                  : null,
            ),
          ),
        ],
      );
    }
    return _NotesList(
      notes: notes,
      books: books,
      onSelected: (note) => setState(() => _selectedNoteId = note.id),
    );
  }

  List<Note> _applyFilters(List<Note> notes) {
    final books = ref.read(libraryBooksProvider).value ?? const [];
    final categories =
        ref.read(categoriesProvider).value ?? const <BookCategory>[];
    final categoryIds = _categoryFilterId == null
        ? null
        : _categoryAndDescendantIds(categories, _categoryFilterId!);
    final filtered = notes.where((note) {
      final type = _typeFilter;
      if (type != null && note.noteType != type) {
        return false;
      }
      final bookId = _bookFilterId;
      if (bookId != null && note.bookId != bookId) {
        return false;
      }
      if (_unlinkedOnly && note.bookId != null) {
        return false;
      }
      if (categoryIds != null) {
        final book = books.where((item) => item.book.id == note.bookId);
        if (book.isEmpty || !categoryIds.contains(book.first.book.categoryId)) {
          return false;
        }
      }
      return true;
    }).toList();
    switch (_sort) {
      case _NoteSort.updatedDesc:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _NoteSort.updatedAsc:
        filtered.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case _NoteSort.createdDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  Future<List<Note>> _filterByTag(List<Note> notes) async {
    final tagId = _tagFilterId;
    if (tagId == null) {
      return notes;
    }
    final result = <Note>[];
    for (final note in notes) {
      final tags = await ref
          .read(tagRepositoryProvider)
          .getTagsForNote(note.id);
      if (tags.any((tag) => tag.id == tagId)) {
        result.add(note);
      }
    }
    return result;
  }

  Future<void> _showNoteEditor(BuildContext context, {Note? note}) async {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final shortWindow = constraints.maxHeight < 680;
          return AlertDialog(
            title: Text(note == null ? '新建笔记' : '编辑笔记'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: constraints.maxHeight * 0.62,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (note?.sourceText?.isNotEmpty == true) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '原文摘录',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note!.sourceText!,
                        maxLines: shortWindow ? 2 : 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: '标题'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      minLines: shortWindow ? 5 : 8,
                      maxLines: shortWindow ? 8 : 14,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        helperText: '纯文本显示；可使用 **加粗**、*斜体*、`代码` 等简单标记',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    titleController.dispose();
    contentController.dispose();

    if (saved != true || content.isEmpty) {
      return;
    }
    final savedNote = await ref
        .read(noteRepositoryProvider)
        .saveNote(
          id: note?.id,
          bookId: note?.bookId,
          annotationId: note?.annotationId,
          title: title.isEmpty ? null : title,
          content: content,
          sourceText: note?.sourceText,
          locator: note?.locator,
          noteType: note?.noteType ?? NoteType.text,
        );
    setState(() => _selectedNoteId = savedNote.id);
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记？'),
        content: Text(
          note.annotationId == null ? '删除后不可恢复。' : '只删除这条笔记，不会删除关联标注。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final annotationId = note.annotationId;
    await ref.read(noteRepositoryProvider).deleteNote(note.id);
    if (annotationId != null) {
      await ref
          .read(annotationRepositoryProvider)
          .unlinkNote(annotationId: annotationId);
    }
    setState(() => _selectedNoteId = null);
  }

  void _jumpToSource(BuildContext context, Note note) {
    final bookId = note.bookId;
    final locator = note.locator;
    if (bookId == null || locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这条笔记没有原文位置')));
      return;
    }
    context.goNamed(
      'reader',
      pathParameters: {'bookId': bookId},
      extra: enrichLocatorForJump(locator, fallbackExcerpt: note.sourceText),
    );
  }
}

final class _NotesFilters extends StatelessWidget {
  const _NotesFilters({
    required this.typeFilter,
    required this.categoryFilterId,
    required this.bookFilterId,
    required this.tagFilterId,
    required this.sort,
    required this.books,
    required this.categories,
    required this.tags,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onBookChanged,
    required this.onTagChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  final NoteType? typeFilter;
  final String? categoryFilterId;
  final String? bookFilterId;
  final String? tagFilterId;
  final _NoteSort sort;
  final List<LibraryBook> books;
  final List<BookCategory> categories;
  final List<dynamic> tags;
  final ValueChanged<NoteType?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onBookChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<_NoteSort> onSortChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            _FilterMenuButton<NoteType?>(
              icon: Icons.category_outlined,
              label: typeFilter == null ? '全部类型' : _noteTypeLabel(typeFilter!),
              entries: [
                const PopupMenuItem<NoteType?>(
                  value: null,
                  child: Text('全部类型'),
                ),
                ...NoteType.values.map(
                  (type) => PopupMenuItem<NoteType?>(
                    value: type,
                    child: Text(_noteTypeLabel(type)),
                  ),
                ),
              ],
              onSelected: onTypeChanged,
            ),
            const SizedBox(width: 8),
            _FilterMenuButton<String?>(
              icon: Icons.folder_outlined,
              label: categoryFilterId == null
                  ? '全部文件夹'
                  : _categoryName(categories, categoryFilterId!),
              entries: [
                const PopupMenuItem<String?>(value: null, child: Text('全部文件夹')),
                ...categories.map(
                  (category) => PopupMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onSelected: onCategoryChanged,
            ),
            const SizedBox(width: 8),
            _FilterMenuButton<String?>(
              icon: Icons.menu_book_outlined,
              label: bookFilterId == null
                  ? '全部书籍'
                  : _bookTitle(books, bookFilterId!),
              entries: [
                const PopupMenuItem<String?>(value: null, child: Text('全部书籍')),
                ...books.map(
                  (item) => PopupMenuItem<String?>(
                    value: item.book.id,
                    child: Text(item.book.title),
                  ),
                ),
              ],
              onSelected: onBookChanged,
            ),
            const SizedBox(width: 8),
            _FilterMenuButton<String?>(
              icon: Icons.label_outline,
              label: tagFilterId == null
                  ? '全部标签'
                  : _tagName(tags, tagFilterId!),
              entries: [
                const PopupMenuItem<String?>(value: null, child: Text('全部标签')),
                ...tags.map(
                  (tag) => PopupMenuItem<String?>(
                    value: tag.id as String,
                    child: Text(tag.name as String),
                  ),
                ),
              ],
              onSelected: onTagChanged,
            ),
            const SizedBox(width: 8),
            _FilterMenuButton<_NoteSort>(
              icon: Icons.sort,
              label: _sortLabel(sort),
              entries: const [
                PopupMenuItem(
                  value: _NoteSort.updatedDesc,
                  child: Text('最近更新'),
                ),
                PopupMenuItem(value: _NoteSort.updatedAsc, child: Text('最早更新')),
                PopupMenuItem(
                  value: _NoteSort.createdDesc,
                  child: Text('最近创建'),
                ),
              ],
              onSelected: onSortChanged,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('清除'),
            ),
          ],
        ),
      ),
    );
  }

  String _bookTitle(List<dynamic> books, String id) {
    for (final item in books) {
      if (item.book.id == id) {
        return item.book.title;
      }
    }
    return '全部书籍';
  }

  String _categoryName(List<BookCategory> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return '全部文件夹';
  }

  String _tagName(List<dynamic> tags, String id) {
    for (final tag in tags) {
      if (tag.id == id) {
        return tag.name as String;
      }
    }
    return '全部标签';
  }
}

final class _FilterMenuButton<T> extends StatelessWidget {
  const _FilterMenuButton({
    required this.icon,
    required this.label,
    required this.entries,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<PopupMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (context) => entries,
      child: InputChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: null,
      ),
    );
  }
}

final class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.books,
    required this.onSelected,
    this.selectedNoteId,
  });

  final List<Note> notes;
  final List<LibraryBook> books;
  final String? selectedNoteId;
  final ValueChanged<Note> onSelected;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            FocusScope.of(context).nextFocus(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            FocusScope.of(context).previousFocus(),
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: notes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final note = notes[index];
          return _NoteCard(
            note: note,
            bookTitle: _bookTitleForNote(books, note.bookId),
            selected: selectedNoteId == note.id,
            onTap: () => onSelected(note),
          );
        },
      ),
    );
  }
}

final class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.bookTitle,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final String? bookTitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: Icon(_noteIcon(note.noteType)),
        title: Text(
          note.title?.isNotEmpty == true ? note.title! : '无标题笔记',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [?bookTitle, _noteSummary(note)].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 72),
          child: Text(
            _noteTypeLabel(note.noteType),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

final class _NotesCollectionSidebar extends StatelessWidget {
  const _NotesCollectionSidebar({
    required this.notes,
    required this.books,
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedBookId,
    required this.unlinkedOnly,
    required this.onAll,
    required this.onUnlinked,
    required this.onCategorySelected,
    required this.onBookSelected,
  });

  final List<Note> notes;
  final List<LibraryBook> books;
  final List<BookCategory> categories;
  final String? selectedCategoryId;
  final String? selectedBookId;
  final bool unlinkedOnly;
  final VoidCallback onAll;
  final VoidCallback onUnlinked;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onBookSelected;

  @override
  Widget build(BuildContext context) {
    final booksWithNotes = books
        .where((item) => notes.any((note) => note.bookId == item.book.id))
        .toList(growable: false);
    final categorizedIds = categories.map((item) => item.id).toSet();
    final uncategorizedBooks = booksWithNotes
        .where(
          (item) =>
              item.book.categoryId == null ||
              !categorizedIds.contains(item.book.categoryId),
        )
        .toList(growable: false);
    final looseNotes = notes.where((note) => note.bookId == null).length;
    final orderedCategories = _orderedCategories(categories);
    final visitedCategoryIds = <String>{};
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _CollectionTile(
          icon: Icons.notes_outlined,
          title: '全部笔记',
          count: notes.length,
          selected:
              selectedCategoryId == null &&
              selectedBookId == null &&
              !unlinkedOnly,
          onTap: onAll,
        ),
        if (looseNotes > 0)
          _CollectionTile(
            icon: Icons.note_alt_outlined,
            title: '未关联书籍',
            count: looseNotes,
            selected: unlinkedOnly,
            onTap: onUnlinked,
          ),
        for (final category in orderedCategories.where(
          (item) => item.parentId == null,
        ))
          _buildCategory(
            context,
            category,
            orderedCategories,
            visitedCategoryIds,
          ),
        for (final category in orderedCategories)
          if (!visitedCategoryIds.contains(category.id))
            _buildCategory(
              context,
              category,
              orderedCategories,
              visitedCategoryIds,
            ),
        if (uncategorizedBooks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 12, 6),
            child: Text('未分类书籍'),
          ),
          for (final item in uncategorizedBooks) _buildBook(context, item),
        ],
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context,
    BookCategory category,
    List<BookCategory> orderedCategories,
    Set<String> visitedCategoryIds,
  ) {
    if (!visitedCategoryIds.add(category.id)) {
      return const SizedBox.shrink();
    }
    final categoryIds = _categoryAndDescendantIds(categories, category.id);
    final categoryBooks = books
        .where((item) => item.book.categoryId == category.id)
        .where((item) => notes.any((note) => note.bookId == item.book.id))
        .toList(growable: false);
    final count = notes.where((note) {
      for (final item in books) {
        if (item.book.id == note.bookId &&
            categoryIds.contains(item.book.categoryId)) {
          return true;
        }
      }
      return false;
    }).length;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ExpansionTile(
        key: PageStorageKey<String>('notes-category-${category.id}'),
        initiallyExpanded:
            selectedCategoryId == category.id ||
            categoryBooks.any((item) => item.book.id == selectedBookId),
        leading: const Icon(Icons.folder_outlined),
        title: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count'),
            IconButton(
              tooltip: '查看此文件夹的笔记',
              onPressed: () => onCategorySelected(category.id),
              icon: Icon(
                Icons.filter_alt_outlined,
                color: selectedCategoryId == category.id
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ],
        ),
        children: [
          for (final child in orderedCategories.where(
            (item) => item.parentId == category.id,
          ))
            _buildCategory(
              context,
              child,
              orderedCategories,
              visitedCategoryIds,
            ),
          for (final item in categoryBooks) _buildBook(context, item),
        ],
      ),
    );
  }

  Widget _buildBook(BuildContext context, LibraryBook item) {
    final count = notes.where((note) => note.bookId == item.book.id).length;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: _CollectionTile(
        icon: Icons.menu_book_outlined,
        title: item.book.title,
        count: count,
        selected: selectedBookId == item.book.id,
        onTap: () => onBookSelected(item.book.id),
      ),
    );
  }
}

final class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(icon, size: 20),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('$count', style: Theme.of(context).textTheme.labelSmall),
      onTap: onTap,
    );
  }
}

final class _NotePreview extends StatelessWidget {
  const _NotePreview({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onJump,
  });

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Text(
            note.title?.isNotEmpty == true ? note.title! : '无标题笔记',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(_noteTypeLabel(note.noteType))),
              if (note.locator != null)
                Chip(label: Text(note.locator!.displayLabel)),
            ],
          ),
          if (note.sourceText?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text('原文摘录', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(note.sourceText!),
          ],
          const SizedBox(height: 16),
          Text('内容', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          _SimpleMarkupText(note.content),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onJump,
                icon: const Icon(Icons.open_in_new),
                label: const Text('跳转原文'),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
              ),
              FilledButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on Note {
  bool get canJump => bookId != null && locator != null;
}

IconData _noteIcon(NoteType type) {
  return switch (type) {
    NoteType.text => Icons.edit_note_outlined,
    NoteType.excerpt => Icons.format_quote,
    NoteType.comment => Icons.comment_outlined,
    NoteType.ai => Icons.auto_awesome_outlined,
    NoteType.question => Icons.help_outline,
  };
}

String _noteTypeLabel(NoteType type) {
  return switch (type) {
    NoteType.text => '文字',
    NoteType.excerpt => '摘录',
    NoteType.comment => '批注',
    NoteType.ai => 'AI',
    NoteType.question => '问题',
  };
}

/// Lightweight markup for note preview without pulling a full Markdown package.
final class _SimpleMarkupText extends StatelessWidget {
  const _SimpleMarkupText(this.source);

  final String source;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return SelectableText.rich(
      TextSpan(style: base, children: _parse(source, base)),
    );
  }

  List<InlineSpan> _parse(String text, TextStyle? base) {
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\([^)]+\))',
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('`') &&
          token.endsWith('`') &&
          token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0x22000000),
            ),
          ),
        );
      } else {
        final link = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').firstMatch(token);
        if (link != null) {
          spans.add(
            TextSpan(
              text: link.group(1),
              style: base?.copyWith(
                color: const Color(0xFF1D4ED8),
                decoration: TextDecoration.underline,
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: token));
        }
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }
    return spans;
  }
}

String _sortLabel(_NoteSort sort) {
  return switch (sort) {
    _NoteSort.updatedDesc => '最近更新',
    _NoteSort.updatedAsc => '最早更新',
    _NoteSort.createdDesc => '最近创建',
  };
}

String _noteSummary(Note note) {
  final source = note.sourceText;
  if (source != null && source.isNotEmpty) {
    return '$source\n${note.content}';
  }
  return note.content;
}

String? _bookTitleForNote(List<LibraryBook> books, String? bookId) {
  if (bookId == null) return null;
  for (final item in books) {
    if (item.book.id == bookId) return item.book.title;
  }
  return null;
}

Set<String> _categoryAndDescendantIds(
  List<BookCategory> categories,
  String categoryId,
) {
  final ids = <String>{categoryId};
  var changed = true;
  while (changed) {
    changed = false;
    for (final category in categories) {
      if (category.parentId != null &&
          ids.contains(category.parentId) &&
          ids.add(category.id)) {
        changed = true;
      }
    }
  }
  return ids;
}

List<BookCategory> _orderedCategories(List<BookCategory> categories) {
  final sorted = [...categories]
    ..sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      return order != 0 ? order : left.name.compareTo(right.name);
    });
  final ordered = <BookCategory>[];
  void appendChildren(String? parentId) {
    for (final category in sorted.where((item) => item.parentId == parentId)) {
      ordered.add(category);
      appendChildren(category.id);
    }
  }

  appendChildren(null);
  for (final category in sorted) {
    if (!ordered.any((item) => item.id == category.id)) {
      ordered.add(category);
    }
  }
  return ordered;
}
