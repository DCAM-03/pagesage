import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'epub_document.dart';

/// A chapter parsed out of one XHTML document.
///
/// [text] is the chapter's words and nothing else, so every offset into it
/// still means what it meant before pictures existed. [blocks] says where
/// the pictures sit in that flow.
final class ParsedChapter {
  const ParsedChapter({
    required this.text,
    required this.blocks,
    required this.anchors,
  });

  final String text;
  final List<EpubBlock> blocks;

  /// Character offset into [text] for each element carrying an id.
  final Map<String, int> anchors;
}

/// Turns one XHTML document into a chapter: its text, its pictures, and
/// where the two sit relative to each other.
///
/// The rule that keeps everything else working: a picture takes no
/// characters. It sits between two runs of text, and the offsets on either
/// side of it are the text's own. Search, progress, jump and highlighting
/// all work on character offsets, and none of them should have to learn
/// that a chapter can contain something that is not a character.
///
/// The text is built here rather than read off the markup, because a
/// chapter's text and its offsets have to agree exactly: a jump that
/// lands on the wrong word is worse than no jump. Building the text means
/// every offset is known as it is written.
final class EpubChapterParser {
  EpubChapterParser({required this.entries});

  /// Every file in the book, by normalized archive path.
  final Map<String, ArchiveFile> entries;

  /// Pictures already read, so a picture used twice is read once.
  final Map<String, EpubImage> _imageCache = <String, EpubImage>{};

  /// The most bytes one picture may decompress to.
  ///
  /// A book is a zip of things the author chose, and a zip entry can
  /// expand to a size nobody sane intended. The cap is what stands
  /// between a strange book and a reader that runs out of memory.
  static const int maxImageBytes = 24 * 1024 * 1024;

  /// The most pixels one picture may have.
  ///
  /// A picture is drawn at the width of the page, so its pixel count is
  /// what decides how much memory it takes to draw. This is generous for
  /// a scanned figure and small enough to keep a whole book open.
  static const int maxImagePixels = 40 * 1000 * 1000;

  ParsedChapter parse({required String xhtml, required String href}) {
    final document = _parseXml(xhtml);
    if (document == null) {
      return ParsedChapter(
        text: _normalizeText(_stripTags(xhtml)),
        blocks: const [],
        anchors: const {},
      );
    }

    final body =
        document.findAllElements('body', namespace: '*').firstOrNull ??
        document.rootElement;
    final builder = _ChapterBuilder(
      basePath: p.url.dirname(href),
      readImage: _readImage,
    );
    builder.walk(body);
    return builder.finish();
  }

  XmlDocument? _parseXml(String xhtml) {
    try {
      return XmlDocument.parse(
        xhtml,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      );
    } on XmlParserException {
      return null;
    }
  }

  String _stripTags(String xhtml) {
    final withoutScripts = xhtml
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
          ' ',
        );
    return withoutScripts.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  EpubImage _readImage(String path, String? alt) {
    final cached = _imageCache[path];
    if (cached != null) {
      return cached;
    }
    final image = _loadFromArchive(path, alt);
    _imageCache[path] = image;
    return image;
  }

  EpubImage _loadFromArchive(String path, String? alt) {
    final entry = entries[path];
    if (entry == null || !entry.isFile) {
      return _unavailable(path, alt, '图片不在书中');
    }
    if (entry.size > maxImageBytes) {
      return _unavailable(path, alt, '图片过大，已跳过');
    }
    final Uint8List bytes;
    try {
      bytes = entry.readBytes() ?? Uint8List(0);
    } on Object {
      return _unavailable(path, alt, '图片无法解压');
    }
    if (bytes.lengthInBytes > maxImageBytes) {
      return _unavailable(path, alt, '图片过大，已跳过');
    }
    final size = readImageSize(bytes);
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
      bytes: bytes,
      pixelWidth: size?.width ?? 0,
      pixelHeight: size?.height ?? 0,
      alt: alt,
      unavailableReason: size == null ? '图片格式无法识别' : null,
    );
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

/// Walks a chapter's markup, collecting text and pictures in order.
final class _ChapterBuilder {
  _ChapterBuilder({required this.basePath, required this.readImage});

  final String basePath;

  /// Reads a picture out of the book by its archive path.
  final EpubImage Function(String path, String? alt) readImage;

  /// The chapter's text, paragraph by paragraph.
  final StringBuffer _text = StringBuffer();

  /// How many characters are in [_text] so far.
  int _textLength = 0;

  /// The blocks, in order.
  final List<EpubBlock> _blocks = <EpubBlock>[];

  /// Offsets for elements carrying an id.
  final Map<String, int> _anchors = <String, int>{};

  /// The paragraph being written, if any.
  final StringBuffer _paragraph = StringBuffer();

  /// Whether a paragraph is open.
  bool _inParagraph = false;

  /// The kind of paragraph being written.
  EpubBlockType _paragraphType = EpubBlockType.paragraph;

  void walk(XmlNode node) {
    for (final child in node.children) {
      if (child is XmlElement) {
        _walkElement(child);
      } else if (child is XmlText) {
        _appendText(child.value);
      } else if (child is XmlCDATA) {
        _appendText(child.value);
      }
    }
  }

