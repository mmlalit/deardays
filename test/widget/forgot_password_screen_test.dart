import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({String? prefillEmail}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: ForgotPasswordScreen(prefillEmail: prefillEmail),
    );
  }

  group('ForgotPasswordScreen - Header', () {
    testWidgets('shows gradient header with reset password label', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Reset'), findsWidgets);
    });

    testWidgets('shows back arrow button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen - Form state', () {
    testWidgets('shows Forgot your password heading', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Forgot'), findsWidgets);
    });

    testWidgets('shows email text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows Send Reset Link button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('shows Back to login link', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Back to login'), findsOneWidget);
    });

    testWidgets('shows security note about expiry', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('60 minutes'), findsOneWidget);
    });

    testWidgets('email field accepts input', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('pre-fills email from prefillEmail parameter', (tester) async {
      await tester.pumpWidget(buildApp(prefillEmail: 'existing@example.com'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('existing@example.com'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen - Validation', () {
    testWidgets('shows email required error when submitting empty field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();

      expect(find.textContaining('required'), findsOneWidget);
    });

    testWidgets('shows invalid email error for malformed address', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'notanemail');
      await tester.pump();

      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();

      expect(find.textContaining('valid email'), findsOneWidget);
    });

    testWidgets('error clears when user edits field after failed submit', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      // Submit empty to trigger error
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.textContaining('required'), findsOneWidget);

      // Edit the field — error should clear
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();
      expect(find.textContaining('required'), findsNothing);
    });
  });

  group('ForgotPasswordScreen - Layout', () {
    testWidgets('does not show success state initially', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Check your inbox'), findsNothing);
      expect(find.byIcon(Icons.mark_email_read_outlined), findsNothing);
    });

    testWidgets('renders without overflow', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      // No RenderFlex overflow means the layout is correct
      expect(tester.takeException(), isNull);
    });
  });
}
