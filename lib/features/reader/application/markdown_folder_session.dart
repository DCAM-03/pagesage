import 'dart:async';

import '../../../domain/books/book.dart';
import '../../../domain/books/reading_position.dart';
import '../../../renderers/common/renderer_event.dart';
import '../../../renderers/markdown/markdown_folder.dart';
import '../../../renderers/markdown/markdown_folder_diff.dart';

/// Owns which note is open in a folder book and how its local position is
/// translated to the book-wide position stored in the library.
///
/// A folder book is one shelf entry over many files, but the renderer opens
/// one file at a time. The controller keeps that distinction in one place so
/// the reading page only has to render the active file and its outline.
final class MarkdownFolderSessionController {
  MarkdownFolderSessionController({MarkdownFolderSource? source})
    : _source = source ?? const MarkdownFolderLoader();

  final MarkdownFolderSource _source;

  MarkdownFolderSource get source => _source;

  String? _bookId;
  Future<MarkdownFolderSession>? _future;
  MarkdownFolderSession? _session;

  MarkdownFolderManifest? get manifest => _session?.manifest;
  MarkdownFolderFile? get activeFile => _session?.activeFile;
  ReadingLocator? get initialLocator => _session?.initialLocator;

  void replaceManifest(
    MarkdownFolderManifest manifest, {
    bool keepActiveFile = true,
  }) {
    final current = _session;
    if (current == null) return;
    final currentActive = current.activeFile;
    final active = keepActiveFile
        ? manifest.fileForHref(currentActive.relativePath)
        : null;
    if (keepActiveFile && active == null) {
      _folderNotice = '文件已移除，当前为上次内容';
      return;
    }
    _folderNotice = null;
    _session = MarkdownFolderSession(
      manifest: manifest,
      activeFile: active ?? manifest.firstFile ?? currentActive,
      initialLocator: current.initialLocator,
    );
  }

  void markActiveFileUnavailable(String message) {
    final current = _session;
    if (current == null) return;
    _folderNotice = message;
  }

  String? get folderNotice => _folderNotice;
  String? _folderNotice;

  ReadingAnchorResult reanchor(
    ReadingLocator locator, {
    required String oldText,
    required String newText,
    bool textRevisionChanged = true,
  }) {
    return const ReadingAnchorResolver().resolve(
      locator,
      oldText: oldText,
      newText: newText,
      textRevisionChanged: textRevisionChanged,
    );
  }

  Future<MarkdownFolderSession> load({
    required Book book,
    required ReadingLocator? initialLocator,
  }) {
    final pending = _bookId == book.id ? _future : null;
    if (pending != null) {
      return pending;
    }
    _bookId = book.id;
    _session = null;
    late final Future<MarkdownFolderSession> future;
    future = _load(book.id, book.libraryFilePath, initialLocator, () => future);
    _future = future;
    return future;
  }

  Future<MarkdownFolderSession> _load(
    String bookId,
    String libraryFilePath,
    ReadingLocator? initialLocator,
    Future<MarkdownFolderSession> Function() currentFuture,
  ) async {
    final manifest = await _source.loadManifest(libraryFilePath);
    final restored = await _resolveInitialLocator(
      rootPath: libraryFilePath,
      manifest: manifest,
      locator: initialLocator,
    );
    final activeFile =
        manifest.fileForHref(restored?.href) ??
        manifest.fileAtProgress(restored?.progress ?? 0) ??
        manifest.firstFile;
    if (activeFile == null) {
      throw const MarkdownFolderException('这个文件夹里没有 Markdown 文件');
    }
    final session = MarkdownFolderSession(
      manifest: manifest,
      activeFile: activeFile,
      initialLocator: _localized(restored, activeFile),
    );
    if (_bookId == bookId && identical(_future, currentFuture())) {
      _session = session;
    }
    return session;
  }

  Future<ReadingLocator?> _resolveInitialLocator({
    required String rootPath,
    required MarkdownFolderManifest manifest,
    required ReadingLocator? locator,
  }) async {
    var target = locator;
    if (target == null ||
        target.type != ReadingLocatorType.markdown ||
        target.folderFileLocal ||
        target.chapterIndex == null) {
      return target;
    }
    final legacy = await _source.resolveLegacyPosition(
      rootPath,
      target.chapterIndex!,
    );
    if (legacy != null) {
      return _copyMarkdown(
        target,
        href: legacy.relativePath,
        chapterIndex: legacy.chapterIndex,
        folderFileLocal: true,
      );
    }
    final byHref = manifest.fileForHref(target.href);
    if (byHref == null) {
      return target;
    }
    return _copyMarkdown(
      target,
      href: byHref.relativePath,
      chapterIndex: 0,
      chapterOffset: 0,
      progress: manifest.progressForFile(byHref.relativePath, 0),
      folderFileLocal: true,
    );
  }

  ReadingLocator? _localized(ReadingLocator? locator, MarkdownFolderFile file) {
    if (locator == null || locator.type != ReadingLocatorType.markdown) {
      return locator;
    }
    return _copyMarkdown(
      locator,
      href: file.relativePath,
      folderFileLocal: true,
    );
  }

  /// True when [locator] names a file that differs from the active one.
  bool switchesFile(ReadingLocator locator) {
    final file = manifest?.fileForHref(locator.href);
    return file != null && file.relativePath != activeFile?.relativePath;
  }

  MarkdownFolderFile? fileForJump(ReadingLocator locator) {
    final current = manifest;
    if (current == null) {
      return null;
    }
    return current.fileForHref(locator.href) ?? activeFile;
  }

  /// Whether a jump has to read the old merged document to find its file.
  bool needsLegacyJump(ReadingLocator locator) {
    return manifest != null &&
        locator.type == ReadingLocatorType.markdown &&
        manifest!.fileForHref(locator.href) == null &&
        !locator.folderFileLocal &&
        locator.chapterIndex != null;
  }

