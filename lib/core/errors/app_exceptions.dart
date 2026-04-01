/// Base exception class for DearDays application errors.
///
/// All domain-specific exceptions should extend this class so UI layers
/// can catch `AppException` as a single type for user-facing error messages.
///
/// Repositories should throw these instead of raw `Exception('...')`.
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppException($code): $message';
}

/// Thrown when the user is not authenticated (null userId).
class AuthRequiredException extends AppException {
  const AuthRequiredException()
      : super('Authentication required. Please sign in.');
}

/// Thrown when a network request fails and no cached data is available.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error. Please try again.']);
}

/// Thrown when a requested resource is not found.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Not found.']);
}

/// Thrown when the user exceeds a rate or usage limit.
class LimitExceededException extends AppException {
  const LimitExceededException(super.message);
}
