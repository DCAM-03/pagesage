import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../domain/annotations/annotation.dart';
import '../../domain/books/book.dart';
import '../../domain/books/reader_fonts.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import '../common/renderer_event.dart';
import 'epub_document.dart';
import 'epub_document_loader.dart';
import 'epub_jump.dart';
import 'epub_paginator.dart';

final class EpubRendererView extends StatefulWidget {
  const EpubRendererView({
    required this.book,
    required this.settings,
    required this.initialProgress,
    required this.annotations,
    required this.onEvent,
    this.searchQuery,
    this.focusLocator,
    this.jumpToken = 0,
    this.documentLoader,
    super.key,
  });

  final Book book;
  final ReaderSettings settings;
  final ReadingProgressSnapshot? initialProgress;
  final List<Annotation> annotations;
  final ValueChanged<RendererEvent> onEvent;
  final String? searchQuery;

  /// Temporary jump target used for flash-highlight after notes/search/bookmarks.
  final ReadingLocator? focusLocator;

  /// Bumped by the host when the reader should jump without remounting.
  final int jumpToken;

  /// How the book is opened.
  ///
  /// A widget test passes its own, because a file read from inside the
  /// fake-async zone of `testWidgets` never settles.
  final EpubDocumentLoader? documentLoader;

  @override
  State<EpubRendererView> createState() => _EpubRendererViewState();
}

final class _EpubRendererViewState extends State<EpubRendererView> {
  late final Future<EpubDocument> _documentFuture;
  final _scrollController = ScrollController();
  final _pageController = PageController();
  Timer? _locationTimer;
  EpubDocument? _document;
  bool _continuousRestored = false;
  bool _pagedRestored = false;
  bool _readySent = false;
  bool _capabilitySent = false;
  String _lastReportedSearchQuery = '';
  List<EpubPage> _lastPages = const [];
  Set<int> _pagedChapterIndexes = const {};
  int _currentPagedPage = 0;

  /// Active chapter for paged mode (only this chapter is measured/paginated).
  int _pagedChapterIndex = 0;
  DateTime _lastWheelPageTurnAt = DateTime.fromMillisecondsSinceEpoch(0);
  double? _lastKnownProgress;
  String? _paginationCacheKey;
  List<EpubPage> _paginationCachePages = const [];
  String? _continuousItemsCacheKey;
  List<_ContinuousListItem> _continuousItems = const [];
  GlobalObjectKey? _jumpTargetKey;
  int? _pendingJumpItemIndex;

  @override
  void initState() {
    super.initState();
    _documentFuture = (widget.documentLoader ?? EpubDocumentLoader()).load(
      widget.book.libraryFilePath,
    );
    _scrollController.addListener(_scheduleLocationReport);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EpubRendererView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged =
        oldWidget.settings.readerMode != widget.settings.readerMode;
    final typographyChanged =
        oldWidget.settings.fontSize != widget.settings.fontSize ||
        oldWidget.settings.lineHeight != widget.settings.lineHeight ||
        oldWidget.settings.pageMargin != widget.settings.pageMargin ||
        oldWidget.settings.paragraphSpacing !=
            widget.settings.paragraphSpacing ||
        oldWidget.settings.fontFamily != widget.settings.fontFamily;
    // Theme-only changes must not reset restore flags / re-jump.
    if (modeChanged || typographyChanged) {
      _continuousRestored = false;
      _pagedRestored = false;
      if (typographyChanged) {
        // Force re-pagination / continuous item rebuild when metrics change.
        _paginationCacheKey = null;
        _continuousItemsCacheKey = null;
      }
      if (modeChanged && widget.settings.readerMode == ReaderMode.paged) {
        final document = _document;
        if (document != null && document.chapters.isNotEmpty) {
          _pagedChapterIndex = document
              .chapterForProgress(_restoreProgress(document))
              .index
              .clamp(0, document.chapters.length - 1);
          _paginationCacheKey = null;
          _currentPagedPage = 0;
        }
      }
    }
    if (oldWidget.jumpToken != widget.jumpToken) {
      // Host requested an in-place jump (TOC / search). Re-apply restore without
      // reloading the document.
      final locator = widget.initialProgress?.locator;
      final document = _document;
      // Prefer the jump locator over the last scroll progress.
      if (locator != null && document != null) {
        if (locator.chapterIndex != null) {
          _lastKnownProgress = document.progressForChapter(
            chapterIndex: locator.chapterIndex!,
            chapterOffset: locator.chapterOffset ?? 0,
          );
        } else {
          _lastKnownProgress = locator.progress;
        }
      }
      _continuousRestored = false;
      _pagedRestored = false;
      if (document != null) {
        if (widget.settings.readerMode == ReaderMode.continuous) {
          _restoreInitialOffset(document);
        } else {
          final jumpChapter = locator?.chapterIndex;
          if (jumpChapter != null &&
              jumpChapter != _pagedChapterIndex &&
              document.chapters.isNotEmpty) {
            _pagedChapterIndex = jumpChapter.clamp(
              0,
              document.chapters.length - 1,
            );
            _paginationCacheKey = null;
            _currentPagedPage = 0;
          }
          // Rebuild supplies chapter pages; restore lands on offset.
          setState(() {});
        }
      }
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _reportSearchResults();
    }
  }

