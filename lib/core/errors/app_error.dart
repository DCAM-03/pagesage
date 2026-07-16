sealed class AppError implements Exception {
  const AppError(this.message, {this.recoveryAction});

  final String message;
  final String? recoveryAction;

  @override
  String toString() => message;
}

final class DataError extends AppError {
  const DataError(super.message, {super.recoveryAction});
}

final class FileImportError extends AppError {
  const FileImportError(super.message, {super.recoveryAction});
}

final class RendererError extends AppError {
  const RendererError(super.message, {super.recoveryAction});
}
