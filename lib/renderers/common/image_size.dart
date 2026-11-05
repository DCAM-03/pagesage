import 'dart:typed_data';

/// Reads the size of an image from its bytes.
///
/// Only the header is read: the formats a book can carry are PNG, JPEG,
/// GIF and WebP, and each of them states its size in its first few bytes.
({int width, int height})? readImageSize(Uint8List bytes) {
  if (bytes.length < 16) {
    return null;
  }
  // PNG: 8-byte signature, then a 4-byte length, "IHDR", then width and
  // height as two big-endian 32-bit numbers.
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    final width = _uint32(bytes, 16);
    final height = _uint32(bytes, 20);
    if (width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }
  // JPEG: walk the marker segments to the start-of-frame.
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var index = 2;
    while (index + 9 < bytes.length) {
      if (bytes[index] != 0xFF) {
        index++;
        continue;
      }
      final marker = bytes[index + 1];
      // Standalone markers carry no length.
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        index += 2;
        continue;
      }
      final length = (bytes[index + 2] << 8) | bytes[index + 3];
      final isStartOfFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isStartOfFrame) {
        final height = (bytes[index + 5] << 8) | bytes[index + 6];
        final width = (bytes[index + 7] << 8) | bytes[index + 8];
        if (width <= 0 || height <= 0) {
          return null;
        }
        return (width: width, height: height);
      }
      if (length < 2) {
        return null;
      }
      index += 2 + length;
    }
    return null;
  }
  // GIF: "GIF87a"/"GIF89a", then width and height as little-endian 16-bit.
  if (bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    final width = bytes[6] | (bytes[7] << 8);
    final height = bytes[8] | (bytes[9] << 8);
    if (width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }
  // WebP: "RIFF"...."WEBP", then a chunk that carries the dimensions.
  if (bytes.length >= 30 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    final chunk = String.fromCharCodes([
      bytes[12],
      bytes[13],
      bytes[14],
      bytes[15],
    ]);
    if (chunk == 'VP8X') {
      final width = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
      final height = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
      return (width: width, height: height);
    }
    if (chunk == 'VP8 ') {
      final width = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
      final height = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
      if (width > 0 && height > 0) {
        return (width: width, height: height);
      }
    }
    if (chunk == 'VP8L') {
      final bits =
          bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
      final width = (bits & 0x3FFF) + 1;
      final height = ((bits >> 14) & 0x3FFF) + 1;
      return (width: width, height: height);
    }
  }
  return null;
}

int _uint32(Uint8List bytes, int offset) {
  if (offset + 3 >= bytes.length) {
    return 0;
  }
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
