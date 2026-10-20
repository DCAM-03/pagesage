import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'epub_document.dart';

final class EpubDocumentLoader {
  const EpubDocumentLoader();

  static final Map<String, Future<EpubDocument>> _inFlight = {};
  static final Map<String, _CachedEpubDocument> _cache = {};
  static const int _maxCacheEntries = 4;

  Future<EpubDocument> load(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const EpubLoadException('EPUB 文件不存在');
    }
    final stat = await file.stat();
    final cacheKey =
        '${file.absolute.path}|${stat.modified.millisecondsSinceEpoch}|${stat.size}';

    final cached = _cache[cacheKey];
    if (cached != null) {
      // Refresh LRU order.
      _cache.remove(cacheKey);
      _cache[cacheKey] = cached;
      return cached.document;
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing;
    }

    final future = _loadUncached(file);
    _inFlight[cacheKey] = future;
    try {
      final document = await future;
      _cache[cacheKey] = _CachedEpubDocument(document: document);
      while (_cache.length > _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      return document;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<EpubDocument> _loadUncached(File file) async {
    // Stream zip from disk so open does not allocate a second full-file buffer.
    final input = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      return _documentFromArchive(archive);
    } finally {
      await input.close();
    }
  }

  Future<EpubDocument> _documentFromArchive(Archive archive) async {
    final entries = {
      for (final entry in archive.files) _normalizePath(entry.name): entry,
    };

    final container = _readUtf8(entries['META-INF/container.xml']);
    final opfPath = _findOpfPath(container);
    final opf = _readUtf8(entries[_normalizePath(opfPath)]);
    final package = _parsePackage(opf, opfPath);

    final chapters = <EpubChapter>[];
    for (final href in package.spinePaths) {
      final entry = entries[_normalizePath(href)];
      if (entry == null || !entry.isFile) {
        continue;
      }
      final xhtml = _readUtf8(entry);
      final text = _extractText(xhtml);
      // Keep empty/image-only spine items so TOC hrefs can still resolve.
      chapters.add(
        EpubChapter(
          index: chapters.length,
          href: href,
          title:
              _extractTitle(xhtml) ??
              (text.trim().isEmpty
                  ? '插图 ${chapters.length + 1}'
                  : '章节 ${chapters.length + 1}'),
          text: text,
        ),
      );
    }

    if (chapters.isEmpty ||
        chapters.every((chapter) => chapter.text.trim().isEmpty)) {
      throw const EpubLoadException('未找到可阅读的 EPUB 正文');
    }

    final toc = _findToc(
      entries: entries,
      package: package,
      chapters: chapters,
    );
    return EpubDocument(chapters: chapters, toc: toc);
  }

  String _findOpfPath(String containerXml) {
    final document = XmlDocument.parse(
      containerXml,
      entityMapping: const XmlDefaultEntityMapping.html5(),
    );
    final rootFile = _firstOrNull(
      document.findAllElements('rootfile', namespace: '*'),
    );
    final fullPath = rootFile?.getAttribute('full-path');
    if (fullPath == null || fullPath.isEmpty) {
      throw const EpubLoadException('EPUB 缺少 OPF 描述文件');
    }
    return fullPath;
  }

  _EpubPackage _parsePackage(String opfXml, String opfPath) {
    final document = XmlDocument.parse(
      opfXml,
      entityMapping: const XmlDefaultEntityMapping.html5(),
    );
    final basePath = p.url.dirname(opfPath);
    final manifest = <String, _ManifestItem>{};
    for (final item in document.findAllElements('item', namespace: '*')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifest[id] = _ManifestItem(
          id: id,
          href: _joinArchivePath(basePath, href),
          mediaType: item.getAttribute('media-type') ?? '',
          properties: item.getAttribute('properties') ?? '',
        );
      }
    }

    final paths = <String>[];
    final spine = _firstOrNull(
      document.findAllElements('spine', namespace: '*'),
    );
    final ncxId = spine?.getAttribute('toc');
    for (final itemRef in document.findAllElements('itemref', namespace: '*')) {
      final idRef = itemRef.getAttribute('idref');
      final href = idRef == null ? null : manifest[idRef];
      if (href != null) {
        paths.add(href.href);
      }
    }
    return _EpubPackage(
      manifest: manifest,
      spinePaths: paths,
      navPath: manifest.values
          .where(
            (item) => item.properties.split(RegExp(r'\s+')).contains('nav'),
          )
          .map((item) => item.href)
          .firstOrNull,
      ncxPath: ncxId == null
          ? manifest.values
                .where(
                  (item) =>
                      item.mediaType == 'application/x-dtbncx+xml' ||
                      item.href.toLowerCase().endsWith('.ncx'),
                )
                .map((item) => item.href)
                .firstOrNull
          : manifest[ncxId]?.href,
    );
  }

