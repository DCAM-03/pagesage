// Generates the two PDF samples the POC still lacks:
//
//   chinese-embedded.pdf - a real embedded CJK font (exercises the glyph
//     outline path in CanvasPdfDevice, not the system-font fallback).
//   vector.pdf           - paths, bezier curves, gradients and strokes
//     (exercises fillPath / fillPathGradient / strokePath).
//
// LibreOffice cannot be used for either: its HTML import drops font-family
// declarations entirely, so Chinese text falls back to a non-embedded Latin
// font, and inline SVG never reaches the PDF at all.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final home = Platform.environment['HOME'];
  final configuredFont = Platform.environment['PAGESAGE_CJK_FONT'];
  final cjkCandidates = [
    if (configuredFont != null && configuredFont.isNotEmpty) configuredFont,
    File.fromUri(
      Platform.script.resolve('../../assets/fonts/LXGWWenKaiLite-Regular.ttf'),
    ).path,
    if (home != null && home.isNotEmpty) ...[
      '$home/.local/share/fonts/SarasaMonoSC/SarasaMonoSC-Regular.ttf',
      '$home/.local/share/fonts/MapleMono-CN/MapleMono-CN-Regular.ttf',
    ],
    '/usr/share/fonts/google-noto-cjk-vf-fonts/NotoSansCJK-VF.ttc',
  ];
  final fontPath = cjkCandidates.firstWhere(
    (candidate) => File(candidate).existsSync(),
    orElse: () => '',
  );
  if (fontPath.isEmpty) {
    stderr.writeln(
      'no CJK font found; tried:\n  ${cjkCandidates.join('\n  ')}',
    );
    exit(1);
  }
  stdout.writeln('using CJK font: $fontPath');

  await _buildEmbeddedCjk(fontPath);
  await _buildVector();
}

Future<void> _buildEmbeddedCjk(String fontPath) async {
  final bytes = File(fontPath).readAsBytesSync();
  final font = pw.Font.ttf(ByteData.sublistView(bytes));

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => [
        pw.Text('嵌入字体渲染测试', style: pw.TextStyle(font: font, fontSize: 28)),
        pw.SizedBox(height: 18),
        pw.Text(
          '本页使用真正嵌入的 CJK 字体，验证 pdf_graphics 的字形轮廓渲染路径。',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.SizedBox(height: 16),
        pw.Text('一、生僻字', style: pw.TextStyle(font: font, fontSize: 18)),
        pw.Text(
          '永东国 Wolf、鼠、龖、靐、齾、爩 —— 四叠字与罕见字',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.SizedBox(height: 14),
        pw.Text('二、中英混排', style: pw.TextStyle(font: font, fontSize: 18)),
        pw.Text(
          'PageSage 阅读器 test 123 ABC xyz mixed script 混排测试。',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.SizedBox(height: 14),
        pw.Text('三、标点符号', style: pw.TextStyle(font: font, fontSize: 18)),
        pw.Text(
          '，。！？；：、（）【】《》「」『』—…·',
          style: pw.TextStyle(font: font, fontSize: 14),
        ),
        pw.SizedBox(height: 14),
        // A second page so page-count and paging are exercised too.
        pw.Text(
          '第二页 — 用于验证多页文档',
          style: pw.TextStyle(font: font, fontSize: 18),
        ),
      ],
    ),
  );

  final out = File('samples/chinese-embedded.pdf');
  out.writeAsBytesSync(await doc.save());
  stdout.writeln('wrote ${out.path} (${out.lengthSync()} bytes)');
}

Future<void> _buildVector() async {
  final doc = pw.Document();
  final page = pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (context) => pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Vector graphics', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 16),
          pw.Container(
            height: 340,
            width: 480,
            color: PdfColors.grey200,
            child: _shapes(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Below: gradient, curves, strokes of varying width.'),
          pw.SizedBox(height: 10),
          pw.Container(height: 220, width: 480, child: _curves()),
        ],
      ),
    ),
  );
  doc.addPage(page);

  final out = File('samples/vector.pdf');
  out.writeAsBytesSync(await doc.save());
  stdout.writeln('wrote ${out.path} (${out.lengthSync()} bytes)');
}

/// Axis-aligned rectangles and a circle-ish shape, to fill.
pw.Widget _shapes() => pw.Stack(
  children: [
    pw.Positioned(
      left: 20,
      top: 20,
      child: pw.Container(width: 120, height: 90, color: PdfColors.blue600),
    ),
    pw.Positioned(
      left: 170,
      top: 20,
      child: pw.Container(
        width: 120,
        height: 90,
        decoration: const pw.BoxDecoration(
          color: PdfColors.orange600,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(24)),
        ),
      ),
    ),
    pw.Positioned(
      left: 320,
      top: 20,
      child: pw.Container(
        width: 120,
        height: 90,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [PdfColors.green600, PdfColors.green900],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
        ),
      ),
    ),
    pw.Container(
      margin: const pw.EdgeInsets.only(left: 20, top: 140),
      width: 420,
      height: 20,
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.pink600, PdfColors.purple600, PdfColors.cyan600],
        ),
      ),
    ),
    pw.Container(
      margin: const pw.EdgeInsets.only(left: 20, top: 180),
      width: 420,
      height: 60,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 3),
        color: PdfColors.white,
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          '3pt stroke border',
          style: const pw.TextStyle(fontSize: 12),
        ),
      ),
    ),
  ],
);

/// Free-form bezier artwork, to exercise curve flattening.
pw.Widget _curves() => pw.CustomPaint(
  size: const PdfPoint(480, 200),
  painter: (c, s) {
    c
      ..setStrokeColor(PdfColors.blueGrey900)
      ..setLineWidth(3)
      ..moveTo(10, 150)
      ..curveTo(90, 10, 170, 190, 250, 60)
      ..curveTo(330, -10, 400, 120, 470, 40)
      ..strokePath()
      ..setStrokeColor(PdfColors.deepOrange)
      ..setLineWidth(1.5)
      ..moveTo(10, 185)
      ..lineTo(470, 185)
      ..strokePath()
      ..setFillColor(PdfColors.teal600)
      // y-up: apex needs the LARGER y. Swapped from the first attempt,
      // which pointed down and confirmed the renderer was right all along.
      ..moveTo(120, 120)
      ..lineTo(160, 195)
      ..lineTo(200, 120)
      ..closePath()
      ..fillPath();
  },
);
