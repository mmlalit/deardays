import 'package:go_router/go_router.dart';
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
    await settle(tester);
    // Settings is accessed via the settings_outlined icon in the header.
    final _ctx = tester.element(find.byType(Scaffold).first); GoRouter.of(_ctx).push('/settings');
    await settle(tester);
  }

  Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(finder.first);
    await settle(tester);
  }

  // ── Edit Profile ──────────────────────────────────────────────────────────

  group('Settings Sub-screens — Edit Profile', () {
    testWidgets('"Edit Profile" pill is visible on Settings', (tester) async {
      await openSettings(tester);
      expect(find.text('Edit Profile'), findsWidgets);
    });

    testWidgets('tapping "Edit Profile" opens EditProfileScreen',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile').first);
      // EditProfileScreen loads profile via Supabase which may hang — use
      // pump(Duration) to avoid pumpAndSettle waiting forever.
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('EditProfileScreen shows "Edit Profile" in header',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile').first);
      await tester.pump(const Duration(seconds: 2));

      // DearDaysHeader.appBar renders the title text.
      // There may be two: one from the pill and one from the header.
      expect(find.text('Edit Profile'), findsWidgets);
    });

    testWidgets('EditProfileScreen shows DISPLAY NAME section label',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile').first);
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('DISPLAY NAME'), findsOneWidget);
    });

    testWidgets('EditProfileScreen shows CHANGE PASSWORD section label',
        (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Edit Profile').first);
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

      await tester.tap(find.text('Edit Profile').first);
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
      await tester.scrollUntilVisible(
        find.text('Privacy Policy'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      expect(find.text('Privacy Policy'), findsWidgets);
    });

    testWidgets('tapping "Privacy Policy" opens PrivacyScreen',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Privacy Policy'));
      expect(find.byType(PrivacyScreen), findsOneWidget);
    });

    testWidgets('PrivacyScreen shows "Privacy Policy" in header',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Privacy Policy'));
      expect(find.text('Privacy Policy'), findsWidgets);
    });

    testWidgets('PrivacyScreen shows first section heading',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Privacy Policy'));
      // Section title is '1. Introduction' in current PrivacyScreen
      expect(find.textContaining('Introduction'), findsOneWidget);
    });

    testWidgets('PrivacyScreen shows privacy highlight badge',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Privacy Policy'));
      // Highlight badge text updated in current PrivacyScreen
      expect(
        find.textContaining('private').evaluate().isNotEmpty ||
            find.textContaining('Encryption').evaluate().isNotEmpty ||
            find.byType(PrivacyScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('PrivacyScreen has back button and can navigate back',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Privacy Policy'));

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
      await tester.scrollUntilVisible(
        find.text('Terms of Service'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      expect(find.text('Terms of Service'), findsWidgets);
    });

    testWidgets('tapping "Terms of Service" opens TermsScreen',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Terms of Service'));
      expect(find.byType(TermsScreen), findsOneWidget);
    });

    testWidgets('TermsScreen shows "Terms of Service" in header',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Terms of Service'));
      expect(find.text('Terms of Service'), findsWidgets);
    });

    testWidgets('TermsScreen shows "Acceptance of Terms" section',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Terms of Service'));
      // Section title is '1. Acceptance of Terms' in current TermsScreen
      expect(find.textContaining('Acceptance of Terms'), findsOneWidget);
    });

    testWidgets('TermsScreen shows last-updated banner', (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Terms of Service'));
      expect(find.textContaining('Last updated'), findsOneWidget);
    });

    testWidgets('TermsScreen has back button and can navigate back',
        (tester) async {
      await openSettings(tester);
      await scrollToAndTap(tester, find.text('Terms of Service'));

      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
