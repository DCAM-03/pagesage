import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/files/app_paths.dart';
import '../../../core/files/format_detector.dart';
import '../../../core/files/hash_service.dart';
import '../../../core/files/metadata_extractor.dart';
import '../../../core/platform/platform_providers.dart';
import '../../../renderers/pdf/pdf_cover_renderer.dart';
import 'import_use_case.dart';

final appPathsProvider = Provider<AppPaths>((ref) => AppPaths());

final hashServiceProvider = Provider<HashService>((ref) => HashService());

final metadataExtractorProvider = Provider<MetadataExtractor>((ref) {
  return MetadataExtractor(
    appPaths: ref.watch(appPathsProvider),
    // The app can rasterize, so a PDF's shelf cover is its first page — the
    // same picture opening the book shows. The CLI tools leave this off and
    // keep the embedded-image fallback.
    pdfCoverPainter: const PdfCoverRenderer().renderCoverPng,
  );
});

final formatDetectorProvider = Provider<FormatDetector>(
  (ref) => FormatDetector(),
);

final importUseCaseProvider = Provider<ImportUseCase>((ref) {
  return ImportUseCase(
    filePickerService: ref.watch(filePickerServiceProvider),
    formatDetector: ref.watch(formatDetectorProvider),
    hashService: ref.watch(hashServiceProvider),
    metadataExtractor: ref.watch(metadataExtractorProvider),
    appPaths: ref.watch(appPathsProvider),
    bookRepository: ref.watch(bookRepositoryProvider),
    searchIndexer: ref.watch(searchIndexerProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
    taskCancellationRegistry: ref.watch(taskCancellationRegistryProvider),
  );
});
