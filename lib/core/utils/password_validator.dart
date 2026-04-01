/// Shared password validation for login, signup, and password change flows.
class PasswordValidator {
  PasswordValidator._();

  static const int minLength = 8;

  /// Common passwords that are trivially guessable.
  static const _commonPasswords = {
    'password', 'password1', 'password123', 'qwerty', 'qwerty123',
    'welcome', 'welcome1', 'letmein', 'admin', 'login',
    'abc123', 'monkey', 'master', 'dragon', 'trustno1',
    '1234567890', 'sunshine', 'princess', 'football', 'shadow',
    'iloveyou', 'charlie', 'superman', 'michael', 'ashley',
  };

  /// Validates [password] and returns an error message, or `null` if valid.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\[\]\\\/~`]'))) {
      return 'Password must contain at least one special character.';
    }
    // Check against common passwords (case-insensitive, ignoring trailing
    // special chars and digits so "Password123!" still matches "password").
    final stripped = password.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    if (_commonPasswords.contains(stripped) ||
        _commonPasswords.contains(password.toLowerCase())) {
      return 'This is a common password. Please choose something more unique.';
    }
    return null;
  }

  /// Human-readable hint for the password requirements.
  static const String hint =
      'Min $minLength chars, uppercase, lowercase, number, special character';
}
