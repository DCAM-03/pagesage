import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_fonts.dart';

void main() {
  test('resolves bundled fonts and system default', () {
    expect(ReaderFonts.resolve(null).isSystem, isTrue);
    expect(ReaderFonts.resolve('').label, '系统默认');
    expect(
      ReaderFonts.resolve('LXGW WenKai Lite').familyName,
      'LXGW WenKai Lite',
    );
    expect(
      ReaderFonts.renderFamilyFor('Atkinson Hyperlegible'),
      'Atkinson Hyperlegible',
    );
  });
}
