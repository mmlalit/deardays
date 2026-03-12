import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';

import '../helpers/test_app.dart';

/// E2E tests for Settings sub-screens: Edit Profile, Privacy Policy, Terms of
/// Service. Each is opened via Navigator.push from SettingsScreen.

void settingsSubscreenFlowTests() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await tester.pumpAndSettle();
    // Settings is accessed via the profile avatar (first GestureDetector).
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
  }

  // ── Edit Profile ──────────────────────────────────────────────────────────

  group('Settings Sub-screens — Edit Profile', () {
    testWidgets('"Edit Profile" pill is visible on Settings', (tester) async {
      await openSettings(tester);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('tapping "Edit Profile" opens EditProfileScreen',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile'));
      // EditProfileScreen loads profile via Supabase which may hang — use
      // pump(Duration) to avoid pumpAndSettle waiting forever.
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('EditProfileScreen shows "Edit Profile" in header',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile'));
      await tester.pump(const Duration(seconds: 2));

      // DearDaysHeader.appBar renders the title text.
      // There may be two: one from the pill and one from the header.
      expect(find.text('Edit Profile'), findsWidgets);
    });

    testWidgets('EditProfileScreen shows DISPLAY NAME section label',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('DISPLAY NAME'), findsOneWidget);
    });

    testWidgets('EditProfileScreen shows CHANGE PASSWORD section label',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile'));
      await tester.pump(const Duration(seconds: 2));

      // Scroll down to make the password section visible.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('CHANGE PASSWORD'), findsOneWidget);
    });

    testWidgets('EditProfileScreen has back button and can navigate back',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile'));
      await tester.pump(const Duration(seconds: 2));

      // DearDaysHeader uses Icons.arrow_back_ios_new.
      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  // ── Privacy Policy ────────────────────────────────────────────────────────

  group('Settings Sub-screens — Privacy Policy', () {
    testWidgets('"Privacy Policy" row is visible in Settings', (tester) async {
      await openSettings(tester);

      // Scroll to the ABOUT section.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('tapping "Privacy Policy" opens PrivacyScreen',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
    });

    testWidgets('PrivacyScreen shows "Privacy Policy" in header',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
    });

    testWidgets('PrivacyScreen shows "Our Privacy Commitment" section',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Our Privacy Commitment'), findsOneWidget);
    });

    testWidgets('PrivacyScreen shows encryption highlight badge',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Server-Side Encryption'), findsOneWidget);
    });

    testWidgets('PrivacyScreen has back button and can navigate back',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  // ── Terms of Service ──────────────────────────────────────────────────────

  group('Settings Sub-screens — Terms of Service', () {
    testWidgets('"Terms of Service" row is visible in Settings',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('tapping "Terms of Service" opens TermsScreen',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsScreen), findsOneWidget);
    });

    testWidgets('TermsScreen shows "Terms of Service" in header',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsWidgets);
    });

    testWidgets('TermsScreen shows "Acceptance of Terms" section',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.text('Acceptance of Terms'), findsOneWidget);
    });

    testWidgets('TermsScreen shows last-updated banner', (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Last updated'), findsOneWidget);
    });

    testWidgets('TermsScreen has back button and can navigate back',
        (tester) async {
      await openSettings(tester);

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
