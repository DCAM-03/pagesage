import 'dart:io';
import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import '../../core/files/markdown_source.dart';
import '../common/image_size.dart';
import '../epub/epub_document.dart';

/// Turns a Markdown file into the document the reader already understands.
///
/// Markdown is read as a book of chapters and blocks, not as a page of
/// markup: a level-one heading starts a chapter, the blocks under it are
/// paragraphs, lists, quotes, code and pictures, and the chapter's text is
/// built while walking so every offset is known as it is written. That is
/// what lets the same pagination, progress, jump and search code serve
/// Markdown and EPUB alike.
///
/// Pictures take no characters, exactly as they do in an EPUB: the text is
/// only the words, and a picture sits between two runs of them.
final class MarkdownParser {
  const MarkdownParser({required this.basePath});

  /// The directory the file lives in, for resolving relative picture paths.
  final String basePath;

  /// The most bytes one picture may take.
  static const int maxImageBytes = 24 * 1024 * 1024;

  /// The most pixels one picture may have.
  static const int maxImagePixels = 40 * 1000 * 1000;

  /// How much of a picture is read to find its size.
  static const int _headerBytes = 128 * 1024;

  Future<EpubDocument> parse(
    String raw, {
    required String fallbackTitle,
  }) async {
    final source = MarkdownSource.parse(raw);
    final document = md.Document(
      // GitHub-flavoured Markdown is what a README or a note is written in:
      // tables, fenced code, strikethrough and task lists are all part of
      // the language as people actually use it.
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    final nodes = document.parseLines(source.body.split('\n'));
    final builder = _DocumentBuilder(
      fallbackTitle: source.title ?? fallbackTitle,
      parser: this,
    );
    await builder.walk(nodes);
    return builder.finish();
  }

  /// Reads a picture the document points at.
  Future<EpubImage> loadImage(String source, String? alt) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return _unavailable('', alt, '图片没有来源地址');
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Local-first: a document that points at the network does not get to
      // make the reader wait on it.
      return _unavailable('', alt, '远程图片不予加载');
    }
    if (trimmed.startsWith('data:')) {
      return _loadDataUri(trimmed, alt);
    }

    final path = _resolve(trimmed);
    final file = File(path);
    try {
      final length = await file.length();
      if (length > maxImageBytes) {
        return _unavailable(path, alt, '图片过大，已跳过');
      }
      // The header says how big the picture is; the rest of it is not read
      // until the reader draws it. A folder of notes is a folder of
      // screenshots, and holding all of them in the document is what turns
      // opening a book into a memory surprise.
      final size = readImageSize(await _readHeader(file, length));
      if (size != null && size.width * size.height > maxImagePixels) {
        return EpubImage(
          archivePath: path,
          bytes: Uint8List(0),
          pixelWidth: size.width,
          pixelHeight: size.height,
          alt: alt,
          unavailableReason: '图片像素过多，已跳过',
        );
      }
      return EpubImage(
        archivePath: path,
        bytes: Uint8List(0),
        sourcePath: path,
        pixelWidth: size?.width ?? 0,
        pixelHeight: size?.height ?? 0,
        alt: alt,
        unavailableReason: size == null ? '图片格式无法识别' : null,
      );
    } on FileSystemException {
      return _unavailable(path, alt, '图片不在磁盘上');
    } on Object {
      return _unavailable(path, alt, '图片无法读取');
    }
  }

  /// The first [_headerBytes] of a picture, which is all a header needs.
  Future<Uint8List> _readHeader(File file, int length) async {
    final handle = await file.open();
    try {
      final count = length < _headerBytes ? length : _headerBytes;
      return await handle.read(count);
    } finally {
      await handle.close();
    }
  }

  EpubImage _loadDataUri(String uri, String? alt) {
    try {
      final data = UriData.parse(uri);
      final bytes = data.contentAsBytes();
      if (bytes.lengthInBytes > maxImageBytes) {
        return _unavailable('data:', alt, '图片过大，已跳过');
      }
      final size = readImageSize(bytes);
      if (size != null && size.width * size.height > maxImagePixels) {
        return EpubImage(
          archivePath: 'data:',
          bytes: Uint8List(0),
          pixelWidth: size.width,
          pixelHeight: size.height,
          alt: alt,
          unavailableReason: '图片像素过多，已跳过',
        );
      }
      return EpubImage(
        archivePath: 'data:',
        bytes: bytes,
        pixelWidth: size?.width ?? 0,
        pixelHeight: size?.height ?? 0,
        alt: alt,
        unavailableReason: size == null ? '图片格式无法识别' : null,
      );
    } on Object {
      return _unavailable('', alt, '内嵌图片无法解码');
    }
  }

  String _resolve(String href) {
    final withoutFragment = href.split('#').first.split('?').first;
    final decoded = _decode(withoutFragment);
    if (decoded.startsWith('/')) {
      return p.normalize(decoded);
    }
    return p.normalize(p.join(basePath, decoded));
  }

  String _decode(String value) {
    try {
      return Uri.decodeFull(value);
    } on Object {
      return value;
    }
  }

  EpubImage _unavailable(String path, String? alt, String reason) {
    return EpubImage(
      archivePath: path,
      bytes: Uint8List(0),
      pixelWidth: 0,
      pixelHeight: 0,
      alt: alt,
      unavailableReason: reason,
    );
  }
}

