import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../tasks/task_cancellation.dart';

final class HashService {
  Future<String> sha256File(File file, {TaskCancelToken? cancelToken}) async {
    final output = _DigestSink();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      cancelToken?.throwIfCancelled();
      input.add(chunk);
    }
    cancelToken?.throwIfCancelled();
    input.close();
    return output.digest.toString();
  }

  String sha256Text(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get digest => _digest!;

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}
}
