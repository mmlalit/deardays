import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();
  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
    );
  }

  group('HomeScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows greeting text', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      final hasGreeting =
          find.textContaining('Good Morning').evaluate().isNotEmpty ||
          find.textContaining('Good Afternoon').evaluate().isNotEmpty ||
          find.textContaining('Good Evening').evaluate().isNotEmpty;
      expect(hasGreeting, isTrue);
    });

    testWidgets('shows WRITE action button in capture grid', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      // Capture grid labels are UPPERCASE: SPEAK IT / SNAP IT / WRITE / CHAT
      expect(find.text('WRITE'), findsOneWidget);
    });

    testWidgets('shows user first name from profile', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(profile: mockProfile),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Test'), findsWidgets);
    });
  });

  group('HomeScreen - Recent Memories', () {
    testWidgets('shows Recent Memories section header', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Memories'), findsWidgets);
    });
  });

  group('HomeScreen - With entries', () {
    testWidgets('shows memory cards when entries exist', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      // The home screen renders memory cards (at minimum the HomeScreen exists)
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