  void _walkElement(XmlElement element) {
    final name = element.name.local.toLowerCase();

    if (name == 'script' || name == 'style' || name == 'head') {
      return;
    }
    if (name == 'img' || (name == 'image' && _isSvgImage(element))) {
      _appendImage(element);
      return;
    }
    if (name == 'svg') {
      // Inline SVG is drawn as its own thing or not at all; its text
      // children are labels, not prose.
      for (final child in element.children) {
        if (child is XmlElement) {
          _walkElement(child);
        }
      }
      return;
    }
    if (name == 'br') {
      _appendText('\n');
      return;
    }
    if (name == 'hr') {
      _closeParagraph();
      return;
    }

    _recordAnchor(element);

    if (_isBlockLevel(name)) {
      _closeParagraph();
      _openParagraph(_typeFor(name));
      walk(element);
      _closeParagraph();
      return;
    }

    walk(element);
  }

  bool _isSvgImage(XmlElement element) {
    // <image> inside <svg> is a picture; <image> elsewhere is not a thing.
    final parent = element.parent;
    return parent is XmlElement && parent.name.local.toLowerCase() == 'svg';
  }

  bool _isBlockLevel(String name) {
    return const {
      'p',
      'div',
      'li',
      'blockquote',
      'dd',
      'dt',
      'section',
      'article',
      'aside',
      'header',
      'footer',
      'td',
      'th',
      'tr',
      'table',
      'ul',
      'ol',
      'dl',
      'figure',
      'figcaption',
      'pre',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
    }.contains(name);
  }

  EpubBlockType _typeFor(String name) {
    if (name == 'figcaption') {
      return EpubBlockType.caption;
    }
    if (name == 'pre') {
      return EpubBlockType.code;
    }
    if (name.length == 2 && name[0] == 'h' && name[1] != ' ') {
      return EpubBlockType.heading;
    }
    return EpubBlockType.paragraph;
  }

  void _recordAnchor(XmlElement element) {
    final id = element.getAttribute('id') ?? element.getAttribute('name');
    if (id == null || id.isEmpty) {
      return;
    }
    _anchors.putIfAbsent(id, () => _textLength);
  }

  void _openParagraph(EpubBlockType type) {
    if (_inParagraph) {
      return;
    }
    _inParagraph = true;
    _paragraphType = type;
  }

  void _appendText(String value) {
    if (value.isEmpty) {
      return;
    }
    if (!_inParagraph) {
      _openParagraph(EpubBlockType.paragraph);
    }
    _paragraph.write(value);
  }

  /// Ends the open paragraph and records it as a block.
  void _closeParagraph() {
    if (!_inParagraph) {
      return;
    }
    _inParagraph = false;
    final raw = _paragraph.toString();
    _paragraph.clear();
    final body = _collapseParagraph(raw);
    if (body.isEmpty) {
      return;
    }
    _writeSeparator();
    final start = _textLength;
    _text.write(body);
    _textLength += body.length;
    _blocks.add(
      EpubTextBlock(
        startOffset: start,
        endOffset: _textLength,
        text: body,
        type: _paragraphType,
      ),
    );
  }

  /// Separates two blocks with a blank line.
  ///
  /// The separator is not part of any block: a block's text is exactly
  /// its own words, and its offsets are exactly where those words sit.
  /// The separator is written before a block rather than after one, so a
  /// chapter's text does not end in blank space.
  ///
  /// A picture counts as a block here: the words before it and the words
  /// after it are not one run of text.
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

  void _appendImage(XmlElement element) {
    final image = _loadImage(element);
    // A picture sits between two runs of text, so the paragraph ends here.
    _closeParagraph();
    final offset = _textLength;
    _blocks.add(EpubImageBlock(startOffset: offset, image: image));
  }

  EpubImage _loadImage(XmlElement element) {
    final alt = _cleanAlt(element.getAttribute('alt'));
    final src =
        element.getAttribute('src') ??
        element.getAttribute('href', namespace: '*');
    if (src == null || src.trim().isEmpty) {
      return EpubImage(
        archivePath: '',
        bytes: Uint8List(0),
        pixelWidth: 0,
        pixelHeight: 0,
        alt: alt,
        unavailableReason: '图片没有来源地址',
      );
    }
    final trimmed = src.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Local-first: a book that points at the network does not get to
      // make the reader wait on it.
      return EpubImage(
        archivePath: '',
        bytes: Uint8List(0),
        pixelWidth: 0,
        pixelHeight: 0,
        alt: alt,
        unavailableReason: '远程图片不予加载',
      );
    }
    if (trimmed.startsWith('data:')) {
      return _loadDataUri(trimmed, alt);
    }
    return readImage(_resolve(trimmed), alt);
  }

  String _resolve(String href) {
    final withoutFragment = href.split('#').first.split('?').first;
    final decoded = _decode(withoutFragment);
    if (decoded.startsWith('/')) {
      return p.url.normalize(decoded.substring(1));
    }
    if (basePath == '.' || basePath.isEmpty) {
      return p.url.normalize(decoded);
    }
    return p.url.normalize(p.url.join(basePath, decoded));
  }

