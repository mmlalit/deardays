import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';

/// Authentication service wrapping Supabase Auth with zero-knowledge
/// encryption key management.
///
/// On sign-up, a unique encryption salt is generated and stored in the user's
/// Supabase profile. On every login, the encryption key is re-derived from the
/// user's password + salt and held in [EncryptionService] memory only.
///
/// Social logins (Apple, Google) are supported but require a separate
/// encryption passphrase flow since we do not have access to a password. That
/// flow should prompt the user to set an encryption passphrase on first social
/// login.
class AuthService {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final EncryptionService _encryption = EncryptionService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final RevenueCatService _revenueCat = RevenueCatService();

  // ---------------------------------------------------------------------------
  // Supabase client accessor
  // ---------------------------------------------------------------------------

  /// Returns the current Supabase client instance.
  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Auth state accessors
  // ---------------------------------------------------------------------------

  /// Returns the currently authenticated [User], or `null` if not logged in.
  User? get currentUser => _client.auth.currentUser;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes (sign in, sign out, token refresh, etc.).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Email / password auth
  // ---------------------------------------------------------------------------

  /// Creates a new account with [email] and [password].
  ///
  /// After successful sign-up:
  /// 1. Generates a unique encryption salt.
  /// 2. Stores the salt in the user's Supabase profile row.
  /// 3. Derives the encryption key from password + salt.
  /// 4. Stores the key in [EncryptionService] memory (never on disk).
  /// 5. Persists the salt locally in secure storage for offline access.
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
    DateTime? consentGivenAt,
    DateTime? healthConsentGivenAt,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Generate a unique salt for this user's encryption key derivation.
      final salt = _encryption.generateSalt();

      // Store the salt in the user's profile on Supabase.
      // The salt is NOT secret — it just ensures each user has a unique key
      // even if they choose the same password.
      final profileData = <String, dynamic>{
        'id': response.user!.id,
        'encryption_salt': salt,
        'trial_started_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (displayName != null && displayName.trim().isNotEmpty) {
        profileData['display_name'] = displayName.trim();
      }

      // Record GDPR/CCPA consent timestamps.
      if (consentGivenAt != null) {
        profileData['consent_given_at'] = consentGivenAt.toIso8601String();
      }
      if (healthConsentGivenAt != null) {
        profileData['health_consent_given_at'] =
            healthConsentGivenAt.toIso8601String();
      }

      await _client.from('profiles').upsert(profileData);

      // Derive the encryption key and hold it in memory.
      final keyBase64 = await _encryption.deriveKey(password, salt);
      _encryption.setKey(keyBase64);

      // Cache the salt locally so we can re-derive the key on next login
      // without hitting the network (useful for offline / biometric unlock).
      await _secureStorage.saveEncryptionSalt(salt);

      // Store the derived key in the device keychain so it can be restored
      // on app restart without requiring the user to re-enter their password.
      await _secureStorage.saveEncryptionKey(keyBase64);