  List<EpubTocItem> _findToc({
    required Map<String, ArchiveFile> entries,
    required _EpubPackage package,
    required List<EpubChapter> chapters,
  }) {
    final navPath = package.navPath;
    if (navPath != null) {
      final navEntry = entries[_normalizePath(navPath)];
      if (navEntry != null && navEntry.isFile) {
        final nav = _parseNavToc(
          _readUtf8(navEntry),
          navPath,
          chapters,
          entries,
        );
        if (nav.isNotEmpty) {
          return nav;
        }
      }
    }

    final ncxPath = package.ncxPath;
    if (ncxPath != null) {
      final ncxEntry = entries[_normalizePath(ncxPath)];
      if (ncxEntry != null && ncxEntry.isFile) {
        final ncx = _parseNcxToc(
          _readUtf8(ncxEntry),
          ncxPath,
          chapters,
          entries,
        );
        if (ncx.isNotEmpty) {
          return ncx;
        }
      }
    }

    return chapters
        .map(
          (chapter) => EpubTocItem(
            title: chapter.title,
            href: chapter.href,
            chapterIndex: chapter.index,
          ),
        )
        .toList(growable: false);
  }

  List<EpubTocItem> _parseNavToc(
    String navXhtml,
    String navPath,
    List<EpubChapter> chapters,
    Map<String, ArchiveFile> entries,
  ) {
    try {
      final document = XmlDocument.parse(
        navXhtml,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      );
      final navElement = document.findAllElements('nav', namespace: '*').where((
        element,
      ) {
        final typeTokens = <String>{
          ..._attributeTokens(element, 'type'),
          ..._attributeTokens(element, 'epub:type'),
          ..._attributeTokens(element, 'role'),
        };
        return typeTokens.contains('toc') || typeTokens.contains('doc-toc');
      }).firstOrNull;
      // Some producers omit epub:type; fall back to the first nav with an ol/ul.
      final fallbackNav =
          navElement ??
          document.findAllElements('nav', namespace: '*').where((element) {
            return element.findAllElements('ol', namespace: '*').isNotEmpty ||
                element.findAllElements('ul', namespace: '*').isNotEmpty;
          }).firstOrNull;
      if (fallbackNav == null) {
        return const [];
      }
      final list =
          fallbackNav.findElements('ol', namespace: '*').firstOrNull ??
          fallbackNav.findElements('ul', namespace: '*').firstOrNull;
      return list == null
          ? const []
          : _parseNavList(list, p.url.dirname(navPath), chapters, entries);
    } on Object {
      return const [];
    }
  }

  List<EpubTocItem> _parseNavList(
    XmlElement list,
    String basePath,
    List<EpubChapter> chapters,
    Map<String, ArchiveFile> entries,
  ) {
    final items = <EpubTocItem>[];
    for (final li in list.findElements('li', namespace: '*')) {
      final link =
          li.findElements('a', namespace: '*').firstOrNull ??
          li.findElements('span', namespace: '*').firstOrNull;
      final title = _cleanTitle(link?.innerText);
      final rawHref = link?.name.local == 'a'
          ? link?.getAttribute('href')
          : null;
      final childList =
          li.findElements('ol', namespace: '*').firstOrNull ??
          li.findElements('ul', namespace: '*').firstOrNull;
      final children = childList == null
          ? const <EpubTocItem>[]
          : _parseNavList(childList, basePath, chapters, entries);
      if (title == null || title.isEmpty) {
        items.addAll(children);
        continue;
      }
      final target = _resolveTocTarget(basePath, rawHref, chapters, entries);
      items.add(
        EpubTocItem(
          title: title,
          href: target.href,
          chapterIndex: target.chapterIndex,
          fragment: target.fragment,
          chapterOffset: target.chapterOffset,
          children: children,
        ),
      );
    }
    return items;
  }

