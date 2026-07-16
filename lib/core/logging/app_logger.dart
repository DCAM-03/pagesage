import 'package:logger/logger.dart';

import 'privacy_sanitizer.dart';

final class AppLogger {
  AppLogger({Logger? logger, this._sanitizer = const PrivacySanitizer()})
    : _logger = logger ?? Logger();

  final Logger _logger;
  final PrivacySanitizer _sanitizer;

  void info(Object? message) {
    _logger.i(_sanitizer.sanitize(message));
  }

  void warning(Object? message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(
      _sanitizer.sanitize(message),
      error: _sanitizer.sanitize(error),
      stackTrace: stackTrace,
    );
  }

  void error(Object? message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(
      _sanitizer.sanitize(message),
      error: _sanitizer.sanitize(error),
      stackTrace: stackTrace,
    );
  }
}
