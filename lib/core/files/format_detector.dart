import 'dart:convert';
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

    // Markdown has no magic number: the extension is the claim and the
    // content is the check. A readable, non-empty text file is a Markdown
    // document; a binary file that happens to be named `.md` is not.
    if ((extension == 'md' || extension == 'markdown') &&
        _mimeMatches(BookFormat.markdown, mimeType) &&
        await _looksLikeText(file)) {
      return BookFormat.markdown;
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
      BookFormat.markdown =>
        normalized == 'text/markdown' ||
            normalized == 'text/x-markdown' ||
            normalized == 'text/plain',
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

  /// Whether the file holds readable text.
  ///
  /// A book is something a person reads, so a NUL byte or an invalid UTF-8
  /// sequence in the first few kilobytes means this is not one, whatever its
  /// name says. An empty file is text too — it opens to an empty chapter
  /// instead of failing as an unknown format.
  Future<bool> _looksLikeText(File file) async {
    final bytes = await _readHeader(file, 4096);
    if (bytes.isEmpty) {
      return true;
    }
    for (final byte in bytes) {
      if (byte == 0x00) {
        return false;
      }
    }
    try {
      utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      // A multi-byte character can be cut by the 4096-byte window. Only the
      // end of the sample may be truncated, so retry without the tail.
      final trimmed = bytes.length > 4
          ? bytes.sublist(0, bytes.length - 4)
          : bytes;
      try {
        utf8.decode(trimmed, allowMalformed: false);
      } on FormatException {
        return false;
      }
    }
    return true;
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
