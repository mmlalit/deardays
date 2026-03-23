import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Zero-knowledge encryption service for DearDays.
///
/// Security model:
/// - All journal content is encrypted client-side before being sent to Supabase.
/// - The encryption key is derived from the user's password using PBKDF2 with
///   100,000 iterations, making brute-force attacks computationally expensive.
/// - A unique random salt is generated per user and stored in their profile.
///   The salt is NOT secret, but it prevents rainbow-table attacks.
/// - The derived key is held in memory ONLY — it is never persisted to disk,
///   never sent to the server, and never logged.
/// - Each encryption operation uses a fresh random IV (Initialization Vector),
///   ensuring identical plaintext produces different ciphertext every time.
/// - AES-256-GCM provides both confidentiality and integrity (authenticated
///   encryption). Tampering with ciphertext will cause decryption to fail.
/// - On logout or app lock, [clearKey] MUST be called to wipe the key from
///   memory. The key is re-derived on next login from the user's password.
///
/// Threat model:
/// - Server compromise: attacker gets only encrypted blobs + salts. Without
///   the user's password, content cannot be decrypted.
/// - Device compromise: key is in memory only while the app is active. Once
///   cleared, the key cannot be recovered from the device.
/// - DearDays developers: we never have access to plaintext content or keys.
class EncryptionService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  EncryptionService._internal();

  static final EncryptionService _instance = EncryptionService._internal();

  /// Returns the singleton instance of [EncryptionService].
  factory EncryptionService() => _instance;

  // ---------------------------------------------------------------------------
  // In-memory key storage
  // ---------------------------------------------------------------------------

  /// The derived encryption key, kept in memory only.
  /// NEVER persist this value to disk or transmit it over the network.
  String? _currentKeyBase64;

  /// Returns the current in-memory encryption key, or `null` if not set.
  String? get currentKey => _currentKeyBase64;

  /// Stores the encryption key in memory. Call this after successful key
  /// derivation during login. The key must be base64-encoded, 256 bits.
  void setKey(String keyBase64) {
    _currentKeyBase64 = keyBase64;
  }

  /// Wipes the encryption key from memory. MUST be called on logout, app
  /// lock, or when the user changes their password.
  void clearKey() {
    _currentKeyBase64 = null;
  }

  // ---------------------------------------------------------------------------
  // Key derivation
  // ---------------------------------------------------------------------------

  /// Number of PBKDF2 iterations. NIST recommends at least 100,000 as of 2023.
  /// Higher values increase the time cost for brute-force attacks.
  static const int _pbkdf2Iterations = 100000;

  /// Length of the derived key in bytes (256 bits for AES-256).
  static const int _keyLengthBytes = 32;

  /// Derives a 256-bit encryption key from [password] and [salt] using PBKDF2
  /// with HMAC-SHA256.
  ///
  /// The [salt] should be the base64-encoded salt stored in the user's profile.
  /// Returns the derived key as a base64-encoded string.
  ///
  /// This is intentionally slow (~100k iterations) to resist brute-force
  /// attacks against stolen encrypted data.
  ///
  /// Runs in a background isolate via [compute] to avoid blocking the UI thread.
  Future<String> deriveKey(String password, String salt) async {
    return compute(_deriveKeyIsolate, (password, salt));
  }

  // ignore: unused_element
  Future<String> _deriveKeySync(String password, String salt) async {
    final saltBytes = base64.decode(salt);
    final passwordBytes = utf8.encode(password);

    // PBKDF2 with HMAC-SHA256
    final hmacSha256 = Hmac(sha256, passwordBytes);
    final derivedKey = Uint8List(_keyLengthBytes);

    // PBKDF2 derives the key in blocks. For a 32-byte key with SHA-256
    // (32-byte output), we only need one block.
    final int blocksNeeded =
        (_keyLengthBytes / sha256.blockSize).ceil().clamp(1, 256);

    int offset = 0;
    for (int blockIndex = 1; blockIndex <= blocksNeeded; blockIndex++) {
      // U1 = PRF(password, salt || INT_32_BE(blockIndex))
      final blockBytes = Uint8List(4);
      blockBytes[0] = (blockIndex >> 24) & 0xff;
      blockBytes[1] = (blockIndex >> 16) & 0xff;
      blockBytes[2] = (blockIndex >> 8) & 0xff;
      blockBytes[3] = blockIndex & 0xff;

      final saltAndBlock = Uint8List.fromList([...saltBytes, ...blockBytes]);
      var u = hmacSha256.convert(saltAndBlock).bytes;
      final block = Uint8List.fromList(u);

      // Iteratively apply PRF _pbkdf2Iterations - 1 more times, XORing results.
      for (int i = 1; i < _pbkdf2Iterations; i++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (int j = 0; j < block.length; j++) {
          block[j] ^= u[j];
        }
      }

      // Copy this block into the derived key (truncate if needed).
      final copyLength =
          (offset + block.length > _keyLengthBytes)
              ? _keyLengthBytes - offset
              : block.length;
      derivedKey.setRange(offset, offset + copyLength, block);
      offset += copyLength;
    }

    return base64.encode(derivedKey);
  }


  /// Generates a cryptographically random 16-byte salt and returns it as a
  /// base64-encoded string. Store this in the user's profile row — it is NOT
  /// secret, but it must be unique per user.
  String generateSalt() {
    final secureRandom = SecureRandom(16);
    return base64.encode(secureRandom.bytes);
  }

  // ---------------------------------------------------------------------------
  // Encryption / Decryption (AES-256-GCM)
  // ---------------------------------------------------------------------------

  /// AES-GCM uses a 12-byte (96-bit) IV, which is the recommended size per
  /// NIST SP 800-38D.
  static const int _ivLengthBytes = 12;

  /// Encrypts [plaintext] using AES-256-GCM with a random IV.
  ///
  /// Returns a base64-encoded string containing `IV (12 bytes) + ciphertext`.
  /// The IV is prepended so it can be extracted during decryption.
  ///
  /// [keyBase64] must be a base64-encoded 256-bit key.
  ///
  /// Throws [ArgumentError] if the key is invalid.
  /// Throws [EncryptionException] if encryption fails.
  String encryptText(String plaintext, String keyBase64) {
    try {
      final keyBytes = base64.decode(keyBase64);
      if (keyBytes.length != _keyLengthBytes) {
        throw ArgumentError(
          'Invalid key length: expected $_keyLengthBytes bytes, '
          'got ${keyBytes.length} bytes.',
        );
      }

      final key = Key(Uint8List.fromList(keyBytes));
      final iv = IV(SecureRandom(_ivLengthBytes).bytes);
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Prepend IV to ciphertext so we can extract it during decryption.
      final combined = Uint8List.fromList([
        ...iv.bytes,
        ...encrypted.bytes,
      ]);

      return base64.encode(combined);
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw EncryptionException('Encryption failed: $e');
    }
  }

  /// Decrypts a base64-encoded string produced by [encryptText].
  ///
  /// Extracts the 12-byte IV from the front of the data, then decrypts the
  /// remaining ciphertext using AES-256-GCM.
  ///
  /// [keyBase64] must be the same base64-encoded key used for encryption.
  ///
  /// Throws [ArgumentError] if inputs are invalid.
  /// Throws [EncryptionException] if decryption fails (wrong key, tampered
  /// data, etc.).
  String decryptText(String encryptedBase64, String keyBase64) {
    try {
      final keyBytes = base64.decode(keyBase64);
      if (keyBytes.length != _keyLengthBytes) {
        throw ArgumentError(
          'Invalid key length: expected $_keyLengthBytes bytes, '
          'got ${keyBytes.length} bytes.',
        );
      }

      final combined = base64.decode(encryptedBase64);
      if (combined.length < _ivLengthBytes + 1) {
        throw ArgumentError(
          'Encrypted data is too short to contain an IV and ciphertext.',
        );
      }

      // Split IV and ciphertext.
      final ivBytes = combined.sublist(0, _ivLengthBytes);
      final ciphertextBytes = combined.sublist(_ivLengthBytes);

      final key = Key(Uint8List.fromList(keyBytes));
      final iv = IV(Uint8List.fromList(ivBytes));
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

      return encrypter.decrypt(Encrypted(Uint8List.fromList(ciphertextBytes)), iv: iv);
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw EncryptionException(
        'Decryption failed. This usually means the key is wrong or the data '
        'has been tampered with. Details: $e',
      );
    }
  }
}

