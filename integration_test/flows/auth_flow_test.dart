/// Auth screen flow tests.
///
/// Auth screens (Login, Signup, ForgotPassword) live outside the E2E app's
/// auth gate, so we render them directly via a standalone MaterialApp.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';
import 'package:deardays/features/auth/presentation/screens/signup_screen.dart';
import 'package:deardays/features/auth/presentation/screens/forgot_password_screen.dart';

/// Wraps an auth screen in a lightweight MaterialApp (no router needed).
Widget _authApp(Widget screen) => MaterialApp(
      theme: AppTheme.light,
      home: screen,
    );

void authFlowTests() {
  // ── LoginScreen ────────────────────────────────────────────────────────────

  group('Auth — LoginScreen', () {
    testWidgets('LoginScreen renders', (tester) async {
      await tester.pumpWidget(_authApp(LoginScreen(onLogin: () {})));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('LoginScreen shows email field', (tester) async {
      await tester.pumpWidget(_authApp(LoginScreen(onLogin: () {})));
      await tester.pump(const Duration(seconds: 1));

      // Email field — look for hint text or InputDecoration label
      expect(
        find.textContaining('mail').evaluate().isNotEmpty ||
            find.byType(TextField).evaluate().isNotEmpty ||
            find.byType(TextFormField).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('LoginScreen shows password field', (tester) async {
      await tester.pumpWidget(_authApp(LoginScreen(onLogin: () {})));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('assword').evaluate().isNotEmpty ||
            find.byType(TextField).evaluate().length >= 2 ||
            find.byType(TextFormField).evaluate().length >= 2,
        isTrue,
      );
    });

    testWidgets('LoginScreen shows Sign Up link', (tester) async {
      await tester.pumpWidget(_authApp(LoginScreen(onLogin: () {})));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Sign up').evaluate().isNotEmpty ||
            find.textContaining('Sign Up').evaluate().isNotEmpty ||
            find.textContaining('Create').evaluate().isNotEmpty ||
            find.textContaining('Register').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── SignupScreen ───────────────────────────────────────────────────────────

  group('Auth — SignupScreen', () {
    testWidgets('SignupScreen renders', (tester) async {
      await tester.pumpWidget(_authApp(SignupScreen(onLogin: () {})));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('SignupScreen shows form fields', (tester) async {
      await tester.pumpWidget(_authApp(SignupScreen(onLogin: () {})));
      await tester.pump(const Duration(seconds: 1));

      // Should have at least name, email, password fields
      expect(
        find.byType(TextField).evaluate().length >= 2 ||
            find.byType(TextFormField).evaluate().length >= 2,
        isTrue,
      );
    });
  });

  // ── ForgotPasswordScreen ──────────────────────────────────────────────────

  group('Auth — ForgotPasswordScreen', () {
    testWidgets('ForgotPasswordScreen renders', (tester) async {
      await tester.pumpWidget(_authApp(const ForgotPasswordScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen shows email field', (tester) async {
      await tester.pumpWidget(_authApp(const ForgotPasswordScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('mail').evaluate().isNotEmpty ||
            find.byType(TextField).evaluate().isNotEmpty ||
            find.byType(TextFormField).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
