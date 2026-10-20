import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_document/pdf_document.dart';
import 'package:xml/xml.dart';

import '../../domain/books/book.dart';
import '../tasks/task_cancellation.dart';
import 'app_paths.dart';

/// Paints a PDF's first page into a PNG, or returns null when it cannot.
///
/// Injected rather than imported so this file — and the `dart run` tools built
/// on it — stay free of `dart:ui`. The app passes `PdfCoverRenderer`, which
/// renders the page the reader would see; a headless caller passes nothing and
/// gets the embedded-JPEG fallback.
typedef PdfCoverPainter = Future<Uint8List?> Function(Uint8List bytes);

final class BookMetadata {
  const BookMetadata({
    this.title,
    this.author,
    this.language,
    this.description,
    this.coverPath,
  });

  final String? title;
  final String? author;
  final String? language;
  final String? description;
  final String? coverPath;
}

final class MetadataExtractor {
  const MetadataExtractor({
    required AppPaths appPaths,
    PdfCoverPainter? pdfCoverPainter,
  }) : this._(appPaths, pdfCoverPainter);

  const MetadataExtractor._(this._appPaths, this._pdfCoverPainter);

  final AppPaths _appPaths;

  /// Optional page painter for PDF covers; null falls back to embedded images.
  final PdfCoverPainter? _pdfCoverPainter;

  Future<BookMetadata> extract({
    required File file,
    required BookFormat format,
    required String bookId,
    TaskCancelToken? cancelToken,
  }) {
    cancelToken?.throwIfCancelled();
    return switch (format) {
      BookFormat.epub => _extractEpub(file, bookId, cancelToken),
      BookFormat.pdf => _extractPdf(file, bookId, cancelToken),
    };
  }

