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
    final nodes = document.parseLines(
      _repairTableDelimiters(source.body).split('\n'),
    );
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
        final built = _draftFor(node).finish();
        _startChapter(built.text.trim());
        _addText(
          built.text,
          EpubBlockType.heading,
          prepared: true,
          runs: built.runs,
          headingLevel: 1,
        );
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
        _addTable(node);
      case 'hr':
        // A rule is a mark between two runs of text, and takes no characters
        // of its own, so offsets either side stay what they were.
        _blocks.add(EpubDividerBlock(startOffset: _textLength));
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
    final built = _draftFor(node).finish();
    final text = built.text.trim();
    if (text.isEmpty) {
      return;
    }
    _addText(
      text,
      EpubBlockType.heading,
      prepared: true,
      runs: built.runs,
      headingLevel: int.tryParse(node.tag.substring(1)),
    );
    // Level-two headings are the table of contents inside a chapter; deeper
    // ones are structure in the text, not places a reader jumps to.
    if (node.tag == 'h2') {
      _openToc?.children.add(_TocChild(title: text, offset: _lastBlockStart));
    }
  }

  Future<void> _addParagraph(md.Element node, EpubBlockType type) async {
    var draft = _InlineDraft();

    Future<void> flush() async {
      final built = draft.finish();
      draft = _InlineDraft();
      if (built.text.trim().isEmpty) {
        return;
      }
      _addText(built.text, type, prepared: true, runs: built.runs);
    }

    for (final child in node.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'img') {
        await flush();
        await _addImage(child);
        continue;
      }
      draft.writeNode(child);
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
      final draft = _InlineDraft();
      final nested = <md.Element>[];
      for (final item in child.children ?? const <md.Node>[]) {
        if (item is md.Element && (item.tag == 'ul' || item.tag == 'ol')) {
          nested.add(item);
          continue;
        }
        draft.writeNode(item);
      }
      final built = draft.finish();
      if (built.text.isNotEmpty) {
        // The indent is built after collapsing: a nested item's own leading
        // spaces are structure, and the paragraph rule would eat them.
        final prefix = '$indent$marker ';
        _addText(
          '$prefix${built.text}',
          type,
          prepared: true,
          runs: [
            for (final run in built.runs)
              EpubInlineRun(
                start: run.start + prefix.length,
                end: run.end + prefix.length,
                style: run.style,
              ),
          ],
        );
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
    List<EpubInlineRun> runs = const <EpubInlineRun>[],
    int? headingLevel,
  }) {
    final text = prepared
        ? raw.trimRight()
        : (code ? _prepareCode(raw) : _collapse(raw));
    if (text.trim().isEmpty) {
      return;
    }
    // A collapsed or prepared string can differ in length from its source, so
    // runs only ever arrive with text that was already built to match them.
    assert(prepared || runs.isEmpty, 'inline runs need prepared text');
    final start = _appendText(text);
    _blocks.add(
      EpubTextBlock(
        startOffset: start,
        endOffset: _textLength,
        text: text,
        type: type,
        headingLevel: headingLevel,
        runs: runs.isEmpty
            ? const <EpubInlineRun>[]
            : <EpubInlineRun>[
                for (final run in runs)
                  EpubInlineRun(
                    start: run.start + start,
                    end: run.end + start,
                    style: run.style,
                  ),
              ],
      ),
    );
    _lastBlockStart = start;
  }

  /// The inline content of [node], with its styling runs.
  _InlineDraft _draftFor(md.Element node) {
    final draft = _InlineDraft();
    for (final child in node.children ?? const <md.Node>[]) {
      draft.writeNode(child);
    }
    return draft;
  }

  /// Writes [text] into the chapter after a separator, returning its start.
  int _appendText(String text) {
    _writeSeparator();
    final start = _textLength;
    _write(text);
    return start;
  }

  /// The last two characters written, which is all the separator needs to
  /// know. Reading them back from the buffer would copy the chapter's whole
  /// text on every block — quadratic work in a long chapter, for a check
  /// worth two characters.
  String _tail = '';

  void _write(String value) {
    _text.write(value);
    _textLength += value.length;
    if (value.isEmpty) {
      return;
    }
    final combined = _tail + value;
    _tail = combined.length <= 2
        ? combined
        : combined.substring(combined.length - 2);
  }

  /// A table is drawn as a table, so its cells are kept apart rather than
  /// laid out as lines of text. The words still go into the chapter's text,
  /// which is what keeps search, progress and selection working on it.
  void _addTable(md.Element node) {
    final rows = <List<String>>[];
    var hasHeader = false;

    void collect(md.Node node, {required bool inHead}) {
      if (node is md.Element && node.tag == 'tr') {
        final cells = <String>[];
        for (final cell in node.children ?? const <md.Node>[]) {
          if (cell is md.Element && (cell.tag == 'th' || cell.tag == 'td')) {
            cells.add(_collapse(_inlineText(cell)));
          }
        }
        if (cells.isEmpty) {
          return;
        }
        rows.add(cells);
        if (inHead && !hasHeader) {
          hasHeader = true;
        }
        return;
      }
      if (node is md.Element) {
        final isHeadSection = node.tag == 'thead';
        for (final child in node.children ?? const <md.Node>[]) {
          collect(child, inHead: inHead || isHeadSection);
        }
      }
    }

    for (final child in node.children ?? const <md.Node>[]) {
      collect(child, inHead: false);
    }
    if (rows.isEmpty) {
      return;
    }

    // A ragged row would break the grid; every row gets the same cells.
    final columns = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final padded = <List<String>>[
      for (final row in rows)
        List<String>.unmodifiable(<String>[
          for (var column = 0; column < columns; column += 1)
            column < row.length ? row[column] : '',
        ]),
    ];

    final text = padded.map((row) => row.join('   ')).join('\n');
    if (text.trim().isEmpty) {
      return;
    }
    final start = _appendText(text);
    _blocks.add(
      EpubTableBlock(
        startOffset: start,
        endOffset: _textLength,
        text: text,
        rows: List<List<String>>.unmodifiable(padded),
        hasHeader: hasHeader,
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
    _tail = '';
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
    if (_tail.endsWith('\n\n')) {
      return;
    }
    _write(_tail.endsWith('\n') ? '\n' : '\n\n');
  }

  String _codeText(md.Element pre) {
    return pre.textContent.replaceAll(RegExp(r'\s+$'), '');
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

/// Builds a block's inline text together with the styling inside it.
///
/// Emphasis nests — bold inside italic, code inside a link — so a style is
/// recorded as a run over a range rather than as a property of a word: the
/// ranges overlap, and the renderer applies every run that reaches a
/// character. Nothing is rewritten into the text itself, which is why search
/// and progress keep working on the same characters the writer typed.
final class _InlineDraft {
  final StringBuffer _buffer = StringBuffer();
  final List<EpubInlineRun> _runs = <EpubInlineRun>[];

  void write(String text) {
    if (text.isEmpty) {
      return;
    }
    _buffer.write(text);
  }

  void writeNode(md.Node node) {
    if (node is md.Text) {
      // A newline in the source is a wrap in the file, not in the text.
      write(_collapseInline(node.text));
      return;
    }
    if (node is! md.Element) {
      return;
    }
    switch (node.tag) {
      case 'br':
        write('\n');
      case 'img':
        // Pictures are placed by the block walker, not inline in text.
        break;
      case 'input':
        if (node.attributes['type'] == 'checkbox') {
          write(node.attributes['checked'] != null ? '☑ ' : '☐ ');
        }
      case 'strong':
        _styled(node, EpubInlineStyle.strong);
      case 'em':
        _styled(node, EpubInlineStyle.emphasis);
      case 'del':
        _styled(node, EpubInlineStyle.strike);
      case 'code':
        _styled(node, EpubInlineStyle.code);
      case 'a':
        _styled(node, EpubInlineStyle.link);
      default:
        _writeChildren(node);
    }
  }

  void _writeChildren(md.Element node) {
    for (final child in node.children ?? const <md.Node>[]) {
      writeNode(child);
    }
  }

  void _styled(md.Element node, EpubInlineStyle style) {
    final start = _buffer.length;
    _writeChildren(node);
    if (_buffer.length > start) {
      _runs.add(EpubInlineRun(start: start, end: _buffer.length, style: style));
    }
  }

  /// The block's text with its ends trimmed, and the runs moved to match.
  _BuiltInline finish() {
    final raw = _buffer.toString();
    final text = raw.trim();
    if (text.isEmpty) {
      return const _BuiltInline(text: '', runs: <EpubInlineRun>[]);
    }
    final leading = raw.length - raw.trimLeft().length;
    final runs = <EpubInlineRun>[];
    for (final run in _runs) {
      final start = (run.start - leading).clamp(0, text.length);
      final end = (run.end - leading).clamp(0, text.length);
      if (start < end) {
        runs.add(EpubInlineRun(start: start, end: end, style: run.style));
      }
    }
    return _BuiltInline(
      text: text,
      runs: List<EpubInlineRun>.unmodifiable(runs),
    );
  }
}

final class _BuiltInline {
  const _BuiltInline({required this.text, required this.runs});

  final String text;
  final List<EpubInlineRun> runs;
}

/// Whitespace collapsed inside one piece of inline text, without trimming:
/// the space between "a" and a bold "b" belongs to one of them.
String _collapseInline(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t\f\u00a0\n]+'), ' ');
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

/// Makes a table's delimiter row agree with its header row.
///
/// `package:markdown` decides a table's column count from the delimiter row
/// (`| --- | --- |`) and then throws the whole table away when the header row
/// does not have exactly that many cells. Hand-written notes break that rule
/// constantly — a missing pipe, a cell added later — and losing the table is
/// a far worse answer than trusting the header.
///
/// The delimiter row is markup, not content: it says how many columns there
/// are and how they align, and nothing a reader ever sees. So it is rewritten
/// to match the header, keeping each column's alignment. Fenced code is left
/// alone: a code block that happens to contain pipes is code.
String _repairTableDelimiters(String body) {
  final lines = body.split('\n');
  String? fence;
  var changed = false;
  for (var index = 1; index < lines.length; index += 1) {
    final line = lines[index];
    final fenceMatch = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line);
    if (fenceMatch != null) {
      final marker = fenceMatch.group(1)!;
      if (fence == null) {
        fence = marker[0];
      } else if (marker[0] == fence) {
        fence = null;
      }
      continue;
    }
    if (fence != null) {
      continue;
    }
    final header = lines[index - 1];
    if (!_looksLikeDelimiter(line) || !header.contains('|')) {
      continue;
    }
    if (line.trimLeft() != line || header.trimLeft() != header) {
      // Indented lines are code, or at least not a table at the top level.
      continue;
    }
    final headerCells = _rowCells(header);
    if (headerCells.isEmpty) {
      continue;
    }
    final alignments = _delimiterAlignments(line);
    if (alignments.length == headerCells.length) {
      continue;
    }
    lines[index] = _delimiterRow(headerCells.length, alignments);
    changed = true;
  }
  return changed ? lines.join('\n') : body;
}

/// Whether [line] is a table's delimiter row and nothing else.
bool _looksLikeDelimiter(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || !trimmed.contains('-')) {
    return false;
  }
  final cells = _rowCells(trimmed);
  if (cells.isEmpty) {
    return false;
  }
  for (final cell in cells) {
    if (!RegExp(r'^:?-+:?$').hasMatch(cell)) {
      return false;
    }
  }
  return true;
}

/// The alignment of each column in a delimiter row: `left`, `right`, `center`
/// or `none`.
List<String> _delimiterAlignments(String line) {
  return [
    for (final cell in _rowCells(line))
      switch ((cell.startsWith(':'), cell.endsWith(':'))) {
        (true, true) => 'center',
        (true, false) => 'left',
        (false, true) => 'right',
        _ => 'none',
      },
  ];
}

String _delimiterRow(int columns, List<String> alignments) {
  final cells = <String>[];
  for (var column = 0; column < columns; column += 1) {
    final alignment = column < alignments.length ? alignments[column] : 'none';
    cells.add(switch (alignment) {
      'left' => ':---',
      'right' => '---:',
      'center' => ':---:',
      _ => '---',
    });
  }
  return '| ${cells.join(' | ')} |';
}

/// Splits a table row into its cells the way `package:markdown` does: one
/// leading and one trailing pipe frame the row rather than making empty
/// cells, and `\|` is a literal pipe inside a cell.
List<String> _rowCells(String line) {
  final text = line.trim();
  final cells = <String>[];
  final buffer = StringBuffer();
  var started = false;
  var index = 0;
  while (index < text.length) {
    final char = text.codeUnitAt(index);
    if (char == 0x5C && index + 1 < text.length) {
      buffer.writeCharCode(text.codeUnitAt(index + 1));
      started = true;
      index += 2;
      continue;
    }
    if (char == 0x7C) {
      if (!started) {
        started = true;
        index += 1;
        continue;
      }
      cells.add(buffer.toString().trim());
      buffer.clear();
      index += 1;
      continue;
    }
    started = true;
    buffer.writeCharCode(char);
    index += 1;
  }
  if (buffer.isNotEmpty) {
    cells.add(buffer.toString().trim());
  }
  return cells;
}
