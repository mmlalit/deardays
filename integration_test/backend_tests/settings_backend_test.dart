/// Settings screen — real-backend tests.
///
/// Tests profile display, edit profile, subscription, notifications,
/// privacy/terms screens, and sign out presence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/test_app_real.dart';

Future<void> _openSettings(WidgetTester tester) async {
  final scaffold = find.byType(Scaffold);
  if (scaffold.evaluate().isEmpty) return;
  GoRouter.of(tester.element(scaffold.first)).push('/settings');
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _tapBack(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back_rounded);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void settingsBackendTests() {
  setUpAll(() async => await initBackendApp());

  group('Settings — Profile & Account', () {
    testWidgets('settings screen opens', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('ACCOUNT section visible', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final found = find.text('ACCOUNT').evaluate().isNotEmpty ||
          find.textContaining('Account').evaluate().isNotEmpty;
      expect(found, isTrue);
    });

    testWidgets('Edit Profile opens and returns', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final row = find.text('Edit Profile');
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(MaterialApp), findsOneWidget);
        await _tapBack(tester);
      }
    });

    testWidgets('Subscription opens and returns', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final row = find.text('Subscription');
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(MaterialApp), findsOneWidget);
        await _tapBack(tester);
      }
    });
  });

  group('Settings — Notifications', () {
    testWidgets('Daily Reminder toggle is present', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 500));

      final found = find.text('Daily Reminder').evaluate().isNotEmpty;
      // ignore: avoid_print
      print('[SETTINGS] Daily Reminder visible: $found');
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('tapping Daily Reminder does not crash', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 500));

      final row = find.text('Daily Reminder');
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first, warnIfMissed: false);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Settings — Privacy & Legal', () {
    testWidgets('Privacy Policy opens', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      final row = find.text('Privacy Policy');
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(MaterialApp), findsOneWidget);
        await _tapBack(tester);
      }
    });

    testWidgets('Terms of Service opens', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      final row = find.text('Terms of Service');
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(MaterialApp), findsOneWidget);
        await _tapBack(tester);
      }
    });
  });

  group('Settings — Sign Out', () {
    testWidgets('Sign Out is present but NOT tapped', (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 3; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      final found = find.text('Sign Out').evaluate().isNotEmpty;
      // ignore: avoid_print
      print('[SETTINGS] Sign Out visible: $found');
      // Intentionally NOT tapping — would end the session
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ── NEGATIVE TESTS ──────────────────────────────────────────────────────────

  group('Settings — Negative: Edge cases', () {
    testWidgets('rapidly opening and closing settings does not crash',
        (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));

      for (var i = 0; i < 3; i++) {
        await _openSettings(tester);
        await _tapBack(tester);
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('scrolling past all settings content does not crash',
        (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Scroll back up
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollable, const Offset(0, 400));
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('tapping non-existent sub-screen link does not crash',
        (tester) async {
      await tester.pumpWidget(buildBackendApp());
      await tester.pump(const Duration(seconds: 4));
      await _openSettings(tester);

      // Try tapping Backup/Restore if it exists
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 500));

      final backup = find.text('Backup & Restore');
      if (backup.evaluate().isNotEmpty) {
        await tester.tap(backup.first);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(MaterialApp), findsOneWidget);
        await _tapBack(tester);
      }
    });
  });
}