  ({int chapterIndex, int start, int end, String? excerpt})? get _focusRange {
    final locator = widget.focusLocator;
    if (locator == null) {
      return null;
    }
    return epubFocusRangeFor(locator);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return FutureBuilder<EpubDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final message = snapshot.error is EpubLoadException
              ? (snapshot.error! as EpubLoadException).message
              : '无法解析 EPUB 文件';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onEvent(RendererFailed(message));
            }
          });
          return _EpubError(message: message);
        }

        final document = snapshot.data;
        if (document == null) {
          return _EpubLoading(settings: settings);
        }

        _document = document;
        _sendReady();
        _sendCapability();
        _reportSearchResults();

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
                _nextChapter,
            const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
                _previousChapter,
            const SingleActivator(LogicalKeyboardKey.pageDown): _pageForward,
            const SingleActivator(LogicalKeyboardKey.arrowRight): _pageForward,
            const SingleActivator(LogicalKeyboardKey.pageUp): _pageBackward,
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _pageBackward,
          },
          child: Focus(
            autofocus: true,
            child: _EpubThemeBackground(
              settings: settings,
              child: settings.readerMode == ReaderMode.paged
                  ? _buildPagedDocument(context, document, settings)
                  : _buildContinuousDocument(document, settings),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinuousDocument(
    EpubDocument document,
    ReaderSettings settings,
  ) {
    _restoreInitialOffset(document);
    final continuousItems = _continuousItemsFor(document);
    final currentChapterIndex = _currentChapterIndex(document);
    final focusRange = _focusRange;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = _epubHorizontalPadding(
          constraints.maxWidth,
          settings.pageMargin,
        );
        return Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              child: SelectionArea(
                onSelectionChanged: (selection) {
                  _handleContinuousSelectionChanged(document, selection);
                },
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  // Keep off-screen chapters cheap: rebuild on demand instead of
                  // retaining every SelectableText forever.
                  addAutomaticKeepAlives: false,
                  // Prefetch more content so fling feels continuous (Moon+/Kindle).
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1800),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    settings.pageMargin + 8,
                    horizontalPadding,
                    settings.pageMargin + 88,
                  ),
                  itemCount: continuousItems.length,
                  itemBuilder: (context, index) {
                    final item = continuousItems[index];
                    final isJumpTarget = _pendingJumpItemIndex == index;
                    final itemKey = isJumpTarget
                        ? (_jumpTargetKey ??= GlobalObjectKey(
                            'jump-${widget.jumpToken}-$index',
                          ))
                        : ValueKey('item-$index');
                    return Center(
                      key: itemKey,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: switch (item) {
                          _ContinuousChapterBody(:final chapter) => Padding(
                            padding: EdgeInsets.only(
                              top: chapter.index == 0 ? 0 : 20,
                            ),
                            child: _EpubChapterView(
                              chapter: chapter,
                              settings: settings,
                              annotations: widget.annotations,
                              searchQuery: widget.searchQuery,
                              focusRange: focusRange,
                              // Outer ListView already owns SelectionArea.
                              enableSelection: false,
                              bottomPadding: 20,
                              onAnnotationSelected: (annotation) {
                                widget.onEvent(
                                  RendererAnnotationSelected(annotation.id),
                                );
                              },
                              onTextSelected: _reportTextSelected,
                            ),
                          ),
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            _PageTurnZone(
              alignment: Alignment.centerLeft,
              tooltip: '上一页',
              icon: Icons.chevron_left,
              label: '上一页',
              onTap: _pageBackward,
            ),
            _PageTurnZone(
              alignment: Alignment.centerRight,
              tooltip: '下一页',
              icon: Icons.chevron_right,
              label: '下一页',
              onTap: _pageForward,
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 14,
              child: Center(
                child: _ChapterJumpBar(
                  previousEnabled: currentChapterIndex > 0,
                  nextEnabled:
                      currentChapterIndex < document.chapters.length - 1,
                  previousLabel: '上一章',
                  nextLabel: '下一章',
                  onPrevious: _previousChapter,
                  onNext: _nextChapter,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ContinuousListItem> _continuousItemsFor(EpubDocument document) {
    // One list item per chapter. Block splitting happens lazily inside the
    // chapter widget when that row is built — open cost no longer O(all text).
    final key =
        '${widget.book.id}|${document.chapters.length}|${document.totalTextLength}';
    if (_continuousItemsCacheKey == key && _continuousItems.isNotEmpty) {
      return _continuousItems;
    }
    final items = <_ContinuousListItem>[
      for (final chapter in document.chapters) _ContinuousChapterBody(chapter),
    ];
    _continuousItemsCacheKey = key;
    _continuousItems = items;
    return items;
  }

  Widget _buildPagedDocument(
    BuildContext context,
    EpubDocument document,
    ReaderSettings settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _paginateDocument(document, settings, constraints);
        _lastPages = pages;
        _restoreInitialPage(document, pages);
        return Listener(
          onPointerSignal: _handlePagedPointerSignal,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                // Smooth page snaps with enough inertia for finger-follow turns.
                physics: const BouncingScrollPhysics(
                  parent: PageScrollPhysics(),
                ),
                allowImplicitScrolling: true,
                itemCount: pages.length,
                onPageChanged: (index) {
                  _currentPagedPage = index;
                  _reportPagedLocation(document, pages, index);
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final chapterIndex = page.chapter.index;
                  return RepaintBoundary(
                    child: _EpubPagedPageView(
                      page: page,
                      totalBookPages: pages.length,
                      bookPageNumber: index + 1,
                      settings: settings,
                      annotations: widget.annotations,
                      searchQuery: widget.searchQuery,
                      focusRange: _focusRange,
                      hasPreviousChapter: _pagedChapterIndexes.any(
                        (value) => value < chapterIndex,
                      ),
                      hasNextChapter: _pagedChapterIndexes.any(
                        (value) => value > chapterIndex,
                      ),
                      onPreviousChapter: _previousChapter,
                      onNextChapter: _nextChapter,
                      onAnnotationSelected: (annotation) {
                        widget.onEvent(
                          RendererAnnotationSelected(annotation.id),
                        );
                      },
                      onTextSelected: _reportTextSelected,
                    ),
                  );
                },
              ),
              _PageTurnZone(
                alignment: Alignment.centerLeft,
                tooltip: '上一页',
                icon: Icons.chevron_left,
                label: '上一页',
                onTap: _pageBackward,
              ),
              _PageTurnZone(
                alignment: Alignment.centerRight,
                tooltip: '下一页',
                icon: Icons.chevron_right,
                label: '下一页',
                onTap: _pageForward,
              ),
            ],
          ),
        );
      },
    );
  }

  void _restoreInitialOffset(EpubDocument document) {
    if (_continuousRestored) {
      return;
    }
    _continuousRestored = true;
    final locator = widget.initialProgress?.locator;
    final items = _continuousItemsFor(document);
    if (locator != null && locator.chapterIndex != null && items.isNotEmpty) {
      // Continuous list is 1:1 with chapters (lazy body), so the item index
      // is the chapter index clamped into the list.
      final chapterIndex = locator.chapterIndex!.clamp(0, items.length - 1);
      _pendingJumpItemIndex = chapterIndex;
      _jumpTargetKey = GlobalObjectKey(
        'jump-${widget.jumpToken}-$_pendingJumpItemIndex',
      );
    } else {
      _pendingJumpItemIndex = null;
      _jumpTargetKey = null;
    }
    _jumpContinuousToLocator(document, attempt: 0);
  }

  void _jumpContinuousToLocator(EpubDocument document, {required int attempt}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      // ListView may not know full extent on first frame; retry a few times.
      if (max <= 0 && attempt < 12) {
        _jumpContinuousToLocator(document, attempt: attempt + 1);
        return;
      }

      final locator = widget.initialProgress?.locator;
      final targetContext = _jumpTargetKey?.currentContext;
      if (targetContext != null) {
        final reduceMotion = widget.settings.reduceMotion;
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.18,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ).whenComplete(() {
          if (!mounted) {
            return;
          }
          if (locator?.chapterIndex != null) {
            _lastKnownProgress = document.progressForChapter(
              chapterIndex: locator!.chapterIndex!,
              chapterOffset: locator.chapterOffset ?? 0,
            );
          }
          _reportLocationNow(document);
        });
        return;
      }

      // Fallback: coarse progress estimate when the target item is not built yet.
      if (attempt < 12 && _pendingJumpItemIndex != null) {
        final estimated =
            max *
            (_pendingJumpItemIndex! /
                    (_continuousItemsFor(document).length.clamp(1, 1 << 30)))
                .clamp(0.0, 1.0);
        if ((estimated - _scrollController.offset).abs() > 24) {
          _scrollController.jumpTo(estimated.clamp(0.0, max).toDouble());
        }
        _jumpContinuousToLocator(document, attempt: attempt + 1);
        return;
      }

      final target = locator == null
          ? max * _restoreProgress(document).clamp(0.0, 1.0)
          : max *
                document
                    .progressForChapter(
                      chapterIndex:
                          locator.chapterIndex ??
                          document.chapterForProgress(locator.progress).index,
                      chapterOffset: locator.chapterOffset ?? 0,
                    )
                    .clamp(0.0, 1.0);
      final clamped = target.clamp(0.0, max).toDouble();
      if ((_scrollController.offset - clamped).abs() > 1) {
        _scrollController.jumpTo(clamped);
      }
      if (locator?.chapterIndex != null) {
        _lastKnownProgress = document.progressForChapter(
          chapterIndex: locator!.chapterIndex!,
          chapterOffset: locator.chapterOffset ?? 0,
        );
      }
      _reportLocationNow(document);
    });
  }

  void _restoreInitialPage(EpubDocument document, List<EpubPage> pages) {
    if (_pagedRestored) {
      return;
    }
    final locator = widget.initialProgress?.locator;
    if (document.chapters.isNotEmpty) {
      final desiredChapter =
          locator?.chapterIndex ??
          document.chapterForProgress(_restoreProgress(document)).index;
      final clamped = desiredChapter.clamp(0, document.chapters.length - 1);
      if (clamped != _pagedChapterIndex) {
        _pagedChapterIndex = clamped;
        _paginationCacheKey = null;
        _currentPagedPage = 0;
        // Rebuild with the restore chapter before locking restore.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
        return;
      }
    }
    if (pages.isEmpty) {
      return;
    }
    _pagedRestored = true;
    final targetPage = _restorePageIndex(pages, locator);
    _currentPagedPage = targetPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(targetPage);
      _reportPagedLocation(document, pages, targetPage);
    });
  }

  int _nearestPageIndex(List<EpubPage> pages, double progress) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < pages.length; index += 1) {
      final distance = (pages[index].progress - progress).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  double _restoreProgress(EpubDocument document) {
    final current = _lastKnownProgress;
    if (current != null) {
      return current.clamp(0, 1).toDouble();
    }
    final locator = widget.initialProgress?.locator;
    if (locator?.chapterIndex != null) {
      return document.progressForChapter(
        chapterIndex: locator!.chapterIndex!,
        chapterOffset: locator.chapterOffset ?? 0,
      );
    }
    return locator?.progress ?? 0;
  }

  int _restorePageIndex(List<EpubPage> pages, ReadingLocator? locator) {
    if (locator?.chapterIndex != null) {
      final chapterIndex = locator!.chapterIndex!;
      final offset = locator.chapterOffset ?? 0;
      final exact = pages.indexWhere(
        (page) =>
            page.chapter.index == chapterIndex &&
            page.startOffset <= offset &&
            offset <= page.endOffset,
      );
      if (exact >= 0) {
        return exact;
      }
      final next = pages.indexWhere(
        (page) =>
            page.chapter.index == chapterIndex && page.startOffset > offset,
      );
      if (next >= 0) {
        return next;
      }
      final firstInChapter = pages.indexWhere(
        (page) => page.chapter.index == chapterIndex,
      );
      if (firstInChapter >= 0) {
        return firstInChapter;
      }
    }
    return _nearestPageIndex(
      pages,
      locator?.progress ?? _lastKnownProgress ?? 0,
    );
  }

  List<EpubPage> _paginateDocument(
    EpubDocument document,
    ReaderSettings settings,
    BoxConstraints constraints,
  ) {
    if (document.chapters.isEmpty) {
      _paginationCacheKey = null;
      _paginationCachePages = const [];
      _pagedChapterIndexes = const {};
      return const [];
    }
    final chapterIndex = _pagedChapterIndex.clamp(
      0,
      document.chapters.length - 1,
    );
    _pagedChapterIndex = chapterIndex;
    final key = [
      widget.book.id,
      document.chapters.length,
      document.totalTextLength,
      chapterIndex,
      constraints.maxWidth.toStringAsFixed(1),
      constraints.maxHeight.toStringAsFixed(1),
      settings.fontSize.toStringAsFixed(2),
      settings.lineHeight.toStringAsFixed(2),
      settings.paragraphSpacing.toStringAsFixed(2),
      settings.pageMargin.toStringAsFixed(2),
      settings.fontFamily,
    ].join('|');
    if (_paginationCacheKey == key) {
      return _paginationCachePages;
    }
    final pages = _paginateChapterAt(
      document: document,
      chapterIndex: chapterIndex,
      settings: settings,
      viewport: Size(constraints.maxWidth, constraints.maxHeight),
    );
    _paginationCacheKey = key;
    _paginationCachePages = pages;
    // Chapter nav uses document spine, not only currently measured pages.
    _pagedChapterIndexes = {
      for (final chapter in document.chapters) chapter.index,
    };
    return pages;
  }

  List<EpubPage> _paginateChapterAt({
    required EpubDocument document,
    required int chapterIndex,
    required ReaderSettings settings,
    required Size viewport,
  }) {
    if (document.chapters.isEmpty) {
      return const [];
    }
    final index = chapterIndex.clamp(0, document.chapters.length - 1);
    final chapter = document.chapters[index];
    var globalOffset = 0;
    for (final item in document.chapters) {
      if (item.index == chapter.index) {
        break;
      }
      globalOffset += item.text.length;
    }
    final totalLength = document.totalTextLength <= 0
        ? 1
        : document.totalTextLength;
    return const EpubPaginator().paginateChapter(
      chapter: chapter,
      settings: settings,
      viewport: viewport,
      globalOffset: globalOffset,
      totalLength: totalLength,
    );
  }

  /// Switch paged mode to [chapterIndex] and land on first/last page.
  void _loadPagedChapter(
    EpubDocument document, {
    required int chapterIndex,
    required bool openAtEnd,
  }) {
    if (document.chapters.isEmpty) {
      return;
    }
    final next = chapterIndex.clamp(0, document.chapters.length - 1);
    if (next == _pagedChapterIndex && _lastPages.isNotEmpty) {
      final target = openAtEnd ? _lastPages.length - 1 : 0;
      _animateToPagedPage(target);
      return;
    }
    _pagedChapterIndex = next;
    _paginationCacheKey = null;
    _currentPagedPage = 0;
    _pagedRestored = true;
    // Avoid PageController asserting when the new chapter has fewer pages.
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _lastPages.isEmpty) {
        return;
      }
      final target = openAtEnd ? _lastPages.length - 1 : 0;
      _pageController.jumpToPage(target);
      _currentPagedPage = target;
      _reportPagedLocation(document, _lastPages, target);
    });
  }

  void _sendReady() {
    if (_readySent) {
      return;
    }
    _readySent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onEvent(const RendererReady());
      }
    });
  }

  void _sendCapability() {
    if (_capabilitySent) {
      return;
    }
    _capabilitySent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onEvent(
          const RendererCapabilityChanged(textSelection: true, search: true),
        );
      }
    });
  }

  void _reportSearchResults() {
    final document = _document;
    final query = widget.searchQuery?.trim() ?? '';
    if (document == null || _lastReportedSearchQuery == query) {
      return;
    }
    _lastReportedSearchQuery = query;
    final results = query.isEmpty
        ? const <RendererSearchResult>[]
        : _searchDocument(document, query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onEvent(RendererSearchResults(results));
      }
    });
  }

  List<RendererSearchResult> _searchDocument(
    EpubDocument document,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();
    final results = <RendererSearchResult>[];
    for (final chapter in document.chapters) {
      final lowerText = chapter.text.toLowerCase();
      var start = 0;
      while (results.length < 100) {
        final index = lowerText.indexOf(lowerQuery, start);
        if (index < 0) {
          break;
        }
        final snippetStart = (index - 48).clamp(0, chapter.text.length);
        final snippetEnd = (index + query.length + 72).clamp(
          0,
          chapter.text.length,
        );
        final snippet = chapter.text
            .substring(snippetStart, snippetEnd)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        results.add(
          RendererSearchResult(
            title: chapter.title,
            snippet: snippet,
            locator: ReadingLocator.epub(
              href: chapter.href,
              chapterIndex: chapter.index,
              chapterOffset: index,
              chapterEndOffset: index + query.length,
              progress: document.progressForChapterIndex(chapter.index),
              excerpt: snippet,
            ),
          ),
        );
        start = index + query.length;
      }
      if (results.length >= 100) {
        break;
      }
    }
    return results;
  }

  void _scheduleLocationReport() {
    _locationTimer?.cancel();
    // Coalesce continuous-scroll location events so chrome/DB work stays off
    // the hot scroll path.
    _locationTimer = Timer(const Duration(milliseconds: 320), () {
      final document = _document;
      if (document != null) {
        _reportLocationNow(document);
      }
    });
  }

  void _reportLocationNow(EpubDocument document) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final progress = max <= 0
        ? 0.0
        : (position.pixels / max).clamp(0, 1).toDouble();
    _lastKnownProgress = progress;
    final chapter = document.chapterForProgress(progress);
    final chapterOffset = _continuousChapterOffsetNearViewport(
      document,
      chapter,
    );
    final excerpt = _excerptAtChapterOffset(chapter, chapterOffset);
    final refinedProgress = document.progressForChapter(
      chapterIndex: chapter.index,
      chapterOffset: chapterOffset,
    );
    widget.onEvent(
      RendererLocationChanged(
        locator: ReadingLocator.epub(
          href: chapter.href,
          chapterIndex: chapter.index,
          chapterOffset: chapterOffset,
          progress: refinedProgress > 0 ? refinedProgress : progress,
          excerpt: excerpt,
        ),
        progress: refinedProgress > 0 ? refinedProgress : progress,
        chapterTitle: chapter.title,
      ),
    );
  }

  /// Best-effort chapter offset for continuous mode.
  ///
  /// With one list row per chapter, precise fragment offsets are only known
  /// after a jump locator; otherwise report chapter start (progress still works).
  int _continuousChapterOffsetNearViewport(
    EpubDocument document,
    EpubChapter chapter,
  ) {
    final locator = widget.initialProgress?.locator;
    if (locator != null &&
        locator.chapterIndex == chapter.index &&
        locator.chapterOffset != null) {
      return locator.chapterOffset!.clamp(0, chapter.text.length);
    }
    final focus = widget.focusLocator;
    if (focus != null &&
        focus.chapterIndex == chapter.index &&
        focus.chapterOffset != null) {
      return focus.chapterOffset!.clamp(0, chapter.text.length);
    }
    return 0;
  }

  String? _excerptAtChapterOffset(EpubChapter chapter, int chapterOffset) {
    final text = chapter.text;
    if (text.isEmpty) {
      return null;
    }
    final start = chapterOffset.clamp(0, text.length);
    final end = (start + 96).clamp(start, text.length);
    if (end <= start) {
      return null;
    }
    return compactLocatorExcerpt(text.substring(start, end));
  }

  void _reportPagedLocation(
    EpubDocument document,
    List<EpubPage> pages,
    int index,
  ) {
    if (pages.isEmpty) {
      return;
    }
    final page = pages[index.clamp(0, pages.length - 1).toInt()];
    _lastKnownProgress = page.progress;
    final excerpt = _excerptAtChapterOffset(page.chapter, page.startOffset);
    widget.onEvent(
      RendererLocationChanged(
        locator: ReadingLocator.epub(
          href: page.chapter.href,
          chapterIndex: page.chapter.index,
          chapterOffset: page.startOffset,
          chapterEndOffset: page.endOffset,
          progress: page.progress,
          excerpt: excerpt,
        ),
        progress: page.progress,
        chapterTitle: page.chapter.title,
      ),
    );
  }

  void _handleContinuousSelectionChanged(
    EpubDocument document,
    SelectedContent? selection,
  ) {
    final plain = selection?.plainText.trim() ?? '';
    if (plain.isEmpty) {
      return;
    }
    for (final chapter in document.chapters) {
      final index = chapter.text.indexOf(plain);
      if (index < 0) {
        continue;
      }
      _reportTextSelected(
        _EpubTextSelection(
          chapter: chapter,
          text: plain,
          startOffset: index,
          endOffset: index + plain.length,
        ),
      );
      return;
    }
    final chapter = document.chapterForProgress(_lastKnownProgress ?? 0);
    final loose = chapter.text.indexOf(plain);
    _reportTextSelected(
      _EpubTextSelection(
        chapter: chapter,
        text: plain,
        startOffset: loose < 0 ? 0 : loose,
        endOffset: loose < 0 ? plain.length : loose + plain.length,
      ),
    );
  }

  void _reportTextSelected(_EpubTextSelection selection) {
    final selected = selection.text.trim();
    if (selected.isEmpty) {
      return;
    }
    final progress =
        widget.settings.readerMode == ReaderMode.paged && _lastPages.isNotEmpty
        ? _lastPages[_currentPagedPage.clamp(0, _lastPages.length - 1).toInt()]
              .progress
        : 0.0;
    widget.onEvent(
      RendererTextSelected(
        text: selected,
        locator: ReadingLocator.epub(
          href: selection.chapter.href,
          chapterIndex: selection.chapter.index,
          chapterOffset: selection.startOffset,
          chapterEndOffset: selection.endOffset,
          progress: progress,
          excerpt: selected,
        ),
      ),
    );
  }

  void _pageForward() {
    if (widget.settings.readerMode == ReaderMode.paged &&
        _lastPages.isNotEmpty) {
      _turnPagedPage(1);
      return;
    }
    _scrollByViewport(1);
  }

  void _pageBackward() {
    if (widget.settings.readerMode == ReaderMode.paged &&
        _lastPages.isNotEmpty) {
      _turnPagedPage(-1);
      return;
    }
    _scrollByViewport(-1);
  }

  void _handlePagedPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _lastPages.isEmpty) {
      return;
    }
    final primaryDelta =
        event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (primaryDelta.abs() < 4) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastWheelPageTurnAt) <
        const Duration(milliseconds: 180)) {
      return;
    }
    _lastWheelPageTurnAt = now;
    // Wheel turns should feel immediate; animation is for buttons/keys only.
    _jumpToPagedPage(primaryDelta > 0 ? 1 : -1);
  }

  void _jumpToPagedPage(int direction) {
    final document = _document;
    if (!_pageController.hasClients || _lastPages.isEmpty || document == null) {
      return;
    }
    final target = _currentPagedPage + direction;
    if (target >= 0 && target < _lastPages.length) {
      if (target == _currentPagedPage) {
        return;
      }
      _pageController.jumpToPage(target);
      _currentPagedPage = target;
      _reportPagedLocation(document, _lastPages, target);
      return;
    }
    // Cross chapter boundary: paginate neighbor chapter only.
    final neighbor = _pagedChapterIndex + (direction > 0 ? 1 : -1);
    if (neighbor < 0 || neighbor >= document.chapters.length) {
      return;
    }
    _loadPagedChapter(
      document,
      chapterIndex: neighbor,
      openAtEnd: direction < 0,
    );
  }

  void _nextChapter() {
    _goToRelativeChapter(1);
  }

  void _previousChapter() {
    _goToRelativeChapter(-1);
  }

  void _goToRelativeChapter(int direction) {
    final document = _document;
    if (document == null || document.chapters.isEmpty) {
      return;
    }
    final currentChapterIndex = _currentChapterIndex(document);
    final targetChapterIndex = (currentChapterIndex + direction).clamp(
      0,
      document.chapters.length - 1,
    );
    if (targetChapterIndex == currentChapterIndex) {
      return;
    }
    if (widget.settings.readerMode == ReaderMode.paged) {
      _loadPagedChapter(
        document,
        chapterIndex: targetChapterIndex,
        openAtEnd: false,
      );
      return;
    }
    _scrollToChapter(document, targetChapterIndex);
  }

  int _currentChapterIndex(EpubDocument document) {
    if (widget.settings.readerMode == ReaderMode.paged &&
        _lastPages.isNotEmpty) {
      return _lastPages[_currentPagedPage
              .clamp(0, _lastPages.length - 1)
              .toInt()]
          .chapter
          .index;
    }
    final progress = _lastKnownProgress ?? 0;
    return document.chapterForProgress(progress).index;
  }

  void _animateToPagedPage(int target) {
    if (!_pageController.hasClients || _lastPages.isEmpty) {
      return;
    }
    final duration = widget.settings.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    if (duration == Duration.zero) {
      _pageController.jumpToPage(target);
      _currentPagedPage = target;
      final document = _document;
      if (document != null) {
        _reportPagedLocation(document, _lastPages, target);
      }
      return;
    }
    unawaited(
      _pageController
          .animateToPage(target, duration: duration, curve: Curves.easeOutCubic)
          .then((_) {
            final document = _document;
            if (mounted && document != null) {
              _currentPagedPage = target;
              _reportPagedLocation(document, _lastPages, target);
            }
          }),
    );
  }

  void _scrollToChapter(EpubDocument document, int chapterIndex) {
    if (!_scrollController.hasClients) {
      return;
    }
    final progress = document.progressForChapterIndex(chapterIndex);
    final items = _continuousItemsFor(document);
    if (items.isNotEmpty) {
      final itemIndex = chapterIndex.clamp(0, items.length - 1);
      if (itemIndex >= 0) {
        _pendingJumpItemIndex = itemIndex;
        _jumpTargetKey = GlobalObjectKey(
          'chapter-jump-${widget.jumpToken}-$itemIndex',
        );
        // Force one rebuild so the target item key is attached, then ensureVisible.
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final targetContext = _jumpTargetKey?.currentContext;
          if (targetContext != null) {
            unawaited(
              Scrollable.ensureVisible(
                targetContext,
                alignment: 0.08,
                duration: Duration.zero,
              ),
            );
          } else if (_scrollController.hasClients) {
            final position = _scrollController.position;
            final ratio = (itemIndex / items.length).clamp(0, 1).toDouble();
            final target = (position.maxScrollExtent * ratio).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            );
            _scrollController.jumpTo(target.toDouble());
          }
          _lastKnownProgress = progress;
          _reportLocationNow(document);
        });
        return;
      }
    }
    final position = _scrollController.position;
    final target = (position.maxScrollExtent * progress).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.jumpTo(target.toDouble());
    _lastKnownProgress = progress;
    _reportLocationNow(document);
  }

  void _turnPagedPage(int direction) {
    final document = _document;
    if (!_pageController.hasClients || _lastPages.isEmpty || document == null) {
      return;
    }
    final target = _currentPagedPage + direction;
    if (target < 0 || target >= _lastPages.length) {
      final neighbor = _pagedChapterIndex + (direction > 0 ? 1 : -1);
      if (neighbor < 0 || neighbor >= document.chapters.length) {
        return;
      }
      _loadPagedChapter(
        document,
        chapterIndex: neighbor,
        openAtEnd: direction < 0,
      );
      return;
    }
    if (target == _currentPagedPage) {
      return;
    }
    // Keep page turns snappy; long ease animations feel laggy under wheel/keys.
    final duration = widget.settings.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 140);
    if (duration == Duration.zero) {
      _pageController.jumpToPage(target);
      _currentPagedPage = target;
      _reportPagedLocation(document, _lastPages, target);
      return;
    }
    unawaited(
      _pageController
          .animateToPage(target, duration: duration, curve: Curves.easeOut)
          .then((_) {
            if (mounted && _document != null) {
              _currentPagedPage = target;
              _reportPagedLocation(_document!, _lastPages, target);
            }
          }),
    );
  }

  void _scrollByViewport(int direction) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final delta =
        viewport * (widget.settings.readerMode == ReaderMode.paged ? 1 : 0.86);
    final target = (position.pixels + direction * delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final duration = widget.settings.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    if (duration == Duration.zero) {
      _scrollController.jumpTo(target.toDouble());
      final document = _document;
      if (document != null) {
        _reportLocationNow(document);
      }
      return;
    }
    unawaited(
      _scrollController
          .animateTo(
            target.toDouble(),
            duration: duration,
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            final document = _document;
            if (mounted && document != null) {
              _reportLocationNow(document);
            }
          }),
    );
  }
}

