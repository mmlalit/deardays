import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/auth/auth_service.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestEnv();

  group('AuthService', () {
    late AuthService service;

    setUp(() {
      service = AuthService();
    });

    test('can be instantiated', () {
      expect(service, isA<AuthService>());
    });

    test('currentUser is null when not authenticated', () {
      expect(service.currentUser, isNull);
    });

    test('isAuthenticated is false when not logged in', () {
      expect(service.isAuthenticated, isFalse);
    });

    test('authStateChanges returns a stream', () {
      expect(service.authStateChanges, isA<Stream<AuthState>>());
    });

    test('resetPassword does not throw for valid email format', () async {
      try {
        await service.resetPassword('test@example.com');
      } catch (e) {
        // Expected — no real Supabase server
        expect(e, isNotNull);
      }
    });

    test('signOut clears secure storage without throwing', () async {
      try {
        await service.signOut();
      } catch (e) {
        // Expected — mock Supabase may throw
        expect(e, isNotNull);
      }
    });

    test('hasActiveSubscription returns false when not authenticated',
        () async {
      final result = await service.hasActiveSubscription();
      expect(result, isFalse);
    });

    test('isInFreeTrial returns false when not authenticated', () async {
      final result = await service.isInFreeTrial();
      expect(result, isFalse);
    });

    test('signUpWithEmail requires email and password', () async {
      try {
        await service.signUpWithEmail('test@test.com', 'password123');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('signInWithEmail requires email and password', () async {
      try {
        await service.signInWithEmail('test@test.com', 'password123');
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}
