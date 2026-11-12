import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/annotations/annotation.dart';
import 'package:pagesage/renderers/pdf/pdf_annotation_colors.dart';

void main() {
  group('pdfAnnotationColor', () {
    test('day keeps the bright wash used over white paper', () {
      expect(
        pdfAnnotationColor(AnnotationColor.yellow, night: false).toARGB32(),
        0x66FFD54F,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.blue, night: false).toARGB32(),
        0x664FC3F7,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.green, night: false).toARGB32(),
        0x6681C784,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.red, night: false).toARGB32(),
        0x66E57373,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.purple, night: false).toARGB32(),
        0x66BA68C8,
      );
    });

    test('night uses the design system dark suggestions', () {
      expect(
        pdfAnnotationColor(AnnotationColor.yellow, night: true).toARGB32(),
        0x668C7A2A,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.blue, night: true).toARGB32(),
        0x6651768F,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.green, night: true).toARGB32(),
        0x66527A5F,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.red, night: true).toARGB32(),
        0x66805858,
      );
      expect(
        pdfAnnotationColor(AnnotationColor.purple, night: true).toARGB32(),
        0x666B5C8C,
      );
    });

    test('every night wash differs from its day counterpart', () {
      for (final color in AnnotationColor.values) {
        expect(
          pdfAnnotationColor(color, night: true),
          isNot(pdfAnnotationColor(color, night: false)),
          reason: color.name,
        );
      }
    });
  });
}
