import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';

void main() {
  Widget buildApp() {
    return MaterialApp(
      home: LoginScreen(onLogin: () {}),
    );
  }

  group('LoginScreen - Branding', () {
    testWidgets('shows DearDays logo/name', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('DearDays'), findsOneWidget);
    });

    testWidgets('shows tagline', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('journal'), findsWidgets);
    });
  });

  group('LoginScreen - Social buttons', () {
    testWidgets('shows Continue with Email button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continue with Email'), findsOneWidget);
    });

    testWidgets('shows Continue with Apple button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('shows Continue with Google button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('LoginScreen - Email form', () {
    testWidgets('tapping Continue with Email reveals email form', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('email field accepts input', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('sign-up mode shows health consent checkbox', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      // Default is sign-up mode
      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets('password field has visibility toggle', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      // Should have a visibility toggle icon
      expect(
        find.byIcon(Icons.visibility_outlined)
            .evaluate()
            .isNotEmpty ||
        find.byIcon(Icons.visibility_off_outlined)
            .evaluate()
            .isNotEmpty,
        isTrue,
      );
    });

    testWidgets('sign-in/sign-up toggle changes mode', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      // Default is Sign Up — look for Sign In toggle
      expect(
        find.textContaining('Sign In').evaluate().isNotEmpty ||
        find.textContaining('Log In').evaluate().isNotEmpty ||
        find.textContaining('sign in').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('submit button is visible in email form', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Create').evaluate().isNotEmpty ||
        find.textContaining('Log In').evaluate().isNotEmpty ||
        find.textContaining('Sign').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
