// POC stage 2: verify text selection and zoom work on top of the
// pdf_graphics -> Flutter Canvas path, with CJK text specifically.
//
// Exercises the selection API the reader would actually use:
//   textIn(rect)        - drag-select -> text
//   positionNear(x, y)  - tap         -> caret index
//   quadsFor(a, b)      - selection   -> highlight geometry
//   findAll(...)        - search      -> match geometry
// and renders the highlight through CanvasPdfDevice so the geometry is
// checked visually, not just numerically.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
// ignore: implementation_imports
import 'package:dart_pdf_editor/src/image_decoder.dart';
import 'package:flutter/material.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

const _outDir = 'build/poc_out';

const _page1Samples = [
  'samples/chinese.pdf',
  'samples/chinese-embedded.pdf',
  'samples/vector.pdf',
];

void main() => runApp(const PocApp());

class PocApp extends StatefulWidget {
  const PocApp({super.key});

  @override
  State<PocApp> createState() => _PocAppState();
}

class _PocAppState extends State<PocApp> {
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    Directory(_outDir).createSync(recursive: true);
    try {
      for (final p in _page1Samples) {
        try {
          final out = await renderFirstPages(p, _outDir);
          _log.add('RENDER $p -> ${out.length} PNG');
        } catch (e) {
          _log.add('RENDER $p -> ERR $e');
        }
      }
      final report = await runSelectionAndZoomPoc(
        'samples/chinese-embedded.pdf',
        outDir: _outDir,
        log: (m) {
          _log.add(m);
        },
      );
      _log
        ..add('')
        ..add(report);
    } catch (e, s) {
      _log.add('FATAL $e');
      debugPrint('$s');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pdf selection POC',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Selection + Zoom POC (CJK)')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(children: _log.map(Text.new).toList()),
        ),
      ),
    );
  }
}

/// Renders up to [maxPages] pages of [pdfPath] to PNG.
Future<List<String>> renderFirstPages(
  String pdfPath,
  String outDir, {
  int maxPages = 2,
}) async {
  final file = File(pdfPath);
  if (!file.existsSync()) throw StateError('missing: $pdfPath');
  final doc = PdfDocument.open(await file.readAsBytes());
  final out = <String>[];
  for (var i = 0; i < math.min(doc.pageCount, maxPages); i++) {
    final page = doc.page(i);
    final box = page.cropBox;
    final png = await _renderPage(
      doc: doc,
      cos: doc.cos,
      page: page,
      box: box,
      scale: 1.5,
      highlights: const [],
      outPath: '$outDir/${_stem(pdfPath)}-r${i + 1}.png',
    );
    out.add(png);
  }
  return out;
}

String _stem(String p) => p.split('/').last.replaceAll('.pdf', '');