/// Collects chapters, blocks and the table of contents while walking.
final class _DocumentBuilder {
  _DocumentBuilder({required this.fallbackTitle, required this.parser});

  final String fallbackTitle;
  final MarkdownParser parser;

  final List<EpubChapter> _chapters = <EpubChapter>[];
  final List<_TocDraft> _toc = <_TocDraft>[];

  StringBuffer _text = StringBuffer();
  int _textLength = 0;
  List<EpubBlock> _blocks = <EpubBlock>[];
  String? _chapterTitle;

  /// The open chapter's entry in the table of contents, if it has a heading.
  _TocDraft? _openToc;

  Future<void> walk(List<md.Node> nodes) async {
    for (final node in nodes) {
      await _walkNode(node, EpubBlockType.paragraph);
    }
  }

  Future<void> _walkNode(md.Node node, EpubBlockType type) async {
    if (node is md.Text) {
      _addText(node.text, type);
      return;
    }
    if (node is! md.Element) {
      return;
    }

    switch (node.tag) {
      case 'h1':
        _startChapter(node.textContent.trim());
        _addText(node.textContent, EpubBlockType.heading);
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _addHeading(node, type);
      case 'p':
        await _addParagraph(node, type);
      case 'ul':
        await _addList(node, depth: 0, ordered: false, type: type);
      case 'ol':
        await _addList(node, depth: 0, ordered: true, type: type);
      case 'blockquote':
        final children = node.children ?? const <md.Node>[];
        for (final child in children) {
          await _walkNode(child, EpubBlockType.quote);
        }
      case 'pre':
        _addText(_codeText(node), EpubBlockType.code, code: true);
      case 'table':
        _addText(_tableText(node), EpubBlockType.code, code: true);
      case 'hr':
        return;
      case 'img':
        await _addImage(node);
      default:
        final children = node.children ?? const <md.Node>[];
        for (final child in children) {
          await _walkNode(child, type);
        }
    }
  }

  void _addHeading(md.Element node, EpubBlockType type) {
    final text = node.textContent.trim();
    if (text.isEmpty) {
      return;
    }
    _addText(text, EpubBlockType.heading);
    // Level-two headings are the table of contents inside a chapter; deeper
    // ones are structure in the text, not places a reader jumps to.
    if (node.tag == 'h2') {
      _openToc?.children.add(_TocChild(title: text, offset: _lastBlockStart));
    }
  }

