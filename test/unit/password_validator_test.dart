library;

/// Tests for PasswordValidator.
///
/// Verifies:
/// - Minimum length enforcement
/// - Uppercase letter requirement
/// - Lowercase letter requirement
/// - Number requirement
/// - Special character requirement
/// - Common password rejection
/// - Valid passwords pass
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/utils/password_validator.dart';

void main() {
  group('PasswordValidator', () {
    group('length requirement', () {
      test('rejects empty password', () {
        expect(PasswordValidator.validate(''), isNotNull);
      });

      test('rejects password shorter than minimum', () {
        expect(PasswordValidator.validate('Ab1!xyz'), isNotNull);
        expect(PasswordValidator.validate('Ab1!xyz')!, contains('8'));
      });

      test('accepts password at minimum length', () {
        // 8 chars with upper + lower + number + special
        final result = PasswordValidator.validate('Abcdef1!');
        expect(result, isNull);
      });
    });

    group('uppercase requirement', () {
      test('rejects password without uppercase', () {
        final result = PasswordValidator.validate('abcdef1!xx');
        expect(result, isNotNull);
        expect(result!, contains('uppercase'));
      });
    });

    group('lowercase requirement', () {
      test('rejects password without lowercase', () {
        final result = PasswordValidator.validate('ABCDEF1!XX');
        expect(result, isNotNull);
        expect(result!, contains('lowercase'));
      });
    });

    group('number requirement', () {
      test('rejects password without number', () {
        final result = PasswordValidator.validate('Abcdefgh!');
        expect(result, isNotNull);
        expect(result!, contains('number'));
      });
    });

    group('special character requirement', () {
      test('rejects password without special character', () {
        final result = PasswordValidator.validate('Abcdefg1x');
        expect(result, isNotNull);
        expect(result!, contains('special'));
      });

      test('accepts various special characters', () {
        expect(PasswordValidator.validate('Abcdef1!'), isNull);
        expect(PasswordValidator.validate('Abcdef1@'), isNull);
        expect(PasswordValidator.validate('Abcdef1#'), isNull);
        expect(PasswordValidator.validate('Abcdef1\$'), isNull);
        expect(PasswordValidator.validate('Abcdef1%'), isNull);
      });
    });

    group('common password rejection', () {
      test('rejects Password123!', () {
        final result = PasswordValidator.validate('Password123!');
        expect(result, isNotNull);
        expect(result!, contains('common'));
      });

      test('rejects Qwerty123!', () {
        final result = PasswordValidator.validate('Qwerty123!');
        expect(result, isNotNull);
      });

      test('rejects Welcome1!', () {
        final result = PasswordValidator.validate('Welcome1!');
        expect(result, isNotNull);
      });
    });

    group('valid passwords', () {
      test('accepts strong password', () {
        expect(PasswordValidator.validate('MyJ0urnal!2026'), isNull);
      });

      test('accepts long password', () {
        expect(PasswordValidator.validate('This1sAV3ryStr0ng!Pass'), isNull);
      });

      test('accepts password with unicode', () {
        expect(PasswordValidator.validate('Héllo1World!'), isNull);
      });
    });

    group('hint text', () {
      test('hint includes minimum length', () {
        expect(PasswordValidator.hint, contains('${PasswordValidator.minLength}'));
      });
    });
  });
}
