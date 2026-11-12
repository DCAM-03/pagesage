import 'dart:async';
import 'dart:io';

import '../common/book_document_loader.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../domain/annotations/annotation.dart';
import '../../domain/books/book.dart';
import '../../domain/books/reader_fonts.dart';
import '../../domain/books/reader_settings.dart';
import '../../domain/books/reading_position.dart';
import '../common/code_syntax.dart';
import '../common/diagram/diagram_view.dart';
import '../common/renderer_event.dart';
import '../common/math_view.dart';
import 'epub_document.dart';
import 'epub_document_loader.dart';
import 'epub_jump.dart';
import '../../domain/books/locator_excerpt.dart';
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
    this.documentPath,
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
  final BookDocumentLoader? documentLoader;

  /// The file to open, when it is not the book's own library path.
  ///
  /// A folder book is one shelf entry over many notes; the reader opens the
  /// active note and keeps the shelf path for identity.
  final String? documentPath;

  @override
  State<EpubRendererView> createState() => _EpubRendererViewState();
}

final class _EpubRendererViewState extends State<EpubRendererView> {
  late Future<EpubDocument> _documentFuture;
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

  /// Pages already measured, by measurement signature and chapter.
  ///
  /// Measuring a chapter is the most expensive thing paged mode does, and a
  /// reader moves back and forth over the same chapters. Keeping a few of
  /// them turns a chapter switch into a lookup. The cache is dropped whenever
  /// the page geometry or the type changes, because those change every height.
  final Map<String, List<EpubPage>> _measuredPages = <String, List<EpubPage>>{};

  /// How many chapters stay measured. Enough to cover where a reader has just
  /// been and where they are going, small enough to stay cheap.
  static const int _measuredChaptersToKeep = 10;
  String _measurementSignature = '';
  Timer? _prefetchTimer;
  int? _prefetchChapter;
  String? _continuousItemsCacheKey;
  List<_ContinuousListItem> _continuousItems = const [];
  GlobalObjectKey? _jumpTargetKey;
  GlobalObjectKey? _jumpTargetFragmentKey;
  int? _pendingJumpItemIndex;
  int? _pendingJumpChapterOffset;

  @override
  void initState() {
    super.initState();
    _documentFuture = _createDocumentFuture();
    _scrollController.addListener(_scheduleLocationReport);
  }

