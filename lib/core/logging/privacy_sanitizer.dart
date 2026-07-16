final class PrivacySanitizer {
  const PrivacySanitizer();

  String sanitize(Object? value, {int maxLength = 800}) {
    if (value == null) {
      return '';
    }
    var text = value.toString();
    text = text.replaceAll(
      RegExp(
        r'(sk-[A-Za-z0-9_\-]{8,}|Bearer\s+[A-Za-z0-9._\-]+)',
        caseSensitive: false,
      ),
      '[已隐藏密钥]',
    );
    text = text.replaceAll(
      RegExp(
        r'(api[_-]?key|authorization)\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      ),
      r'$1=[已隐藏密钥]',
    );
    text = text.replaceAll(RegExp(r'[A-Za-z]:\\[^\s,;]+'), '[本地路径]');
    text = text.replaceAll(RegExp(r'/[^\s,;]+(?:/[^\s,;]+)+'), '[本地路径]');
    text = text.replaceAll(
      RegExp(
        r'(上下文|contextText|sourceText|selectedText)\s*[:：=]\s*[\s\S]+',
        caseSensitive: false,
      ),
      r'$1=[已隐藏正文]',
    );
    if (text.length > maxLength) {
      return '${text.substring(0, maxLength)}...';
    }
    return text;
  }
}
