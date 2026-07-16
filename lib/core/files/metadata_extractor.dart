import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_document/pdf_document.dart';
import 'package:xml/xml.dart';

import '../../domain/books/book.dart';
import '../tasks/task_cancellation.dart';
import 'app_paths.dart';

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
  const MetadataExtractor({required AppPaths appPaths}) : this._(appPaths);

  const MetadataExtractor._(this._appPaths);

  final AppPaths _appPaths;

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
    final bytes = await file.readAsBytes();
    cancelToken?.throwIfCancelled();
    final archive = ZipDecoder().decodeBytes(bytes);
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
    final metadata = opf.findAllElements('metadata', namespace: '*').firstOrNull;
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
      final cover = _fileByName(archive, entryPath) ??
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
    final raw = await file.readAsBytes();
    cancelToken?.throwIfCancelled();
    final bytes = Uint8List.fromList(raw);

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

  /// Heuristic PDF cover: pick the largest embedded JPEG stream.
  /// Many publisher PDFs store the first-page art as DCTDecode images.
  Future<String?> _extractPdfCover({
    required Uint8List bytes,
    required String bookId,
    TaskCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final jpegs = _extractEmbeddedJpegs(bytes);
    if (jpegs.isEmpty) {
      return null;
    }
    jpegs.sort((a, b) => b.length.compareTo(a.length));
    // Prefer a "cover-sized" image: not tiny icons, not multi-MB scans first.
    Uint8List chosen = jpegs.first;
    for (final jpeg in jpegs) {
      if (jpeg.length >= 8 * 1024 && jpeg.length <= 2 * 1024 * 1024) {
        chosen = jpeg;
        break;
      }
    }
    final targetPath = await _appPaths.coverPath(bookId: bookId, extension: 'jpg');
    cancelToken?.throwIfCancelled();
    await File(targetPath).writeAsBytes(chosen, flush: true);
    return targetPath;
  }

  List<Uint8List> _extractEmbeddedJpegs(Uint8List bytes) {
    final out = <Uint8List>[];
    var i = 0;
    while (i < bytes.length - 3) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
        var j = i + 2;
        while (j < bytes.length - 1) {
          if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
            final slice = bytes.sublist(i, j + 2);
            // Skip tiny thumbnails / noise.
            if (slice.length >= 4 * 1024) {
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

  String _resolveOpfHref(String opfDir, String href) {
    final decoded = Uri.decodeFull(href.replaceAll('\\', '/'));
    final joined = opfDir == '.' || opfDir.isEmpty
        ? decoded
        : p.posix.normalize(p.posix.join(opfDir, decoded));
    return joined.replaceAll('\\', '/');
  }

  String _extensionForCover(
    String path,
    String archiveName,
    Uint8List bytes,
  ) {
    final fromPath = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (fromPath.isNotEmpty && fromPath.length <= 5) {
      return fromPath;
    }
    final fromName =
        p.extension(archiveName).replaceFirst('.', '').toLowerCase();
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