  List<EpubTocItem> _parseNcxToc(
    String ncxXml,
    String ncxPath,
    List<EpubChapter> chapters,
    Map<String, ArchiveFile> entries,
  ) {
    try {
      final document = XmlDocument.parse(
        ncxXml,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      );
      final navMap = document
          .findAllElements('navMap', namespace: '*')
          .firstOrNull;
      if (navMap == null) {
        return const [];
      }
      return _parseNcxPoints(navMap, p.url.dirname(ncxPath), chapters, entries);
    } on Object {
      return const [];
    }
  }

  List<EpubTocItem> _parseNcxPoints(
    XmlElement parent,
    String basePath,
    List<EpubChapter> chapters,
    Map<String, ArchiveFile> entries,
  ) {
    final items = <EpubTocItem>[];
    for (final point in parent.findElements('navPoint', namespace: '*')) {
      final title = _cleanTitle(
        point
            .findElements('navLabel', namespace: '*')
            .firstOrNull
            ?.findElements('text', namespace: '*')
            .firstOrNull
            ?.innerText,
      );
      final rawHref = point
          .findElements('content', namespace: '*')
          .firstOrNull
          ?.getAttribute('src');
      final children = _parseNcxPoints(point, basePath, chapters, entries);
      if (title == null || title.isEmpty) {
        items.addAll(children);
        continue;
      }
      final target = _resolveTocTarget(basePath, rawHref, chapters, entries);
      items.add(
        EpubTocItem(
          title: title,
          href: target.href,
          chapterIndex: target.chapterIndex,
          fragment: target.fragment,
          chapterOffset: target.chapterOffset,
          children: children,
        ),
      );
    }
    return items;
  }

  _TocTarget _resolveTocTarget(
    String basePath,
    String? rawHref,
    List<EpubChapter> chapters,
    Map<String, ArchiveFile> entries,
  ) {
    if (chapters.isEmpty) {
      return const _TocTarget(href: '', chapterIndex: null);
    }
    if (rawHref == null || rawHref.trim().isEmpty) {
      final first = chapters.first;
      return _TocTarget(href: first.href, chapterIndex: first.index);
    }

    final decoded = _decodeHref(rawHref.trim());
    final hashIndex = decoded.indexOf('#');
    final pathPart = hashIndex >= 0 ? decoded.substring(0, hashIndex) : decoded;
    final fragment = hashIndex >= 0 && hashIndex < decoded.length - 1
        ? decoded.substring(hashIndex + 1)
        : null;
    final queryIndex = pathPart.indexOf('?');
    final cleanPath = queryIndex >= 0
        ? pathPart.substring(0, queryIndex)
        : pathPart;

    final resolvedHref = cleanPath.isEmpty
        ? null
        : _joinArchivePath(basePath, cleanPath);
    final chapter = resolvedHref == null
        ? null
        : _matchChapter(resolvedHref, chapters);

    final offset = fragment == null || fragment.isEmpty
        ? null
        : _fragmentOffset(
            chapter: chapter,
            fragment: fragment,
            entries: entries,
          );

    return _TocTarget(
      href: chapter?.href ?? resolvedHref ?? chapters.first.href,
      chapterIndex: chapter?.index,
      fragment: fragment,
      chapterOffset: offset,
    );
  }

  EpubChapter? _matchChapter(String href, List<EpubChapter> chapters) {
    final normalized = _normalizePath(href);
    final byExact = chapters
        .where((chapter) => _normalizePath(chapter.href) == normalized)
        .firstOrNull;
    if (byExact != null) {
      return byExact;
    }

    final byLower = chapters
        .where(
          (chapter) =>
              _normalizePath(chapter.href).toLowerCase() ==
              normalized.toLowerCase(),
        )
        .firstOrNull;
    if (byLower != null) {
      return byLower;
    }

    final targetBase = p.url.basename(normalized).toLowerCase();
    final byBase = chapters
        .where(
          (chapter) => p.url.basename(chapter.href).toLowerCase() == targetBase,
        )
        .toList(growable: false);
    if (byBase.length == 1) {
      return byBase.single;
    }

    // Prefer longest suffix match: "Text/ch1.xhtml" vs "OEBPS/Text/ch1.xhtml".
    EpubChapter? best;
    var bestScore = -1;
    for (final chapter in chapters) {
      final candidate = _normalizePath(chapter.href);
      if (candidate.endsWith(normalized) || normalized.endsWith(candidate)) {
        final score = candidate.length < normalized.length
            ? candidate.length
            : normalized.length;
        if (score > bestScore) {
          bestScore = score;
          best = chapter;
        }
      }
    }
    return best;
  }

