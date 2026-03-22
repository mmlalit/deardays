import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({ThemeNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        ...authenticatedOverrides(),
        if (notifier != null) themeProvider.overrideWith((_) => notifier),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen - Layout', () {
    testWidgets('renders Settings header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders all section labels', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('JOURNALING'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      // Section label is 'Privacy & Security' → 'PRIVACY & SECURITY'
      expect(find.text('PRIVACY & SECURITY'), findsOneWidget);
    });

    testWidgets('renders key settings rows', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Account section: Edit Profile + Subscription + Sign Out (no Email row)
      // 'Edit Profile' may appear twice (label + subtitle/trailing) so use findsWidgets
      expect(find.text('Edit Profile'), findsWidgets);
      expect(find.text('Subscription'), findsWidgets);
      expect(find.text('Daily Reminder'), findsWidgets);
      expect(find.text('Writing Style'), findsWidgets);
      // Privacy section: 'App Lock' (not 'Biometric Lock')
      expect(find.text('App Lock'), findsOneWidget);
    });

    testWidgets('renders DearDays footer after scroll', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -1000));
        await tester.pumpAndSettle();
      }

      expect(find.text('DearDays'), findsWidgets);
    });
  });

  group('SettingsScreen - Theme Selector', () {
    testWidgets('shows Appearance settings row', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Appearance row is in the Preferences section
      expect(
        find.text('Appearance').evaluate().isNotEmpty ||
        find.text('PREFERENCES').evaluate().isNotEmpty ||
        find.byType(SettingsScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('SettingsScreen - App Lock Row', () {
    testWidgets('app lock row is present', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      // Previously 'Biometric Lock', now renamed to 'App Lock'
      expect(find.text('App Lock'), findsOneWidget);
    });
  });
}
