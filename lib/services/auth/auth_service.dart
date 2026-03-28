import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/services/analytics/analytics_service.dart';
import 'package:deardays/services/crash_reporting/crash_reporting_service.dart';

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
    CrashReportingService().addBreadcrumb('Sign-in attempted', data: {'method': 'email'});

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      CrashReportingService().addBreadcrumb('Sign-in successful');
      CrashReportingService().setUser(response.user!.id);
      AnalyticsService().track(AnalyticsEvent.userLoggedIn, properties: {'method': 'email'});
      // Ensure profile row exists (may be missing if data was cleared).
      try {
        await _client.from('profiles').upsert(
          {'id': response.user!.id},
          onConflict: 'id',
          ignoreDuplicates: true,
        );
      } catch (_) {}

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
  ///
  /// `signInWithOAuth` opens the system browser and returns before the OAuth
  /// callback completes, so `currentSession` is stale at that point. We listen
  /// for the next `signedIn` auth state change to capture the real session.
  Future<AuthResponse> signInWithApple() async {
    CrashReportingService().addBreadcrumb('Sign-in attempted', data: {'method': 'apple'});

    final completer = Completer<AuthResponse>();

    // Listen for the auth callback that fires once the OAuth redirect lands.
    late final StreamSubscription<AuthState> sub;
    sub = _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn && !completer.isCompleted) {
        sub.cancel();
        final session = state.session;
        final user = session?.user;
        if (user != null) {
          CrashReportingService().addBreadcrumb('Sign-in successful');
          CrashReportingService().setUser(user.id);
          AnalyticsService().track(AnalyticsEvent.userLoggedIn, properties: {'method': 'apple'});
        }
        completer.complete(
          AuthResponse(session: session, user: session?.user),
        );
      }
    });

    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.deardays://callback',
    );

    // If the user cancels or the callback never fires, time out after 2 min.
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        sub.cancel();
        return AuthResponse(session: _client.auth.currentSession, user: currentUser);
      },
    );
  }

  /// Signs in with Google using the native Google Sign-In flow.
  ///
  /// The web client ID must be passed via `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
  /// at build time. Without it, Google Sign-In will throw.
  Future<AuthResponse> signInWithGoogle() async {
    CrashReportingService().addBreadcrumb('Sign-in attempted', data: {'method': 'google'});

    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (webClientId.isEmpty) {
      throw AuthException('Google Sign-In is not configured.');
    }

    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled the sign-in
      return AuthResponse(session: _client.auth.currentSession, user: currentUser);
    }

    final googleAuth = await googleUser.authentication;
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );

    if (response.user != null) {
      CrashReportingService().addBreadcrumb('Sign-in successful');
      CrashReportingService().setUser(response.user!.id);
      AnalyticsService().track(AnalyticsEvent.userLoggedIn, properties: {'method': 'google'});

      try {
        await _client.from('profiles').upsert(
          {
            'id': response.user!.id,
            'display_name': googleUser.displayName,
            'encryption_salt': 'server-side',
            'trial_started_at': DateTime.now().toUtc().toIso8601String(),
            'consent_given_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
      } catch (_) {}

      try {
        await _revenueCat.login(response.user!.id);
      } catch (_) {}
    }

    return response;
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

  /// Clears all Hive boxes that store user-scoped data.
  /// Call before signing out so no stale data leaks to the next user.
  static Future<void> clearAllUserData() async {
    const boxNames = [
      'checkin_conversations',
      'story_nodes',
      'life_book_polish_cache',
      'ai_queue',
      'sync_queue',
      'offline_entries',
      'reflection_cache',
      'entries',
      'drafts',
      'sync_meta',
    ];
    for (final name in boxNames) {
      try {
        final b = await Hive.openBox<dynamic>(name);
        await b.clear();
      } catch (_) {}
    }
  }

  /// Signs the user out and wipes all locally stored sensitive data.
  Future<void> signOut() async {
    // Clear encryption key from memory immediately.
    EncryptionService().clearKey();

    // Clear local storage (entries, drafts, sync_meta).
    try {
      await LocalStorageService().clearAll();
    } catch (_) {
      // LocalStorageService may not be initialized if user never wrote entries.
    }

    // Clear Hive boxes before invalidating the session.
    await clearAllUserData();

    // Clear all locally stored sensitive data (tokens, etc.).
    await _secureStorage.clearAll();

    // Reset RevenueCat to anonymous user.
    await _revenueCat.logout();

    // Sign out from Supabase (revokes refresh token on server).
    await _client.auth.signOut();

    CrashReportingService().addBreadcrumb('Sign-out completed');
    CrashReportingService().clearUser();
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
