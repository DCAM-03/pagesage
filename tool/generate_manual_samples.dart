import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

const defaultManualSamplesPath = '.codex-run/samples';

Future<List<GeneratedSample>> generateManualSamples({
  String outputPath = defaultManualSamplesPath,
}) async {
  final outputDir = Directory(outputPath);
  await outputDir.create(recursive: true);

  final samples = <GeneratedSample>[
    GeneratedSample(
      fileName: 'standard.epub',
      description: '标准 EPUB：2 章、EPUB3 目录、常规段落。',
      write: (file) => file.writeAsBytes(
        buildEpub(
          title: 'PageSage Standard EPUB',
          includeNav: true,
          chapters: const [
            EpubSampleChapter(
              fileName: 'chapter1.xhtml',
              title: '第一章 进入书库',
              body: '''
                <h1>第一章 进入书库</h1>
                <p>这是 PageSage 的本地验收样本。它用于检查导入、打开、目录跳转、书签、笔记和保存进度。</p>
                <p>正文保持原创，不依赖外部版权材料。阅读时请检查行宽、段距、工具栏自动隐藏和当前章节提示。</p>
              ''',
            ),
            EpubSampleChapter(
              fileName: 'chapter2.xhtml',
              title: '第二章 阅读循环',
              body: '''
                <h1>第二章 阅读循环</h1>
                <p>关闭应用后重新打开，应恢复到上次阅读位置附近。也可以在本章添加高亮和摘录笔记。</p>
                <p>搜索关键词：PageSage、local-first、notebook。</p>
              ''',
            ),
          ],
        ),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'long-text.epub',
      description: '长文本 EPUB：长标题、长段落、代码块和长单词。',
      write: (file) => file.writeAsBytes(
        buildEpub(
          title: 'PageSage Long Text Layout EPUB With Very Long Title',
          includeNav: true,
          chapters: [
            EpubSampleChapter(
              fileName: 'chapter1.xhtml',
              title: '长文本、窄屏和字体缩放布局验收章节',
              body:
                  '''
                <h1>长文本、窄屏和字体缩放布局验收章节</h1>
                <p>${List.filled(18, '这是一段用于检查阅读器长段落换行、滚动位置、搜索命中和移动端窄屏排版的原创文本。').join()}</p>
                <pre><code>Future&lt;void&gt; validateReader() async {
  await openBook('long-text.epub');
  await changeFontSize(22);
  await createNote('layout-check');
}</code></pre>
                <p>LongUnbrokenTokenForOverflowValidationLongUnbrokenTokenForOverflowValidationLongUnbrokenTokenForOverflowValidation</p>
              ''',
            ),
            const EpubSampleChapter(
              fileName: 'chapter2.xhtml',
              title: '第二章 无障碍焦点',
              body: '''
                <h1>第二章 无障碍焦点</h1>
                <p>使用 Tab、方向键和 Esc 检查阅读器工具栏、目录、搜索、Notebook 和 AI 面板的焦点顺序。</p>
              ''',
            ),
          ],
        ),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'image.epub',
      description: '带图片 EPUB：内嵌原创小 PNG，用于图片占位和正文环绕检查。',
      write: (file) => file.writeAsBytes(
        buildEpub(
          title: 'PageSage Image EPUB',
          includeNav: true,
          includeImage: true,
          chapters: const [
            EpubSampleChapter(
              fileName: 'chapter1.xhtml',
              title: '图片章节',
              body: '''
                <h1>图片章节</h1>
                <p>下面是一张内嵌的本地生成图片。它用于检查图片、说明文字和阅读宽度。</p>
                <figure>
                  <img src="images/checker.png" alt="PageSage sample checker image"/>
                  <figcaption>PageSage 本地验收图片。</figcaption>
                </figure>
                <p>图片后正文应该继续保持可读，不应被工具栏遮挡。</p>
              ''',
            ),
          ],
        ),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'no-toc.epub',
      description: '无目录 EPUB：验证章节列表 fallback。',
      write: (file) => file.writeAsBytes(
        buildEpub(
          title: 'PageSage No TOC EPUB',
          includeNav: false,
          chapters: const [
            EpubSampleChapter(
              fileName: 'chapter1.xhtml',
              title: '无目录第一章',
              body: '<h1>无目录第一章</h1><p>该样本没有 nav.xhtml，阅读器应回退到章节列表。</p>',
            ),
            EpubSampleChapter(
              fileName: 'chapter2.xhtml',
              title: '无目录第二章',
              body: '<h1>无目录第二章</h1><p>用于检查目录面板和章节标题 fallback。</p>',
            ),
          ],
        ),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'large.epub',
      description: '大型 EPUB：40 章，用于导入、索引、取消和滚动性能检查。',
      write: (file) => file.writeAsBytes(
        buildEpub(
          title: 'PageSage Large EPUB',
          includeNav: true,
          chapters: List.generate(
            40,
            (index) => EpubSampleChapter(
              fileName: 'chapter${index + 1}.xhtml',
              title: '大型样本章节 ${index + 1}',
              body:
                  '<h1>大型样本章节 ${index + 1}</h1>'
                  '<p>${List.filled(24, '本章用于制造足够的导入、索引和滚动负载。').join()}</p>',
            ),
          ),
        ),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'standard-text.pdf',
      description: '标准文本 PDF：3 页文本，用于页码、搜索、缩放和保存进度。',
      write: (file) => file.writeAsBytes(
        buildTextPdf(const [
          'PageSage PDF sample page 1. Search keyword local-first reader.',
          'PageSage PDF sample page 2. Use this page for jump and zoom checks.',
          'PageSage PDF sample page 3. Add bookmark and restore progress here.',
        ]),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'large-text.pdf',
      description: '大 PDF：80 页文本，用于滚动、页码跳转和长任务取消。',
      write: (file) => file.writeAsBytes(
        buildTextPdf(
          List.generate(
            80,
            (index) =>
                'Large PDF page ${index + 1}. PageSage generated validation text for scrolling, indexing, and cancellation.',
          ),
        ),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'rotated-text.pdf',
      description: '90° 旋转文本 PDF：用于旋转页布局、选区与标注贴合验收。',
      write: (file) => file.writeAsBytes(
        buildTextPdf(const [
          'Rotated PDF page. PageSage geometry check for /Rotate 90.',
        ], rotate: 90),
        flush: true,
      ),
    ),
    GeneratedSample(
      fileName: 'outline-link.pdf',
      description: '目录与链接 PDF：3 页，/Outlines 两层，含页内跳转与外部 URI。',
      write: (file) => file.writeAsBytes(buildOutlineLinkPdf(), flush: true),
    ),
    GeneratedSample(
      fileName: 'image-only.pdf',
      description: '无文本层 PDF：只有矢量图形，用于搜索/划词禁用状态。',
      write: (file) => file.writeAsBytes(buildImageOnlyPdf(), flush: true),
    ),
    GeneratedSample(
      fileName: 'image-xobject.pdf',
      description: '单张图片 PDF：一页，含真实图片 XObject，用于图片批注与吸附验收。',
      write: (file) => file.writeAsBytes(buildImageXObjectPdf(), flush: true),
    ),
    GeneratedSample(
      fileName: 'image-xobject-rotated.pdf',
      description: '旋转 90° 的单张图片 PDF：用于图片批注在旋转页上的坐标验收。',
      write: (file) =>
          file.writeAsBytes(buildImageXObjectPdf(rotate: 90), flush: true),
    ),
    GeneratedSample(
      fileName: 'broken.pdf',
      description: '损坏 PDF：用于可恢复错误 UI。',
      write: (file) => file.writeAsBytes(
        ascii.encode('%PDF-1.4\n% PageSage intentionally broken sample\n'),
        flush: true,
      ),
    ),
  ];

  for (final sample in samples) {
    await sample.write(File(p.join(outputDir.path, sample.fileName)));
  }
  await File(
    p.join(outputDir.path, 'README.md'),
  ).writeAsString(buildSamplesReadme(samples), flush: true);
  return samples;
}

Uint8List buildEpub({
  required String title,
  required List<EpubSampleChapter> chapters,
  required bool includeNav,
  bool includeImage = false,
}) {
  final manifestItems = <String>[
    for (var i = 0; i < chapters.length; i += 1)
      '<item id="chapter${i + 1}" href="${chapters[i].fileName}" media-type="application/xhtml+xml"/>',
    if (includeNav)
      '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    if (includeImage)
      '<item id="checker" href="images/checker.png" media-type="image/png"/>',
  ];
  final spineItems = <String>[
    for (var i = 0; i < chapters.length; i += 1)
      '<itemref idref="chapter${i + 1}"/>',
  ];

  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(
      ArchiveFile.string('META-INF/container.xml', '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
    )
    ..addFile(
      ArchiveFile.string('OEBPS/content.opf', '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:uuid:pagesage-${_slug(title)}</dc:identifier>
    <dc:title>${_escapeXml(title)}</dc:title>
    <dc:language>zh-CN</dc:language>
    <dc:creator>PageSage Local Samples</dc:creator>
  </metadata>
  <manifest>
    ${manifestItems.join('\n    ')}
  </manifest>
  <spine>
    ${spineItems.join('\n    ')}
  </spine>
</package>
'''),
    );

  if (includeNav) {
    archive.addFile(
      ArchiveFile.string('OEBPS/nav.xhtml', '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <head><title>${_escapeXml(title)} 目录</title></head>
  <body>
    <nav epub:type="toc">
      <ol>
        ${chapters.map((chapter) => '<li><a href="${chapter.fileName}">${_escapeXml(chapter.title)}</a></li>').join('\n        ')}
      </ol>
    </nav>
  </body>
</html>
'''),
    );
  }

  for (final chapter in chapters) {
    archive.addFile(
      ArchiveFile.string('OEBPS/${chapter.fileName}', '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>${_escapeXml(chapter.title)}</title>
    <style>
      body { font-family: serif; line-height: 1.7; }
      pre { white-space: pre-wrap; border: 1px solid #999; padding: 12px; }
      img { max-width: 100%; }
    </style>
  </head>
  <body>
    ${chapter.body}
  </body>
</html>
'''),
    );
  }

  if (includeImage) {
    archive.addFile(
      ArchiveFile('OEBPS/images/checker.png', _checkerPng.length, _checkerPng),
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List buildTextPdf(List<String> pageTexts, {int rotate = 0}) {
  final pageObjects = <String>[];
  final contentObjects = <String>[];
  final fontObjectNumber = 3 + pageTexts.length * 2;
  // /Rotate is clockwise on screen; only multiples of 90 are meaningful, which
  // is also what the renderer's pageSize() assumes.
  final rotateEntry = rotate % 360 == 0 ? '' : ' /Rotate ${rotate % 360}';
  for (var i = 0; i < pageTexts.length; i += 1) {
    final pageObjectNumber = 3 + i * 2;
    final contentObjectNumber = pageObjectNumber + 1;
    final escaped = _escapePdfText(pageTexts[i]);
    final operations =
        '''
BT
/F1 13 Tf
72 730 Td
($escaped) Tj
0 -28 Td
(Generated by PageSage local manual samples.) Tj
ET''';
    pageObjects.add(
      '$pageObjectNumber 0 obj\n'
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]$rotateEntry '
      '/Contents $contentObjectNumber 0 R '
      '/Resources << /Font << /F1 $fontObjectNumber 0 R >> >> >>\n'
      'endobj\n',
    );
    contentObjects.add(
      '$contentObjectNumber 0 obj\n'
      '<< /Length ${ascii.encode(operations).length} >>\n'
      'stream\n$operations\nendstream\n'
      'endobj\n',
    );
  }

  final kids = [
    for (var i = 0; i < pageTexts.length; i += 1) '${3 + i * 2} 0 R',
  ].join(' ');
  return _writePdfObjects([
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [$kids] /Count ${pageTexts.length} >>',
    for (var i = 0; i < pageTexts.length; i += 1) ...[
      _objectBody(pageObjects[i]),
      _objectBody(contentObjects[i]),
    ],
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ]);
}

/// A three-page PDF with a two-level outline and link annotations.
///
/// Built by hand like the other samples: the point is the `/Outlines` tree and
/// two kinds of `/Link`, so the renderer's outline flattening and link tap can
/// be tested against a real document rather than a stub. Page 1's link jumps
/// to page 3, and page 2 carries an external URI plus a hidden link that must
/// be ignored.
Uint8List buildOutlineLinkPdf() {
  const pages = [
    'Outline link sample page one.',
    'Outline link sample page two.',
    'Outline link sample page three.',
  ];
  const pageCount = 3;
  final pageObjects = <String>[];
  final contentObjects = <String>[];

  // Object layout: 1 catalog, 2 page tree, then two objects per page, then the
  // two page-2 link objects (one of them hidden), the font, the outline
  // dictionary and its three items.
  const annotOne = 3 + pageCount * 2;
  const annotTwo = annotOne + 1;
  const annotHidden = annotTwo + 1;
  final fontObject = annotHidden + 1;
  // The outline root is the object *after* the font; its /First is the next.
  final outlineRoot = fontObject + 1;
  final firstItem = outlineRoot + 1;

  for (var i = 0; i < pageCount; i += 1) {
    final pageObject = 3 + i * 2;
    final contentObject = pageObject + 1;
    final annotations = switch (i) {
      0 => ' /Annots [$annotOne 0 R]',
      1 => ' /Annots [$annotTwo 0 R $annotHidden 0 R]',
      _ => '',
    };
    final operations =
        '''
BT
/F1 13 Tf
72 730 Td
(${_escapePdfText(pages[i])}) Tj
0 -28 Td
(PageSage outline and link sample.) Tj
ET''';
    pageObjects.add(
      '$pageObject 0 obj\n'
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]$annotations '
      '/Contents $contentObject 0 R '
      '/Resources << /Font << /F1 $fontObject 0 R >> >> >>\n'
      'endobj\n',
    );
    contentObjects.add(
      '$contentObject 0 obj\n'
      '<< /Length ${ascii.encode(operations).length} >>\n'
      'stream\n$operations\nendstream\n'
      'endobj\n',
    );
  }

  // Outline items: top level "Chapter One" -> page 1, "Chapter Two" -> page 2
  // with one child. /Top puts the destination near the heading at y = 730.
  final itemOne = firstItem;
  final itemTwo = firstItem + 1;
  final itemThree = firstItem + 2;
  final kids = [
    for (var i = 0; i < pageCount; i += 1) '${3 + i * 2} 0 R',
  ].join(' ');

  return _writePdfObjects([
    '<< /Type /Catalog /Pages 2 0 R /Outlines $outlineRoot 0 R >>',
    '<< /Type /Pages /Kids [$kids] /Count $pageCount >>',
    for (var i = 0; i < pageCount; i += 1) ...[
      _objectBody(pageObjects[i]),
      _objectBody(contentObjects[i]),
    ],
    // Page 1: a link that jumps to page 3.
    '<< /Type /Annot /Subtype /Link /Rect [70 725 260 750] '
        '/Border [0 0 0] /A << /S /GoTo /D [${3 + 2 * 2} 0 R /XYZ 72 730 0] >> >>',
    // Page 2: an external URI, plus one hidden link that a reader must ignore.
    '<< /Type /Annot /Subtype /Link /Rect [70 725 260 750] '
        '/Border [0 0 0] /A << /S /URI /URI (https://example.com/pagesage) >> >>',
    '<< /Type /Annot /Subtype /Link /Rect [70 600 260 625] /F 2 '
        '/Border [0 0 0] /A << /S /URI /URI (https://example.com/hidden) >> >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /Outlines /First $itemOne 0 R /Last $itemTwo 0 R /Count 3 >>',
    '<< /Title (Chapter One) /Parent $outlineRoot 0 R '
        '/Next $itemTwo 0 R /Dest [3 0 R /XYZ 72 730 0] >>',
    '<< /Title (Chapter Two) /Parent $outlineRoot 0 R '
        '/Prev $itemOne 0 R /First $itemThree 0 R /Last $itemThree 0 R '
        '/Count 1 /Dest [5 0 R /XYZ 72 730 0] >>',
    '<< /Title (Section 2.1) /Parent $itemTwo 0 R '
        '/Dest [5 0 R /XYZ 72 500 0] >>',
  ]);
}

/// A page with one real image XObject and no text: the one sample that
/// exercises the image path.
///
/// `image-only.pdf` cannot serve this purpose despite its name — it draws its
/// checkerboard with vector paths, so a renderer (and any image detector)
/// finds no image at all. Tests that need an image must use this file.
///
/// The image is a 300x200 placement at user-space (150, 400) on a 612x792
/// page, and [rotate] turns the whole page so the display-space geometry can
/// be checked too.
Uint8List buildImageXObjectPdf({int rotate = 0}) {
  const imageWidth = 120;
  const imageHeight = 80;
  final rgb = Uint8List(imageWidth * imageHeight * 3);
  for (var y = 0; y < imageHeight; y += 1) {
    for (var x = 0; x < imageWidth; x += 1) {
      final offset = (y * imageWidth + x) * 3;
      // A two-tone pattern, so a wrong decode is visible rather than a flat
      // colour that could pass for a correct one.
      final light = ((x ~/ 15) + (y ~/ 15)).isEven;
      rgb[offset] = light ? 220 : 40;
      rgb[offset + 1] = light ? 96 : 70;
      rgb[offset + 2] = light ? 64 : 120;
    }
  }
  // ASCIIHexDecode keeps the whole file printable, so the existing
  // string-based object writer stays valid; a binary stream would be mangled
  // by its ASCII encoding.
  final hex = StringBuffer();
  for (final byte in rgb) {
    hex.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  hex.write('>');
  const operations = '''
q
300 0 0 200 150 400 cm
/Im1 Do
Q''';
  return _writePdfObjects([
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Rotate $rotate '
        '/Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${ascii.encode(operations).length} >>\nstream\n$operations\nendstream',
    '<< /Type /XObject /Subtype /Image /Width $imageWidth '
        '/Height $imageHeight /ColorSpace /DeviceRGB '
        '/BitsPerComponent 8 /Filter /ASCIIHexDecode '
        '/Length ${hex.length} >>\nstream\n$hex\nendstream',
  ]);
}

Uint8List buildImageOnlyPdf() {
  const operations = '''
0.90 0.90 0.86 rg
72 120 468 560 re
f
0.16 0.18 0.20 RG
2 w
72 120 468 560 re
S
0.30 0.42 0.60 rg
120 610 180 40 re
f
0.75 0.35 0.22 rg
120 540 260 28 re
f
0.20 0.55 0.38 rg
120 490 220 28 re
f''';
  return _writePdfObjects([
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>',
    '<< /Length ${ascii.encode(operations).length} >>\nstream\n$operations\nendstream',
  ]);
}

String buildSamplesReadme(List<GeneratedSample> samples) {
  final buffer = StringBuffer()
    ..writeln('# PageSage Manual Samples')
    ..writeln()
    ..writeln(
      '这些文件由 `dart run tool/generate_manual_samples.dart` 本地生成，不进入生产资源包。',
    )
    ..writeln()
    ..writeln('| 文件 | 用途 |')
    ..writeln('| --- | --- |');
  for (final sample in samples) {
    buffer.writeln('| `${sample.fileName}` | ${sample.description} |');
  }
  return buffer.toString();
}

Uint8List _writePdfObjects(List<String> bodies) {
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < bodies.length; i += 1) {
    offsets.add(ascii.encode(buffer.toString()).length);
    buffer.write('${i + 1} 0 obj\n${bodies[i]}\nendobj\n');
  }
  final xrefOffset = ascii.encode(buffer.toString()).length;
  buffer
    ..write('xref\n0 ${bodies.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${bodies.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

String _objectBody(String object) {
  final lines = object.trim().split('\n');
  return lines.sublist(1, lines.length - 1).join('\n');
}

String _escapePdfText(String text) {
  return text
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

String _escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _slug(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

final _checkerPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAWElEQVR4nO3PQQ0AIBDAMMC/5+ONAvZoFSzZnQVm7b0O8G8B3JYAWwJsCbAlwJYAWwJsCbAlwJYAWwJsCbAlwJYAWwJsCbAlwJYAWwJsCbAlwJYAWwK8AF2pAi/voHMUAAAAAElFTkSuQmCC',
);

final class EpubSampleChapter {
  const EpubSampleChapter({
    required this.fileName,
    required this.title,
    required this.body,
  });

  final String fileName;
  final String title;
  final String body;
}

final class GeneratedSample {
  const GeneratedSample({
    required this.fileName,
    required this.description,
    required this.write,
  });

  final String fileName;
  final String description;
  final Future<void> Function(File file) write;
}

Future<void> main(List<String> args) async {
  final outputPath = args.isEmpty ? defaultManualSamplesPath : args.first;
  final samples = await generateManualSamples(outputPath: outputPath);
  stdout.writeln('Generated ${samples.length} manual samples in $outputPath');
  for (final sample in samples) {
    stdout.writeln('- ${sample.fileName}: ${sample.description}');
  }
}
