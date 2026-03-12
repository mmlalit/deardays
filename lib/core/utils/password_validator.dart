/// Shared password validation for login, signup, and password change flows.
class PasswordValidator {
  PasswordValidator._();

  static const int minLength = 8;

  /// Validates [password] and returns an error message, or `null` if valid.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    return null;
  }

  /// Human-readable hint for the password requirements.
  static const String hint = 'Min $minLength chars, 1 uppercase, 1 number';
}
