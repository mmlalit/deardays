import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] to provide a consistent API for storing
/// sensitive data such as encryption salts, auth tokens, and user preferences.
///
/// All values are stored in the platform's secure keychain/keystore:
/// - iOS: Keychain with accessibility set to first_unlock (available after
///   first device unlock, persists across app restarts).
/// - Android: EncryptedSharedPreferences backed by the Android Keystore.
///
/// IMPORTANT: This service stores metadata and tokens — NEVER store the
/// encryption key itself. The key lives only in [EncryptionService] memory.
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

  static const String _keyEncryptionSalt = 'dd_encryption_salt';
  static const String _keyBiometricEnabled = 'dd_biometric_enabled';
  static const String _keyAuthToken = 'dd_auth_token';
  static const String _keyPinHash = 'dd_pin_hash';
  static const String _keyPatternHash = 'dd_pattern_hash';
  static const String _keyLockMethod = 'dd_lock_method'; // none, pin, pattern, biometric

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
  // Encryption salt
  // ---------------------------------------------------------------------------

  /// Saves the user's encryption salt. The salt is unique per user and is used
  /// alongside their password to derive the encryption key via PBKDF2.
  /// The salt itself is not secret, but storing it securely prevents local
  /// tampering.
  Future<void> saveEncryptionSalt(String salt) async {
    await _storage.write(key: _keyEncryptionSalt, value: salt);
  }

  /// Retrieves the stored encryption salt, or `null` if none exists (e.g.,
  /// first launch or after a full wipe).
  Future<String?> getEncryptionSalt() async {
    return await _storage.read(key: _keyEncryptionSalt);
  }

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
  // Logout / wipe
  // ---------------------------------------------------------------------------

  /// Deletes ALL stored secure data. MUST be called on logout to ensure no
  /// sensitive data remains on the device.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
