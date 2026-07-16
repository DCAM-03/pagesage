import '../books/reading_position.dart';

enum AnnotationColor {
  yellow('yellow'),
  blue('blue'),
  green('green'),
  red('red'),
  purple('purple');

  const AnnotationColor(this.value);

  final String value;

  static AnnotationColor fromValue(String value) {
    return values.firstWhere(
      (color) => color.value == value,
      orElse: () => AnnotationColor.yellow,
    );
  }
}

enum AnnotationStyle {
  highlight('highlight'),
  underline('underline');

  const AnnotationStyle(this.value);

  final String value;

  static AnnotationStyle fromValue(String value) {
    return values.firstWhere(
      (style) => style.value == value,
      orElse: () => AnnotationStyle.highlight,
    );
  }
}

final class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.locator,
    required this.selectedText,
    required this.color,
    required this.style,
    required this.createdAt,
    required this.updatedAt,
    this.noteId,
  });

  final String id;
  final String bookId;
  final ReadingLocator locator;
  final String selectedText;
  final AnnotationColor color;
  final AnnotationStyle style;
  final String? noteId;
  final int createdAt;
  final int updatedAt;
}

abstract interface class AnnotationRepository {
  Stream<List<Annotation>> watchByBook(String bookId);

  Future<List<Annotation>> getAll();

  Future<List<Annotation>> getByBook(String bookId);

  Future<Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    AnnotationColor color,
    AnnotationStyle style,
  });

  Future<void> linkNote({required String annotationId, required String noteId});

  Future<void> deleteAnnotation(String id);
}
