enum OcrCapabilityStatus {
  available,
  engineMissing,
  languageMissing,
  unsupportedVersion,
  probeFailed,
}

final class OcrCapability {
  OcrCapability({
    required this.status,
    required this.message,
    this.engineVersion,
    List<String> languages = const [],
  }) : languages = List.unmodifiable(languages);

  final OcrCapabilityStatus status;
  final String message;
  final String? engineVersion;
  final List<String> languages;

  bool get isAvailable => status == OcrCapabilityStatus.available;
}

abstract interface class OcrCapabilitySource {
  Future<OcrCapability> capability({bool refresh = false});
}