double _epubHorizontalPadding(double viewportWidth, double requestedMargin) {
  final baseMargin = requestedMargin.clamp(18, 48).toDouble();
  if (viewportWidth <= 0 || viewportWidth <= 760 + baseMargin * 2) {
    return baseMargin;
  }
  return ((viewportWidth - 760) / 2).clamp(baseMargin, 160).toDouble();
}

final class _PageTurnZone extends StatefulWidget {
  const _PageTurnZone({
    required this.alignment,
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Alignment alignment;
  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PageTurnZone> createState() => _PageTurnZoneState();
}

final class _PageTurnZoneState extends State<_PageTurnZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: widget.alignment,
      child: Tooltip(
        message: widget.tooltip,
        child: SizedBox(
          width: 96,
          height: double.infinity,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTap,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hovered ? 1 : 0.18,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: EdgeInsets.symmetric(
                      horizontal: _hovered ? 10 : 6,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: 22,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        if (_hovered) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ChapterJumpBar extends StatefulWidget {
  const _ChapterJumpBar({
    required this.previousEnabled,
    required this.nextEnabled,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final bool previousEnabled;
  final bool nextEnabled;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<_ChapterJumpBar> createState() => _ChapterJumpBarState();
}

final class _ChapterJumpBarState extends State<_ChapterJumpBar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: _hovered ? 1 : 0.72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: widget.previousEnabled ? widget.onPrevious : null,
                  icon: const Icon(Icons.skip_previous_outlined, size: 18),
                  label: Text(widget.previousLabel),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                SizedBox(
                  height: 22,
                  child: VerticalDivider(color: colorScheme.outlineVariant),
                ),
                TextButton.icon(
                  onPressed: widget.nextEnabled ? widget.onNext : null,
                  icon: const Icon(Icons.skip_next_outlined, size: 18),
                  label: Text(widget.nextLabel),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _EpubPagedPageView extends StatelessWidget {
  const _EpubPagedPageView({
    required this.page,
    required this.totalBookPages,
    required this.bookPageNumber,
    required this.settings,
    required this.annotations,
    required this.searchQuery,
    required this.focusRange,
    required this.hasPreviousChapter,
    required this.hasNextChapter,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onAnnotationSelected,
    required this.onTextSelected,
  });

  final EpubPage page;
  final int totalBookPages;
  final int bookPageNumber;
  final ReaderSettings settings;
  final List<Annotation> annotations;
  final String? searchQuery;
  final ({int chapterIndex, int start, int end, String? excerpt})? focusRange;
  final bool hasPreviousChapter;
  final bool hasNextChapter;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<Annotation> onAnnotationSelected;
  final ValueChanged<_EpubTextSelection> onTextSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = settings.themePreset.foreground;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: settings.pageMargin,
        vertical: (settings.pageMargin * 0.72).clamp(12, 36).toDouble(),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      page.chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: textColor.withValues(alpha: 0.64),
                      ),
                    ),
                  ),
                  Text(
                    '${page.pageNumberInChapter}/${page.totalPagesInChapter}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: textColor.withValues(alpha: 0.56),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 12),
                      child: _EpubChapterView(
                        chapter: page.chapter,
                        settings: settings,
                        annotations: annotations,
                        searchQuery: searchQuery,
                        focusRange: focusRange,
                        fragments: page.fragments,
                        showTitle: false,
                        bottomPadding: 0,
                        onAnnotationSelected: onAnnotationSelected,
                        onTextSelected: onTextSelected,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: hasPreviousChapter ? onPreviousChapter : null,
                    icon: const Icon(Icons.skip_previous_outlined, size: 18),
                    label: const Text('上一章'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: textColor.withValues(alpha: 0.72),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // Paged mode measures one chapter at a time.
                        '本章 $bookPageNumber / $totalBookPages',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${(page.progress * 100).round()}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.46),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: hasNextChapter ? onNextChapter : null,
                    icon: const Icon(Icons.skip_next_outlined, size: 18),
                    label: const Text('下一章'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: textColor.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EpubChapterView extends StatefulWidget {
  const _EpubChapterView({
    required this.chapter,
    required this.settings,
    required this.annotations,
    required this.searchQuery,
    required this.onAnnotationSelected,
    required this.onTextSelected,
    this.focusRange,
    this.fragments,
    this.showTitle = true,
    this.bottomPadding = 32,
    this.enableSelection = true,
  });

  final EpubChapter chapter;
  final ReaderSettings settings;
  final List<Annotation> annotations;
  final String? searchQuery;
  final ({int chapterIndex, int start, int end, String? excerpt})? focusRange;
  final ValueChanged<Annotation> onAnnotationSelected;
  final ValueChanged<_EpubTextSelection> onTextSelected;
  final List<EpubPageFragment>? fragments;
  final bool showTitle;
  final double bottomPadding;

  /// When false, parent owns SelectionArea (continuous mode).
  final bool enableSelection;

  @override
  State<_EpubChapterView> createState() => _EpubChapterViewState();
}

final class _EpubChapterViewState extends State<_EpubChapterView> {
  List<EpubPageFragment>? _cachedFragments;
  Object? _fragmentsSource;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final textColor = settings.themePreset.foreground;
    final fragments = _fragmentsForChapter();

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Text(
            widget.chapter.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: textColor),
          ),
          const SizedBox(height: 16),
        ],
        for (final fragment in fragments)
          _EpubFragmentView(
            chapter: widget.chapter,
            fragment: fragment,
            settings: settings,
            annotations: widget.annotations,
            searchQuery: widget.searchQuery,
            focusRange: widget.focusRange,
            onAnnotationSelected: widget.onAnnotationSelected,
            onTextSelected: widget.onTextSelected,
          ),
      ],
    );

    // In paged mode the parent gives a tight height. Measurement deltas can
    // still leave content a few pixels taller; never assert-overflow the page.
    final selectableBody = widget.enableSelection
        ? SelectionArea(
            onSelectionChanged: (selection) {
              _handleChapterSelectionChanged(selection);
            },
            child: body,
          )
        : body;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.hasBoundedHeight;
          if (!hasBoundedHeight) {
            return selectableBody;
          }
          return ClipRect(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  child: selectableBody,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleChapterSelectionChanged(SelectedContent? selection) {
    final plain = selection?.plainText.trim() ?? '';
    if (plain.isEmpty) {
      return;
    }
    final chapter = widget.chapter;
    final index = chapter.text.indexOf(plain);
    widget.onTextSelected(
      _EpubTextSelection(
        chapter: chapter,
        text: plain,
        startOffset: index < 0 ? 0 : index,
        endOffset: index < 0 ? plain.length : index + plain.length,
      ),
    );
  }

  List<EpubPageFragment> _fragmentsForChapter() {
    final provided = widget.fragments;
    if (provided != null) {
      return provided;
    }
    if (identical(_fragmentsSource, widget.chapter) &&
        _cachedFragments != null) {
      return _cachedFragments!;
    }
    final fragments = epubBlocks(widget.chapter)
        .map(
          (block) => EpubPageFragment(
            chapterIndex: widget.chapter.index,
            href: widget.chapter.href,
            startOffset: block.startOffset,
            endOffset: block.endOffset,
            text: block.text,
            blockType: block.type,
            image: block.image,
          ),
        )
        .toList(growable: false);
    _fragmentsSource = widget.chapter;
    _cachedFragments = fragments;
    return fragments;
  }
}

final class _EpubFragmentView extends StatefulWidget {
  const _EpubFragmentView({
    required this.chapter,
    required this.fragment,
    required this.settings,
    required this.annotations,
    required this.searchQuery,
    required this.onAnnotationSelected,
    required this.onTextSelected,
    this.focusRange,
  });

  final EpubChapter chapter;
  final EpubPageFragment fragment;
  final ReaderSettings settings;
  final List<Annotation> annotations;
  final String? searchQuery;
  final ({int chapterIndex, int start, int end, String? excerpt})? focusRange;
  final ValueChanged<Annotation> onAnnotationSelected;
  final ValueChanged<_EpubTextSelection> onTextSelected;

  @override
  State<_EpubFragmentView> createState() => _EpubFragmentViewState();
}

final class _EpubFragmentViewState extends State<_EpubFragmentView> {
  final List<GestureRecognizer> _inlineRecognizers = [];
  List<InlineSpan>? _cachedSpans;
  TextStyle? _cachedBaseStyle;
  Object? _spanCacheKey;

  @override
  void didUpdateWidget(covariant _EpubFragmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter != widget.chapter ||
        oldWidget.fragment != widget.fragment) {
      _invalidateSpanCache();
    }
    if (oldWidget.annotations != widget.annotations ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.focusRange != widget.focusRange ||
        oldWidget.settings != widget.settings) {
      _invalidateSpanCache();
    }
  }

  @override
  void dispose() {
    _disposeInlineRecognizers();
    super.dispose();
  }

  void _invalidateSpanCache() {
    _disposeInlineRecognizers();
    _cachedSpans = null;
    _cachedBaseStyle = null;
    _spanCacheKey = null;
  }

  void _disposeInlineRecognizers() {
    for (final recognizer in _inlineRecognizers) {
      recognizer.dispose();
    }
    _inlineRecognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final fragment = widget.fragment;
    if (fragment.blockType == EpubBlockType.image) {
      return Padding(
        padding: EdgeInsets.only(bottom: _spacingForFragment(fragment)),
        child: _EpubImageView(settings: widget.settings, image: fragment.image),
      );
    }
    final style = _styleForFragment(fragment, _baseStyle());
    // Use plain Text.rich so a parent SelectionArea can span multiple
    // paragraphs. SelectableText creates isolated selection regions.
    final text = Text.rich(
      TextSpan(style: style, children: _spansFor(style)),
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      textAlign: fragment.blockType == EpubBlockType.heading
          ? TextAlign.start
          : TextAlign.left,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: _spacingForFragment(fragment)),
      child: switch (fragment.blockType) {
        EpubBlockType.code => _EpubCodeBlock(
          settings: widget.settings,
          child: text,
        ),
        EpubBlockType.caption => _EpubCaption(child: text),
        EpubBlockType.image ||
        EpubBlockType.heading ||
        EpubBlockType.paragraph => text,
      },
    );
  }

  TextStyle _baseStyle() {
    final settings = widget.settings;
    final textColor = settings.themePreset.foreground;
    final family = ReaderFonts.renderFamilyFor(settings.fontFamily);
    return TextStyle(
      color: textColor,
      fontFamily: family.isEmpty ? null : family,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontWeight: settings.themePreset.epubInk ? FontWeight.w400 : null,
      shadows: settings.themePreset.epubInk
          ? [
              Shadow(
                color: textColor.withValues(alpha: 0.10),
                offset: const Offset(0.25, 0.25),
              ),
            ]
          : null,
    );
  }

  double _spacingForFragment(EpubPageFragment fragment) {
    return switch (fragment.blockType) {
      EpubBlockType.heading => widget.settings.paragraphSpacing * 1.55,
      EpubBlockType.code => widget.settings.paragraphSpacing * 1.35,
      EpubBlockType.caption => widget.settings.paragraphSpacing * 0.6,
      EpubBlockType.image => widget.settings.paragraphSpacing * 1.2,
      EpubBlockType.paragraph => widget.settings.paragraphSpacing,
    };
  }

  TextStyle _styleForFragment(EpubPageFragment fragment, TextStyle baseStyle) {
    return switch (fragment.blockType) {
      EpubBlockType.heading => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 1.22,
        fontWeight: FontWeight.w700,
        height: (baseStyle.height ?? 1.5) * 0.92,
      ),
      EpubBlockType.code => baseStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: baseStyle.fontSize! * 0.92,
        height: 1.52,
      ),
      EpubBlockType.caption => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 0.88,
        height: (baseStyle.height ?? 1.5) * 0.95,
        color: baseStyle.color?.withValues(alpha: 0.72),
      ),
      EpubBlockType.image || EpubBlockType.paragraph => baseStyle,
    };
  }

  List<InlineSpan> _spansFor(TextStyle style) {
    final focus = widget.focusRange;
    final cacheKey = Object.hash(
      widget.fragment.startOffset,
      widget.fragment.endOffset,
      widget.fragment.text,
      widget.searchQuery,
      focus?.chapterIndex,
      focus?.start,
      focus?.end,
      focus?.excerpt,
      widget.annotations.length,
      widget.settings.themePreset,
      style.fontSize,
      style.height,
      style.fontFamily,
      style.fontWeight,
    );
    if (_spanCacheKey == cacheKey &&
        _cachedSpans != null &&
        _cachedBaseStyle == style) {
      return _cachedSpans!;
    }
    _disposeInlineRecognizers();
    final spans = _buildTextSpans(widget.fragment, style);
    _spanCacheKey = cacheKey;
    _cachedSpans = spans;
    _cachedBaseStyle = style;
    return spans;
  }

  List<InlineSpan> _buildTextSpans(
    EpubPageFragment fragment,
    TextStyle baseStyle,
  ) {
    final text = fragment.text;
    final chapter = widget.chapter;
    final chapterAnnotations = widget.annotations
        .where((annotation) {
          final locatorChapter = annotation.locator.chapterIndex;
          return locatorChapter == null || locatorChapter == chapter.index;
        })
        .toList(growable: false);
    final query = widget.searchQuery?.trim();
    final focusRange = widget.focusRange;
    final hasFocus =
        focusRange != null && focusRange.chapterIndex == chapter.index;
    if (chapterAnnotations.isEmpty &&
        (query == null || query.isEmpty) &&
        !hasFocus) {
      return [TextSpan(text: text)];
    }

    final matches = <_AnnotationMatch>[];
    for (final annotation in chapterAnnotations) {
      final selected = annotation.selectedText.trim();
      if (selected.isEmpty) {
        continue;
      }
      final locatorStart = annotation.locator.chapterOffset;
      if (locatorStart != null &&
          annotation.locator.chapterIndex == chapter.index) {
        final locatorEnd =
            annotation.locator.chapterEndOffset ??
            locatorStart + selected.length;
        final overlapStart = locatorStart > fragment.startOffset
            ? locatorStart
            : fragment.startOffset;
        final overlapEnd = locatorEnd < fragment.endOffset
            ? locatorEnd
            : fragment.endOffset;
        if (overlapStart < overlapEnd) {
          matches.add(
            _AnnotationMatch(
              start: overlapStart - fragment.startOffset,
              end: overlapEnd - fragment.startOffset,
              annotation: annotation,
            ),
          );
        }
        continue;
      }
      var start = 0;
      while (true) {
        final index = text.indexOf(selected, start);
        if (index < 0) {
          break;
        }
        matches.add(
          _AnnotationMatch(
            start: index,
            end: index + selected.length,
            annotation: annotation,
          ),
        );
        start = index + selected.length;
      }
    }

    if (query != null && query.isNotEmpty) {
      final lowerText = text.toLowerCase();
      final lowerQuery = query.toLowerCase();
      var start = 0;
      while (true) {
        final index = lowerText.indexOf(lowerQuery, start);
        if (index < 0) {
          break;
        }
        matches.add(
          _AnnotationMatch(
            start: index,
            end: index + query.length,
            annotation: null,
            isSearchHit: true,
          ),
        );
        start = index + query.length;
      }
    }

    if (hasFocus) {
      final focusStart = focusRange.start;
      final focusEnd = focusRange.end;
      if (focusEnd > focusStart) {
        final overlapStart = focusStart > fragment.startOffset
            ? focusStart
            : fragment.startOffset;
        final overlapEnd = focusEnd < fragment.endOffset
            ? focusEnd
            : fragment.endOffset;
        if (overlapStart < overlapEnd) {
          matches.add(
            _AnnotationMatch(
              start: overlapStart - fragment.startOffset,
              end: overlapEnd - fragment.startOffset,
              annotation: null,
              isFocusHit: true,
            ),
          );
        }
      } else {
        final excerpt = focusRange.excerpt?.trim();
        if (excerpt != null && excerpt.isNotEmpty) {
          final lowerText = text.toLowerCase();
          final lowerExcerpt = excerpt.toLowerCase();
          final index = lowerText.indexOf(lowerExcerpt);
          if (index >= 0) {
            matches.add(
              _AnnotationMatch(
                start: index,
                end: index + excerpt.length,
                annotation: null,
                isFocusHit: true,
              ),
            );
          } else {
            // Fallback: match a shorter prefix when full excerpt was truncated.
            final needle = lowerExcerpt.length > 24
                ? lowerExcerpt.substring(0, 24)
                : lowerExcerpt;
            final soft = lowerText.indexOf(needle);
            if (soft >= 0) {
              matches.add(
                _AnnotationMatch(
                  start: soft,
                  end: soft + needle.length,
                  annotation: null,
                  isFocusHit: true,
                ),
              );
            }
          }
        }
      }
    }

    matches.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) {
        return startCompare;
      }
      // Prefer permanent annotations over temporary focus/search paint.
      if (a.annotation != null && b.annotation == null) {
        return -1;
      }
      if (a.annotation == null && b.annotation != null) {
        return 1;
      }
      if (a.isFocusHit == b.isFocusHit && a.isSearchHit == b.isSearchHit) {
        return 0;
      }
      if (a.isFocusHit != b.isFocusHit) {
        return a.isFocusHit ? 1 : -1;
      }
      return a.isSearchHit ? 1 : -1;
    });
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in matches) {
      if (match.start < offset) {
        continue;
      }
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      if (match.isFocusHit) {
        spans.add(
          TextSpan(
            text: text.substring(match.start, match.end),
            style: baseStyle.copyWith(backgroundColor: _focusHitColor()),
          ),
        );
      } else if (match.isSearchHit) {
        spans.add(
          TextSpan(
            text: text.substring(match.start, match.end),
            style: baseStyle.copyWith(backgroundColor: _searchHitColor()),
          ),
        );
      } else {
        final annotation = match.annotation!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onAnnotationSelected(annotation);
        _inlineRecognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: text.substring(match.start, match.end),
            recognizer: recognizer,
            style: baseStyle.copyWith(
              backgroundColor: annotation.style == AnnotationStyle.highlight
                  ? _highlightColor(annotation.color)
                  : null,
              decoration: annotation.style == AnnotationStyle.underline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: _highlightColor(annotation.color),
              decorationThickness: 2,
            ),
          ),
        );
      }
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    return spans;
  }

  Color _highlightColor(AnnotationColor color) {
    final settings = widget.settings;
    final contrast = settings.themePreset == ReaderThemePreset.contrast;
    final night = settings.themePreset == ReaderThemePreset.night;
    final ink = settings.themePreset.epubInk;
    return switch ((color, night, ink, contrast)) {
      (AnnotationColor.yellow, _, _, true) => const Color(0xFFFFFF00),
      (AnnotationColor.blue, _, _, true) => const Color(0xFFB9E7FF),
      (AnnotationColor.green, _, _, true) => const Color(0xFFC6F6C6),
      (AnnotationColor.red, _, _, true) => const Color(0xFFFFD0D0),
      (AnnotationColor.purple, _, _, true) => const Color(0xFFE1D5FF),
      (AnnotationColor.yellow, false, false, false) => const Color(0x99FFE58A),
      (AnnotationColor.blue, false, false, false) => const Color(0x99B9D7FF),
      (AnnotationColor.green, false, false, false) => const Color(0x99BDECCB),
      (AnnotationColor.red, false, false, false) => const Color(0x99FFB8B8),
      (AnnotationColor.purple, false, false, false) => const Color(0x99D8C7FF),
      (AnnotationColor.yellow, true, false, false) => const Color(0x668C7A2A),
      (AnnotationColor.blue, true, false, false) => const Color(0x6651768F),
      (AnnotationColor.green, true, false, false) => const Color(0x66527A5F),
      (AnnotationColor.red, true, false, false) => const Color(0x66805858),
      (AnnotationColor.purple, true, false, false) => const Color(0x666B5C8C),
      (AnnotationColor.yellow, _, true, false) => const Color(0x668F8658),
      (AnnotationColor.blue, _, true, false) => const Color(0x665F7480),
      (AnnotationColor.green, _, true, false) => const Color(0x666B7C62),
      (AnnotationColor.red, _, true, false) => const Color(0x667F6662),
      (AnnotationColor.purple, _, true, false) => const Color(0x66716A80),
    };
  }

  Color _focusHitColor() {
    final settings = widget.settings;
    final contrast = settings.themePreset == ReaderThemePreset.contrast;
    final night = settings.themePreset == ReaderThemePreset.night;
    if (contrast) {
      return const Color(0xFFFFF59D);
    }
    if (night) {
      return const Color(0x99E6B422);
    }
    return const Color(0xCCFFE066);
  }

  Color _searchHitColor() {
    final settings = widget.settings;
    if (settings.themePreset == ReaderThemePreset.contrast) {
      return const Color(0xFFFFFF00);
    }
    if (settings.themePreset.epubInk) {
      return const Color(0x667D775D);
    }
    return const Color(0x99FFD659);
  }
}

