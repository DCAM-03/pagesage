import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/ocr/method_channel_ocr_engine.dart';
import 'package:pagesage/core/ocr/method_channel_pdf_page_rasterizer.dart';
import 'package:pagesage/domain/ocr/ocr_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/pagesage/ocr');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('native engine preserves reported language and line geometry', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'supportedLanguages') return ['zh-Hans', 'en-US'];
      if (call.method == 'isAvailable') return true;
      return {
        'text': '一行文字',
        'engine': 'winrt',
        'language': 'zh-Hans',
        'imageWidth': 1600,
        'imageHeight': 2200,
        'blocks': [
          {
            'text': '一行文字',
            'left': 0.1,
            'top': 0.2,
            'width': 0.6,
            'height': 0.03,
          },
        ],
      };
    });
    final engine = MethodChannelOcrEngine(channel: channel, id: 'winrt');
    expect(await engine.isAvailable(), isTrue);
    expect(await engine.supportedLanguages(), ['zh-Hans', 'en-US']);
    final result = await engine.recognize(
      imageBytes: Uint8List(4),
      languageHint: 'zh',
    );
    expect(result.language, 'zh-Hans');
    expect(result.blocks.single.left, 0.1);
    expect(result.blocks.single.height, 0.03);
    expect(result.imageHeight, 2200);
  });

  test(
    'missing Windows language is actionable instead of silent fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'ocr_language_unavailable');
      });
      await expectLater(
        MethodChannelOcrEngine(
          channel: channel,
          id: 'winrt',
        ).recognize(imageBytes: Uint8List(4), languageHint: 'zh-Hans'),
        throwsA(
          isA<OcrUnavailableException>().having(
            (error) => error.message,
            'message',
            contains('语言包'),
          ),
        ),
      );
    },
  );

  test(
    'native raster receives the pixel budget and returns image size',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'renderPage');
        expect(call.arguments['maxPixels'], 1000000);
        expect(call.arguments['maxEdge'], 1200);
        return {
          'bytes': Uint8List.fromList([1, 2, 3]),
          'width': 800,
          'height': 1200,
        };
      });
      final image = await MethodChannelPdfPageRasterizer(channel: channel)
          .renderPage(
            filePath: 'fixture.pdf',
            pageNumber: 2,
            maxEdge: 1200,
            maxPixels: 1000000,
          );
      expect(image.width, 800);
      expect(image.height, 1200);
      expect(image.pageNumber, 2);
    },
  );
}
