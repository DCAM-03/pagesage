import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/books/reading_position.dart';
import '../features/app_shell/presentation/main_shell.dart';
import '../features/library/presentation/library_page.dart';
import '../features/notes/presentation/notes_page.dart';
import '../features/reader/presentation/reader_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tasks/presentation/task_center_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/library'),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (context, state) => const LibraryPage(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/notes',
            name: 'notes',
            builder: (context, state) => const NotesPage(),
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const TaskCenterPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/book/:bookId/reader',
        name: 'reader',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final initialLocator = state.extra is ReadingLocator
              ? state.extra! as ReadingLocator
              : null;
          return ReaderPage(bookId: bookId, initialLocator: initialLocator);
        },
      ),
    ],
  );
});
