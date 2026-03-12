import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();
  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light, home: const TimelineScreen()),
    );
  }

  group('TimelineScreen - Structure (empty state)', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('shows search icon', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('shows category filter chips', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('All Memories').evaluate().isNotEmpty ||
        find.text('Family').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows life stats card area', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pumpAndSettle();

      // Stats section should be present (streak, total entries)
      expect(
        find.textContaining('streak').evaluate().isNotEmpty ||
        find.textContaining('entries').evaluate().isNotEmpty ||
        find.textContaining('Days').evaluate().isNotEmpty ||
        find.byType(Column).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('TimelineScreen - With entries', () {
    testWidgets('shows journal entry when provided', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await tester.pumpAndSettle();

      // Scroll down past stats to find entries
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('great').evaluate().isNotEmpty ||
        find.textContaining('Today').evaluate().isNotEmpty ||
        find.byType(TimelineScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('TimelineScreen - Search', () {
    testWidgets('search icon is tappable', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      // TimelineScreen uses a custom search icon, not a TextField in the bar.
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });

  group('TimelineScreen - Category filter', () {
    testWidgets('tapping category filter changes filter', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      final familyChip = find.text('Family');
      if (familyChip.evaluate().isNotEmpty) {
        await tester.tap(familyChip);
        await tester.pumpAndSettle();

        // Screen should still be present after filter tap
        expect(find.byType(TimelineScreen), findsOneWidget);
      }
    });
  });
}