  Future<EpubDocument> _createDocumentFuture() {
    return (widget.documentLoader ?? EpubDocumentLoader()).load(
      widget.documentPath ?? widget.book.libraryFilePath,
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _cancelPrefetch();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EpubRendererView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentPath != widget.documentPath ||
        oldWidget.book.libraryFilePath != widget.book.libraryFilePath) {
      _documentFuture = _createDocumentFuture();
      _document = null;
      _continuousRestored = false;
      _pagedRestored = false;
      _readySent = false;
      _capabilitySent = false;
      _invalidateMeasuredPages();
      _continuousItemsCacheKey = null;
      _jumpTargetKey = null;
      _jumpTargetFragmentKey = null;
      _pendingJumpItemIndex = null;
      _pendingJumpChapterOffset = null;
    }
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
        _invalidateMeasuredPages();
        _continuousItemsCacheKey = null;
      }
      if (modeChanged && widget.settings.readerMode == ReaderMode.paged) {
        final document = _document;
        if (document != null && document.chapters.isNotEmpty) {
          _pagedChapterIndex = document
              .chapterForProgress(_restoreProgress(document))
              .index
              .clamp(0, document.chapters.length - 1);
          _invalidateMeasuredPages();
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
      _jumpTargetKey = null;
      _jumpTargetFragmentKey = null;
      _pendingJumpItemIndex = null;
      _pendingJumpChapterOffset = null;
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
            _invalidateMeasuredPages();
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

  /// A position in this book, typed the way this book is read.
  ///
  /// A Markdown book and an EPUB are read the same way, but a stored position
  /// that calls a Markdown chapter an EPUB one is a small lie that costs
  /// nothing to avoid.
  ReadingLocator _locator({
    String? href,
    required int chapterIndex,
    required int chapterOffset,
    int? chapterEndOffset,
    required double progress,
    String? excerpt,
  }) {
    if (widget.book.format == BookFormat.markdown) {
      return ReadingLocator.markdown(
        href: href,
        chapterIndex: chapterIndex,
        chapterOffset: chapterOffset,
        chapterEndOffset: chapterEndOffset,
        progress: progress,
        excerpt: excerpt,
      );
    }
    return ReadingLocator.epub(
      href: href,
      chapterIndex: chapterIndex,
      chapterOffset: chapterOffset,
      chapterEndOffset: chapterEndOffset,
      progress: progress,
      excerpt: excerpt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return FutureBuilder<EpubDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final message = snapshot.error is BookLoadException
              ? (snapshot.error! as BookLoadException).message
              : '无法解析这本书';
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
                    settings.pageMargin + 20,
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
                        child: SizedBox(
                          width: double.infinity,
                          child: switch (item) {
                            _ContinuousChapterSlice(
                              :final chapter,
                              :final startBlock,
                              :final endBlock,
                              :final isFirst,
                              :final isLast,
                            ) =>
                              Padding(
                                padding: EdgeInsets.only(
                                  top: isFirst && chapter.index != 0 ? 20 : 0,
                                ),
                                child: _EpubChapterView(
                                  chapter: chapter,
                                  fragments: _sliceFragments(
                                    chapter,
                                    startBlock,
                                    endBlock,
                                  ),
                                  settings: settings,
                                  annotations: widget.annotations,
                                  searchQuery: widget.searchQuery,
                                  focusRange: focusRange,
                                  showTitle: isFirst,
                                  // Outer ListView already owns SelectionArea.
                                  enableSelection: false,
                                  bottomPadding: isLast ? 20 : 0,
                                  jumpTargetOffset: isJumpTarget
                                      ? _pendingJumpChapterOffset
                                      : null,
                                  jumpTargetKey: isJumpTarget
                                      ? _jumpTargetFragmentKey
                                      : null,
                                  onAnnotationSelected: (annotation) {
                                    widget.onEvent(
                                      RendererAnnotationSelected(annotation.id),
                                    );
                                  },
                                  onTextSelected: _reportTextSelected,
                                  onExternalLink: (uri) => widget.onEvent(
                                    RendererExternalLinkRequested(uri),
                                  ),
                                  onInternalLink: _handleInternalLink,
                                ),
                              ),
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// How many blocks one continuous row holds.
  ///
  /// Small enough that building a row is one frame's work, large enough that
  /// a reader scrolling a chapter is not creating rows constantly.
  static const int _continuousBlocksPerSlice = 8;

  List<_ContinuousListItem> _continuousItemsFor(EpubDocument document) {
    final key =
        '${widget.book.id}|${document.chapters.length}|${document.totalTextLength}';
    if (_continuousItemsCacheKey == key && _continuousItems.isNotEmpty) {
      return _continuousItems;
    }
    final items = <_ContinuousListItem>[];
    final chapterFirstItem = <int>[];
    for (final chapter in document.chapters) {
      chapterFirstItem.add(items.length);
      final blockCount = epubBlocks(chapter).length;
      if (blockCount == 0) {
        // A chapter with nothing in it still shows its title.
        items.add(
          _ContinuousChapterSlice(
            chapter: chapter,
            startBlock: 0,
            endBlock: 0,
            isFirst: true,
            isLast: true,
          ),
        );
        continue;
      }
      for (
        var start = 0;
        start < blockCount;
        start += _continuousBlocksPerSlice
      ) {
        final end = start + _continuousBlocksPerSlice;
        items.add(
          _ContinuousChapterSlice(
            chapter: chapter,
            startBlock: start,
            endBlock: end > blockCount ? blockCount : end,
            isFirst: start == 0,
            isLast: end >= blockCount,
          ),
        );
      }
    }
    _continuousItemsCacheKey = key;
    _continuousItems = items;
    _continuousChapterFirstItem = chapterFirstItem;
    return items;
  }

  /// Index of each chapter's first row, so a chapter jump is a row jump.
  List<int> _continuousChapterFirstItem = const <int>[];

  /// The fragments of one row, built when the row is built.
  List<EpubPageFragment> _sliceFragments(
    EpubChapter chapter,
    int startBlock,
    int endBlock,
  ) {
    final blocks = epubBlocks(chapter);
    final from = startBlock.clamp(0, blocks.length);
    final to = endBlock.clamp(from, blocks.length);
    return <EpubPageFragment>[
      for (var index = from; index < to; index += 1)
        EpubPageFragment(
          chapterIndex: chapter.index,
          href: chapter.href,
          startOffset: blocks[index].startOffset,
          endOffset: blocks[index].endOffset,
          text: blocks[index].text,
          blockType: blocks[index].type,
          image: blocks[index].image,
          tableCells: blocks[index].tableCells,
          tableHasHeader: blocks[index].tableHasHeader,
          tableAlignments: blocks[index].tableAlignments,
          imageCaption: blocks[index].imageCaption,
          inlineRuns: blocks[index].inlineRuns,
          headingLevel: blocks[index].headingLevel,
          listMarker: blocks[index].listMarker,
          listIndent: blocks[index].listIndent,
          quoteDepth: blocks[index].quoteDepth,
          hasListHangingIndent: blocks[index].hasListHangingIndent,
          taskChecked: blocks[index].taskChecked,
          codeLanguage: blocks[index].codeLanguage,
          codeRuns: blocks[index].codeRuns,
          mathSource: blocks[index].mathSource,
          diagramSource: blocks[index].diagramSource,
        ),
    ];
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
                      onExternalLink: (uri) =>
                          widget.onEvent(RendererExternalLinkRequested(uri)),
                      onInternalLink: _handleInternalLink,
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
      final chapterIndex = locator.chapterIndex!.clamp(
        0,
        document.chapters.length - 1,
      );
      final chapter = document.chapters[chapterIndex];
      final chapterOffset = (locator.chapterOffset ?? 0).clamp(
        0,
        chapter.text.length,
      );
      final firstItem = chapterIndex < _continuousChapterFirstItem.length
          ? _continuousChapterFirstItem[chapterIndex]
          : chapterIndex;
      final blocks = epubBlocks(chapter);
      var blockIndex = blocks.indexWhere(
        (block) =>
            block.startOffset <= chapterOffset &&
            chapterOffset <= block.endOffset,
      );
      if (blockIndex < 0) {
        blockIndex = blocks.lastIndexWhere(
          (block) => block.startOffset <= chapterOffset,
        );
      }
      if (blockIndex < 0) {
        blockIndex = 0;
      }
      final sliceOffset = blockIndex ~/ _continuousBlocksPerSlice;
      _pendingJumpItemIndex = (firstItem + sliceOffset).clamp(
        0,
        items.length - 1,
      );
      _pendingJumpChapterOffset = locator.chapterOffset;
      _jumpTargetKey = GlobalObjectKey(
        'jump-${widget.jumpToken}-$_pendingJumpItemIndex',
      );
      _jumpTargetFragmentKey = locator.chapterOffset == null
          ? null
          : GlobalObjectKey(
              'jump-fragment-${widget.jumpToken}-${locator.chapterOffset}',
            );
    } else {
      _pendingJumpItemIndex = null;
      _pendingJumpChapterOffset = null;
      _jumpTargetKey = null;
      _jumpTargetFragmentKey = null;
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
      final targetContext =
          _jumpTargetFragmentKey?.currentContext ??
          _jumpTargetKey?.currentContext;
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
        _invalidateMeasuredPages();
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
      _invalidateMeasuredPages();
      _pagedChapterIndexes = const {};
      return const [];
    }
    final chapterIndex = _pagedChapterIndex.clamp(
      0,
      document.chapters.length - 1,
    );
    _pagedChapterIndex = chapterIndex;
    final viewport = Size(constraints.maxWidth, constraints.maxHeight);
    final signature = [
      widget.book.id,
      document.chapters.length,
      document.totalTextLength,
      viewport.width.toStringAsFixed(1),
      viewport.height.toStringAsFixed(1),
      settings.fontSize.toStringAsFixed(2),
      settings.lineHeight.toStringAsFixed(2),
      settings.paragraphSpacing.toStringAsFixed(2),
      settings.pageMargin.toStringAsFixed(2),
      settings.fontFamily,
    ].join('|');
    if (signature != _measurementSignature) {
      // Every measured page belongs to the old geometry or the old type.
      _invalidateMeasuredPages();
      _measurementSignature = signature;
    }
    final pages = _pagesForChapter(
      document: document,
      chapterIndex: chapterIndex,
      settings: settings,
      viewport: viewport,
    );
    // Chapter nav uses document spine, not only currently measured pages.
    _pagedChapterIndexes = {
      for (final chapter in document.chapters) chapter.index,
    };
    _scheduleNeighbourPrefetch(
      document: document,
      chapterIndex: chapterIndex,
      settings: settings,
      viewport: viewport,
    );
    return pages;
  }

  /// The pages of [chapterIndex], measured once and then remembered.
  List<EpubPage> _pagesForChapter({
    required EpubDocument document,
    required int chapterIndex,
    required ReaderSettings settings,
    required Size viewport,
  }) {
    final key = '$_measurementSignature|$chapterIndex';
    final cached = _measuredPages.remove(key);
    if (cached != null) {
      // Re-insert at the end: the least recently used chapter goes first.
      _measuredPages[key] = cached;
      return cached;
    }
    final pages = _paginateChapterAt(
      document: document,
      chapterIndex: chapterIndex,
      settings: settings,
      viewport: viewport,
    );
    _rememberPages(key, pages);
    return pages;
  }

  void _rememberPages(String key, List<EpubPage> pages) {
    _measuredPages.remove(key);
    _measuredPages[key] = pages;
    while (_measuredPages.length > _measuredChaptersToKeep) {
      _measuredPages.remove(_measuredPages.keys.first);
    }
  }

  /// Measures the next chapter while the reader is not waiting for anything.
  ///
  /// A chapter switch is a page turn with a 30–60 ms measure in the middle of
  /// it, which is exactly the pause a reader notices. The neighbouring chapter
  /// is measured once the current page has been sitting still for a moment,
  /// so that turning into it later is a lookup. Any page turn cancels the
  /// pending work: the reader's input comes first.
  void _scheduleNeighbourPrefetch({
    required EpubDocument document,
    required int chapterIndex,
    required ReaderSettings settings,
    required Size viewport,
  }) {
    final neighbour = chapterIndex + 1;
    if (neighbour >= document.chapters.length) {
      return;
    }
    if (_prefetchChapter == neighbour &&
        _prefetchTimer != null &&
        _prefetchTimer!.isActive) {
      return;
    }
    _prefetchTimer?.cancel();
    _prefetchChapter = neighbour;
    _prefetchTimer = Timer(const Duration(milliseconds: 400), () {
      _prefetchTimer = null;
      if (!mounted) {
        return;
      }
      final key = '$_measurementSignature|$neighbour';
      if (_measuredPages.containsKey(key)) {
        return;
      }
      _rememberPages(
        key,
        _paginateChapterAt(
          document: document,
          chapterIndex: neighbour,
          settings: settings,
          viewport: viewport,
        ),
      );
    });
  }

  void _cancelPrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _prefetchChapter = null;
  }

  void _invalidateMeasuredPages() {
    _cancelPrefetch();
    _measuredPages.clear();
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
    _cancelPrefetch();
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
    _invalidateMeasuredPages();
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
            locator: _locator(
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
        locator: _locator(
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

  void _handleInternalLink(String target) {
    final document = _document;
    if (document == null || !target.startsWith('#')) {
      return;
    }
    final rawId = target.substring(1);
    var id = rawId;
    try {
      id = Uri.decodeComponent(rawId);
    } on ArgumentError {
      // A literal percent sign is a valid target name, not an encoding error.
    }
    for (final chapter in document.chapters) {
      final anchor = chapter.anchors[id];
      if (anchor == null) {
        continue;
      }
      final offset = anchor.clamp(0, chapter.text.length).toInt();
      final progress = document.progressForChapter(
        chapterIndex: chapter.index,
        chapterOffset: offset,
      );
      widget.onEvent(
        RendererInternalLinkRequested(
          _locator(
            href: chapter.href,
            chapterIndex: chapter.index,
            chapterOffset: offset,
            progress: progress,
            excerpt: _excerptAtChapterOffset(chapter, offset),
          ),
        ),
      );
      return;
    }
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
        locator: _locator(
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
        locator: _locator(
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
    _cancelPrefetch();
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
    _cancelPrefetch();
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
      final itemIndex = chapterIndex < _continuousChapterFirstItem.length
          ? _continuousChapterFirstItem[chapterIndex].clamp(0, items.length - 1)
          : chapterIndex.clamp(0, items.length - 1);
      if (itemIndex >= 0) {
        _pendingJumpItemIndex = itemIndex;
        _pendingJumpChapterOffset = null;
        _jumpTargetKey = GlobalObjectKey(
          'chapter-jump-${widget.jumpToken}-$itemIndex',
        );
        _jumpTargetFragmentKey = null;
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
    _cancelPrefetch();
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
    required this.onExternalLink,
    required this.onInternalLink,
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
  final ValueChanged<String> onExternalLink;
  final ValueChanged<String> onInternalLink;

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
          child: SizedBox(
            width: double.infinity,
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
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
                          onExternalLink: onExternalLink,
                          onInternalLink: onInternalLink,
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: textColor.withValues(alpha: 0.6),
                              ),
                        ),
                        Text(
                          '${(page.progress * 100).round()}%',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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
    required this.onExternalLink,
    required this.onInternalLink,
    this.focusRange,
    this.fragments,
    this.showTitle = true,
    this.bottomPadding = 32,
    this.enableSelection = true,
    this.jumpTargetOffset,
    this.jumpTargetKey,
  });

  final EpubChapter chapter;
  final ReaderSettings settings;
  final List<Annotation> annotations;
  final String? searchQuery;
  final ({int chapterIndex, int start, int end, String? excerpt})? focusRange;
  final ValueChanged<Annotation> onAnnotationSelected;
  final ValueChanged<_EpubTextSelection> onTextSelected;
  final ValueChanged<String> onExternalLink;
  final ValueChanged<String> onInternalLink;
  final List<EpubPageFragment>? fragments;
  final bool showTitle;
  final double bottomPadding;
  final int? jumpTargetOffset;
  final GlobalObjectKey? jumpTargetKey;

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
        if (widget.showTitle &&
            !fragments.any(
              (fragment) =>
                  fragment.blockType == EpubBlockType.heading &&
                  fragment.text.trim() == widget.chapter.title.trim(),
            )) ...[
          Text(
            widget.chapter.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: textColor),
          ),
          const SizedBox(height: 16),
        ],
        for (final fragment in fragments)
          KeyedSubtree(
            key: _isJumpTarget(fragment) ? widget.jumpTargetKey : null,
            child: _EpubFragmentView(
              chapter: widget.chapter,
              fragment: fragment,
              settings: settings,
              annotations: widget.annotations,
              searchQuery: widget.searchQuery,
              focusRange: widget.focusRange,
              onAnnotationSelected: widget.onAnnotationSelected,
              onTextSelected: widget.onTextSelected,
              onExternalLink: widget.onExternalLink,
              onInternalLink: widget.onInternalLink,
            ),
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

  bool _isJumpTarget(EpubPageFragment fragment) {
    final offset = widget.jumpTargetOffset;
    return widget.jumpTargetKey != null &&
        offset != null &&
        fragment.startOffset <= offset &&
        offset <= fragment.endOffset;
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
            tableCells: block.tableCells,
            tableHasHeader: block.tableHasHeader,
            tableAlignments: block.tableAlignments,
            imageCaption: block.imageCaption,
            inlineRuns: block.inlineRuns,
            headingLevel: block.headingLevel,
            listMarker: block.listMarker,
            listIndent: block.listIndent,
            quoteDepth: block.quoteDepth,
            hasListHangingIndent: block.hasListHangingIndent,
            taskChecked: block.taskChecked,
            codeLanguage: block.codeLanguage,
            codeRuns: block.codeRuns,
            mathSource: block.mathSource,
            diagramSource: block.diagramSource,
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
    required this.onExternalLink,
    required this.onInternalLink,
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
  final ValueChanged<String> onExternalLink;
  final ValueChanged<String> onInternalLink;

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

  /// The styled stretches inside one table cell.
  ///
  /// Cell runs use offsets local to the cell, because the cell is laid out as
  /// its own text widget. Links still go through the same host callbacks as
  /// links in prose, and search hits and annotations are mapped back through
  /// the cell's chapter offset.
  List<InlineSpan> _cellSpansFor(EpubTableCell cell, TextStyle baseStyle) {
    final text = cell.text;
    if (text.isEmpty) {
      return const <InlineSpan>[];
    }
    final runs = cell.runs;
    final matches = _cellMatchesFor(cell);
    if (runs.isEmpty && matches.isEmpty) {
      return <InlineSpan>[TextSpan(text: text)];
    }
    final points = <int>{0, text.length};
    for (final run in runs) {
      points
        ..add(run.start.clamp(0, text.length))
        ..add(run.end.clamp(0, text.length));
    }
    for (final match in matches) {
      points
        ..add(match.start.clamp(0, text.length))
        ..add(match.end.clamp(0, text.length));
    }
    final boundaries = points.toList()..sort();
    final accent = widget.settings.themePreset.link;
    final codeBackground = widget.settings.themePreset.foreground.withValues(
      alpha: 0.06,
    );
    final spans = <InlineSpan>[];
    var matchIndex = 0;
    for (var index = 0; index + 1 < boundaries.length; index += 1) {
      final start = boundaries[index];
      final end = boundaries[index + 1];
      if (start >= end) {
        continue;
      }
      var style = epubInlineRunStyle(
        baseStyle,
        runs,
        start,
        end,
        accent: accent,
        codeBackground: codeBackground,
      );
      while (matchIndex < matches.length && matches[matchIndex].end <= start) {
        matchIndex += 1;
      }
      final match =
          matchIndex < matches.length &&
              matches[matchIndex].start <= start &&
              matches[matchIndex].end >= end
          ? matches[matchIndex]
          : null;
      if (match != null) {
        if (match.isFocusHit) {
          style = style.copyWith(backgroundColor: _focusHitColor());
        } else if (match.isSearchHit) {
          style = style.copyWith(backgroundColor: _searchHitColor());
        } else {
          final annotation = match.annotation!;
          style = style.copyWith(
            backgroundColor: annotation.style == AnnotationStyle.highlight
                ? _highlightColor(annotation.color)
                : style.backgroundColor,
            decoration: annotation.style == AnnotationStyle.underline
                ? TextDecoration.combine([
                    if (style.decoration != null &&
                        style.decoration != TextDecoration.none)
                      style.decoration!,
                    TextDecoration.underline,
                  ])
                : style.decoration,
            decorationColor: _highlightColor(annotation.color),
            decorationThickness: 2,
          );
        }
      }
      TapGestureRecognizer? recognizer;
      String? target;
      var external = false;
      for (final run in runs) {
        final candidate = run.target;
        if (candidate == null ||
            candidate.isEmpty ||
            run.start > start ||
            run.end < end) {
          continue;
        }
        final internal =
            candidate.startsWith('#') &&
            (run.style == EpubInlineStyle.link ||
                run.style == EpubInlineStyle.footnote);
        final isExternal =
            run.style == EpubInlineStyle.link &&
            _isSafeExternalTarget(candidate);
        if (!internal && !isExternal) {
          continue;
        }
        target = candidate;
        external = isExternal;
        break;
      }
      if (target != null) {
        final linkTarget = target;
        recognizer = TapGestureRecognizer()
          ..onTap = () => external
              ? widget.onExternalLink(linkTarget)
              : widget.onInternalLink(linkTarget);
        _inlineRecognizers.add(recognizer);
      } else if (match != null && !match.isFocusHit && !match.isSearchHit) {
        final annotation = match.annotation!;
        recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onAnnotationSelected(annotation);
        _inlineRecognizers.add(recognizer);
      }
      EpubInlineRun? mathRun;
      for (final run in runs) {
        if (run.style != EpubInlineStyle.math ||
            run.mathSource == null ||
            run.start > start ||
            run.end < end) {
          continue;
        }
        mathRun = run;
        break;
      }
      if (mathRun != null) {
        spans.add(
          TextSpan(
            style: style,
            recognizer: recognizer,
            children: <InlineSpan>[
              _mathSpan(
                source: mathRun.mathSource!,
                fallback: text.substring(start, end),
                style: style,
              ),
            ],
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: style,
            recognizer: recognizer,
          ),
        );
      }
    }
    return spans;
  }

  /// Search, focus and annotation ranges inside one table cell.
  ///
  /// Annotations and focus ranges carry chapter offsets, so they are clipped
  /// against the cell's chapter range. Text matching is the fallback for
  /// older annotations that have no offset.
  List<_AnnotationMatch> _cellMatchesFor(EpubTableCell cell) {
    final matches = <_AnnotationMatch>[];
    final chapter = widget.chapter;
    final text = cell.text;
    final cellStart = cell.chapterOffset;
    final cellEnd = cellStart < 0 ? null : cellStart + text.length;

    for (final annotation in widget.annotations) {
      final locatorChapter = annotation.locator.chapterIndex;
      if (locatorChapter != null && locatorChapter != chapter.index) {
        continue;
      }
      final selected = annotation.selectedText.trim();
      if (selected.isEmpty) {
        continue;
      }
      final locatorStart = annotation.locator.chapterOffset;
      if (cellEnd != null &&
          locatorStart != null &&
          annotation.locator.chapterIndex == chapter.index) {
        final locatorEnd =
            annotation.locator.chapterEndOffset ??
            locatorStart + selected.length;
        final overlapStart = locatorStart > cellStart
            ? locatorStart
            : cellStart;
        final overlapEnd = locatorEnd < cellEnd ? locatorEnd : cellEnd;
        if (overlapStart < overlapEnd) {
          matches.add(
            _AnnotationMatch(
              start: overlapStart - cellStart,
              end: overlapEnd - cellStart,
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

    final query = widget.searchQuery?.trim();
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

    final focusRange = widget.focusRange;
    final hasFocus =
        focusRange != null && focusRange.chapterIndex == chapter.index;
    if (hasFocus) {
      final focusStart = focusRange.start;
      final focusEnd = focusRange.end;
      if (cellEnd != null && focusEnd > focusStart) {
        final overlapStart = focusStart > cellStart ? focusStart : cellStart;
        final overlapEnd = focusEnd < cellEnd ? focusEnd : cellEnd;
        if (overlapStart < overlapEnd) {
          matches.add(
            _AnnotationMatch(
              start: overlapStart - cellStart,
              end: overlapEnd - cellStart,
              annotation: null,
              isFocusHit: true,
            ),
          );
        }
      } else {
        final excerpt = focusRange.excerpt?.trim();
        if (excerpt != null && excerpt.isNotEmpty) {
          final index = text.toLowerCase().indexOf(excerpt.toLowerCase());
          if (index >= 0) {
            matches.add(
              _AnnotationMatch(
                start: index,
                end: index + excerpt.length,
                annotation: null,
                isFocusHit: true,
              ),
            );
          }
        }
      }
    }

    matches.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) {
        return startCompare;
      }
      if (a.annotation != null && b.annotation == null) {
        return -1;
      }
      if (a.annotation == null && b.annotation != null) {
        return 1;
      }
      if (a.isFocusHit != b.isFocusHit) {
        return a.isFocusHit ? 1 : -1;
      }
      return a.isSearchHit ? 1 : -1;
    });
    final kept = <_AnnotationMatch>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }
      kept.add(match);
      cursor = match.end;
    }
    return kept;
  }

  @override
  Widget build(BuildContext context) {
    final fragment = widget.fragment;
    final quoteDepth = fragment.quoteDepth > 0
        ? fragment.quoteDepth
        : (fragment.blockType == EpubBlockType.quote ? 1 : 0);
    final content = _contentFor(fragment);
    final quoted = quoteDepth == 0
        ? content
        : _EpubQuoteBlock(
            settings: widget.settings,
            depth: quoteDepth,
            child: content,
          );
    return Padding(
      padding: EdgeInsets.only(bottom: _spacingForFragment(fragment)),
      child: quoted,
    );
  }

  Widget _contentFor(EpubPageFragment fragment) {
    if (fragment.blockType == EpubBlockType.image) {
      return _EpubImageView(
        settings: widget.settings,
        image: fragment.image,
        caption: fragment.imageCaption,
      );
    }
    final tableCells = fragment.tableCells;
    if (tableCells != null) {
      _disposeInlineRecognizers();
      return _EpubTableBlock(
        settings: widget.settings,
        cells: tableCells,
        hasHeader: fragment.tableHasHeader,
        alignments: fragment.tableAlignments,
        cellSpans: _cellSpansFor,
      );
    }
    if (fragment.blockType == EpubBlockType.divider) {
      return _EpubDivider(settings: widget.settings);
    }
    if (fragment.blockType == EpubBlockType.math &&
        fragment.mathSource != null) {
      return DisplayMathView(
        source: fragment.mathSource!,
        fallback: fragment.text,
        style: _baseStyle(),
      );
    }
    final style = _styleForFragment(fragment, _baseStyle());
    final marker = fragment.listMarker;
    final markerLength = fragment.listMarker != null ? marker?.length ?? 0 : 0;
    final visibleText = markerLength == 0
        ? fragment.text
        : fragment.text.substring(markerLength.clamp(0, fragment.text.length));
    // Use plain Text.rich so a parent SelectionArea can span multiple
    // paragraphs. SelectableText creates isolated selection regions.
    final text = Text.rich(
      TextSpan(
        style: style,
        children: _spansFor(
          style,
          markerLength: markerLength,
          visibleText: visibleText,
        ),
      ),
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      textAlign: fragment.blockType == EpubBlockType.heading
          ? TextAlign.start
          : TextAlign.left,
    );

    final body = marker == null
        ? text
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fragment.hasListHangingIndent)
                SizedBox(
                  width: epubListHangingIndent * (fragment.listIndent + 1.0),
                  child: SelectionContainer.disabled(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: epubListHangingIndent * fragment.listIndent,
                      ),
                      child: fragment.taskChecked == null
                          ? Text(marker.trim(), style: style)
                          : _EpubTaskMarker(
                              checked: fragment.taskChecked!,
                              style: style,
                              settings: widget.settings,
                            ),
                    ),
                  ),
                ),
              Expanded(child: text),
            ],
          );

    return switch (fragment.blockType) {
      EpubBlockType.code => _EpubCodeBlock(
        settings: widget.settings,
        language: fragment.codeLanguage,
        child: body,
      ),
      EpubBlockType.math => _EpubCodeBlock(
        settings: widget.settings,
        language: fragment.codeLanguage ?? 'LaTeX',
        child: body,
      ),
      EpubBlockType.diagram => _EpubCodeBlock(
        settings: widget.settings,
        language: fragment.codeLanguage ?? 'Mermaid',
        child: _diagramBodyFor(fragment, body),
      ),
      EpubBlockType.caption => _EpubCaption(child: body),
      EpubBlockType.quote => body,
      EpubBlockType.image ||
      EpubBlockType.table ||
      EpubBlockType.divider ||
      EpubBlockType.heading ||
      EpubBlockType.paragraph => body,
    };
  }

  Widget _diagramBodyFor(EpubPageFragment fragment, Widget fallback) {
    final source = fragment.diagramSource;
    if (source == null || source.isEmpty) {
      return fallback;
    }
    return MermaidDiagramView(source: source, settings: widget.settings);
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
    return epubBlockSpacing(
      type: fragment.blockType,
      paragraphSpacing: widget.settings.paragraphSpacing,
      headingLevel: fragment.headingLevel,
      isList: fragment.listMarker != null,
    );
  }

  TextStyle _styleForFragment(EpubPageFragment fragment, TextStyle baseStyle) {
    return switch (fragment.blockType) {
      EpubBlockType.heading => epubHeadingTextStyle(
        baseStyle,
        fragment.headingLevel,
      ),
      EpubBlockType.code => baseStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: baseStyle.fontSize! * 0.92,
        height: 1.52,
      ),
      EpubBlockType.math || EpubBlockType.diagram => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 0.9,
        height: 1.45,
        color: baseStyle.color?.withValues(alpha: 0.72),
      ),
      EpubBlockType.caption => baseStyle.copyWith(
        fontSize: baseStyle.fontSize! * 0.88,
        height: (baseStyle.height ?? 1.5) * 0.95,
        color: baseStyle.color?.withValues(alpha: 0.72),
      ),
      EpubBlockType.quote => baseStyle.copyWith(
        color: baseStyle.color?.withValues(alpha: 0.86),
      ),
      EpubBlockType.table => epubTableTextStyle(baseStyle),
      EpubBlockType.image ||
      EpubBlockType.divider ||
      EpubBlockType.paragraph => baseStyle,
    };
  }

  List<InlineSpan> _spansFor(
    TextStyle style, {
    required int markerLength,
    required String visibleText,
  }) {
    final focus = widget.focusRange;
    final cacheKey = Object.hash(
      widget.fragment.startOffset,
      widget.fragment.endOffset,
      visibleText,
      Object.hashAll(widget.fragment.inlineRuns),
      Object.hashAll(widget.fragment.codeRuns),
      widget.searchQuery,
      focus?.chapterIndex,
      focus?.start,
      focus?.end,
      focus?.excerpt,
      widget.annotations.length,
      widget.settings.themePreset,
      widget.fragment.codeLanguage,
      markerLength,
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
    final spans = _buildTextSpans(
      widget.fragment,
      style,
      markerLength,
      visibleText,
    );
    _spanCacheKey = cacheKey;
    _cachedSpans = spans;
    _cachedBaseStyle = style;
    return spans;
  }

  List<InlineSpan> _buildTextSpans(
    EpubPageFragment fragment,
    TextStyle baseStyle,
    int markerLength,
    String text,
  ) {
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
    final runs = _inlineRunsFor(fragment);
    final targets = _linkTargetsFor(fragment, markerLength);
    final codeRuns = _codeRunsFor(fragment);
    if (runs.isEmpty &&
        codeRuns.isEmpty &&
        chapterAnnotations.isEmpty &&
        (query == null || query.isEmpty) &&
        !hasFocus &&
        targets.isEmpty) {
      return _plainSpans(text, markerLength);
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
    // The leftmost match wins where two overlap, as it always has.
    final kept = <_AnnotationMatch>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) {
        continue;
      }
      kept.add(match);
      cursor = match.end;
    }
    if (kept.isEmpty && runs.isEmpty && codeRuns.isEmpty && targets.isEmpty) {
      return _plainSpans(text, markerLength);
    }

    // A span is as long as the stretch where nothing changes: a run of styled
    // text, an annotation, a search hit. Cutting at every boundary keeps the
    // styles honest instead of letting one of them swallow the others.
    final points = <int>{0, text.length};
    for (final run in runs) {
      points.add(run.start - markerLength);
      points.add(run.end - markerLength);
    }
    for (final run in codeRuns) {
      points.add(run.start);
      points.add(run.end);
    }
    for (final target in targets) {
      points.add(target.start - markerLength);
      points.add(target.end - markerLength);
    }
    for (final match in kept) {
      points.add(match.start);
      points.add(match.end);
    }
    final boundaries =
        points.where((point) => point >= 0 && point <= text.length).toList()
          ..sort();

    final spans = <InlineSpan>[];
    var matchIndex = 0;
    var targetIndex = 0;
    for (var index = 0; index + 1 < boundaries.length; index += 1) {
      final start = boundaries[index];
      final end = boundaries[index + 1];
      if (start >= end) {
        continue;
      }
      while (matchIndex < kept.length && kept[matchIndex].end <= start) {
        matchIndex += 1;
      }
      while (targetIndex < targets.length &&
          targets[targetIndex].end - markerLength <= start) {
        targetIndex += 1;
      }
      final match =
          matchIndex < kept.length &&
              kept[matchIndex].start <= start &&
              kept[matchIndex].end >= end
          ? kept[matchIndex]
          : null;
      var style = _styleWithInlineRuns(
        baseStyle,
        runs,
        start + markerLength,
        end + markerLength,
      );
      if (codeRuns.isNotEmpty) {
        style = _styleWithCodeRuns(style, codeRuns, start, end);
      }
      TapGestureRecognizer? recognizer;
      ({int start, int end, String target, bool external})? linkedTarget;
      if (targetIndex < targets.length) {
        final target = targets[targetIndex];
        if (target.start - markerLength <= start &&
            target.end - markerLength >= end) {
          linkedTarget = target;
        }
      }
      if (match != null) {
        if (match.isFocusHit) {
          style = style.copyWith(backgroundColor: _focusHitColor());
        } else if (match.isSearchHit) {
          style = style.copyWith(backgroundColor: _searchHitColor());
        } else {
          final annotation = match.annotation!;
          recognizer = TapGestureRecognizer()
            ..onTap = () => widget.onAnnotationSelected(annotation);
          _inlineRecognizers.add(recognizer);
          style = style.copyWith(
            backgroundColor: annotation.style == AnnotationStyle.highlight
                ? _highlightColor(annotation.color)
                : style.backgroundColor,
            decoration: annotation.style == AnnotationStyle.underline
                ? TextDecoration.combine([
                    if (style.decoration != null &&
                        style.decoration != TextDecoration.none)
                      style.decoration!,
                    TextDecoration.underline,
                  ])
                : style.decoration,
            decorationColor: _highlightColor(annotation.color),
            decorationThickness: 2,
          );
        }
      }
      if (linkedTarget != null) {
        final target = linkedTarget;
        recognizer = TapGestureRecognizer()
          ..onTap = () => target.external
              ? widget.onExternalLink(target.target)
              : widget.onInternalLink(target.target);
        _inlineRecognizers.add(recognizer);
      }
      spans.add(
        _spanForStretch(
          text: text.substring(start, end),
          style: style,
          recognizer: recognizer,
          runs: runs,
          markerLength: markerLength,
          start: start,
          end: end,
        ),
      );
    }
    return spans;
  }

  InlineSpan _spanForStretch({
    required String text,
    required TextStyle style,
    required GestureRecognizer? recognizer,
    required List<EpubInlineRun> runs,
    required int markerLength,
    required int start,
    required int end,
  }) {
    for (final run in runs) {
      if (run.style != EpubInlineStyle.math || run.mathSource == null) {
        continue;
      }
      final runStart = run.start - markerLength;
      final runEnd = run.end - markerLength;
      if (runStart < start || runEnd > end) {
        continue;
      }
      final left = text.substring(0, runStart - start);
      final right = text.substring(runEnd - start);
      return TextSpan(
        style: style,
        recognizer: recognizer,
        children: <InlineSpan>[
          if (left.isNotEmpty) TextSpan(text: left, style: style),
          _mathSpan(
            source: run.mathSource!,
            fallback: text.substring(runStart - start, runEnd - start),
            style: style,
          ),
          if (right.isNotEmpty) TextSpan(text: right, style: style),
        ],
      );
    }
    return TextSpan(text: text, recognizer: recognizer, style: style);
  }

  List<InlineSpan> _plainSpans(String text, int markerLength) {
    return [TextSpan(text: text)];
  }

  /// The styled stretches of [fragment], in offsets local to its text.
  ///
  /// A block can be split across pages, so a run may reach past the fragment;
  /// only the part that lands inside it is kept, cut to the fragment's ends.
  List<EpubInlineRun> _inlineRunsFor(EpubPageFragment fragment) {
    final runs = fragment.inlineRuns;
    if (runs.isEmpty) {
      return const <EpubInlineRun>[];
    }
    final start = fragment.startOffset;
    final end = fragment.endOffset;
    final markerLength = fragment.listMarker != null
        ? fragment.listMarker?.length ?? 0
        : 0;
    final local = <EpubInlineRun>[];
    for (final run in runs) {
      final runStart = run.start > start ? run.start : start;
      final runEnd = run.end < end ? run.end : end;
      final localStart = runStart - start - markerLength;
      final localEnd = runEnd - start - markerLength;
      if (localStart < 0 || localEnd > fragment.text.length - markerLength) {
        continue;
      }
      if (runStart >= runEnd) {
        continue;
      }
      local.add(
        EpubInlineRun(
          start: localStart,
          end: localEnd,
          style: run.style,
          target: run.target,
          mathSource: run.mathSource,
        ),
      );
    }
    return local;
  }

  /// Syntax-colour runs clipped to this fragment's visible text.
  ///
  /// Both sides of the comparison stay in chapter offsets. Unlike the shared
  /// inline styles, the visible text of a code block has no marker column.
  List<EpubCodeRun> _codeRunsFor(EpubPageFragment fragment) {
    if (fragment.blockType != EpubBlockType.code || fragment.codeRuns.isEmpty) {
      return const <EpubCodeRun>[];
    }
    final local = <EpubCodeRun>[];
    for (final run in fragment.codeRuns) {
      final runStart = run.start > fragment.startOffset
          ? run.start
          : fragment.startOffset;
      final runEnd = run.end < fragment.endOffset
          ? run.end
          : fragment.endOffset;
      if (runStart >= runEnd) {
        continue;
      }
      local.add(
        EpubCodeRun(
          start: runStart - fragment.startOffset,
          end: runEnd - fragment.startOffset,
          type: run.type,
        ),
      );
    }
    return local;
  }

  TextStyle _styleWithCodeRuns(
    TextStyle baseStyle,
    List<EpubCodeRun> runs,
    int start,
    int end,
  ) {
    for (final run in runs) {
      if (run.start <= start && run.end >= end) {
        return baseStyle.copyWith(
          color: codeSyntaxColor(widget.settings.themePreset, run.type),
        );
      }
    }
    return baseStyle;
  }

  List<({int start, int end, String target, bool external})> _linkTargetsFor(
    EpubPageFragment fragment,
    int markerLength,
  ) {
    final localOffset = fragment.startOffset;
    final results = <({int start, int end, String target, bool external})>[];
    for (final run in fragment.inlineRuns) {
      final target = run.target;
      if (target == null || target.isEmpty) {
        continue;
      }
      final internal =
          target.startsWith('#') &&
          (run.style == EpubInlineStyle.footnote ||
              run.style == EpubInlineStyle.link);
      final external = switch (run.style) {
        EpubInlineStyle.link => _isSafeExternalTarget(target),
        _ => false,
      };
      if (!internal && !external) {
        continue;
      }
      final start = run.start > localOffset ? run.start : localOffset;
      final end = run.end < fragment.endOffset ? run.end : fragment.endOffset;
      if (start < end) {
        final localStart = start - localOffset - markerLength;
        final localEnd = end - localOffset - markerLength;
        if (localStart < 0 || localEnd > fragment.text.length - markerLength) {
          continue;
        }
        results.add((
          start: localStart,
          end: localEnd,
          target: target,
          external: external,
        ));
      }
    }
    return results;
  }

  bool _isSafeExternalTarget(String target) {
    if (target.startsWith('#')) {
      return false;
    }
    final colon = target.indexOf(':');
    final scheme = colon <= 0 ? '' : target.substring(0, colon).toLowerCase();
    return const {'http', 'https', 'mailto'}.contains(scheme);
  }

  InlineSpan _mathSpan({
    required String source,
    required String fallback,
    required TextStyle style,
  }) {
    return InlineMathSpan(source: source, fallback: fallback, style: style);
  }

  /// [baseStyle] with every inline style reaching across this stretch applied.
  ///
  /// Two styles over the same words compose rather than fight: bold italic
  /// stays both, and a strikethrough link keeps its underline.
  TextStyle _styleWithInlineRuns(
    TextStyle baseStyle,
    List<EpubInlineRun> runs,
    int start,
    int end,
  ) {
    return epubInlineRunStyle(
      baseStyle,
      runs,
      start,
      end,
      accent: widget.settings.themePreset.link,
      codeBackground: widget.settings.themePreset.foreground.withValues(
        alpha: 0.06,
      ),
    );
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

/// Continuous-mode row: one slice of a chapter.
///
/// A chapter used to be a single row. That made the row's widget tree the
/// whole chapter, so the frame that brought it into view laid out every
/// paragraph at once — a second of stutter on a long note, and hundreds of
/// megabytes for a big one. A chapter is now a run of slices, and the reader
/// lays out the ones on screen.
final class _ContinuousChapterSlice extends _ContinuousListItem {
  const _ContinuousChapterSlice({
    required this.chapter,
    required this.startBlock,
    required this.endBlock,
    required this.isFirst,
    required this.isLast,
  });

  final EpubChapter chapter;

  /// Half-open range of [EpubChapter.blocks] this slice draws.
  final int startBlock;
  final int endBlock;

  final bool isFirst;
  final bool isLast;
}

/// A task-list checkbox.
///
/// The glyph stays in the chapter text for offsets and search, but the eye
/// gets a real checkbox in the marker column instead of a second bullet.
final class _EpubTaskMarker extends StatelessWidget {
  const _EpubTaskMarker({
    required this.checked,
    required this.style,
    required this.settings,
  });

  final bool checked;
  final TextStyle style;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final lineHeight = (style.fontSize ?? 16) * (style.height ?? 1.4);
    final color = checked
        ? settings.themePreset.link.withValues(alpha: 0.86)
        : settings.themePreset.foreground.withValues(alpha: 0.66);
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Icon(
          checked
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          size: 17,
          color: color,
          semanticLabel: checked ? '已完成' : '未完成',
        ),
      ),
    );
  }
}

final class _EpubCodeBlock extends StatelessWidget {
  const _EpubCodeBlock({
    required this.settings,
    required this.child,
    this.language,
  });

  final ReaderSettings settings;
  final Widget child;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final foreground = settings.themePreset.foreground;
    final backgroundAlpha = settings.themePreset == ReaderThemePreset.night
        ? 0.10
        : 0.055;
    final label = language?.trim();
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: backgroundAlpha),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: epubCodeBlockPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label != null && label.isNotEmpty)
                SizedBox(
                  height: epubCodeLanguageHeight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.56),
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: child,
              ),
            ],
          ),
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
  const _EpubImageView({
    required this.settings,
    required this.image,
    this.caption,
  });

  final ReaderSettings settings;
  final EpubImage? image;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final picture = image;
    final captionText = caption?.trim() ?? '';
    final hasCaption = captionText.isNotEmpty;
    final placeholder = picture == null || !picture.isAvailable;
    final visiblePicture = placeholder ? null : picture;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (placeholder)
          _EpubImagePlaceholder(
            settings: settings,
            label: picture?.unavailableReason ?? '图片',
          )
        else
          Semantics(
            label: visiblePicture!.alt ?? '插图',
            image: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth;
                final width =
                    visiblePicture.pixelWidth > 0 &&
                        visiblePicture.pixelWidth < available
                    ? visiblePicture.pixelWidth.toDouble()
                    : available;
                final cacheWidth = width.isFinite && width > 0
                    ? (width * MediaQuery.devicePixelRatioOf(context)).round()
                    : null;
                Widget placeholderBuilder(
                  BuildContext context,
                  Object error,
                  StackTrace? _,
                ) {
                  return _EpubImagePlaceholder(
                    settings: settings,
                    label: '图片无法显示',
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: visiblePicture.sourcePath != null
                      ? Image.file(
                          File(visiblePicture.sourcePath!),
                          fit: BoxFit.contain,
                          width: width,
                          cacheWidth: cacheWidth,
                          errorBuilder: placeholderBuilder,
                        )
                      : Image.memory(
                          visiblePicture.bytes,
                          fit: BoxFit.contain,
                          width: width,
                          cacheWidth: cacheWidth,
                          errorBuilder: placeholderBuilder,
                        ),
                );
              },
            ),
          ),
        if (hasCaption) ...[
          const SizedBox(height: epubImageCaptionGap),
          SelectionContainer.disabled(
            child: Text(
              captionText,
              textAlign: TextAlign.center,
              style: _imageCaptionStyle(settings),
            ),
          ),
        ],
      ],
    );
  }

  TextStyle _imageCaptionStyle(ReaderSettings settings) {
    final family = ReaderFonts.renderFamilyFor(settings.fontFamily);
    return epubImageCaptionTextStyle(
      TextStyle(
        fontFamily: family.isEmpty ? null : family,
        fontSize: settings.fontSize,
        height: settings.lineHeight,
      ),
      settings.themePreset.foreground,
    );
  }
}