  Future<void> _addParagraph(md.Element node, EpubBlockType type) async {
    final buffer = StringBuffer();

    Future<void> flush() async {
      final text = buffer.toString();
      buffer.clear();
      _addText(text, type);
    }

    for (final child in node.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'img') {
        await flush();
        await _addImage(child);
        continue;
      }
      buffer.write(_inlineText(child));
    }
    await flush();
  }

  Future<void> _addList(
    md.Element list, {
    required int depth,
    required bool ordered,
    required EpubBlockType type,
  }) async {
    var index = 1;
    for (final child in list.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'li') {
        continue;
      }
      final marker = ordered ? '${index++}.' : '•';
      final indent = '  ' * depth;
      final buffer = StringBuffer();
      final nested = <md.Element>[];
      for (final item in child.children ?? const <md.Node>[]) {
        if (item is md.Element && (item.tag == 'ul' || item.tag == 'ol')) {
          nested.add(item);
          continue;
        }
        buffer.write(_inlineText(item));
      }
      final text = _collapse(buffer.toString());
      if (text.isNotEmpty) {
        // The indent is built after collapsing: a nested item's own leading
        // spaces are structure, and the paragraph rule would eat them.
        _addText('$indent$marker $text', type, prepared: true);
      }
      for (final sub in nested) {
        await _addList(
          sub,
          depth: depth + 1,
          ordered: sub.tag == 'ol',
          type: type,
        );
      }
    }
  }

  Future<void> _addImage(md.Element node) async {
    final alt = node.attributes['alt']?.trim();
    final src = node.attributes['src'] ?? '';
    final image = await parser.loadImage(
      src,
      (alt == null || alt.isEmpty) ? null : alt,
    );
    _blocks.add(EpubImageBlock(startOffset: _textLength, image: image));
  }

  void _addText(
    String raw,
    EpubBlockType type, {
    bool code = false,
    bool prepared = false,
  }) {
    final text = prepared
        ? raw.trimRight()
        : (code ? _prepareCode(raw) : _collapse(raw));
    if (text.trim().isEmpty) {
      return;
    }
    _writeSeparator();
    final start = _textLength;
    _text.write(text);
    _textLength += text.length;
    _blocks.add(
      EpubTextBlock(
        startOffset: start,
        endOffset: _textLength,
        text: text,
        type: type,
      ),
    );
    _lastBlockStart = start;
  }

  int _lastBlockStart = 0;

  /// Starts a new chapter. Its heading becomes the first thing in it.
  void _startChapter(String title) {
    _closeChapter();
    _chapterTitle = title.isEmpty ? null : title;
    _openToc = _TocDraft(title: _chapterTitle ?? fallbackTitle);
    _toc.add(_openToc!);
  }

  void _closeChapter() {
    if (_blocks.isEmpty && _textLength == 0) {
      _openToc = null;
      _chapterTitle = null;
      return;
    }
    final index = _chapters.length;
    _chapters.add(
      EpubChapter(
        index: index,
        href: '',
        title: _chapterTitle ?? fallbackTitle,
        text: _text.toString(),
        blocks: List<EpubBlock>.unmodifiable(_blocks),
      ),
    );
    // A chapter's table-of-contents entry points at its heading, which is
    // the first block whenever the chapter was opened by one.
    final open = _openToc;
    if (open != null && open.chapterIndex == null) {
      open.chapterIndex = index;
      open.offset ??= 0;
    }
    _text = StringBuffer();
    _textLength = 0;
    _blocks = <EpubBlock>[];
    _chapterTitle = null;
    _openToc = null;
  }

  EpubDocument finish() {
    _closeChapter();
    return EpubDocument(
      chapters: List<EpubChapter>.unmodifiable(_chapters),
      toc: List<EpubTocItem>.unmodifiable(
        _toc.map((entry) => entry.toItem()).toList(growable: false),
      ),
    );
  }

  /// Separates two blocks with a blank line, before the later one.
  void _writeSeparator() {
    if (_textLength == 0) {
      return;
    }
    final current = _text.toString();
    if (current.endsWith('\n\n')) {
      return;
    }
    final endsWithNewline = current.endsWith('\n');
    _text.write(endsWithNewline ? '\n' : '\n\n');
    _textLength += endsWithNewline ? 1 : 2;
  }

  String _codeText(md.Element pre) {
    return pre.textContent.replaceAll(RegExp(r'\s+$'), '');
  }

  /// A table drawn as aligned text.
  ///
  /// The reader has no table layout, but a table's meaning is its columns:
  /// set in a monospace block, with the columns padded to their widest cell,
  /// it stays readable. Prose that wrapped would destroy the alignment and
  /// with it the meaning.
  String _tableText(md.Element table) {
    final rows = <List<String>>[];
    var header = false;

    void collect(md.Node node, {required bool isHeader}) {
      if (node is md.Element && node.tag == 'tr') {
        final cells = <String>[];
        for (final cell in node.children ?? const <md.Node>[]) {
          if (cell is md.Element && (cell.tag == 'th' || cell.tag == 'td')) {
            cells.add(_collapse(_inlineText(cell)).replaceAll('\n', ' '));
          }
        }
        if (cells.isNotEmpty) {
          rows.add(cells);
          if (isHeader && !header) {
            header = true;
          }
        }
        return;
      }
      if (node is md.Element) {
        final isHeaderSection = node.tag == 'thead';
        for (final child in node.children ?? const <md.Node>[]) {
          collect(child, isHeader: isHeader || isHeaderSection);
        }
      }
    }

    for (final child in table.children ?? const <md.Node>[]) {
      collect(child, isHeader: false);
    }
    if (rows.isEmpty) {
      return '';
    }

    final columns = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final widths = List<int>.filled(columns, 1);
    for (final row in rows) {
      for (var i = 0; i < row.length; i += 1) {
        final width = displayWidth(row[i]);
        if (width > widths[i]) {
          widths[i] = width;
        }
      }
    }

    final out = StringBuffer();
    for (var i = 0; i < rows.length; i += 1) {
      final row = rows[i];
      final cells = <String>[];
      for (var column = 0; column < columns; column += 1) {
        final cell = column < row.length ? row[column] : '';
        cells.add(cell + ' ' * (widths[column] - displayWidth(cell)));
      }
      out.writeln('| ${cells.join(' | ')} |');
      if (header && i == 0) {
        // A rule under the header, not the source's `|---|` row: the reader
        // shows the table, not the markup that described it. It is exactly as
        // wide as the rows so the columns stay framed.
        final ruleWidth =
            widths.fold<int>(0, (sum, width) => sum + width) + 3 * columns + 1;
        out.writeln('-' * ruleWidth);
      }
    }
    return out.toString().trimRight();
  }

  String _inlineText(md.Node node) {
    if (node is md.Text) {
      return node.text;
    }
    if (node is! md.Element) {
      return '';
    }
    switch (node.tag) {
      case 'br':
        return '\n';
      case 'img':
        // Pictures are placed by the paragraph walker, not inline in text.
        return '';
      case 'input':
        if (node.attributes['type'] == 'checkbox') {
          return node.attributes['checked'] != null ? '☑ ' : '☐ ';
        }
        return '';
      default:
        final children = node.children;
        if (children == null) {
          return '';
        }
        return children.map(_inlineText).join();
    }
  }
}