  /// Switches the active note and returns the file-local opening position.
  ReadingLocator openFile(MarkdownFolderFile file) {
    return selectFile(file);
  }

  /// Selects [file] and translates [locator] into its file-local coordinate.
  ReadingLocator selectFile(
    MarkdownFolderFile file, {
    ReadingLocator? locator,
  }) {
    final current = manifest;
    if (current == null) {
      throw StateError('The folder manifest is not loaded');
    }
    final progress = current.progressForFile(file.relativePath, 0);
    _session = MarkdownFolderSession(
      manifest: current,
      activeFile: file,
      initialLocator: null,
    );
    if (locator != null) {
      return _copyMarkdown(
        locator,
        href: file.relativePath,
        folderFileLocal: true,
      );
    }
    return ReadingLocator.markdown(
      href: file.relativePath,
      chapterIndex: 0,
      chapterOffset: 0,
      progress: progress,
      folderFileLocal: true,
    );
  }

  ReadingProgressSnapshot? rendererProgress({
    required String bookId,
    required ReadingProgressSnapshot? snapshot,
    required ReadingProgressSnapshot? jumpProgress,
  }) {
    final base = jumpProgress ?? snapshot;
    final manifest = this.manifest;
    if (manifest == null) {
      return base;
    }
    final locator =
        jumpProgress?.locator ?? initialLocator ?? snapshot?.locator;
    final file =
        manifest.fileForHref(locator?.href) ??
        manifest.fileForHref(activeFile?.relativePath);
    if (file == null) {
      return base;
    }
    final localProgress = manifest.localProgressForFile(
      file.relativePath,
      locator?.progress ?? 0,
    );
    return ReadingProgressSnapshot(
      bookId: bookId,
      locator: ReadingLocator.markdown(
        href: file.relativePath,
        chapterIndex: locator?.chapterIndex,
        chapterOffset: locator?.chapterOffset,
        chapterEndOffset: locator?.chapterEndOffset,
        progress: localProgress,
        excerpt: locator?.excerpt,
        folderFileLocal: true,
      ),
      progress: localProgress,
      updatedAt: base?.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      chapterTitle: base?.chapterTitle,
      pageNumber: base?.pageNumber,
    );
  }

  ReadingLocator normalizeLocator(ReadingLocator locator) {
    final manifest = this.manifest;
    if (manifest == null ||
        locator.type != ReadingLocatorType.markdown ||
        locator.folderFileLocal) {
      return locator;
    }
    final file =
        manifest.fileForHref(locator.href) ??
        manifest.fileForHref(activeFile?.relativePath);
    if (file == null) {
      return locator;
    }
    return _copyMarkdown(
      locator,
      href: file.relativePath,
      progress: manifest.progressForFile(file.relativePath, locator.progress),
      folderFileLocal: true,
    );
  }

  RendererEvent normalizeEvent(RendererEvent event) {
    if (manifest == null) {
      return event;
    }
    return switch (event) {
      RendererLocationChanged() => () {
        final locator = normalizeLocator(event.locator);
        return RendererLocationChanged(
          locator: locator,
          progress: locator.progress,
          chapterTitle: event.chapterTitle,
          pageNumber: event.pageNumber,
          totalPages: event.totalPages,
        );
      }(),
      RendererTextSelected() => RendererTextSelected(
        text: event.text,
        locator: normalizeLocator(event.locator),
        sourceRect: event.sourceRect,
        selectionRects: event.selectionRects,
      ),
      RendererSearchResults() => RendererSearchResults([
        for (final result in event.results)
          RendererSearchResult(
            title: result.title,
            snippet: result.snippet,
            locator: normalizeLocator(result.locator),
          ),
      ]),
      _ => event,
    };
  }

  Future<ReadingLocator?> resolveLegacyJump(ReadingLocator locator) async {
    final manifest = this.manifest;
    final chapterIndex = locator.chapterIndex;
    if (manifest == null || chapterIndex == null) {
      return null;
    }
    final resolved = await _source.resolveLegacyPosition(
      manifest.rootPath,
      chapterIndex,
    );
    if (resolved == null) {
      return null;
    }
    return _copyMarkdown(
      locator,
      href: resolved.relativePath,
      chapterIndex: resolved.chapterIndex,
      folderFileLocal: true,
    );
  }

  ReadingLocator locatorForActiveFile(ReadingLocator locator) {
    final file = activeFile;
    if (file == null) {
      return locator;
    }
    return _copyMarkdown(
      locator,
      href: file.relativePath,
      folderFileLocal: true,
    );
  }

  ReadingLocator _copyMarkdown(
    ReadingLocator locator, {
    String? href,
    int? chapterIndex,
    int? chapterOffset,
    int? chapterEndOffset,
    double? progress,
    String? excerpt,
    bool? folderFileLocal,
  }) {
    return ReadingLocator.markdown(
      href: href ?? locator.href,
      chapterIndex: chapterIndex ?? locator.chapterIndex,
      chapterOffset: chapterOffset ?? locator.chapterOffset,
      chapterEndOffset: chapterEndOffset ?? locator.chapterEndOffset,
      progress: progress ?? locator.progress,
      excerpt: excerpt ?? locator.excerpt,
      selectionRects: locator.selectionRects,
      folderFileLocal: folderFileLocal ?? locator.folderFileLocal,
    );
  }
}

final class MarkdownFolderSession {
  const MarkdownFolderSession({
    required this.manifest,
    required this.activeFile,
    required this.initialLocator,
  });

  final MarkdownFolderManifest manifest;
  final MarkdownFolderFile activeFile;
  final ReadingLocator? initialLocator;
}
