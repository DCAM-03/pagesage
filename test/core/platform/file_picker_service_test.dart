import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/platform/file_picker_service.dart';

void main() {
  test('pickBookFile requests a single EPUB or PDF file', () async {
    final adapter = _FakeFilePickerAdapter([
      const PickedPlatformFile(path: r'C:\books\demo.epub', name: 'demo.epub'),
    ]);
    final service = FilePickerService(adapter: adapter);

    final file = await service.pickBookFile();

    expect(file?.path, r'C:\books\demo.epub');
    expect(file?.name, 'demo.epub');
    expect(adapter.requests.single.allowMultiple, isFalse);
    expect(adapter.requests.single.allowedExtensions, ['epub', 'pdf']);
    expect(adapter.requests.single.dialogTitle, '导入 EPUB/PDF');
  });

  test('pickBookFiles requests multiple EPUB or PDF files', () async {
    final adapter = _FakeFilePickerAdapter([
      const PickedPlatformFile(path: r'C:\books\a.epub', name: 'a.epub'),
      const PickedPlatformFile(path: r'C:\books\b.pdf', name: 'b.pdf'),
    ]);
    final service = FilePickerService(adapter: adapter);

    final files = await service.pickBookFiles();

    expect(files.map((file) => file.name), ['a.epub', 'b.pdf']);
    expect(adapter.requests.single.allowMultiple, isTrue);
    expect(adapter.requests.single.allowedExtensions, ['epub', 'pdf']);
    expect(adapter.requests.single.dialogTitle, '导入 EPUB/PDF');
  });

  test('pickBackupZipFile requests a single zip file', () async {
    final adapter = _FakeFilePickerAdapter([
      const PickedPlatformFile(
        path: r'C:\backups\pagesage.zip',
        name: 'pagesage.zip',
      ),
    ]);
    final service = FilePickerService(adapter: adapter);

    final file = await service.pickBackupZipFile();

    expect(file?.path, r'C:\backups\pagesage.zip');
    expect(adapter.requests.single.allowMultiple, isFalse);
    expect(adapter.requests.single.allowedExtensions, ['zip']);
    expect(adapter.requests.single.dialogTitle, '选择 PageSage 备份文件');
  });

  test('returns null or empty lists when the picker is cancelled', () async {
    final adapter = _FakeFilePickerAdapter(const []);
    final service = FilePickerService(adapter: adapter);

    expect(await service.pickBookFile(), isNull);
    expect(await service.pickBackupZipFile(), isNull);
    expect(await service.pickBookFiles(), isEmpty);
  });

  test('save export path requests markdown file', () async {
    final adapter = _FakeFilePickerAdapter(
      const [],
      savePath: r'C:\exports\notes.md',
    );
    final service = FilePickerService(adapter: adapter);

    final path = await service.pickNotesMarkdownExportPath();

    expect(path, r'C:\exports\notes.md');
    expect(adapter.saveRequests.single.dialogTitle, '导出全部笔记');
    expect(adapter.saveRequests.single.allowedExtensions, ['md']);
  });
}

final class _FakeFilePickerAdapter implements FilePickerAdapter {
  _FakeFilePickerAdapter(this.files, {this.savePath});

  final List<PickedPlatformFile> files;
  final String? savePath;
  final List<FilePickerRequest> requests = [];
  final List<FileSaveRequest> saveRequests = [];

  @override
  Future<List<PickedPlatformFile>> pickFiles(FilePickerRequest request) async {
    requests.add(request);
    return files;
  }

  @override
  Future<String?> saveFile(FileSaveRequest request) async {
    saveRequests.add(request);
    return savePath;
  }
}
