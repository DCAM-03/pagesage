import 'dart:convert';

import '../../domain/books/reading_position.dart';

ReadingLocator locatorFromDatabaseText(String text) {
  try {
    return ReadingLocator.fromJsonText(text);
  } on Object {
    final json = jsonDecode(text);
    if (json is Map<String, Object?>) {
      return ReadingLocator.fromJson(json);
    }
    return ReadingLocator.epub();
  }
}
