import '../books/reading_position.dart';

/// Where an annotation sits on an image in the book.
///
/// Coordinates are always the fraction of the *displayed* page box (after
/// `/Rotate`), 0..1 with y growing downward — the same basis [ReaderRect] uses
/// for text selection, so the two can share the projection code.
///
/// The identity of an image is `page + ordinal + resourceName` (PDF) or
/// `href + ordinal` (EPUB), never the rectangle. A rectangle is what the image
/// occupied in one particular layout; the same illustration in a file
/// re-exported with a different `/Rotate` has a different rectangle but is
/// still the same image to whoever annotated it. [rect] is therefore only a
/// fallback for when the element can no longer be found by identity.
sealed class ImageAnchor {
  const ImageAnchor({required this.rect, this.region});

  /// The image's own box on the displayed page, 0..1.
  final ReaderRect rect;

  /// The part of the image the reader marked, relative to [rect]; null means
  /// the whole image.
  final ReaderRect? region;

  Map<String, Object?> toJson();

  static ImageAnchor? fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    final rect = _rectFromJson(json['rect']);
    if (rect == null) {
      return null;
    }
    final region = _rectFromJson(json['region']);
    return switch (kind) {
      'pdf' => _pdfFromJson(json, rect, region),
      'epub' => _epubFromJson(json, rect, region),
      _ => null,
    };
  }

  static ImageAnchor? _pdfFromJson(
    Map<String, Object?> json,
    ReaderRect rect,
    ReaderRect? region,
  ) {
    final page = _asInt(json['page']);
    if (page == null || page < 1) {
      return null;
    }
    return PdfImageAnchor(
      page: page,
      ordinal: _asInt(json['ordinal']),
      resourceName: json['resourceName'] as String?,
      rect: rect,
      region: region,
    );
  }

  static ImageAnchor? _epubFromJson(
    Map<String, Object?> json,
    ReaderRect rect,
    ReaderRect? region,
  ) {
    final href = json['href'];
    final ordinal = _asInt(json['ordinal']);
    if (href is! String || href.isEmpty || ordinal == null) {
      return null;
    }
    return EpubImageAnchor(
      href: href,
      ordinal: ordinal,
      archivePath: json['archivePath'] as String?,
      rect: rect,
      region: region,
    );
  }

  static ReaderRect? _rectFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ReaderRect.fromJson(value.cast<String, Object?>());
    } on Object {
      // A malformed rect makes the anchor unusable, but it must not stop the
      // annotation list from loading.
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

/// An image placed by a PDF page's content stream.
///
/// [ordinal] counts image elements on [page] in paint order, and
/// [resourceName] is the `/XObject` name the stream invoked. Either can be
/// null: the document may not parse, or the element may be an inline image
/// that has no resource name. Both missing still leaves a usable annotation
/// because [rect] is stored.
final class PdfImageAnchor extends ImageAnchor {
  const PdfImageAnchor({
    required this.page,
    this.ordinal,
    this.resourceName,
    required super.rect,
    super.region,
  });

  /// 1-based page number, matching [ReadingLocator.page].
  final int page;
  final int? ordinal;
  final String? resourceName;

  @override
  Map<String, Object?> toJson() {
    return {
      'kind': 'pdf',
      'page': page,
      if (ordinal != null) 'ordinal': ordinal,
      if (resourceName != null) 'resourceName': resourceName,
      'rect': rect.toJson(),
      if (region != null) 'region': region!.toJson(),
    };
  }
}

/// An image inside an EPUB spine document.
final class EpubImageAnchor extends ImageAnchor {
  const EpubImageAnchor({
    required this.href,
    required this.ordinal,
    this.archivePath,
    required super.rect,
    super.region,
  });

  final String href;

  /// Index of the `<img>` within the document.
  final int ordinal;

  /// Path inside the archive, kept so the bytes can still be found if the
  /// document's markup is renumbered.
  final String? archivePath;

  @override
  Map<String, Object?> toJson() {
    return {
      'kind': 'epub',
      'href': href,
      'ordinal': ordinal,
      if (archivePath != null) 'archivePath': archivePath,
      'rect': rect.toJson(),
      if (region != null) 'region': region!.toJson(),
    };
  }
}