  Future<BookMetadata> _extractEpub(
    File file,
    String bookId,
    TaskCancelToken? cancelToken,
  ) async {
    // Stream the zip from disk so large EPUBs do not need a second full-file
    // buffer on top of the import copy/hash pass. Always close the handle
    // (Windows keeps the temp file locked otherwise).
    cancelToken?.throwIfCancelled();
    final input = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      cancelToken?.throwIfCancelled();
      final container = _fileByName(archive, 'META-INF/container.xml');
      if (container == null) {
        return const BookMetadata();
      }
      final containerXml = _parseXml(_readArchiveText(container));
      final rootfile = containerXml
          .findAllElements('rootfile', namespace: '*')
          .firstOrNull
          ?.getAttribute('full-path');
      if (rootfile == null || rootfile.isEmpty) {
        return const BookMetadata();
      }
      final opfFile = _fileByName(archive, rootfile);
      if (opfFile == null) {
        return const BookMetadata();
      }
      final opf = _parseXml(_readArchiveText(opfFile));
      final metadata = opf
          .findAllElements('metadata', namespace: '*')
          .firstOrNull;
      final title = _text(metadata, 'title');
      final author = _text(metadata, 'creator');
      final language = _text(metadata, 'language');
      final description = _text(metadata, 'description');
      cancelToken?.throwIfCancelled();
      final coverPath = await _extractEpubCover(
        archive: archive,
        opf: opf,
        opfPath: rootfile,
        bookId: bookId,
        cancelToken: cancelToken,
      );
      return BookMetadata(
        title: title,
        author: author,
        language: language,
        description: description,
        coverPath: coverPath,
      );
    } finally {
      await input.close();
    }
  }

  Future<String?> _extractEpubCover({
    required Archive archive,
    required XmlDocument opf,
    required String opfPath,
    required String bookId,
    TaskCancelToken? cancelToken,
  }) async {
    final items = opf.findAllElements('item', namespace: '*').toList();
    final itemById = <String, XmlElement>{
      for (final item in items)
        if ((item.getAttribute('id') ?? '').isNotEmpty)
          item.getAttribute('id')!: item,
    };

    final hrefCandidates = <String>[];

    void addHref(String? href) {
      final value = href?.trim();
      if (value == null || value.isEmpty) {
        return;
      }
      final cleaned = value.split('#').first.trim();
      if (cleaned.isEmpty || hrefCandidates.contains(cleaned)) {
        return;
      }
      hrefCandidates.add(cleaned);
    }

    // 1) EPUB2: <meta name="cover" content="id"/>
    for (final meta in opf.findAllElements('meta', namespace: '*')) {
      final name = (meta.getAttribute('name') ?? '').toLowerCase();
      final property = (meta.getAttribute('property') ?? '').toLowerCase();
      if (name == 'cover') {
        final id = meta.getAttribute('content');
        if (id != null && itemById.containsKey(id)) {
          addHref(itemById[id]!.getAttribute('href'));
        }
      }
      // 2) EPUB3: <meta property="cover-image">id-or-href</meta>
      if (property == 'cover-image' || property.endsWith(':cover-image')) {
        final ref = meta.innerText.trim();
        if (itemById.containsKey(ref)) {
          addHref(itemById[ref]!.getAttribute('href'));
        } else {
          addHref(ref);
        }
      }
    }

    // 3) EPUB3 manifest properties="cover-image"
    for (final item in items) {
      final properties = (item.getAttribute('properties') ?? '').toLowerCase();
      if (properties.split(RegExp(r'\s+')).contains('cover-image')) {
        addHref(item.getAttribute('href'));
      }
    }

    // 4) guide reference type="cover"
    for (final reference in opf.findAllElements('reference', namespace: '*')) {
      final type = (reference.getAttribute('type') ?? '').toLowerCase();
      if (type == 'cover' || type == 'other.ms-coverimage-standard') {
        addHref(reference.getAttribute('href'));
      }
    }

    // 5) id/href contains "cover"
    for (final item in items) {
      final id = (item.getAttribute('id') ?? '').toLowerCase();
      final href = (item.getAttribute('href') ?? '').toLowerCase();
      final media = (item.getAttribute('media-type') ?? '').toLowerCase();
      if (!media.startsWith('image/')) {
        continue;
      }
      if (id.contains('cover') || href.contains('cover')) {
        addHref(item.getAttribute('href'));
      }
    }

    // 6) first image/* in manifest as last resort
    for (final item in items) {
      final media = (item.getAttribute('media-type') ?? '').toLowerCase();
      if (media.startsWith('image/')) {
        addHref(item.getAttribute('href'));
        break;
      }
    }

    final opfDir = p.posix.dirname(opfPath);
    for (final href in hrefCandidates) {
      cancelToken?.throwIfCancelled();
      final entryPath = _resolveOpfHref(opfDir, href);
      final cover =
          _fileByName(archive, entryPath) ??
          _fileByBasename(archive, p.posix.basename(entryPath));
      if (cover == null || !cover.isFile) {
        continue;
      }
      final content = cover.content;
      if (content.isEmpty) {
        continue;
      }
      final bytes = Uint8List.fromList(content);
      final extension = _extensionForCover(entryPath, cover.name, bytes);
      final targetPath = await _appPaths.coverPath(
        bookId: bookId,
        extension: extension,
      );
      cancelToken?.throwIfCancelled();
      await File(targetPath).writeAsBytes(bytes);
      return targetPath;
    }
    return null;
  }

  Future<BookMetadata> _extractPdf(
    File file,
    String bookId,
    TaskCancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    // Single full read for PDF metadata+cover; avoid an extra list copy.
    final bytes = await file.readAsBytes();
    cancelToken?.throwIfCancelled();

    String? title;
    String? author;
    String? description;
    try {
      final document = PdfDocument.open(bytes);
      cancelToken?.throwIfCancelled();
      final docTitle = document.info['Title']?.trim();
      final docAuthor = document.info['Author']?.trim();
      final pageCount = document.pageCount;
      title = docTitle?.isEmpty == true ? null : docTitle;
      author = docAuthor?.isEmpty == true ? null : docAuthor;
      description = pageCount > 0 ? 'PDF，$pageCount 页' : null;
    } on Object {
      // Keep going — cover heuristic can still succeed on imperfect PDFs.
    }

    final coverPath = await _extractPdfCover(
      bytes: bytes,
      bookId: bookId,
      cancelToken: cancelToken,
    );
    return BookMetadata(
      title: title,
      author: author,
      description: description,
      coverPath: coverPath,
    );
  }

  /// Cover for a PDF: page 1, painted.
  ///
  /// A PDF has no cover manifest — page 1 is the only thing every book agrees
  /// on, and it is what opening the book shows. The previous heuristic scanned
  /// the file for embedded JPEG streams and kept the largest cover-sized one,
  /// which surfaced whatever photograph the body happened to contain (in
  /// practice: screenshots of code) and produced nothing at all for a
  /// vector-only first page. Rendering is a few hundred milliseconds on a
  /// dense page and happens once, during import.
  ///
  /// Falls back to the embedded-image scan when no painter is supplied or the
  /// page cannot be rasterized: a headless caller (a unit test without a
  /// renderer, the CLI refresh tool) has no platform rasterizer but can still
  /// pick a stream.
  Future<String?> _extractPdfCover({
    required Uint8List bytes,
    required String bookId,
    TaskCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final painter = _pdfCoverPainter;
    final rendered = painter == null ? null : await painter(bytes);
    cancelToken?.throwIfCancelled();
    if (rendered != null && rendered.length > 128) {
      final targetPath = await _appPaths.coverPath(
        bookId: bookId,
        extension: 'png',
      );
      await File(targetPath).writeAsBytes(rendered, flush: true);
      return targetPath;
    }
    final jpegs = _extractEmbeddedJpegs(bytes);
    if (jpegs.isEmpty) {
      return null;
    }
    // Largest first: the cover art of a scanned book is its biggest image, and
    // the common failure — a screenshot of body content — is now only reached
    // when page 1 itself could not be painted.
    jpegs.sort((a, b) => b.length.compareTo(a.length));
    Uint8List? chosen;
    for (final jpeg in jpegs) {
      if (!_looksLikeValidJpeg(jpeg)) {
        continue;
      }
      if (jpeg.length >= 8 * 1024 && jpeg.length <= 2 * 1024 * 1024) {
        chosen = jpeg;
        break;
      }
      chosen ??= jpeg;
    }
    if (chosen == null) {
      return null;
    }
    final targetPath = await _appPaths.coverPath(
      bookId: bookId,
      extension: 'jpg',
    );
    cancelToken?.throwIfCancelled();
    await File(targetPath).writeAsBytes(chosen, flush: true);
    return targetPath;
  }

  List<Uint8List> _extractEmbeddedJpegs(Uint8List bytes) {
    final out = <Uint8List>[];
    var i = 0;
    while (i < bytes.length - 3) {
      // Real JPEGs are SOI (FFD8) followed by another marker (FFxx), usually
      // APP0/APP1 (FFE0/FFE1). Accepting bare FFD8…FFD9 slices produces
      // corrupt covers that spam native decoders and can destabilize the UI.
      if (bytes[i] == 0xFF &&
          bytes[i + 1] == 0xD8 &&
          i + 3 < bytes.length &&
          bytes[i + 2] == 0xFF) {
        var j = i + 2;
        while (j < bytes.length - 1) {
          if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
            final slice = bytes.sublist(i, j + 2);
            // Skip tiny thumbnails / noise.
            if (slice.length >= 4 * 1024 && _looksLikeValidJpeg(slice)) {
              out.add(slice);
            }
            i = j + 1;
            break;
          }
          j += 1;
        }
      }
      i += 1;
    }
    return out;
  }

  /// Minimal structural check: SOI + marker + EOI.
  bool _looksLikeValidJpeg(Uint8List bytes) {
    if (bytes.length < 4) {
      return false;
    }
    if (bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
      return false;
    }
    if (bytes[bytes.length - 2] != 0xFF || bytes[bytes.length - 1] != 0xD9) {
      return false;
    }
    return true;
  }

  String _resolveOpfHref(String opfDir, String href) {
    final decoded = Uri.decodeFull(href.replaceAll('\\', '/'));
    final joined = opfDir == '.' || opfDir.isEmpty
        ? decoded
        : p.posix.normalize(p.posix.join(opfDir, decoded));
    return joined.replaceAll('\\', '/');
  }

  String _extensionForCover(String path, String archiveName, Uint8List bytes) {
    final fromPath = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (fromPath.isNotEmpty && fromPath.length <= 5) {
      return fromPath;
    }
    final fromName = p
        .extension(archiveName)
        .replaceFirst('.', '')
        .toLowerCase();
    if (fromName.isNotEmpty && fromName.length <= 5) {
      return fromName;
    }
    if (bytes.length > 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'img';
  }

  XmlDocument _parseXml(String text) {
    return XmlDocument.parse(
      text,
      entityMapping: const XmlDefaultEntityMapping.html5(),
    );
  }

  ArchiveFile? _fileByName(Archive archive, String name) {
    final normalized = name.replaceAll('\\', '/');
    final stripped = normalized.startsWith('/')
        ? normalized.substring(1)
        : normalized;
    for (final file in archive.files) {
      final fileName = file.name.replaceAll('\\', '/');
      if (fileName == stripped ||
          fileName.toLowerCase() == stripped.toLowerCase()) {
        return file;
      }
    }
    return null;
  }

  ArchiveFile? _fileByBasename(Archive archive, String basename) {
    final target = basename.toLowerCase();
    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/');
      if (p.posix.basename(name).toLowerCase() == target) {
        return file;
      }
    }
    return null;
  }

  String _readArchiveText(ArchiveFile file) {
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  String? _text(XmlElement? parent, String localName) {
    final value = parent
        ?.findAllElements(localName, namespace: '*')
        .firstOrNull
        ?.innerText
        .trim();
    return value?.isEmpty == true ? null : value;
  }
}
