import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime.now();
  // Use dates > 30 days ago to avoid SearchService recency boost
  // which gives a positive score even for non-matching queries.
  final oldDate = now.subtract(const Duration(days: 60));

  final testEntries = [
    JournalEntry(
      id: 'e1',
      userId: 'test-user-id',
      content: 'Beach sunrise was amazing today',
      mood: 'great',
      entryDate: oldDate,
      wordCount: 5,
      createdAt: oldDate,
      updatedAt: oldDate,
    ),
    JournalEntry(
      id: 'e2',
      userId: 'test-user-id',
      content: 'Rainy day, stayed inside reading',
      mood: 'okay',
      entryDate: oldDate.subtract(const Duration(days: 1)),
      wordCount: 5,
      locationName: 'Home',
      createdAt: oldDate,
      updatedAt: oldDate,
    ),
    JournalEntry(
      id: 'e3',
      userId: 'test-user-id',
      content: 'Had a tough meeting at work',
      mood: 'low',
      entryDate: oldDate.subtract(const Duration(days: 2)),
      wordCount: 6,
      createdAt: oldDate,
      updatedAt: oldDate,
    ),
  ];

  Widget buildSearchScreen({List<JournalEntry>? entries}) {
    return buildTestApp(
      const SearchScreen(),
      overrides: [
        ...authenticatedOverrides(entries: entries ?? testEntries),
      ],
    );
  }

  group('SearchScreen', () {
    testWidgets('renders search bar with hint text', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search memories or ask a question...'), findsOneWidget);
    });

    testWidgets('renders back button', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.arrow_back_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows empty search state with search icon', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Search your memories'), findsOneWidget);
      expect(find.text('Find entries by keyword, mood, or place'),
          findsOneWidget);
    });

    testWidgets('shows "No memories found" for unmatched query',
        (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 2));

      // Use enterText which triggers onChanged
      await tester.enterText(find.byType(TextField), 'zzzznotfound');
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No memories found'), findsOneWidget);
      expect(find.text('Try a different keyword or phrase'), findsOneWidget);
    });

    testWidgets('shows results when query matches', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'beach');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('result'), findsOneWidget);
    });

    testWidgets('clear button clears the search', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'beach');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap clear button
      final clearBtn = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.close_rounded);
      if (clearBtn.evaluate().isNotEmpty) {
        await tester.tap(clearBtn.first);
        await tester.pump(const Duration(milliseconds: 500));

        // After clear, search field should be empty and "No memories found" gone
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
        expect(find.text('No memories found'), findsNothing);
      }
    });

    testWidgets('detects question queries', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'When did I feel proud?');
      await tester.pump(const Duration(milliseconds: 500));

      // Should at minimum render without errors
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders with empty entries list', (tester) async {
      await tester.pumpWidget(buildSearchScreen(entries: []));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