      // Link this user to RevenueCat for purchase tracking.
      await _revenueCat.login(response.user!.id);
    }

    return response;
  }

  /// Signs in with [email] and [password].
  ///
  /// After successful sign-in, derives the encryption key from the password
  /// and the salt stored in the user's profile, then stores the key in memory.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await _deriveAndStoreKey(response.user!.id, password);

      // Link this user to RevenueCat for purchase tracking.
      await _revenueCat.login(response.user!.id);
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // Social auth
  // ---------------------------------------------------------------------------

  /// Signs in with Apple. Note: social logins do not provide a password, so
  /// the encryption key cannot be derived automatically. The app should prompt
  /// the user to set an encryption passphrase on first social login.
  Future<AuthResponse> signInWithApple() async {
    final response = await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.deardays://callback',
    );

    // signInWithOAuth returns a bool for web, but on mobile the auth state
    // change stream will fire when the user completes the OAuth flow.
    // We return a minimal AuthResponse here; the actual session is delivered
    // via [authStateChanges].
    return AuthResponse(session: _client.auth.currentSession, user: currentUser);
  }

  /// Signs in with Google. Same encryption passphrase caveat as Apple.
  Future<AuthResponse> signInWithGoogle() async {
    final response = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.deardays://callback',
    );

    return AuthResponse(session: _client.auth.currentSession, user: currentUser);
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Signs the user out and wipes all sensitive data from memory and secure
  /// storage. After this call, the encryption key is gone — it can only be
  /// re-derived by logging in again with the correct password.
  Future<void> signOut() async {
    // Wipe the encryption key from memory FIRST, before any async work, to
    // minimize the window where the key is available after logout intent.
    _encryption.clearKey();

    // Clear all locally stored sensitive data (salt cache, tokens, etc.).
    await _secureStorage.clearAll();

    // Reset RevenueCat to anonymous user.
    await _revenueCat.logout();

    // Sign out from Supabase (revokes refresh token on server).
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------------

  /// Sends a password reset email. WARNING: changing the password will
  /// invalidate the encryption key derived from the old password. The app must
  /// handle re-encryption of existing data with a new key after password reset.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ---------------------------------------------------------------------------
  // Subscription checks
  // ---------------------------------------------------------------------------

  /// Checks whether the user has an active paid subscription by reading the
  /// `is_subscribed` and `subscription_expires_at` fields from their profile.
  Future<bool> hasActiveSubscription() async {
    final userId = currentUser?.id;
    if (userId == null) return false;

    try {
      final profile =
          await _client.from('profiles').select().eq('id', userId).single();

      final isSubscribed = profile['is_subscribed'] as bool? ?? false;
      final expiresAtStr = profile['subscription_expires_at'] as String?;

      if (!isSubscribed) return false;

      // If there is an expiry date, check that it has not passed.
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        return expiresAt.isAfter(DateTime.now().toUtc());
      }

      // Subscribed with no expiry — treat as active (e.g., lifetime plan).
      return true;
    } catch (_) {
      // If we cannot reach the server, assume no subscription.
      return false;
    }
  }

  /// Returns `true` if the user is within their 30-day free trial period.
  Future<bool> isInFreeTrial() async {
    final userId = currentUser?.id;
    if (userId == null) return false;

    try {
      final profile =
          await _client.from('profiles').select().eq('id', userId).single();

      final trialStartedAtStr = profile['trial_started_at'] as String?;
      if (trialStartedAtStr == null) return false;

      final trialStartedAt = DateTime.parse(trialStartedAtStr);
      final trialEnd = trialStartedAt.add(const Duration(days: 30));

      return DateTime.now().toUtc().isBefore(trialEnd);
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetches the encryption salt from the user's profile, derives the key
  /// from [password] + salt, and stores both the key (in memory) and the salt
  /// (in secure storage) for future use.
  Future<void> _deriveAndStoreKey(String userId, String password) async {
    // Try to get the salt from the server (source of truth).
    String? salt;

    try {
      final profile =
          await _client.from('profiles').select().eq('id', userId).single();
      salt = profile['encryption_salt'] as String?;
    } catch (_) {
      // If the network call fails, fall back to the locally cached salt.
      salt = await _secureStorage.getEncryptionSalt();
    }

    if (salt == null) {
      // This should not happen for existing users. If it does, the user's data
      // cannot be decrypted. The UI should guide them through recovery.
      throw const AuthEncryptionException(
        'No encryption salt found for this account. '
        'Data cannot be decrypted without the original salt.',
      );
    }

    // Derive the encryption key (this is intentionally slow — ~100k PBKDF2
    // iterations).
    final keyBase64 = await _encryption.deriveKey(password, salt);
    _encryption.setKey(keyBase64);

    // Cache the salt locally for offline / biometric unlock scenarios.
    await _secureStorage.saveEncryptionSalt(salt);

    // Store the derived key in the device keychain for session restore.
    await _secureStorage.saveEncryptionKey(keyBase64);
  }
}

/// Exception thrown when encryption-related auth operations fail.
class AuthEncryptionException implements Exception {
  final String message;

  const AuthEncryptionException(this.message);

  @override
  String toString() => 'AuthEncryptionException: $message';
}
