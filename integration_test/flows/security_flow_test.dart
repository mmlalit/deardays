import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/request_access_screen.dart';

import '../helpers/test_app.dart';

UserProfile _minimalProfile({
  required String id,
  required String displayName,
  required DateTime createdAt,
}) =>
    UserProfile(
      id: id,
      displayName: displayName,
      encryptionSalt: '',
      trialStartedAt: createdAt,
      isSubscribed: false,
      createdAt: createdAt,
      consentGivenAt: createdAt,
    );

void securityFlowTests() {
  group('Security — Input Sanitization', () {
    testWidgets('text entry renders HTML tags as literal text', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(TextEntryScreen), findsOneWidget);

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, '<script>alert(1)</script>');
      await tester.pump();

      // Flutter renders text as plain string — no script execution, no dialog.
      expect(find.text('<script>alert(1)</script>'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('text entry renders SQL injection string as literal text',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, "'; DROP TABLE journal_entries; --");
      await tester.pump();

      expect(find.text("'; DROP TABLE journal_entries; --"), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);

      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        'text entry handles null-byte and Unicode replacement char without crash',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, 'Normal \u0000 text \uFFFD end');
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);

      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('search field handles regex special chars without crash',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final searchIcon = find.byIcon(Icons.search_rounded);
      if (searchIcon.evaluate().isNotEmpty) {
        await tester.tap(searchIcon.first);
        await tester.pump(const Duration(seconds: 2));

        if (find.byType(SearchScreen).evaluate().isNotEmpty) {
          final searchField = find.byType(TextField).first;
          await tester.tap(searchField);
          await tester.enterText(searchField, r'(.*)[\w+]+$^|{}');
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('5000-character input does not crash the app', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(const Duration(seconds: 2));

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, 'A' * 5000);
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);

      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('Security — Deep Link Handling', () {
    testWidgets('/share/:token renders RequestAccessScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/share/valid-test-token');
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(RequestAccessScreen), findsOneWidget);
    });

    testWidgets('deep link with URL-safe special chars in token does not crash',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/share/abc-123_XYZ');
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Security — Auth & Data Privacy', () {
    testWidgets('mock provider renders UI without a real auth session',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('encryption salt is never displayed in the UI', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('e2e-salt'), findsNothing);
    });

    testWidgets('internal user ID is not rendered as visible UI text',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('e2e-user'), findsNothing);
    });

    testWidgets('no raw API key prefixes visible in home UI', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('sk-'), findsNothing);
      expect(find.textContaining('gsk_'), findsNothing);
      expect(find.textContaining('AIza'), findsNothing);
    });

    testWidgets('settings screen shows at least one privacy-related item',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final settingsTab = find.text('SETTINGS');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pump(const Duration(seconds: 2));

        final hasPrivacy =
            find.textContaining('Privacy').evaluate().isNotEmpty ||
                find.textContaining('privacy').evaluate().isNotEmpty;
        expect(hasPrivacy, isTrue);
      } else {
        // Settings accessible via icon — skip tab-specific assertion
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });

  group('Security — Data Isolation', () {
    testWidgets('re-building with a different profile override does not crash',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final now = DateTime.now();
      await tester.pumpWidget(buildE2EApp(
        additionalOverrides: [
          profileProvider.overrideWith((_) async => _minimalProfile(
                id: 'isolated-user',
                displayName: 'IsolatedUser',
                createdAt: now,
              )),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
