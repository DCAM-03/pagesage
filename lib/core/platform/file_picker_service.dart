import 'package:file_picker/file_picker.dart';

final class PickedPlatformFile {
  const PickedPlatformFile({required this.path, required this.name});

  final String path;
  final String name;
}

final class PickedBookFile {
  const PickedBookFile({required this.path, required this.name});

  final String path;
  final String name;
}

final class FilePickerRequest {
  const FilePickerRequest({
    required this.allowMultiple,
    required this.allowedExtensions,
    required this.dialogTitle,
  });

  final bool allowMultiple;
  final List<String> allowedExtensions;
  final String dialogTitle;
}

final class FileSaveRequest {
  const FileSaveRequest({
    required this.dialogTitle,
    required this.fileName,
    required this.allowedExtensions,
  });

  final String dialogTitle;
  final String fileName;
  final List<String> allowedExtensions;
}

abstract interface class FilePickerAdapter {
  Future<List<PickedPlatformFile>> pickFiles(FilePickerRequest request);

  Future<String?> saveFile(FileSaveRequest request);

  Future<String?> pickDirectory({required String dialogTitle});
}

final class FilePickerPluginAdapter implements FilePickerAdapter {
  const FilePickerPluginAdapter();

  @override
  Future<List<PickedPlatformFile>> pickFiles(FilePickerRequest request) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: request.allowMultiple,
      type: FileType.custom,
      allowedExtensions: request.allowedExtensions,
      dialogTitle: request.dialogTitle,
      lockParentWindow: true,
    );

    final files = result?.files ?? const <PlatformFile>[];
    return files
        .where((file) => file.path != null)
        .map((file) => PickedPlatformFile(path: file.path!, name: file.name))
        .toList(growable: false);
  }

  @override
  Future<String?> saveFile(FileSaveRequest request) {
    return FilePicker.saveFile(
      dialogTitle: request.dialogTitle,
      fileName: request.fileName,
      type: FileType.custom,
      allowedExtensions: request.allowedExtensions,
      lockParentWindow: true,
    );
  }

  @override
  Future<String?> pickDirectory({required String dialogTitle}) {
    return FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
      lockParentWindow: true,
    );
  }
}

final class FilePickerService {
  factory FilePickerService({
    FilePickerAdapter adapter = const FilePickerPluginAdapter(),
  }) {
    return FilePickerService._(adapter);
  }

  const FilePickerService._(this._adapter);

  final FilePickerAdapter _adapter;

  Future<PickedBookFile?> pickBookFile() async {
    final files = await _adapter.pickFiles(
      const FilePickerRequest(
        allowMultiple: false,
        allowedExtensions: ['epub', 'pdf'],
        dialogTitle: '导入 EPUB/PDF',
      ),
    );

    if (files.isEmpty) {
      return null;
    }
    final file = files.first;
    return PickedBookFile(path: file.path, name: file.name);
  }

  Future<List<PickedBookFile>> pickBookFiles() async {
    final files = await _adapter.pickFiles(
      const FilePickerRequest(
        allowMultiple: true,
        allowedExtensions: ['epub', 'pdf'],
        dialogTitle: '导入 EPUB/PDF',
      ),
    );

    return files
        .map((file) => PickedBookFile(path: file.path, name: file.name))
        .toList(growable: false);
  }

  Future<String?> pickFolder({String dialogTitle = '选择包含电子书的文件夹'}) {
    return _adapter.pickDirectory(dialogTitle: dialogTitle);
  }

  Future<PickedPlatformFile?> pickBackupZipFile() async {
    final files = await _adapter.pickFiles(
      const FilePickerRequest(
        allowMultiple: false,
        allowedExtensions: ['zip'],
        dialogTitle: '选择 PageSage 备份文件',
      ),
    );
    return files.isEmpty ? null : files.first;
  }

  Future<String?> pickNotesMarkdownExportPath() {
    return _adapter.saveFile(
      const FileSaveRequest(
        dialogTitle: '导出全部笔记',
        fileName: 'pagesage-notes.md',
        allowedExtensions: ['md'],
      ),
    );
  }

  Future<String?> pickBookmarksCsvExportPath() {
    return _adapter.saveFile(
      const FileSaveRequest(
        dialogTitle: '导出书签 CSV',
        fileName: 'pagesage-bookmarks.csv',
        allowedExtensions: ['csv'],
      ),
    );
  }

  Future<String?> pickAiMarkdownExportPath() {
    return _adapter.saveFile(
      const FileSaveRequest(
        dialogTitle: '导出 AI 问答',
        fileName: 'pagesage-ai.md',
        allowedExtensions: ['md'],
      ),
    );
  }

  Future<String?> pickAnnotationsJsonExportPath() {
    return _adapter.saveFile(
      const FileSaveRequest(
        dialogTitle: '导出标注 JSON',
        fileName: 'pagesage-annotations.json',
        allowedExtensions: ['json'],
      ),
    );
  }

  Future<String?> pickNotebookMarkdownExportPath() {
    return _adapter.saveFile(
      const FileSaveRequest(
        dialogTitle: '导出 Notebook',
        fileName: 'pagesage-notebook.md',
        allowedExtensions: ['md'],
      ),
    );
  }

  Future<String?> pickBackupZipExportPath() {
    return _adapter.saveFile(
      const FileSaveRequest(
        dialogTitle: '备份 PageSage 数据',
        fileName: 'pagesage-backup.zip',
        allowedExtensions: ['zip'],
      ),
    );
  }
}
