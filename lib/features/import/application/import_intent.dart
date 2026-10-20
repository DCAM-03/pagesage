import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A request to open the import picker, as a one-shot intent.
///
/// The library page consumes an intent by calling [ImportIntentController.take]
/// instead of comparing counters with its own state: the counter lives in a
/// provider that outlives the page, and `ShellRoute` remounts the page whenever
/// the user navigates. A page-local "last handled" value therefore resets to 0
/// and replays the previous request — which opened the file picker every time
/// the user clicked 书库 after an earlier import.
final importIntentProvider = NotifierProvider<ImportIntentController, int>(
  ImportIntentController.new,
);

final class ImportIntentController extends Notifier<int> {
  @override
  int build() => 0;

  /// Records a request; [take] returns and clears it.
  void request() {
    state += 1;
  }

  /// Returns the pending request, or null when there is nothing to handle.
  ///
  /// Taking clears the intent, so every request is handled exactly once no
  /// matter how often the page remounts.
  int? take() {
    final pending = state;
    if (pending == 0) return null;
    state = 0;
    return pending;
  }
}

void requestBookImport(WidgetRef ref) {
  ref.read(importIntentProvider.notifier).request();
}