/// Top-level function for compute() isolate — derives a PBKDF2 key off the main thread.
/// Must be top-level (not a closure/method) for Flutter's compute() to work in a new isolate.
Future<String> _deriveKeyIsolate((String, String) args) async {
  final (password, salt) = args;
  final saltBytes = base64.decode(salt);
  final passwordBytes = utf8.encode(password);
  const iterations = 100000;
  const keyLengthBytes = 32;

  final hmacSha256 = Hmac(sha256, passwordBytes);
  final derivedKey = Uint8List(keyLengthBytes);
  final blocksNeeded = (keyLengthBytes / sha256.blockSize).ceil().clamp(1, 256);
  int offset = 0;
  for (int blockIndex = 1; blockIndex <= blocksNeeded; blockIndex++) {
    final blockBytes = Uint8List(4);
    blockBytes[0] = (blockIndex >> 24) & 0xff;
    blockBytes[1] = (blockIndex >> 16) & 0xff;
    blockBytes[2] = (blockIndex >> 8) & 0xff;
    blockBytes[3] = blockIndex & 0xff;
    final saltAndBlock = Uint8List.fromList([...saltBytes, ...blockBytes]);
    var u = hmacSha256.convert(saltAndBlock).bytes;
    final block = Uint8List.fromList(u);
    for (int i = 1; i < iterations; i++) {
      u = Hmac(sha256, passwordBytes).convert(u).bytes;
      for (int j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }
    final copyLength = (offset + block.length > keyLengthBytes)
        ? keyLengthBytes - offset
        : block.length;
    derivedKey.setRange(offset, offset + copyLength, block);
    offset += copyLength;
  }
  return base64.encode(derivedKey);
}

/// Exception thrown when an encryption or decryption operation fails.
class EncryptionException implements Exception {
  final String message;

  const EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
