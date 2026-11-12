import 'dart:ui';

import '../../domain/annotations/annotation.dart';

/// The wash painted over a PDF annotation.
///
/// PDF pages are painted by the document, not by the reader's theme, so the
/// annotation layer is drawn after the night-mode colour filter. These values
/// therefore have to do two jobs at once: stay legible over light text on a
/// dark page, and stay quiet enough that the page still looks like a document.
///
/// The night values are the design-system's dark suggestions at the same
/// opacity EPUB uses, so both readers speak the same colour language.
Color pdfAnnotationColor(AnnotationColor color, {required bool night}) {
  if (night) {
    return switch (color) {
      AnnotationColor.yellow => const Color(0x668C7A2A),
      AnnotationColor.blue => const Color(0x6651768F),
      AnnotationColor.green => const Color(0x66527A5F),
      AnnotationColor.red => const Color(0x66805858),
      AnnotationColor.purple => const Color(0x666B5C8C),
    };
  }
  return switch (color) {
    AnnotationColor.yellow => const Color(0x66FFD54F),
    AnnotationColor.blue => const Color(0x664FC3F7),
    AnnotationColor.green => const Color(0x6681C784),
    AnnotationColor.red => const Color(0x66E57373),
    AnnotationColor.purple => const Color(0x66BA68C8),
  };
}
