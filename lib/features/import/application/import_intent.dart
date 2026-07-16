import 'package:flutter_riverpod/flutter_riverpod.dart';

final importIntentProvider = NotifierProvider<ImportIntentController, int>(
  ImportIntentController.new,
);

final class ImportIntentController extends Notifier<int> {
  @override
  int build() => 0;

  void request() {
    state += 1;
  }
}

void requestBookImport(WidgetRef ref) {
  ref.read(importIntentProvider.notifier).request();
}