  String _decode(String value) {
    try {
      return Uri.decodeFull(value);
    } on Object {
      return value;
    }
  }

  EpubImage _loadDataUri(String uri, String? alt) {
    final comma = uri.indexOf(',');
    if (comma < 0) {
      return EpubImage(
        archivePath: '',
        bytes: Uint8List(0),
        pixelWidth: 0,
        pixelHeight: 0,
        alt: alt,
        unavailableReason: '内嵌图片格式无法识别',
      );
    }
    final header = uri.substring(5, comma);
    final payload = uri.substring(comma + 1);
    try {
      final bytes = header.contains(';base64')
          ? base64Decode(payload)
          : Uint8List.fromList(utf8.encode(Uri.decodeFull(payload)));
      if (bytes.lengthInBytes > EpubChapterParser.maxImageBytes) {
        return EpubImage(
          archivePath: 'data:',
          bytes: Uint8List(0),
          pixelWidth: 0,
          pixelHeight: 0,
          alt: alt,
          unavailableReason: '图片过大，已跳过',
        );
      }
      final size = readImageSize(bytes);
      return EpubImage(
        archivePath: 'data:',
        bytes: bytes,
        pixelWidth: size?.width ?? 0,
        pixelHeight: size?.height ?? 0,
        alt: alt,
        unavailableReason: size == null ? '图片格式无法识别' : null,
      );
    } on Object {
      return EpubImage(
        archivePath: '',
        bytes: Uint8List(0),
        pixelWidth: 0,
        pixelHeight: 0,
        alt: alt,
        unavailableReason: '内嵌图片无法解码',
      );
    }
  }

  ParsedChapter finish() {
    _closeParagraph();
    return ParsedChapter(
      text: _text.toString(),
      blocks: List<EpubBlock>.unmodifiable(_blocks),
      anchors: Map<String, int>.unmodifiable(_anchors),
    );
  }

  String? _cleanAlt(String? value) {
    if (value == null) {
      return null;
    }
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

/// Collapses a paragraph's raw text into the form it is read in.
///
/// Runs of spaces become one space, newlines stay (a line break in a
/// poem is a line break), and the ends are trimmed. A paragraph that
/// holds nothing but whitespace is nothing.
String _collapseParagraph(String raw) {
  if (raw.isEmpty) {
    return '';
  }
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll(RegExp(r'[ \t\f ]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

String _normalizeText(String value) {
  return value
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'[ \t\r\f]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .trim();
}

/// Reads the size of an image from its bytes.
///
/// Only the header is read: the formats a book can carry are PNG, JPEG,
/// GIF and WebP, and each of them states its size in its first few bytes.
({int width, int height})? readImageSize(Uint8List bytes) {
  if (bytes.length < 16) {
    return null;
  }
  // PNG: 8-byte signature, then a 4-byte length, "IHDR", then width and
  // height as two big-endian 32-bit numbers.
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    final width = _uint32(bytes, 16);
    final height = _uint32(bytes, 20);
    if (width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }
  // JPEG: walk the marker segments to the start-of-frame.
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var index = 2;
    while (index + 9 < bytes.length) {
      if (bytes[index] != 0xFF) {
        index++;
        continue;
      }
      final marker = bytes[index + 1];
      // Standalone markers carry no length.
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        index += 2;
        continue;
      }
      final length = (bytes[index + 2] << 8) | bytes[index + 3];
      final isStartOfFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isStartOfFrame) {
        final height = (bytes[index + 5] << 8) | bytes[index + 6];
        final width = (bytes[index + 7] << 8) | bytes[index + 8];
        if (width <= 0 || height <= 0) {
          return null;
        }
        return (width: width, height: height);
      }
      if (length < 2) {
        return null;
      }
      index += 2 + length;
    }
    return null;
  }
  // GIF: "GIF87a"/"GIF89a", then width and height as little-endian 16-bit.
  if (bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    final width = bytes[6] | (bytes[7] << 8);
    final height = bytes[8] | (bytes[9] << 8);
    if (width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }
  // WebP: "RIFF"...."WEBP", then a chunk that carries the dimensions.
  if (bytes.length >= 30 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    final chunk = String.fromCharCodes([
      bytes[12],
      bytes[13],
      bytes[14],
      bytes[15],
    ]);
    if (chunk == 'VP8X') {
      final width = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
      final height = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
      return (width: width, height: height);
    }
    if (chunk == 'VP8 ') {
      final width = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
      final height = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
      if (width > 0 && height > 0) {
        return (width: width, height: height);
      }
    }
    if (chunk == 'VP8L') {
      final bits =
          bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
      final width = (bits & 0x3FFF) + 1;
      final height = ((bits >> 14) & 0x3FFF) + 1;
      return (width: width, height: height);
    }
  }
  return null;
}

int _uint32(Uint8List bytes, int offset) {
  if (offset + 3 >= bytes.length) {
    return 0;
  }
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
