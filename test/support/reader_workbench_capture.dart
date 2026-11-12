import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';

const captureWorkbench = bool.fromEnvironment('CAPTURE_READER_WORKBENCH');
const workbenchCaptureKey = ValueKey('workbench-capture');

Future<void> loadWorkbenchCaptureFonts() async {
  final cjk = File(
    '/usr/share/fonts/google-noto-sans-cjk-vf-fonts/NotoSansCJK-VF.ttc',
  );
  final uiFont = ByteData.sublistView(await cjk.readAsBytes());
  for (final family in ['Roboto', 'Segoe UI', 'Microsoft YaHei UI']) {
    await (FontLoader(family)..addFont(Future.value(uiFont))).load();
  }
  final artifacts = Directory(Platform.resolvedExecutable).parent.parent.parent;
  final icons = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes()))))
      .load();
  const katexFonts = <String, List<String>>{
    'KaTeX_Main': <String>['Regular', 'Italic', 'Bold', 'BoldItalic'],
    'KaTeX_Math': <String>['Italic', 'BoldItalic'],
    'KaTeX_AMS': <String>['Regular'],
    'KaTeX_Caligraphic': <String>['Regular', 'Bold'],
    'KaTeX_Fraktur': <String>['Regular', 'Bold'],
    'KaTeX_SansSerif': <String>['Regular', 'Bold', 'Italic'],
    'KaTeX_Script': <String>['Regular'],
    'KaTeX_Typewriter': <String>['Regular'],
    'KaTeX_Size1': <String>['Regular'],
    'KaTeX_Size2': <String>['Regular'],
    'KaTeX_Size3': <String>['Regular'],
    'KaTeX_Size4': <String>['Regular'],
  };
  for (final entry in katexFonts.entries) {
    final loader = FontLoader('packages/flutter_math_fork/${entry.key}');
    for (final style in entry.value) {
      loader.addFont(
        rootBundle.load(
          'packages/flutter_math_fork/lib/katex_fonts/fonts/'
          '${entry.key}-$style.ttf',
        ),
      );
    }
    await loader.load();
  }
}

Future<void> captureWorkbenchWidget(WidgetTester tester, String name) async {
  if (!captureWorkbench) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(workbenchCaptureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('截图编码失败');
      final file = File('build/workbench-captures/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
