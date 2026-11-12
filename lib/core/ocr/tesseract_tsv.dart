import 'dart:convert';
import 'dart:math' as math;

import '../../domain/ocr/ocr_models.dart';

const tesseractTsvHeader =
    'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext';

OcrPageResult parseTesseractTsv(
  String tsv, {
  required int imageWidth,
  required int imageHeight,
  required String language,
  required String engine,
}) {
  const invalid = OcrFailedException(
    '识别输出格式或坐标无效，请检查 Tesseract 的 TSV 输出配置',
    code: 'ocr_output_invalid',
  );
  if (imageWidth <= 0 || imageHeight <= 0) throw invalid;
  final rows = LineSplitter.split(tsv).iterator;
  if (!rows.moveNext() || rows.current != tesseractTsvHeader) throw invalid;
  final words = <_TesseractWord>[];
  var pageRows = 0;
  final seen = <String>{};
  var rowCount = 0;
  while (rows.moveNext()) {
    rowCount += 1;
    if (rowCount > 100000) {
      throw const OcrFailedException(
        '识别输出行数超出限制',
        code: 'ocr_output_too_large',
      );
    }
    final row = rows.current;
    if (row.isEmpty) continue;
    final fields = <String>[];
    var start = 0;
    for (var column = 0; column < 11; column += 1) {
      final end = row.indexOf('\t', start);
      if (end < 0) throw invalid;
      fields.add(row.substring(start, end));
      start = end + 1;
    }
    final integers = fields.take(10).map(int.tryParse).toList();
    if (integers.any((value) => value == null || value < 0)) throw invalid;
    final values = integers.cast<int>();
    final level = values[0];
    final page = values[1];
    final left = values[6];
    final top = values[7];
    final width = values[8];
    final height = values[9];
    final confidence = double.tryParse(fields[10]);
    if (level < 1 ||
        level > 5 ||
        page != 1 ||
        confidence == null ||
        !confidence.isFinite ||
        (confidence < 0 && confidence != -1) ||
        confidence > 100 ||
        left + width > imageWidth ||
        top + height > imageHeight) {
      throw invalid;
    }
    if (level == 1) {
      pageRows += 1;
      if (pageRows != 1 ||
          left != 0 ||
          top != 0 ||
          width != imageWidth ||
          height != imageHeight) {
        throw invalid;
      }
    }
    if (level != 5) continue;
    final text = row.substring(start).trim();
    if (text.isEmpty) continue;
    if (width == 0 || height == 0 || values.sublist(2, 6).contains(0)) {
      throw invalid;
    }
    final order = values.sublist(2, 6);
    if (!seen.add(order.join(':'))) throw invalid;
    words.add(
      _TesseractWord(
        order: order,
        text: text,
        left: left,
        top: top,
        width: width,
        height: height,
        confidence: confidence == -1 ? null : confidence / 100,
      ),
    );
    if (words.length > 20000) {
      throw const OcrFailedException(
        '识别文字数量超出单页限制',
        code: 'ocr_output_too_large',
      );
    }
  }
  if (pageRows != 1) throw invalid;
  words.sort((first, second) {
    for (var index = 0; index < 4; index += 1) {
      final comparison = first.order[index].compareTo(second.order[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  });

  final text = StringBuffer();
  final blocks = <OcrTextBlock>[];
  var weightedConfidence = 0.0;
  var confidenceCharacters = 0;
  var lineStart = 0;
  while (lineStart < words.length) {
    final first = words[lineStart];
    var lineEnd = lineStart + 1;
    while (lineEnd < words.length && first.sameLine(words[lineEnd])) {
      lineEnd += 1;
    }
    final lineText = StringBuffer();
    var left = first.left;
    var top = first.top;
    var right = first.left + first.width;
    var bottom = first.top + first.height;
    String? previous;
    for (var index = lineStart; index < lineEnd; index += 1) {
      final word = words[index];
      if (previous != null && _needsSpace(previous, word.text)) {
        lineText.write(' ');
      }
      lineText.write(word.text);
      previous = word.text;
      left = math.min(left, word.left);
      top = math.min(top, word.top);
      right = math.max(right, word.left + word.width);
      bottom = math.max(bottom, word.top + word.height);
      final confidence = word.confidence;
      if (confidence != null) {
        final characters = word.text.runes.length;
        weightedConfidence += confidence * characters;
        confidenceCharacters += characters;
      }
    }
    if (lineStart > 0) {
      final previous = words[lineStart - 1];
      text.write(previous.sameParagraph(first) ? '\n' : '\n\n');
    }
    final line = lineText.toString();
    text.write(line);
    blocks.add(
      OcrTextBlock(
        text: line,
        left: left / imageWidth,
        top: top / imageHeight,
        width: (right - left) / imageWidth,
        height: (bottom - top) / imageHeight,
      ),
    );
    lineStart = lineEnd;
  }
  final resultText = text.toString();
  if (utf8.encode(resultText).length > 1024 * 1024) {
    throw const OcrFailedException(
      '识别文字超出单页大小限制',
      code: 'ocr_output_too_large',
    );
  }
  return OcrPageResult(
    text: resultText,
    language: language,
    engine: engine,
    confidence: confidenceCharacters == 0
        ? null
        : weightedConfidence / confidenceCharacters,
    blocks: List.unmodifiable(blocks),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

bool _needsSpace(String previous, String next) {
  final last = previous.runes.last;
  final first = next.runes.first;
  const closing = ',.!?;:%)]}，。！？；：、）】》〉」』”’％';
  const opening = '([{（【《〈「『“‘';
  if (closing.contains(String.fromCharCode(first)) ||
      opening.contains(String.fromCharCode(last))) {
    return false;
  }
  return !(_isCjk(last) && _isCjk(first));
}

bool _isCjk(int rune) =>
    (rune >= 0x2e80 && rune <= 0x9fff) ||
    (rune >= 0xac00 && rune <= 0xd7af) ||
    (rune >= 0xf900 && rune <= 0xfaff) ||
    (rune >= 0xff00 && rune <= 0xffef) ||
    (rune >= 0x20000 && rune <= 0x323af);

final class _TesseractWord {
  const _TesseractWord({
    required this.order,
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
  });

  final List<int> order;
  final String text;
  final int left;
  final int top;
  final int width;
  final int height;
  final double? confidence;

  bool sameParagraph(_TesseractWord other) =>
      order[0] == other.order[0] && order[1] == other.order[1];

  bool sameLine(_TesseractWord other) =>
      sameParagraph(other) && order[2] == other.order[2];
}
