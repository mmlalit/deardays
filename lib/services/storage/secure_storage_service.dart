import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] to provide a consistent API for storing
/// sensitive data such as auth tokens and user preferences.
///
/// All values are stored in the platform's secure keychain/keystore:
/// - iOS: Keychain with accessibility set to first_unlock (available after
///   first device unlock, persists across app restarts).
/// - Android: EncryptedSharedPreferences backed by the Android Keystore.
class SecureStorageService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  SecureStorageService._internal();

  static final SecureStorageService _instance =
      SecureStorageService._internal();

  /// Returns the singleton instance of [SecureStorageService].
  factory SecureStorageService() => _instance;

  // ---------------------------------------------------------------------------
  // Storage keys — defined as constants to prevent typos
  // ---------------------------------------------------------------------------

  static const String _keyBiometricEnabled = 'dd_biometric_enabled';
  static const String _keyAuthToken = 'dd_auth_token';
  static const String _keyPinHash = 'dd_pin_hash';
  static const String _keyPatternHash = 'dd_pattern_hash';
  static const String _keyLockMethod = 'dd_lock_method'; // none, pin, pattern, biometric
  static const String _keyPinSalt = 'dd_pin_salt';
  static const String _keyPatternSalt = 'dd_pattern_salt';

  // ---------------------------------------------------------------------------
  // Secure storage instance with platform-specific options
  // ---------------------------------------------------------------------------

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Uses EncryptedSharedPreferences on Android, which encrypts both keys
      // and values using the Android Keystore system.
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      // first_unlock: data is accessible after the user has unlocked the device
      // at least once since boot. This allows background access (e.g., push
      // notification processing) while still protecting data at rest.
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ---------------------------------------------------------------------------
  // Biometric authentication preference
  // ---------------------------------------------------------------------------

  /// Persists whether the user has enabled biometric (Face ID / fingerprint)
  /// authentication for app unlock.
  Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled.toString(),
    );
  }

  /// Returns whether biometric authentication is enabled. Defaults to `false`
  /// if not previously set.
  Future<bool> getBiometricEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  // ---------------------------------------------------------------------------
  // PIN lock
  // ---------------------------------------------------------------------------

  Future<void> savePinHash(String pinHash) async {
    await _storage.write(key: _keyPinHash, value: pinHash);
  }

  Future<String?> getPinHash() async {
    return await _storage.read(key: _keyPinHash);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _keyPinHash);
  }

  // ---------------------------------------------------------------------------
  // Pattern lock
  // ---------------------------------------------------------------------------

  Future<void> savePatternHash(String patternHash) async {
    await _storage.write(key: _keyPatternHash, value: patternHash);
  }

  Future<String?> getPatternHash() async {
    return await _storage.read(key: _keyPatternHash);
  }

  Future<void> clearPattern() async {
    await _storage.delete(key: _keyPatternHash);
  }

  // ---------------------------------------------------------------------------
  // Lock method preference
  // ---------------------------------------------------------------------------

  Future<void> saveLockMethod(String method) async {
    await _storage.write(key: _keyLockMethod, value: method);
  }

  Future<String> getLockMethod() async {
    return await _storage.read(key: _keyLockMethod) ?? 'none';
  }

  // ---------------------------------------------------------------------------
  // Auth token
  // ---------------------------------------------------------------------------

  /// Saves the Supabase auth/refresh token for session restoration.
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  /// Retrieves the stored auth token, or `null` if the user is not logged in.
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  // ---------------------------------------------------------------------------
  // Secure PIN/pattern hashing (PBKDF2)
  // ---------------------------------------------------------------------------

  static const int _pbkdf2Iterations = 100000;

  /// Generates a random 16-byte salt encoded as base64.
  String _generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64.encode(bytes);
  }

  /// Derives a PBKDF2-HMAC-SHA256 hash from [input] and [salt].
  ///
  /// Runs on a background isolate via [compute] to avoid blocking the
  /// UI thread during the 100 000 iteration loop.
  Future<String> _pbkdf2Hash(String input, String salt) {
    return compute(_pbkdf2Isolate, [input, salt, _pbkdf2Iterations]);
  }

  /// Top-level-compatible static function for [compute].
  static String _pbkdf2Isolate(List<dynamic> args) {
    final input = args[0] as String;
    final salt = args[1] as String;
    final iterations = args[2] as int;

    final saltBytes = base64.decode(salt);
    final inputBytes = utf8.encode(input);
    final hmacSha256 = Hmac(sha256, inputBytes);

    // Single-block PBKDF2 (32 bytes < SHA-256 output size)
    final blockBytes = Uint8List(4)
      ..[0] = 0
      ..[1] = 0
      ..[2] = 0
      ..[3] = 1;
    final saltAndBlock = Uint8List.fromList([...saltBytes, ...blockBytes]);
    var u = hmacSha256.convert(saltAndBlock).bytes;
    final result = Uint8List.fromList(u);

    for (int i = 1; i < iterations; i++) {
      u = Hmac(sha256, inputBytes).convert(u).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64.encode(result);
  }

  /// Hashes a PIN using PBKDF2 with a per-device random salt.
  /// Generates and stores the salt on first call; reuses it thereafter.
  Future<String> hashPin(String pin) async {
    String? salt = await _storage.read(key: _keyPinSalt);
    if (salt == null) {
      salt = _generateSalt();
      await _storage.write(key: _keyPinSalt, value: salt);
    }
    return _pbkdf2Hash('deardays_pin_$pin', salt);
  }

  /// Hashes a pattern using PBKDF2 with a per-device random salt.
  Future<String> hashPattern(List<int> pattern) async {
    String? salt = await _storage.read(key: _keyPatternSalt);
    if (salt == null) {
      salt = _generateSalt();
      await _storage.write(key: _keyPatternSalt, value: salt);
    }
    return _pbkdf2Hash('deardays_pattern_${pattern.join('-')}', salt);
  }

  // ---------------------------------------------------------------------------
  // Logout / wipe
  // ---------------------------------------------------------------------------

  /// Deletes ALL stored secure data. MUST be called on logout to ensure no
  /// sensitive data remains on the device.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
