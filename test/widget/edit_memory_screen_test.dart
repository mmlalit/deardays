import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime.now();

  // polishedContent format: "Title\n\nBody" — title is first non-empty line,
  // body is remaining lines. EditMemoryScreen parses this in initState.
  final testEntry = JournalEntry(
    id: 'test-entry-id',
    userId: 'test-user-id',
    content: 'Walking through the park, I noticed the cherry blossoms blooming.',
    rawContent: 'Walking through the park, I noticed the cherry blossoms blooming.',
    polishedContent:
        'A Beautiful Morning\n\nWalking through the park, I noticed the cherry blossoms blooming.',
    mood: 'great',
    entryDate: now,
    wordCount: 13,
    createdAt: now,
    updatedAt: now,
  );

  Widget buildApp() {
    return buildTestApp(
      EditMemoryScreen(entry: testEntry),
      overrides: authenticatedOverrides(),
    );
  }

  group('EditMemoryScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EditMemoryScreen), findsOneWidget);
    });

    testWidgets('shows title text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // The title controller is pre-filled with first line of polishedContent
      expect(find.text('A Beautiful Morning'), findsOneWidget);
    });

    testWidgets('shows story text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('cherry blossoms'),
        findsOneWidget,
      );
    });

    testWidgets('renders text fields for editing', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });
  });
}
