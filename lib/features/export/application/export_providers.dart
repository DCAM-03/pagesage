import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../import/application/import_providers.dart';
import 'export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    appPaths: ref.watch(appPathsProvider),
    noteRepository: ref.watch(noteRepositoryProvider),
    bookmarkRepository: ref.watch(bookmarkRepositoryProvider),
    annotationRepository: ref.watch(annotationRepositoryProvider),
    aiConversationRepository: ref.watch(aiConversationRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
  );
});