  int? _fragmentOffset({
    required EpubChapter? chapter,
    required String fragment,
    required Map<String, ArchiveFile> entries,
  }) {
    if (chapter == null) {
      return null;
    }
    final entry = entries[_normalizePath(chapter.href)];
    if (entry == null || !entry.isFile) {
      return null;
    }
    final xhtml = _readUtf8(entry);
    try {
      final document = XmlDocument.parse(
        xhtml,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      );
      final body = document.findAllElements('body', namespace: '*').firstOrNull;
      if (body == null) {
        return null;
      }
      final target = body.descendants.whereType<XmlElement>().where((element) {
        final id = element.getAttribute('id') ?? element.getAttribute('name');
        return id == fragment;
      }).firstOrNull;
      if (target == null) {
        return null;
      }
      // Approximate text offset by measuring plain text before the target node.
      final before = StringBuffer();
      for (final node in body.descendants) {
        if (identical(node, target)) {
          break;
        }
        if (node is XmlText) {
          before.write(node.value);
        }
      }
      final normalized = _normalizeText(before.toString());
      if (normalized.isEmpty) {
        return 0;
      }
      // Keep offset within chapter bounds for safer restore.
      return normalized.length.clamp(0, chapter.text.length).toInt();
    } on Object {
      return null;
    }
  }

  String _extractText(String xhtml) {
    try {
      final document = XmlDocument.parse(
        xhtml,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      );
      final body = _firstOrNull(
        document.findAllElements('body', namespace: '*'),
      );
      return _normalizeText((body ?? document.rootElement).innerText);
    } on XmlParserException {
      final withoutScripts = xhtml
          .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
            ' ',
          )
          .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
            ' ',
          );
      return _normalizeText(withoutScripts.replaceAll(RegExp(r'<[^>]+>'), ' '));
    }
  }

  String? _extractTitle(String xhtml) {
    try {
      final document = XmlDocument.parse(
        xhtml,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      );
      for (final tag in const ['h1', 'h2', 'h3', 'title']) {
        final text = _cleanTitle(
          document.findAllElements(tag, namespace: '*').firstOrNull?.innerText,
        );
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
      return null;
    } on XmlParserException {
      return null;
    }
  }

  String _readUtf8(ArchiveFile? file) {
    if (file == null || !file.isFile) {
      throw const EpubLoadException('EPUB 文件结构不完整');
    }
    return utf8.decode(file.content, allowMalformed: true);
  }

  String _joinArchivePath(String basePath, String href) {
    final cleaned = href.replaceAll('\\', '/');
    if (cleaned.startsWith('/')) {
      return _normalizePath(cleaned.substring(1));
    }
    if (basePath == '.' || basePath.isEmpty) {
      return _normalizePath(cleaned);
    }
    return _normalizePath(p.url.join(basePath.replaceAll('\\', '/'), cleaned));
  }

  String _normalizePath(String value) {
    var path = value.replaceAll('\\', '/');
    // Collapse accidental absolute-style roots from producers.
    while (path.startsWith('./')) {
      path = path.substring(2);
    }
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    return p.url.normalize(path);
  }

  String _decodeHref(String value) {
    try {
      return Uri.decodeFull(value);
    } on Object {
      return value;
    }
  }

  String _normalizeText(String value) {
    return value
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'[ \t\r\f]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
        .trim();
  }

  String? _cleanTitle(String? value) {
    if (value == null) {
      return null;
    }
    final cleaned = value
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Set<String> _attributeTokens(XmlElement element, String name) {
    final raw =
        element.getAttribute(name) ??
        element.getAttribute(name, namespace: '*') ??
        '';
    if (raw.trim().isEmpty) {
      return const {};
    }
    return raw
        .split(RegExp(r'[\s|]+'))
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

final class EpubLoadException implements Exception {
  const EpubLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class _CachedEpubDocument {
  const _CachedEpubDocument({required this.document});

  final EpubDocument document;
}

final class _EpubPackage {
  const _EpubPackage({
    required this.manifest,
    required this.spinePaths,
    required this.navPath,
    required this.ncxPath,
  });

  final Map<String, _ManifestItem> manifest;
  final List<String> spinePaths;
  final String? navPath;
  final String? ncxPath;
}

final class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String mediaType;
  final String properties;
}

final class _TocTarget {
  const _TocTarget({
    required this.href,
    required this.chapterIndex,
    this.fragment,
    this.chapterOffset,
  });

  final String href;
  final int? chapterIndex;
  final String? fragment;
  final int? chapterOffset;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
