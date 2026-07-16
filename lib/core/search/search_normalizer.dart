final class SearchNormalizer {
  const SearchNormalizer();

  String normalize(String value) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final rune in value.runes) {
      final normalized = _normalizeRune(rune);
      if (_isWhitespace(normalized)) {
        pendingSpace = buffer.isNotEmpty;
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.writeCharCode(normalized);
    }
    return buffer.toString().trim().toLowerCase();
  }

  bool containsCjk(String value) {
    return value.runes.any(
      (rune) =>
          (rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0xF900 && rune <= 0xFAFF) ||
          (rune >= 0x3040 && rune <= 0x30FF) ||
          (rune >= 0xAC00 && rune <= 0xD7AF),
    );
  }

  int _normalizeRune(int rune) {
    if (rune == 0x3000) {
      return 0x20;
    }
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      return rune - 0xFEE0;
    }
    return rune;
  }

  bool _isWhitespace(int rune) {
    return rune == 0x20 ||
        rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D ||
        rune == 0x0C;
  }
}
