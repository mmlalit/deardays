import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BookCreationScreen(),
      ),
    );
  }

  group('BookCreationScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BookCreationScreen), findsOneWidget);
    });

    testWidgets('shows Create a Book header', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Create a Book'), findsOneWidget);
    });
  });

  group('BookCreationScreen - Approach cards', () {
    testWidgets('shows 3 creation approach cards', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Pick & Choose'), findsOneWidget);
      expect(find.text('Daily Diary'), findsOneWidget);
      expect(find.text('AI Surprise Me'), findsOneWidget);
    });

    testWidgets('shows approach descriptions', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('Manually select which entries'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pick a date range'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Let AI curate'),
        findsOneWidget,
      );
    });

    testWidgets('cards are tappable - Pick & Choose navigates to flow',
        (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Pick & Choose card
      await tester.tap(find.text('Pick & Choose'));
      await tester.pump(const Duration(milliseconds: 500));

      // After tapping, the approach selection should be replaced by the flow
      // The Pick & Choose flow shows a "Book Title" text field
      expect(find.text('Book Title'), findsOneWidget);
    });
  });
}
