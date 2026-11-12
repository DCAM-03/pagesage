import 'package:flutter/widgets.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_ai_profile_repository.dart';
import 'package:pagesage/core/security/secure_store.dart';

/// One-shot local config helper. Do not commit secrets.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Usage:
  // dart run tool/configure_ai_local.dart <baseUrl> <model> <apiKey>
  // Never hardcode personal endpoints or keys in this file.
  if (args.length < 3) {
    throw StateError(
      'Usage: dart run tool/configure_ai_local.dart <baseUrl> <model> <apiKey>',
    );
  }
  final baseUrl = args[0];
  final model = args[1];
  final apiKey = args[2];

  if (baseUrl.isEmpty || model.isEmpty || apiKey.isEmpty) {
    throw StateError('baseUrl, model, and apiKey are required');
  }

  final database = AppDatabase();
  final secureStore = SecureStore();
  final repository = DriftAiProfileRepository(database, secureStore);

  try {
    final current = await repository.getSettings();
    await repository.saveSettings(
      current.copyWith(
        enabled: true,
        provider: 'openai-compatible',
        baseUrl: baseUrl,
        model: model,
        temperature: 0.2,
        maxTokens: 1200,
        streaming: true,
        confirmBeforeRequest: true,
      ),
      apiKey: apiKey,
    );

    final saved = await repository.getSettings();

    // Never print the API key.
    // ignore: avoid_print
    print(
      'AI configured: enabled=${saved.enabled}, '
      'provider=${saved.provider}, '
      'model=${saved.model}, hasApiKey=${saved.hasApiKey}',
    );
  } finally {
    repository.dispose();
    await database.close();
  }
}