/// Roughly how many terminal columns [text] takes.
///
/// A CJK glyph is twice as wide as a Latin one, and a table padded by code
/// units would be visibly crooked in exactly the documents most likely to
/// have Chinese in them.
int displayWidth(String text) {
  var width = 0;
  for (final rune in text.runes) {
    width += _isWide(rune) ? 2 : 1;
  }
  return width;
}

bool _isWide(int rune) {
  return (rune >= 0x1100 && rune <= 0x115F) ||
      (rune >= 0x2E80 && rune <= 0xA4CF) ||
      (rune >= 0xAC00 && rune <= 0xD7A3) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xFE30 && rune <= 0xFE4F) ||
      (rune >= 0xFF00 && rune <= 0xFF60) ||
      (rune >= 0xFFE0 && rune <= 0xFFE6) ||
      (rune >= 0x20000 && rune <= 0x3FFFD);
}

/// Collapses whitespace the way a paragraph is read.
///
/// A newline in the source is a line wrap by the writer, not a line break in
/// the text: Markdown's hard breaks are marked in the markup (two trailing
/// spaces or a backslash) and arrive here as `br` elements. Collapsing the
/// raw newline is what makes reflowable text actually reflow.
String _collapse(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t\f\u00a0\n]+'), ' ')
      .trim();
}

/// Code keeps its lines and its indentation; only the trailing blank space
/// of the block is dropped.
String _prepareCode(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'\s+$'), '');
}

/// A table-of-contents entry while its chapter is still open.
final class _TocDraft {
  _TocDraft({required this.title});

  final String title;
  final List<_TocChild> children = <_TocChild>[];
  int? chapterIndex;
  int? offset;

  EpubTocItem toItem() {
    return EpubTocItem(
      title: title,
      href: '',
      chapterIndex: chapterIndex,
      chapterOffset: offset,
      children: children
          .map(
            (child) => EpubTocItem(
              title: child.title,
              href: '',
              chapterIndex: chapterIndex,
              chapterOffset: child.offset,
            ),
          )
          .toList(growable: false),
    );
  }
}

final class _TocChild {
  const _TocChild({required this.title, required this.offset});

  final String title;
  final int offset;
}
