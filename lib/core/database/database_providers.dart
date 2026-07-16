import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/secure_store.dart';
import '../../core/search/search_indexer.dart';
import '../../core/tasks/task_cancellation.dart';
import '../../core/tasks/task_models.dart';
import '../../core/files/app_paths.dart';
import '../../domain/ai/ai_models.dart';
import '../../domain/annotations/annotation.dart';
import '../../domain/books/bookmark.dart';
import '../../domain/books/book_repository.dart';
import '../../domain/books/category.dart';
import '../../domain/books/settings_repository.dart';
import '../../domain/books/tag.dart';
import '../../domain/notes/note.dart';
import '../../domain/search/search_models.dart';
import '../../features/settings/application/local_data_service.dart';
import '../security/security_keys.dart';
import 'app_database.dart';
import 'drift_book_repository.dart';
import 'drift_content_repositories.dart';
import 'drift_settings_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final bookDaoProvider = Provider<BookDao>((ref) {
  return ref.watch(appDatabaseProvider).bookDao;
});

final progressDaoProvider = Provider<ProgressDao>((ref) {
  return ref.watch(appDatabaseProvider).progressDao;
});

final settingsDaoProvider = Provider<SettingsDao>((ref) {
  return ref.watch(appDatabaseProvider).settingsDao;
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return ref.watch(appDatabaseProvider).categoryDao;
});

final tagDaoProvider = Provider<TagDao>((ref) {
  return ref.watch(appDatabaseProvider).tagDao;
});

final bookmarkDaoProvider = Provider<BookmarkDao>((ref) {
  return ref.watch(appDatabaseProvider).bookmarkDao;
});

final annotationDaoProvider = Provider<AnnotationDao>((ref) {
  return ref.watch(appDatabaseProvider).annotationDao;
});

final noteDaoProvider = Provider<NoteDao>((ref) {
  return ref.watch(appDatabaseProvider).noteDao;
});

final aiConversationDaoProvider = Provider<AiConversationDao>((ref) {
  return ref.watch(appDatabaseProvider).aiConversationDao;
});

final searchDaoProvider = Provider<SearchDao>((ref) {
  return ref.watch(appDatabaseProvider).searchDao;
});

final taskDaoProvider = Provider<TaskDao>((ref) {
  return ref.watch(appDatabaseProvider).taskDao;
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore();
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return DriftBookRepository(
    bookDao: ref.watch(bookDaoProvider),
    progressDao: ref.watch(progressDaoProvider),
    bookmarkDao: ref.watch(bookmarkDaoProvider),
    annotationDao: ref.watch(annotationDaoProvider),
    noteDao: ref.watch(noteDaoProvider),
    aiConversationDao: ref.watch(aiConversationDaoProvider),
    searchDao: ref.watch(searchDaoProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(settingsDaoProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(ref.watch(categoryDaoProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return DriftTagRepository(ref.watch(tagDaoProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return DriftSearchRepository(ref.watch(searchDaoProvider));
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return DriftBookmarkRepository(
    ref.watch(bookmarkDaoProvider),
    ref.watch(searchRepositoryProvider),
  );
});

final annotationRepositoryProvider = Provider<AnnotationRepository>((ref) {
  return DriftAnnotationRepository(ref.watch(annotationDaoProvider));
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return DriftNoteRepository(
    ref.watch(noteDaoProvider),
    ref.watch(searchRepositoryProvider),
  );
});

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  return DriftAiSettingsRepository(
    ref.watch(settingsDaoProvider),
    ref.watch(secureStoreProvider),
  );
});

final aiConversationRepositoryProvider = Provider<AiConversationRepository>((
  ref,
) {
  return DriftAiConversationRepository(
    ref.watch(aiConversationDaoProvider),
    ref.watch(searchRepositoryProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return DriftTaskRepository(ref.watch(taskDaoProvider));
});

final taskCancellationRegistryProvider = Provider<TaskCancellationRegistry>((
  ref,
) {
  return TaskCancellationRegistry();
});

final searchIndexerProvider = Provider<SearchIndexer>((ref) {
  return SearchIndexer(
    searchRepository: ref.watch(searchRepositoryProvider),
    bookRepository: ref.watch(bookRepositoryProvider),
  );
});

final localDataServiceProvider = Provider<LocalDataService>((ref) {
  return LocalDataService(
    database: ref.watch(appDatabaseProvider),
    appPaths: AppPaths(),
    clearSecrets: () =>
        ref.read(secureStoreProvider).delete(aiApiKeyStorageKey),
  );
});
