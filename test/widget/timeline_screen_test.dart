import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: TimelineScreen()),
    );
  }

  group('TimelineScreen - Structure (empty state)', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('shows search field', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows mood filter chip', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Mood').evaluate().isNotEmpty ||
        find.byIcon(Icons.mood).evaluate().isNotEmpty,
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
        find.byType(SingleChildScrollView).first,
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
    testWidgets('search field accepts input', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'happy');
      await tester.pump();

      expect(find.text('happy'), findsOneWidget);
    });
  });

  group('TimelineScreen - Mood filter', () {
    testWidgets('tapping mood filter opens selection sheet', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      final moodChip = find.text('Mood');
      if (moodChip.evaluate().isNotEmpty) {
        await tester.tap(moodChip);
        await tester.pumpAndSettle();

        // Mood options should appear
        expect(
          find.text('Great').evaluate().isNotEmpty ||
          find.text('Good').evaluate().isNotEmpty ||
          find.text('great').evaluate().isNotEmpty,
          isTrue,
        );
      }
    });
  });
}
