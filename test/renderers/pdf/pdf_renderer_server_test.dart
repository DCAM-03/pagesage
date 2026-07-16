import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/renderers/pdf/pdf_renderer_server.dart';

void main() {
  test(
    'serves PDF bytes with range support and reports missing files',
    () async {
      final dir = await Directory.systemTemp.createTemp('pagesage_pdf_server_');
      addTearDown(() => dir.delete(recursive: true));

      final pdf = File('${dir.path}/sample.pdf');
      await pdf.writeAsBytes([37, 80, 68, 70, 45, 49, 46, 52, 10]);
      final server = await PdfRendererServer.start(bookPath: pdf.path);
      addTearDown(server.close);

      final full = await _get(server.bookUrl);
      expect(full.statusCode, HttpStatus.ok);
      expect(
        full.headers.value(HttpHeaders.contentTypeHeader),
        'application/pdf',
      );
      expect(full.bodyBytes, await pdf.readAsBytes());
      expect(full.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');

      final partial = await _get(
        server.bookUrl,
        headers: {HttpHeaders.rangeHeader: 'bytes=0-3'},
      );
      expect(partial.statusCode, HttpStatus.partialContent);
      expect(partial.bodyBytes, [37, 80, 68, 70]);
      expect(
        partial.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 0-3/9',
      );

      final invalidRange = await _get(
        server.bookUrl,
        headers: {HttpHeaders.rangeHeader: 'bytes=99-120'},
      );
      expect(invalidRange.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(
        invalidRange.headers.value(HttpHeaders.contentRangeHeader),
        'bytes */9',
      );

      await pdf.delete();
      final missing = await _get(server.bookUrl);
      expect(missing.statusCode, HttpStatus.notFound);
      expect(utf8.decode(missing.bodyBytes), contains('PDF file not found'));
    },
  );
}

Future<_HttpResult> _get(String url, {Map<String, String>? headers}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    headers?.forEach(request.headers.set);
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
    return _HttpResult(
      statusCode: response.statusCode,
      headers: response.headers,
      bodyBytes: bytes,
    );
  } finally {
    client.close(force: true);
  }
}

final class _HttpResult {
  const _HttpResult({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
  });

  final int statusCode;
  final HttpHeaders headers;
  final List<int> bodyBytes;
}
