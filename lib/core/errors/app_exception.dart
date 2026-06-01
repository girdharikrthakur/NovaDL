sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.recoverable = true});

  final String message;
  final Object? cause;
  final bool recoverable;

  @override
  String toString() => '$runtimeType: $message';
}

final class DownloadException extends AppException {
  const DownloadException(super.message, {super.cause, super.recoverable});
}

final class DependencyException extends AppException {
  const DependencyException(super.message, {super.cause, super.recoverable});
}

final class SecurityException extends AppException {
  const SecurityException(super.message, {super.cause, super.recoverable});
}

final class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause, super.recoverable});
}
