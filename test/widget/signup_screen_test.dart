import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/auth/presentation/screens/signup_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.light,
      home: SignupScreen(onLogin: () {}),
    );
  }

  // Helper: scroll to and tap the Create My Journal button, then pump for rebuild.
  Future<void> tapCreateButton(WidgetTester tester) async {
    final btnFinder = find.text('Create My Journal', skipOffstage: false);
    await tester.ensureVisible(btnFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(btnFinder);
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Finds the first RichText whose plain text contains [text].
  Finder richTextContaining(String text, {bool skipOffstage = true}) =>
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(text),
        skipOffstage: skipOffstage,
      );

  group('SignupScreen - Header', () {
    testWidgets('shows gradient header strip with logo', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('journal'), findsWidgets);
    });

    testWidgets('shows back arrow button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });

  group('SignupScreen - Heading & CTA', () {
    testWidgets('shows Start your story heading', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('story'), findsWidgets);
    });

    testWidgets('shows Create My Journal button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Create My Journal', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('SignupScreen - Social buttons', () {
    testWidgets('shows Google social button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('shows Apple social button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Apple'), findsOneWidget);
    });
  });

  group('SignupScreen - Form fields', () {
    testWidgets('shows four text fields (name, email, password, confirm)', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('email field accepts input', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      // Email is second field (after name)
      final emailField = find.byType(TextField).at(1);
      await tester.enterText(emailField, 'user@example.com');
      await tester.pump();

      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('password field has visibility toggle', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byIcon(Icons.visibility_outlined).evaluate().isNotEmpty ||
            find.byIcon(Icons.visibility_off_outlined).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('password strength bar appears when password typed', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final pwField = find.byType(TextField).at(2);
      await tester.enterText(pwField, 'Short1');
      await tester.pump();

      // Strength label: Weak / Fair / Good / Strong (may be off-screen)
      final hasStrength =
          find.textContaining('Weak', skipOffstage: false).evaluate().isNotEmpty ||
          find.textContaining('Fair', skipOffstage: false).evaluate().isNotEmpty ||
          find.textContaining('Good', skipOffstage: false).evaluate().isNotEmpty ||
          find.textContaining('Strong', skipOffstage: false).evaluate().isNotEmpty;
      expect(hasStrength, isTrue);
    });

    testWidgets('password strength shows Strong for complex password', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final pwField = find.byType(TextField).at(2);
      await tester.enterText(pwField, 'Str0ng!Pass#2026');
      await tester.pump();

      expect(
        find.textContaining('Strong', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('confirm password match indicator shows check when passwords match',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final pwField = find.byType(TextField).at(2);
      final confirmField = find.byType(TextField).at(3);

      await tester.enterText(pwField, 'Password1');
      await tester.pump();
      await tester.enterText(confirmField, 'Password1');
      await tester.pump();

      // Icon may be off-screen (confirm field near bottom of scroll view)
      expect(
        find.byIcon(Icons.check_circle_rounded, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('confirm password shows X when passwords do not match',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final pwField = find.byType(TextField).at(2);
      final confirmField = find.byType(TextField).at(3);

      await tester.enterText(pwField, 'Password1');
      await tester.pump();
      await tester.enterText(confirmField, 'Different1');
      await tester.pump();

      expect(
        find.byIcon(Icons.cancel_rounded, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('health consent checkbox is present', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      // Checkbox may be below the fold
      expect(find.byType(Checkbox, skipOffstage: false), findsOneWidget);
    });

    testWidgets('health consent checkbox toggles on tap', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final checkboxFinder = find.byType(Checkbox, skipOffstage: false);

      // Scroll to make it visible
      await tester.ensureVisible(checkboxFinder);
      await tester.pump(const Duration(milliseconds: 300));

      Checkbox cb = tester.widget(checkboxFinder);
      expect(cb.value, isFalse);

      await tester.tap(checkboxFinder);
      await tester.pump();

      cb = tester.widget(checkboxFinder);
      expect(cb.value, isTrue);
    });
  });

  group('SignupScreen - Validation', () {
    testWidgets('shows email error when submitting with empty email', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tapCreateButton(tester);

      // Error is near the email field; may be off-screen after scrolling to button
      expect(
        find.text('Email is required.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows password required error when password is empty', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final emailField = find.byType(TextField).at(1);
      await tester.enterText(emailField, 'user@example.com');
      await tester.pump();

      await tapCreateButton(tester);

      expect(
        find.text('Password is required.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows confirm mismatch error on submit', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final emailField = find.byType(TextField).at(1);
      final pwField = find.byType(TextField).at(2);
      final confirmField = find.byType(TextField).at(3);

      await tester.enterText(emailField, 'user@example.com');
      await tester.pump();
      await tester.enterText(pwField, 'Password1');
      await tester.pump();
      await tester.enterText(confirmField, 'Different1');
      await tester.pump();

      await tapCreateButton(tester);

      expect(
        find.text('Passwords do not match.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows invalid email error for bad format on submit', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      final emailField = find.byType(TextField).at(1);
      await tester.enterText(emailField, 'notanemail');
      await tester.pump();

      await tapCreateButton(tester);

      expect(
        find.text('Enter a valid email address.', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('SignupScreen - Navigation', () {
    testWidgets('shows Already have an account? Log in link', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      // The link is a RichText at the bottom — check offstage
      expect(
        richTextContaining('Already have an account', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('shows terms note', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Terms', skipOffstage: false),
        findsWidgets,
      );
    });
  });
}
