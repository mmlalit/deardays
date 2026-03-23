import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final _now = DateTime.now();

  // Entry with no AI story
  Widget buildApp() {
    return buildTestApp(
      MemoryDetailScreen(entry: mockEntry),
      overrides: authenticatedOverrides(),
    );
  }

  // Entry with AI story (polishedContent set)
  Widget buildAiApp() {
    final aiEntry = JournalEntry(
      id: 'ai-entry-id',
      userId: 'test-user-id',
      content: 'Today was a great day.',
      rawContent: 'Today was a great day.',
      polishedContent: 'The light fell softly as the day unfolded with quiet joy.',
      isAiPolished: true,
      mood: 'great',
      entryDate: _now,
      wordCount: 6,
      createdAt: _now,
      updatedAt: _now,
    );
    return buildTestApp(
      MemoryDetailScreen(entry: aiEntry),
      overrides: authenticatedOverrides(),
    );
  }

  group('MemoryDetailScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MemoryDetailScreen), findsOneWidget);
    });

    testWidgets('shows entry content', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Today was a great day'), findsWidgets);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows back navigation', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.arrow_back_rounded),
        findsWidgets,
      );
    });
  });

  group('MemoryDetailScreen - AI Story toggle', () {
    testWidgets('toggle not shown for non-AI-polished entry', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('✨ AI Story'), findsNothing);
      expect(find.text('My Words'), findsNothing);
    });

    testWidgets('toggle shown for AI-polished entry', (tester) async {
      await tester.pumpWidget(buildAiApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('✨ AI Story'), findsOneWidget);
      expect(find.text('My Words'), findsOneWidget);
    });

    testWidgets('AI Story content shown by default for AI-polished entry', (tester) async {
      await tester.pumpWidget(buildAiApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('The light fell softly'),
        findsWidgets,
      );
    });

    testWidgets('tapping My Words switches to polished content', (tester) async {
      await tester.pumpWidget(buildAiApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('My Words'));
      await tester.pump(const Duration(milliseconds: 300));

      // AI Story content is gone, original polished content shown
      expect(find.textContaining('Today was a great day'), findsWidgets);
    });
  });
}
