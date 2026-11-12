import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/annotations/annotation.dart' as domain;
import '../../domain/annotations/image_anchor.dart' as domain;
import '../../domain/books/reading_position.dart';
import '../../domain/books/locator_excerpt.dart';
import 'drift_locator_mapping.dart';
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftAnnotationRepository implements domain.AnnotationRepository {
  const DriftAnnotationRepository(this._dao);

  final db.AnnotationDao _dao;

  @override
  Stream<List<domain.Annotation>> watchByBook(String bookId) {
    return _dao
        .watchByBook(bookId)
        .map((rows) => rows.map(_mapAnnotation).toList(growable: false));
  }

  @override
  Future<List<domain.Annotation>> getByBook(String bookId) async {
    final rows = await _dao.getByBook(bookId);
    return rows.map(_mapAnnotation).toList(growable: false);
  }

  @override
  Future<List<domain.Annotation>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_mapAnnotation).toList(growable: false);
  }

  @override
  Future<domain.Annotation> saveAnnotation({
    String? id,
    required String bookId,
    required ReadingLocator locator,
    required String selectedText,
    domain.AnnotationColor color = domain.AnnotationColor.yellow,
    domain.AnnotationStyle style = domain.AnnotationStyle.highlight,
    domain.ImageAnchor? imageAnchor,
  }) async {
    final rect = imageAnchor?.rect;
    if (rect != null &&
        (!rect.x.isFinite ||
            !rect.y.isFinite ||
            !rect.width.isFinite ||
            !rect.height.isFinite ||
            rect.width <= 0 ||
            rect.height <= 0)) {
      throw ArgumentError.value(
        imageAnchor,
        'imageAnchor',
        'image annotation needs a non-empty rect',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = id == null ? null : await _dao.getAnnotation(id);
    final resolvedLocator = enrichLocatorForJump(
      locator,
      fallbackExcerpt: selectedText,
    );
    final annotation = domain.Annotation(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      locator: resolvedLocator,
      selectedText: selectedText,
      color: color,
      style: style,
      noteId: previous?.noteId,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      target: imageAnchor == null
          ? domain.AnnotationTarget.text
          : domain.AnnotationTarget.image,
      imageAnchor: imageAnchor,
    );
    await _dao.upsertAnnotation(
      db.AnnotationsCompanion.insert(
        id: annotation.id,
        bookId: annotation.bookId,
        locator: annotation.locator.toJsonText(),
        selectedText: annotation.selectedText,
        color: annotation.color.value,
        style: annotation.style.value,
        noteId: Value(annotation.noteId),
        // Has a column default, so the generated insert takes a `Value`.
        target: Value(annotation.target.value),
        imageAnchor: Value(
          annotation.imageAnchor == null
              ? null
              : jsonEncode(annotation.imageAnchor!.toJson()),
        ),
        createdAt: annotation.createdAt,
        updatedAt: annotation.updatedAt,
      ),
    );
    return annotation;
  }

  @override
  Future<void> linkNote({
    required String annotationId,
    required String noteId,
  }) {
    return _dao.linkNote(annotationId: annotationId, noteId: noteId);
  }

  @override
  Future<void> unlinkNote({required String annotationId}) {
    return _dao.unlinkNote(annotationId: annotationId);
  }

  @override
  Future<void> deleteAnnotation(String id) {
    return _dao.deleteAnnotation(id);
  }

  domain.Annotation _mapAnnotation(db.AnnotationRow row) {
    return domain.Annotation(
      id: row.id,
      bookId: row.bookId,
      locator: locatorFromDatabaseText(row.locator),
      selectedText: row.selectedText,
      color: domain.AnnotationColor.fromValue(row.color),
      style: domain.AnnotationStyle.fromValue(row.style),
      noteId: row.noteId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      target: domain.AnnotationTarget.fromValue(row.target),
      imageAnchor: _imageAnchorFromText(row.imageAnchor),
    );
  }

  domain.ImageAnchor? _imageAnchorFromText(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return domain.ImageAnchor.fromJson(decoded.cast<String, Object?>());
      }
    } on Object {
      // A corrupt anchor must not hide the rest of the annotation list; the
      // annotation still jumps to its page through `locator`.
    }
    return null;
  }
}