sealed class _ContinuousListItem {
  const _ContinuousListItem();
}

/// Continuous-mode row: whole chapter body, split lazily when painted.
final class _ContinuousChapterBody extends _ContinuousListItem {
  const _ContinuousChapterBody(this.chapter);

  final EpubChapter chapter;
}

final class _EpubCodeBlock extends StatelessWidget {
  const _EpubCodeBlock({required this.settings, required this.child});

  final ReaderSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final foreground = settings.themePreset.foreground;
    final backgroundAlpha = settings.themePreset == ReaderThemePreset.night
        ? 0.10
        : 0.055;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: foreground.withValues(alpha: 0.13)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      ),
    );
  }
}

/// A picture from the book.
///
/// The picture is drawn at the width of the text column, at the
/// proportions it was made at. Nothing is filtered or inverted: a
/// photograph that looks wrong under a night theme is worse than a
/// photograph that is a little bright.
final class _EpubImageView extends StatelessWidget {
  const _EpubImageView({required this.settings, required this.image});

  final ReaderSettings settings;
  final EpubImage? image;

  @override
  Widget build(BuildContext context) {
    final picture = image;
    if (picture == null || !picture.isAvailable) {
      return _EpubImagePlaceholder(
        settings: settings,
        label: picture?.unavailableReason ?? '图片',
        alt: picture?.alt,
      );
    }
    return Semantics(
      label: picture.alt ?? '插图',
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The picture is drawn at the width of the column, unless it is
          // smaller than that to begin with: an icon stretched across the
          // page is a blur, and a book that meant it as an icon should
          // look like one.
          final available = constraints.maxWidth;
          final width = picture.pixelWidth > 0 && picture.pixelWidth < available
              ? picture.pixelWidth.toDouble()
              : available;
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              picture.bytes,
              fit: BoxFit.contain,
              width: width,
              errorBuilder: (context, error, stackTrace) =>
                  _EpubImagePlaceholder(
                    settings: settings,
                    label: '图片无法显示',
                    alt: picture.alt,
                  ),
            ),
          );
        },
      ),
    );
  }
}

