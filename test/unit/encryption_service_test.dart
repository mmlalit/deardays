import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/services/encryption/encryption_service.dart';

void main() {
  late EncryptionService service;

  setUp(() {
    service = EncryptionService();
    service.clearKey();
  });

  group('EncryptionService - Key Management', () {
    test('currentKey is null initially', () {
      expect(service.currentKey, isNull);
    });

    test('setKey stores key in memory', () {
      service.setKey('dGVzdC1rZXktYmFzZTY0');
      expect(service.currentKey, equals('dGVzdC1rZXktYmFzZTY0'));
    });

    test('clearKey wipes key from memory', () {
      service.setKey('dGVzdC1rZXktYmFzZTY0');
      service.clearKey();
      expect(service.currentKey, isNull);
    });

    test('singleton returns same instance', () {
      final a = EncryptionService();
      final b = EncryptionService();
      expect(identical(a, b), isTrue);
    });
  });

  group('EncryptionService - Key Derivation', () {
    test('deriveKey produces a 256-bit base64 key', () async {
      final salt = base64.encode(List.filled(16, 42));
      final key = await service.deriveKey('myPassword123', salt);

      final keyBytes = base64.decode(key);
      expect(keyBytes.length, equals(32)); // 256 bits
    });

    test('same password + salt produces same key', () async {
      final salt = base64.encode(List.filled(16, 7));
      final key1 = await service.deriveKey('samePassword', salt);
      final key2 = await service.deriveKey('samePassword', salt);

      expect(key1, equals(key2));
    });

    test('different passwords produce different keys', () async {
      final salt = base64.encode(List.filled(16, 7));
      final key1 = await service.deriveKey('password1', salt);
      final key2 = await service.deriveKey('password2', salt);

      expect(key1, isNot(equals(key2)));
    });

    test('different salts produce different keys', () async {
      final salt1 = base64.encode(List.filled(16, 1));
      final salt2 = base64.encode(List.filled(16, 2));
      final key1 = await service.deriveKey('samePassword', salt1);
      final key2 = await service.deriveKey('samePassword', salt2);

      expect(key1, isNot(equals(key2)));
    });

    test('generateSalt returns 16-byte base64 string', () {
      final salt = service.generateSalt();
      final saltBytes = base64.decode(salt);
      expect(saltBytes.length, equals(16));
    });

    test('generateSalt produces unique salts', () {
      final salts = List.generate(100, (_) => service.generateSalt());
      expect(salts.toSet().length, equals(100));
    });
  });

  group('EncryptionService - Encrypt/Decrypt', () {
    late String testKey;

    setUp(() async {
      final salt = base64.encode(List.filled(16, 42));
      testKey = await service.deriveKey('testPassword', salt);
    });

    test('encrypt then decrypt returns original plaintext', () {
      const plaintext = 'Hello, DearDays! This is my journal entry.';
      final encrypted = service.encryptText(plaintext, testKey);
      final decrypted = service.decryptText(encrypted, testKey);

      expect(decrypted, equals(plaintext));
    });

    test('encrypting same text twice produces different ciphertext (random IV)', () {
      const plaintext = 'Same text encrypted twice';
      final encrypted1 = service.encryptText(plaintext, testKey);
      final encrypted2 = service.encryptText(plaintext, testKey);

      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('decryption with wrong key throws EncryptionException', () async {
      const plaintext = 'Secret journal entry';
      final encrypted = service.encryptText(plaintext, testKey);

      final wrongSalt = base64.encode(List.filled(16, 99));
      final wrongKey = await service.deriveKey('wrongPassword', wrongSalt);

      expect(
        () => service.decryptText(encrypted, wrongKey),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('encrypts and decrypts unicode content', () {
      const plaintext = 'Today was beautiful! \u2764\uFE0F Caf\u00E9 \u2614 \u65E5\u672C\u8A9E';
      final encrypted = service.encryptText(plaintext, testKey);
      final decrypted = service.decryptText(encrypted, testKey);

      expect(decrypted, equals(plaintext));
    });

    test('encrypts and decrypts empty string', () {
      const plaintext = '';
      final encrypted = service.encryptText(plaintext, testKey);
      final decrypted = service.decryptText(encrypted, testKey);

      expect(decrypted, equals(plaintext));
    });

    test('encrypts and decrypts long text (5000+ chars)', () {
      final plaintext = 'A' * 5000;
      final encrypted = service.encryptText(plaintext, testKey);
      final decrypted = service.decryptText(encrypted, testKey);

      expect(decrypted, equals(plaintext));
    });

    test('invalid key length throws ArgumentError', () {
      final shortKey = base64.encode(List.filled(16, 0)); // 128-bit, not 256
      expect(
        () => service.encryptText('test', shortKey),
        throwsArgumentError,
      );
    });

    test('tampered ciphertext throws EncryptionException', () {
      const plaintext = 'Tamper test';
      final encrypted = service.encryptText(plaintext, testKey);
      final bytes = base64.decode(encrypted);
      bytes[bytes.length - 1] ^= 0xFF; // flip last byte
      final tampered = base64.encode(bytes);

      expect(
        () => service.decryptText(tampered, testKey),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('too-short ciphertext throws ArgumentError', () {
      final tooShort = base64.encode(List.filled(5, 0));
      expect(
        () => service.decryptText(tooShort, testKey),
        throwsArgumentError,
      );
    });
  });
}