/// Exercises selection + zoom on [pdfPath] and writes annotated PNGs.
Future<String> runSelectionAndZoomPoc(
  String pdfPath, {
  required String outDir,
  required void Function(String) log,
}) async {
  final file = File(pdfPath);
  if (!file.existsSync()) throw StateError('missing: $pdfPath');

  final doc = PdfDocument.open(await file.readAsBytes());
  final cos = doc.cos;
  final page = doc.page(0);
  final box = page.cropBox;

  final text = PdfTextExtractor.extract(doc, 0);
  log('page0 text: ${text.text.length} chars');
  log('  head: "${_head(text.text, 70)}"');

  // --- 1. Drag-select across the title band. ---
  final band = PdfRect(
    box.left + 40,
    box.top - 110,
    box.left + 420,
    box.top - 30,
  );
  final bandText = text.textIn(band);
  log('');
  log('[1] textIn(title band) -> ${bandText.length} chars');
  log('    "$bandText"');

  // --- 2. Tap-to-position. ---
  final caret = text.positionNear(box.left + 200, box.top - 300);
  log('');
  log('[2] positionNear -> caret index $caret');
  log('    around: "${_around(text.text, caret)}"');

  // --- 3. Quads for a CJK substring + visual highlight. ---
  const needle = '中文';
  final start = text.text.indexOf(needle);
  final List<PdfTextQuad> hlQuads;
  if (start < 0) {
    hlQuads = const [];
    log('');
    log('[3] FAIL: "$needle" not found in extracted text');
  } else {
    hlQuads = text.quadsFor(start, start + needle.length);
    final rects = text.rectsFor(start, start + needle.length);
    log('');
    log(
      '[3] quadsFor("$needle" @$start) -> ${hlQuads.length} quads, ${rects.length} rects',
    );
    for (final q in hlQuads.take(3)) {
      final c = q.corners
          .map((p) => '(${p.$1.toStringAsFixed(1)},${p.$2.toStringAsFixed(1)})')
          .join(' ');
      log('    corners $c rtl=${q.isRightToLeft}');
    }
    final inPage = hlQuads.every(
      (q) => q.bounds.top <= box.top + 1 && q.bounds.bottom >= box.bottom - 1,
    );
    log('    quads inside page bounds: $inPage');
  }

  // --- 4. Search. ---
  final matches = text.findAll('渲染');
  log('');
  log('[4] findAll("渲染") -> ${matches.length} matches');
  for (final m in matches.take(3)) {
    log(
      '    ${m.start}..${m.end} rects=${m.rects.length} '
      'text="${text.text.substring(m.start, m.end)}"',
    );
  }

  // --- 5. Zoom levels, with highlights drawn in page space. ---
  log('');
  final out = <String>[];
  for (final zoom in [1.0, 2.0, 3.0]) {
    final sw = Stopwatch()..start();
    final png = await _renderPage(
      doc: doc,
      cos: cos,
      page: page,
      box: box,
      scale: zoom,
      highlights: hlQuads,
      outPath: '$outDir/chinese-zoom${zoom.toStringAsFixed(0)}.png',
    );
    sw.stop();
    log(
      '[5] ${zoom.toStringAsFixed(1)}x -> ${png.split('/').last}  ${sw.elapsedMilliseconds}ms',
    );
    out.add(png);
  }
  return 'wrote ${out.length} PNGs to $outDir';
}

/// Renders one page at [scale], overlaying [highlights] in page space.
Future<String> _renderPage({
  required PdfDocument doc,
  required CosDocument cos,
  required PdfPage page,
  required PdfRect box,
  required double scale,
  required List<PdfTextQuad> highlights,
  required String outPath,
}) async {
  final w = (box.width * scale).round();
  final h = (box.height * scale).round();

  // Pass 1: scan-only walk to collect and decode every image.
  final collector = ImageCollector();
  PdfInterpreter(
    cos: cos,
    device: collector,
    scanImagesOnly: true,
  ).drawPage(page);
  final images = await decodeImages(cos, collector.streams);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = Colors.white,
  );

  canvas.save();
  canvas.scale(scale, scale);
  canvas.translate(0, box.height);
  canvas.scale(1, -1);
  canvas.translate(-box.left, -box.bottom);

  for (final q in highlights) {
    final b = q.bounds;
    canvas.drawRect(
      Rect.fromLTRB(b.left, b.bottom, b.right, b.top),
      Paint()..color = const Color(0x553F8CFF),
    );
  }

  PdfInterpreter(
    cos: cos,
    device: CanvasPdfDevice(canvas, images: images),
  ).drawPage(page);
  canvas.restore();

  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
  for (final img in images.values) {
    img.dispose();
  }
  return outPath;
}

String _head(String s, int n) => s.length <= n ? s : s.substring(0, n);

String _around(String s, int i, {int span = 14}) {
  if (s.isEmpty) return '';
  final a = math.max(0, i - span ~/ 2);
  final b = math.min(s.length, a + span);
  return s.substring(a, b);
}
