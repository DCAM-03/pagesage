import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/ocr/ocr_models.dart';

const ocrTextPipelineVersion = 'ocr-text-v1';
const ocrRenderVersion = 'pdf-display-v1';

/// Builds the durable cache key for one recognized page.
///
/// Every input that can change the text or its geometry is included. The
/// fields are length-prefixed so values containing separators cannot collide.
String buildOcrCacheSignature({
  required String sourceRevision,
  required OcrCacheIdentity identity,
  required int dpi,
  required int maxEdge,
  int maxPixels = 5000000,
  String psm = '3',
  String oem = '1',
  String renderVersion = ocrRenderVersion,
  String pipelineVersion = ocrTextPipelineVersion,
}) {
  final fields = <String>[
    sourceRevision,
    identity.engineId,
    identity.engineVersion ?? '',
    identity.resolvedLanguage,
    '$dpi',
    '$maxEdge',
    '$maxPixels',
    psm,
    oem,
    renderVersion,
    pipelineVersion,
  ];
  return sha256
      .convert(
        utf8.encode(fields.map((value) => '${value.length}:$value').join('|')),
      )
      .toString();
}

/// Revision of a recognized body plus the conversion rules that produced it.
String buildOcrTextRevision({
  required String sourceRevision,
  required String text,
  String pipelineVersion = ocrTextPipelineVersion,
}) {
  return sha256
      .convert(
        utf8.encode(
          [
            sourceRevision,
            pipelineVersion,
            text,
          ].map((value) => '${value.length}:$value').join('|'),
        ),
      )
      .toString();
}
