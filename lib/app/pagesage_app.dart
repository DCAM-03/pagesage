import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/import/application/import_providers.dart';
import '../features/settings/application/settings_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

const _verifyImportPaths = String.fromEnvironment(
  'PAGESAGE_VERIFY_IMPORT_PATHS',
);

final class PageSageApp extends ConsumerWidget {
  const PageSageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(readerSettingsProvider);

    return _DebugStartupImport(
      child: MaterialApp.router(
        title: 'PageSage',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        highContrastTheme: AppTheme.highContrast(),
        highContrastDarkTheme: AppTheme.highContrast(),
        themeMode: settings.value?.appThemeMode ?? ThemeMode.system,
      ),
    );
  }
}

final class _DebugStartupImport extends ConsumerStatefulWidget {
  const _DebugStartupImport({required this.child});

  final Widget child;

  @override
  ConsumerState<_DebugStartupImport> createState() =>
      _DebugStartupImportState();
}

final class _DebugStartupImportState
    extends ConsumerState<_DebugStartupImport> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || kReleaseMode || _verifyImportPaths.trim().isEmpty) {
      return;
    }
    _started = true;
    Future<void>(_importVerificationSamples);
  }

  Future<void> _importVerificationSamples() async {
    final paths = _verifyImportPaths
        .split(RegExp(r'[;|]'))
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty);
    final importUseCase = ref.read(importUseCaseProvider);
    for (final path in paths) {
      await importUseCase.importPath(path);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