/// A figure's caption: quieter than the prose around it.
/// A quote: the words sit behind one bar per nesting level.
///
/// The bars are what make nested quotes readable without turning the page
/// into a stack of boxes. The paginator reserves the same width for each
/// level, so measured and painted lines stay in step.
final class _EpubQuoteBlock extends StatelessWidget {
  const _EpubQuoteBlock({
    required this.settings,
    required this.depth,
    required this.child,
  });

  final ReaderSettings settings;
  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final levels = depth < 1 ? 1 : depth;
    var framed = child;
    for (var level = 0; level < levels; level += 1) {
      final alpha = (0.45 - level * 0.04).clamp(0.25, 0.45).toDouble();
      framed = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: settings.themePreset.link.withValues(alpha: alpha),
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: epubQuoteIndent),
          child: framed,
        ),
      );
    }
    return framed;
  }
}

/// A rule across the column.
///
/// It stands where a `---` does in the source: a breath between two passages,
/// not a box around anything. Its height is fixed so the paginator and the
/// view agree on how much room it takes.
final class _EpubDivider extends StatelessWidget {
  const _EpubDivider({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: epubDividerHeight,
        child: Center(
          child: SizedBox(
            width: double.infinity,
            height: 1,
            child: ColoredBox(
              color: settings.themePreset.foreground.withValues(alpha: 0.16),
            ),
          ),
        ),
      ),
    );
  }
}

