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

      // If we got here, it rendered successfully
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows greeting text', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pumpAndSettle();

      final hasGreeting =
          find.textContaining('Good morning').evaluate().isNotEmpty ||
          find.textContaining('Good afternoon').evaluate().isNotEmpty ||
          find.textContaining('Good evening').evaluate().isNotEmpty;
      expect(hasGreeting, isTrue);
    });

    testWidgets('shows streak when streak > 0', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(streak: mockStreak),
      ));
      await tester.pumpAndSettle();

      // mockStreak has currentStreak = 3
      expect(find.textContaining('streak'), findsWidgets);
    });

    testWidgets('shows user first name from profile', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(profile: mockProfile),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Test'), findsWidgets);
    });
  });

  group('HomeScreen - Mood picker (first check-in)', () {
    testWidgets('shows mood selection on first check-in', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pumpAndSettle();

      // First check-in: mood picker should be visible
      final hasMoodPicker =
          find.text('Great').evaluate().isNotEmpty ||
          find.text('Good').evaluate().isNotEmpty ||
          find.textContaining('feeling').evaluate().isNotEmpty ||
          find.textContaining('mood').evaluate().isNotEmpty;
      expect(hasMoodPicker, isTrue);
    });
  });

  group('HomeScreen - On This Day card', () {
    testWidgets('shows On This Day section when entries exist', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await tester.pumpAndSettle();

      // Scroll down to find the card
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.textContaining('On This Day'), findsWidgets);
    });
  });
}
