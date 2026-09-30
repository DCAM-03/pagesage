import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

final class PdfRendererServer {
  PdfRendererServer._(this._server, this._bookPath)
    // Cache-bust per launch: WebView2 may serve a stale viewer.html otherwise,
    // which pins old ?v= asset URLs and silently runs outdated bridge code.
    : viewerUrl =
          'http://127.0.0.1:${_server.port}/viewer.html'
          '?t=${DateTime.now().millisecondsSinceEpoch}';

  final HttpServer _server;
  final String _bookPath;
  StreamSubscription<HttpRequest>? _subscription;

  String get origin => 'http://127.0.0.1:${_server.port}';
  final String viewerUrl;
  String get bookUrl => '$origin/book.pdf';

  static Future<PdfRendererServer> start({required String bookPath}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final rendererServer = PdfRendererServer._(server, bookPath);
    rendererServer._subscription = server.listen(rendererServer._handle);
    return rendererServer;
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    _setCommonHeaders(request.response);
    try {
      switch (request.uri.path) {
        case '/viewer.html':
          await _serveAsset(
            request,
            'assets/renderer/pdf/viewer.html',
            'text/html; charset=utf-8',
          );
        case '/viewer.css':
          await _serveAsset(
            request,
            'assets/renderer/pdf/viewer.css',
            'text/css; charset=utf-8',
          );
        case '/bridge.js':
          await _serveAsset(
            request,
            'assets/renderer/pdf/bridge.js',
            'application/javascript; charset=utf-8',
          );
        case '/pdf.min.js':
          await _serveAsset(
            request,
            'assets/renderer/pdf/pdf.min.js',
            'application/javascript; charset=utf-8',
          );
        case '/pdf.worker.min.js':
          await _serveAsset(
            request,
            'assets/renderer/pdf/pdf.worker.min.js',
            'application/javascript; charset=utf-8',
          );
        case '/book.pdf':
          await _servePdf(request);
        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('Not found');
          await request.response.close();
      }
    } catch (error) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(error.toString());
        await request.response.close();
      } catch (_) {
        // The response may already be partially sent.
      }
    }
  }

  Future<void> _serveAsset(
    HttpRequest request,
    String assetPath,
    String contentType,
  ) async {
    final data = await rootBundle.load(assetPath);
    request.response.headers.contentType = ContentType.parse(contentType);
    request.response.contentLength = data.lengthInBytes;
    request.response.add(data.buffer.asUint8List());
    await request.response.close();
  }

  Future<void> _servePdf(HttpRequest request) async {
    final file = File(_bookPath);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('PDF file not found');
      await request.response.close();
      return;
    }

    final length = await file.length();
    final range = request.headers.value(HttpHeaders.rangeHeader);
    request.response.headers.contentType = ContentType('application', 'pdf');
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    if (range == null || !range.startsWith('bytes=')) {
      request.response.contentLength = length;
      await request.response.addStream(file.openRead());
      await request.response.close();
      return;
    }

    final parsed = _parseRange(range, length);
    if (parsed == null) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */$length',
      );
      await request.response.close();
      return;
    }

    final (start, end) = parsed;
    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$length',
    );
    request.response.contentLength = end - start + 1;
    await request.response.addStream(file.openRead(start, end + 1));
    await request.response.close();
  }

  (int, int)? _parseRange(String value, int length) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(value);
    if (match == null || length <= 0) {
      return null;
    }

    final startText = match.group(1) ?? '';
    final endText = match.group(2) ?? '';
    if (startText.isEmpty && endText.isEmpty) {
      return null;
    }

    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) {
        return null;
      }
      final start = (length - suffixLength).clamp(0, length - 1);
      return (start, length - 1);
    }

    final start = int.tryParse(startText);
    final end = endText.isEmpty ? length - 1 : int.tryParse(endText);
    if (start == null || end == null || start >= length || end < start) {
      return null;
    }
    return (start, end.clamp(0, length - 1));
  }

  void _setCommonHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, OPTIONS',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Range, Content-Type',
    );
  }
}
