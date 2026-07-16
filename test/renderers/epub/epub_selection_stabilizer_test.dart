import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/epub/epub_selection_stabilizer.dart';

void main() {
  test('publishes only the settled EPUB text selection', () async {
    final published = <String>[];
    final stabilizer = EpubSelectionStabilizer<String>(
      delay: const Duration(milliseconds: 50),
      onSettled: published.add,
    );

    stabilizer.schedule('穷');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    stabilizer.schedule('穷查理宝典');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(published, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(published, ['穷查理宝典']);
  });

  test('cancels pending EPUB text selection', () async {
    final published = <String>[];
    final stabilizer = EpubSelectionStabilizer<String>(
      delay: const Duration(milliseconds: 50),
      onSettled: published.add,
    );

    stabilizer.schedule('将被取消的选区');
    stabilizer.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(published, isEmpty);
  });
}
