import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pagesage/core/platform/file_picker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android exports stream a generated file and preserve content URIs',
    () async {
      const channel = MethodChannel('test/pagesage/files');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'content://documents/tree/export.md';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final picker = FilePickerService(isAndroid: true, filesChannel: channel);
      expect(picker.supportsExportPathSelection, isFalse);
      final path = File('/tmp/notes.md');
      expect(
        await picker.saveExportedFile(path),
        'content://documents/tree/export.md',
      );
      expect(calls.single.method, 'saveExport');
      expect(calls.single.arguments, {
        'sourcePath': path.absolute.path,
        'name': 'notes.md',
        'mimeType': 'text/markdown',
      });
    },
  );

  test('Android document picker cancellation stays cancellation', () async {
    const channel = MethodChannel('test/pagesage/files');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    expect(
      await FilePickerService(
        isAndroid: true,
        filesChannel: channel,
      ).saveExportedFile(File('/tmp/backup.zip')),
      isNull,
    );
  });
  test(
    'selecting an export destination does not truncate an existing file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pagesage-picker-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}/notes.md');
      await target.writeAsString('原导出');
      final picker = FilePickerService(
        adapter: FilePickerPluginAdapter(
          pickSaveLocation: (request) async => target.path,
        ),
      );
      expect(await picker.pickNotesMarkdownExportPath(), target.path);
      expect(await target.readAsString(), '原导出');
    },
  );

  test('cancelling destination selection creates no files', () async {
    final picker = FilePickerService(
      adapter: FilePickerPluginAdapter(pickSaveLocation: (_) async => null),
    );
    expect(await picker.pickNotesMarkdownExportPath(), isNull);
  });
  test('pickBookFile requests a single EPUB, PDF, or Markdown file', () async {
    final adapter = _FakeFilePickerAdapter([
      const PickedPlatformFile(path: r'C:\books\demo.epub', name: 'demo.epub'),
    ]);
    final service = FilePickerService(adapter: adapter);

    final file = await service.pickBookFile();

    expect(file?.path, r'C:\books\demo.epub');
    expect(file?.name, 'demo.epub');
    expect(adapter.requests.single.allowMultiple, isFalse);
    expect(adapter.requests.single.allowedExtensions, [
      'epub',
      'pdf',
      'md',
      'markdown',
    ]);
    expect(adapter.requests.single.dialogTitle, '导入 EPUB/PDF/Markdown');
  });

  test(
    'pickBookFiles requests multiple EPUB, PDF, or Markdown files',
    () async {
      final adapter = _FakeFilePickerAdapter([
        const PickedPlatformFile(path: r'C:\books\a.epub', name: 'a.epub'),
        const PickedPlatformFile(path: r'C:\books\b.pdf', name: 'b.pdf'),
      ]);
      final service = FilePickerService(adapter: adapter);

      final files = await service.pickBookFiles();

      expect(files.map((file) => file.name), ['a.epub', 'b.pdf']);
      expect(adapter.requests.single.allowMultiple, isTrue);
      expect(adapter.requests.single.allowedExtensions, [
        'epub',
        'pdf',
        'md',
        'markdown',
      ]);
      expect(adapter.requests.single.dialogTitle, '导入 EPUB/PDF/Markdown');
    },
  );

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

  group('image save path', () {
    test('writes the PNG the renderer produced', () async {
      final adapter = _FakeFilePickerAdapter(
        const [],
        savePath: r'D:\pictures\page.png',
      );
      final service = FilePickerService(adapter: adapter);
      final bytes = [0x89, 0x50, 0x4E, 0x47];

      final path = await service.pickImageSavePath(
        baseName: '一本书 第 12 页',
        bytes: bytes,
      );

      expect(path, r'D:\pictures\page.png');
      final request = adapter.saveRequests.single;
      expect(request.fileName, '一本书 第 12 页.png');
      expect(request.allowedExtensions, ['png']);
      // The bytes go through the save call; file_picker 12 no longer writes
      // the file itself, so passing them here is the only way it lands.
      expect(request.bytes, bytes);
    });

    test('a title with path separators cannot escape the folder', () async {
      final adapter = _FakeFilePickerAdapter(const [], savePath: '/tmp/a.png');
      final service = FilePickerService(adapter: adapter);

      await service.pickImageSavePath(
        baseName: 'a/b\\c:d*e?f"g<h>i|j',
        bytes: const [1],
      );

      final name = adapter.saveRequests.single.fileName;
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('\\')));
      expect(name, isNot(contains(':')));
      expect(name.endsWith('.png'), isTrue);
    });

    test('an empty title still yields a usable file name', () async {
      final adapter = _FakeFilePickerAdapter(const [], savePath: '/tmp/a.png');
      final service = FilePickerService(adapter: adapter);

      await service.pickImageSavePath(baseName: '   ', bytes: const [1]);

      expect(adapter.saveRequests.single.fileName, 'pagesage-image.png');
    });
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

  @override
  Future<String?> pickDirectory({required String dialogTitle}) async => null;
}
