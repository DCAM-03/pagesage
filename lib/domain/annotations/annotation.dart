import '../books/reading_position.dart';
import 'image_anchor.dart';

/// What an annotation marks.
///
/// Text and image annotations share a table because everything around them is
/// shared: colours, notes, export, Notebook, jump-back. What differs is only
/// the geometry, and that lives in [Annotation.imageAnchor].
enum AnnotationTarget {
  text('text'),
  image('image');

  const AnnotationTarget(this.value);

  final String value;

  static AnnotationTarget fromValue(String value) {
    return values.firstWhere(
      (target) => target.value == value,
      orElse: () => AnnotationTarget.text,
    );
  }
}

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
    this.target = AnnotationTarget.text,
    this.imageAnchor,
  });

  final String id;
  final String bookId;

  /// Where to jump. For an image annotation this still points at the page or
  /// chapter the image sits on, so jump-back, progress and export keep working
  /// without knowing about images.
  final ReadingLocator locator;

  /// The marked text, or the image's caption for an image annotation. Empty
  /// when the image has neither `alt` text nor a caption.
  final String selectedText;
  final AnnotationColor color;
  final AnnotationStyle style;
  final String? noteId;
  final int createdAt;
  final int updatedAt;
  final AnnotationTarget target;

  /// The image this annotation marks, for [AnnotationTarget.image].
  ///
  /// Null on a text annotation. An image target without an anchor is a
  /// contradiction the repository refuses to write: the annotation would have
  /// nowhere to paint.
  final ImageAnchor? imageAnchor;
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
    AnnotationColor color = AnnotationColor.yellow,
    AnnotationStyle style = AnnotationStyle.highlight,
    ImageAnchor? imageAnchor,
  });

  Future<void> linkNote({required String annotationId, required String noteId});

  Future<void> unlinkNote({required String annotationId});

  Future<void> deleteAnnotation(String id);
}
