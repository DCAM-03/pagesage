import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/books/book.dart';

final class UnsupportedBookFormatException implements Exception {
  const UnsupportedBookFormatException(this.extension);

  final String extension;

  @override
  String toString() => 'Unsupported book format: $extension';
}

final class FormatDetector {
  Future<BookFormat> detect(File file, {String? mimeType}) async {
    final extension = p
        .extension(file.path)
        .toLowerCase()
        .replaceFirst('.', '');
    if (extension == BookFormat.epub.value &&
        _mimeMatches(BookFormat.epub, mimeType) &&
        await _hasZipHeader(file)) {
      return BookFormat.epub;
    }

    if (extension == BookFormat.pdf.value &&
        _mimeMatches(BookFormat.pdf, mimeType) &&
        await _hasPdfHeader(file)) {
      return BookFormat.pdf;
    }

    throw UnsupportedBookFormatException(
      extension.isEmpty ? 'unknown' : extension,
    );
  }

  bool _mimeMatches(BookFormat format, String? mimeType) {
    final normalized = mimeType?.toLowerCase().trim();
    if (normalized == null || normalized.isEmpty) {
      return true;
    }
    return switch (format) {
      BookFormat.epub => normalized == 'application/epub+zip',
      BookFormat.pdf =>
        normalized == 'application/pdf' || normalized == 'application/x-pdf',
    };
  }

  Future<bool> _hasPdfHeader(File file) async {
    final bytes = await _readHeader(file, 5);
    return bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2d;
  }

  Future<bool> _hasZipHeader(File file) async {
    final bytes = await _readHeader(file, 4);
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        ((bytes[2] == 0x03 && bytes[3] == 0x04) ||
            (bytes[2] == 0x05 && bytes[3] == 0x06) ||
            (bytes[2] == 0x07 && bytes[3] == 0x08));
  }

  Future<List<int>> _readHeader(File file, int length) async {
    if (!await file.exists()) {
      return const [];
    }
    return file
        .openRead(0, length)
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
  }
}
