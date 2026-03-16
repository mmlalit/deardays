import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';

/// Authentication service wrapping Supabase Auth.
///
/// Encryption is handled server-side (pgcrypto + Supabase Vault) so the
/// client no longer derives or manages encryption keys.
class AuthService {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

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
      final profileData = <String, dynamic>{
        'id': response.user!.id,
        'encryption_salt': 'server-side', // Legacy column — no longer used
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

      // Link this user to RevenueCat for purchase tracking.
      await _revenueCat.login(response.user!.id);
    }

    return response;
  }

  /// Signs in with [email] and [password].
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Link this user to RevenueCat for purchase tracking.
      // Wrapped in try-catch: RevenueCat is unsupported on some platforms
      // (e.g. Windows) and must never break the login flow.
      try {
        await _revenueCat.login(response.user!.id);
      } catch (_) {}
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // Social auth
  // ---------------------------------------------------------------------------

  /// Signs in with Apple.
  Future<AuthResponse> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.deardays://callback',
    );

    return AuthResponse(session: _client.auth.currentSession, user: currentUser);
  }

  /// Signs in with Google.
  Future<AuthResponse> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.deardays://callback',
    );

    return AuthResponse(session: _client.auth.currentSession, user: currentUser);
  }

  // ---------------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------------

  /// Sends a password-reset email. Safe to use because encryption is handled
  /// server-side — changing the password does not affect data decryption.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Signs the user out and wipes all locally stored sensitive data.
  Future<void> signOut() async {
    // Clear all locally stored sensitive data (tokens, etc.).
    await _secureStorage.clearAll();

    // Reset RevenueCat to anonymous user.
    await _revenueCat.logout();

    // Sign out from Supabase (revokes refresh token on server).
    await _client.auth.signOut();
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

  /// Returns `true` if the user is within their 7-day free trial period.
  Future<bool> isInFreeTrial() async {
    final userId = currentUser?.id;
    if (userId == null) return false;

    try {
      final profile =
          await _client.from('profiles').select().eq('id', userId).single();

      final trialStartedAtStr = profile['trial_started_at'] as String?;
      if (trialStartedAtStr == null) return false;

      final trialStartedAt = DateTime.parse(trialStartedAtStr);
      final trialEnd = trialStartedAt.add(const Duration(days: 7));

      return DateTime.now().toUtc().isBefore(trialEnd);
    } catch (_) {
      return false;
    }
  }
}
