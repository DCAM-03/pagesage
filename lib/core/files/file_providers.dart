import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_paths.dart';

/// Where the app keeps its data: the library copy of books, the database,
/// covers, exports and the cache.
///
/// Lives in `core` rather than beside the import flow because the reader, the
/// export service and the settings page all need it, and none of them should
/// have to import an unrelated feature to get a path.
final appPathsProvider = Provider<AppPaths>((ref) => AppPaths());
