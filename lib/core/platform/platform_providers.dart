import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_picker_service.dart';
import 'open_file_location_service.dart';
import 'window_drop_import_service.dart';

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => FilePickerService(),
);

final openFileLocationServiceProvider = Provider<OpenFileLocationService>(
  (ref) => OpenFileLocationService(),
);

final windowDropImportServiceProvider = Provider<WindowDropImportService>(
  (ref) => WindowDropImportService(),
);
