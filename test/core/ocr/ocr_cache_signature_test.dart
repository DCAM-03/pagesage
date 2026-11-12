import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/ocr_cache_signature.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';

void main() {
  const identity = OcrCacheIdentity(
    engineId: 'tesseract',
    engineVersion: '5.5.4',
    resolvedLanguage: 'chi_sim+eng',
  );

  test('signature changes with every recognition input', () {
    final base = buildOcrCacheSignature(
      sourceRevision: 'sha256-source',
      identity: identity,
      dpi: 200,
      maxEdge: 2200,
    );
    expect(
      base,
      buildOcrCacheSignature(
        sourceRevision: 'sha256-source',
        identity: identity,
        dpi: 200,
        maxEdge: 2200,
      ),
    );
    final variants = {
      buildOcrCacheSignature(
        sourceRevision: 'sha256-source-2',
        identity: identity,
        dpi: 200,
        maxEdge: 2200,
      ),
      buildOcrCacheSignature(
        sourceRevision: 'sha256-source',
        identity: const OcrCacheIdentity(
          engineId: 'tesseract',
          engineVersion: '5.5.5',
          resolvedLanguage: 'chi_sim+eng',
        ),
        dpi: 200,
        maxEdge: 2200,
      ),
      buildOcrCacheSignature(
        sourceRevision: 'sha256-source',
        identity: const OcrCacheIdentity(
          engineId: 'tesseract',
          engineVersion: '5.5.4',
          resolvedLanguage: 'eng+chi_sim',
        ),
        dpi: 200,
        maxEdge: 2200,
      ),
      buildOcrCacheSignature(
        sourceRevision: 'sha256-source',
        identity: identity,
        dpi: 300,
        maxEdge: 2200,
      ),
      buildOcrCacheSignature(
        sourceRevision: 'sha256-source',
        identity: identity,
        dpi: 200,
        maxEdge: 3300,
      ),
    };
    expect(variants, hasLength(5));
    expect(variants, isNot(contains(base)));
  });

  test('text revision changes with source, text, or pipeline', () {
    final base = buildOcrTextRevision(sourceRevision: 'source', text: '识别正文');
    expect(base, buildOcrTextRevision(sourceRevision: 'source', text: '识别正文'));
    expect(
      base,
      isNot(buildOcrTextRevision(sourceRevision: 'source-2', text: '识别正文')),
    );
    expect(
      base,
      isNot(buildOcrTextRevision(sourceRevision: 'source', text: '识别正文2')),
    );
    expect(
      base,
      isNot(
        buildOcrTextRevision(
          sourceRevision: 'source',
          text: '识别正文',
          pipelineVersion: 'ocr-text-v2',
        ),
      ),
    );
  });
}
