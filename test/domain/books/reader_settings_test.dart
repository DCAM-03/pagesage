import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/domain/books/reader_settings.dart';

void main() {
  test('serializes and restores reader settings', () {
    const settings = ReaderSettings(
      appThemeMode: ThemeMode.dark,
      fontFamily: 'Georgia',
      fontSize: 21,
      lineHeight: 1.9,
      paragraphSpacing: 18,
      pageMargin: 40,
      readerMode: ReaderMode.paged,
      pdfScale: 1.5,
      pdfZoomMode: PdfZoomMode.fitWidth,
      themePreset: ReaderThemePreset.night,
      reduceMotion: true,
    );

    final restored = ReaderSettings.fromJsonText(settings.toJsonText());

    expect(restored.appThemeMode, ThemeMode.dark);
    expect(restored.fontFamily, 'Georgia');
    expect(restored.fontSize, 21);
    expect(restored.lineHeight, 1.9);
    expect(restored.paragraphSpacing, 18);
    expect(restored.pageMargin, 40);
    expect(restored.readerMode, ReaderMode.paged);
    expect(restored.pdfScale, 1.5);
    expect(restored.pdfZoomMode, PdfZoomMode.fitWidth);
    expect(restored.themePreset, ReaderThemePreset.night);
    expect(restored.reduceMotion, isTrue);
  });

  test('restores defaults for older reader settings json', () {
    final restored = ReaderSettings.fromJsonText(
      '{"themeMode":"system","fontSize":19,"lineHeight":1.8,"themePreset":"paper"}',
    );

    expect(restored.fontSize, 19);
    expect(restored.lineHeight, 1.8);
    expect(restored.themePreset, ReaderThemePreset.paper);
    expect(restored.fontFamily, '');
    expect(restored.paragraphSpacing, 12);
    expect(restored.pageMargin, 24);
    expect(restored.readerMode, ReaderMode.continuous);
    expect(restored.pdfScale, 1.0);
    expect(restored.pdfZoomMode, PdfZoomMode.fitWidth);
    expect(restored.reduceMotion, isFalse);
  });

  test('serializes additional warm eye-care and ink themes', () {
    for (final preset in [
      ReaderThemePreset.warm,
      ReaderThemePreset.amber,
      ReaderThemePreset.sage,
      ReaderThemePreset.ink,
      ReaderThemePreset.inkWarm,
    ]) {
      final restored = ReaderSettings.fromJsonText(
        ReaderSettings(themePreset: preset).toJsonText(),
      );

      expect(restored.themePreset, preset);
    }
    expect(ReaderThemePreset.ink.epubInk, isTrue);
    expect(ReaderThemePreset.inkWarm.epubInk, isTrue);
    expect(ReaderThemePreset.warm.epubInk, isFalse);
  });

  test('merges per-book overrides over global defaults', () {
    const defaults = ReaderSettings(fontSize: 18, reduceMotion: false);

    final merged = defaults.mergeOverride(
      const ReaderSettingsOverride(
        fontSize: 22,
        readerMode: ReaderMode.paged,
        reduceMotion: true,
      ),
    );

    expect(merged.fontSize, 22);
    expect(merged.readerMode, ReaderMode.paged);
    expect(merged.reduceMotion, isTrue);
    expect(merged.lineHeight, defaults.lineHeight);
  });
}