/// A figure's caption: quieter than the prose around it.
final class _EpubCaption extends StatelessWidget {
  const _EpubCaption({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodySmall,
      child: child,
    );
  }
}

final class _EpubImagePlaceholder extends StatelessWidget {
  const _EpubImagePlaceholder({
    required this.settings,
    required this.label,
    this.alt,
  });

  final ReaderSettings settings;
  final String label;

  /// The book's own description of the picture, shown under the reason.
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final foreground = settings.themePreset.foreground;
    final normalizedLabel = label.trim().isEmpty ? '图片占位' : label.trim();
    final altText = alt?.trim();
    return Semantics(
      label: altText == null || altText.isEmpty
          ? normalizedLabel
          : '$normalizedLabel：$altText',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: foreground.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.image_outlined,
                size: 20,
                color: foreground.withValues(alpha: 0.58),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      normalizedLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.68),
                      ),
                    ),
                    if (altText != null && altText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        altText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.52),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EpubThemeBackground extends StatelessWidget {
  const _EpubThemeBackground({required this.settings, required this.child});

  final ReaderSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!settings.themePreset.epubInk) {
      return ColoredBox(color: settings.themePreset.background, child: child);
    }
    return ColoredBox(
      color: settings.themePreset.background,
      child: CustomPaint(
        painter: _EInkPaperPainter(
          color: settings.themePreset.foreground.withValues(alpha: 0.035),
        ),
        child: child,
      ),
    );
  }
}

final class _EInkPaperPainter extends CustomPainter {
  const _EInkPaperPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()..color = color.withValues(alpha: 0.7);
    for (var y = 3.0; y < size.height; y += 23) {
      for (var x = (y.toInt() % 17).toDouble(); x < size.width; x += 31) {
        canvas.drawCircle(Offset(x, y), 0.45, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EInkPaperPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

final class _AnnotationMatch {
  const _AnnotationMatch({
    required this.start,
    required this.end,
    required this.annotation,
    this.isSearchHit = false,
    this.isFocusHit = false,
  });

  final int start;
  final int end;
  final Annotation? annotation;
  final bool isSearchHit;
  final bool isFocusHit;
}

final class _EpubTextSelection {
  const _EpubTextSelection({
    required this.chapter,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final EpubChapter chapter;
  final String text;
  final int startOffset;
  final int endOffset;
}

final class _EpubLoading extends StatelessWidget {
  const _EpubLoading({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: settings.themePreset.background,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

final class _EpubError extends StatelessWidget {
  const _EpubError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