/// A table, drawn as a table.
///
/// Equal columns, ruled rows and a bold header: the point of a table is that
/// the eye can follow a column down, which is exactly what a run of pipes
/// cannot offer. Cells wrap rather than making the table wider than the page,
/// because a reader who raises the font size must not be handed a table that
/// runs off the edge. A table taller than a page is split between rows, and
/// each part repeats its header — that happens in the paginator.
TextAlign _textAlignFor(EpubTableAlignment alignment) {
  return switch (alignment) {
    EpubTableAlignment.center => TextAlign.center,
    EpubTableAlignment.right => TextAlign.right,
    EpubTableAlignment.none || EpubTableAlignment.left => TextAlign.left,
  };
}

typedef _EpubCellSpanBuilder =
    List<InlineSpan> Function(EpubTableCell cell, TextStyle style);

final class _EpubTableBlock extends StatelessWidget {
  const _EpubTableBlock({
    required this.settings,
    required this.cells,
    required this.hasHeader,
    required this.cellSpans,
    this.alignments = const <EpubTableAlignment>[],
  });

  final ReaderSettings settings;

  /// The rows this page shows; the header row first, when there is one.
  final List<List<EpubTableCell>> cells;

  final bool hasHeader;
  final List<EpubTableAlignment> alignments;
  final _EpubCellSpanBuilder cellSpans;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }
    final foreground = settings.themePreset.foreground;
    final family = ReaderFonts.renderFamilyFor(settings.fontFamily);
    final style = epubTableTextStyle(
      TextStyle(
        color: foreground,
        fontFamily: family.isEmpty ? null : family,
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        fontWeight: settings.themePreset.epubInk ? FontWeight.w400 : null,
      ),
    );
    final rule = BorderSide(
      color: foreground.withValues(alpha: 0.18),
      width: epubTableBorderWidth,
    );
    // Columns share the line the way their contents ask for it, so a column
    // of sentences is not squeezed into the slot of a column of numbers. The
    // paginator measures rows from the same shares.
    final flex = epubTableColumnFlex(cells);
    return Semantics(
      label: '表格',
      child: Table(
        defaultColumnWidth: const FlexColumnWidth(),
        columnWidths: <int, TableColumnWidth>{
          for (var column = 0; column < flex.length; column += 1)
            column: FlexColumnWidth(flex[column].toDouble()),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder(top: rule, bottom: rule, horizontalInside: rule),
        children: [
          for (var row = 0; row < cells.length; row += 1)
            TableRow(
              decoration: hasHeader && row == 0
                  ? BoxDecoration(color: foreground.withValues(alpha: 0.06))
                  : null,
              children: [
                for (var column = 0; column < cells[row].length; column += 1)
                  _cell(
                    cells[row][column],
                    row: row,
                    column: column,
                    style: style,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(
    EpubTableCell cell, {
    required int row,
    required int column,
    required TextStyle style,
  }) {
    final cellStyle = hasHeader && row == 0
        ? style.copyWith(fontWeight: FontWeight.w600)
        : style;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: epubTableCellPaddingHorizontal,
        vertical: epubTableCellPaddingVertical,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Text.rich(
          TextSpan(style: cellStyle, children: cellSpans(cell, cellStyle)),
          textAlign: _textAlignFor(
            column < alignments.length
                ? alignments[column]
                : EpubTableAlignment.none,
          ),
        ),
      ),
    );
  }
}

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
  const _EpubImagePlaceholder({required this.settings, required this.label});

  final ReaderSettings settings;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = settings.themePreset.foreground;
    final normalizedLabel = label.trim().isEmpty ? '图片占位' : label.trim();
    return Semantics(
      label: normalizedLabel,
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
