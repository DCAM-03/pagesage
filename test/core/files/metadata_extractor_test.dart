import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/metadata_extractor.dart';
import 'package:pagesage/domain/books/book.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('pagesage_meta_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('extracts EPUB metadata and cover into app library', () async {
    final epub = File(p.join(tempDir.path, 'sample.epub'));
    await epub.writeAsBytes(_buildEpubBytes());

    final metadata = await MetadataExtractor(
      appPaths: AppPaths(),
    ).extract(file: epub, format: BookFormat.epub, bookId: 'book-1');

    expect(metadata.title, '测试标题');
    expect(metadata.author, '作者');
    expect(metadata.language, 'zh-CN');
    expect(metadata.description, '简介');
    expect(metadata.coverPath, isNotNull);
    expect(await File(metadata.coverPath!).exists(), isTrue);
  });

  test('extracts EPUB3 cover-image property without meta name=cover', () async {
    final epub = File(p.join(tempDir.path, 'epub3.epub'));
    await epub.writeAsBytes(_buildEpub3CoverPropertyBytes());

    final metadata = await MetadataExtractor(
      appPaths: AppPaths(),
    ).extract(file: epub, format: BookFormat.epub, bookId: 'book-epub3');

    expect(metadata.coverPath, isNotNull);
    expect(await File(metadata.coverPath!).exists(), isTrue);
    expect(metadata.coverPath, endsWith('.jpg'));
  });

  test('extracts largest embedded JPEG as PDF cover', () async {
    final pdf = File(p.join(tempDir.path, 'sample.pdf'));
    await pdf.writeAsBytes(_buildPdfWithJpegCover());

    final metadata = await MetadataExtractor(
      appPaths: AppPaths(),
    ).extract(file: pdf, format: BookFormat.pdf, bookId: 'book-pdf');

    expect(metadata.coverPath, isNotNull);
    expect(await File(metadata.coverPath!).exists(), isTrue);
    final coverBytes = await File(metadata.coverPath!).readAsBytes();
    expect(coverBytes[0], 0xFF);
    expect(coverBytes[1], 0xD8);
  });
}

List<int> _buildEpubBytes() {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
    )
    ..addFile(
      ArchiveFile.string('OEBPS/content.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>测试标题</dc:title>
    <dc:creator>作者</dc:creator>
    <dc:language>zh-CN</dc:language>
    <dc:description>简介</dc:description>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="images/cover.png" media-type="image/png"/>
  </manifest>
</package>
'''),
    )
    ..addFile(ArchiveFile('OEBPS/images/cover.png', 4, [1, 2, 3, 4]));
  return ZipEncoder().encode(archive);
}

List<int> _buildEpub3CoverPropertyBytes() {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/package.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
    )
    ..addFile(
      ArchiveFile.string('OPS/package.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>EPUB3 Cover</dc:title>
  </metadata>
  <manifest>
    <item id="c1" href="img/front.jpg" media-type="image/jpeg" properties="cover-image"/>
    <item id="x" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
</package>
'''),
    )
    ..addFile(
      ArchiveFile(
        'OPS/img/front.jpg',
        16,
        [0xFF, 0xD8, 0xFF, 0xD9, ...List<int>.filled(12, 0)],
      ),
    );
  return ZipEncoder().encode(archive);
}

List<int> _buildPdfWithJpegCover() {
  final jpeg = Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xE0,
    ...List<int>.filled(8000, 0x11),
    0xFF,
    0xD9,
  ]);
  final buffer = BytesBuilder()
    ..add('%PDF-1.4\n'.codeUnits)
    ..add('1 0 obj<<>>endobj\n'.codeUnits)
    ..add(jpeg)
    ..add('\n%%EOF\n'.codeUnits);
  return buffer.takeBytes();
}

final class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}
