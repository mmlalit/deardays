import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime.now();

  final mockChapters = [
    Chapter(
      id: 'ch-1',
      userId: 'test-user-id',
      title: 'Family',
      chapterNumber: 1,
      startDate: now.subtract(const Duration(days: 90)),
      entryCount: 12,
      createdAt: now,
    ),
    Chapter(
      id: 'ch-2',
      userId: 'test-user-id',
      title: 'Career',
      chapterNumber: 2,
      startDate: now.subtract(const Duration(days: 60)),
      entryCount: 5,
      createdAt: now,
    ),
  ];

  List<Override> bookOverrides({List<Chapter> chapters = const []}) => [
        ...authenticatedOverrides(),
        chaptersProvider.overrideWith((ref) async => chapters),
      ];

  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BookCreationScreen(),
      ),
    );
  }

  // ── Structure ──────────────────────────────────────────────────────────────

  group('BookCreationScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BookCreationScreen), findsOneWidget);
    });

    testWidgets('shows Create a Book header', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Create a Book'), findsOneWidget);
    });
  });

  // ── Approach cards ─────────────────────────────────────────────────────────

  group('BookCreationScreen - Approach cards', () {
    testWidgets('shows Chronological and Thematic cards', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chronological'), findsOneWidget);
      expect(find.text('Thematic'), findsOneWidget);
    });

    testWidgets('does NOT show old approach names', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Pick & Choose'), findsNothing);
      expect(find.text('Daily Diary'), findsNothing);
      expect(find.text('AI Surprise Me'), findsNothing);
    });

    testWidgets('shows taglines for both approaches', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('One continuous life story'), findsOneWidget);
      expect(find.text('Separate stories by theme'), findsOneWidget);
    });

    testWidgets('shows descriptions for both approaches', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('week by week'), findsOneWidget);
      expect(find.textContaining('Each chapter tells its own story'), findsOneWidget);
    });

    testWidgets('shows bullet points for Chronological', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chapters auto-created by month'), findsOneWidget);
      expect(find.text('AI maintains continuity between pages'), findsOneWidget);
    });

    testWidgets('shows bullet points for Thematic', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('You create and name chapters'), findsOneWidget);
      expect(find.text('Each chapter has its own narrative arc'), findsOneWidget);
    });
  });

  // ── Chronological flow ─────────────────────────────────────────────────────

  group('BookCreationScreen - Chronological flow', () {
    testWidgets('tapping Chronological shows its flow', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Chronological').first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('BOOK TITLE'), findsOneWidget);
      expect(find.text('How it works'), findsOneWidget);
    });

    testWidgets('Chronological flow has a Create Book button', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Chronological').first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Create Book'), findsOneWidget);
    });

    testWidgets('Chronological back button returns to selection', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Chronological').first);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chronological'), findsOneWidget);
      expect(find.text('Thematic'), findsOneWidget);
    });

    testWidgets('Chronological shows entry count stat', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Chronological').first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
    });

    testWidgets('Chronological shows info banner about Saturday generation',
        (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Chronological').first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Every Saturday'), findsOneWidget);
    });
  });

  // ── Thematic flow ──────────────────────────────────────────────────────────

  group('BookCreationScreen - Thematic flow', () {
    testWidgets('tapping Thematic shows its flow', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle(); // wait for chaptersProvider future

      expect(find.text('BOOK TITLE'), findsOneWidget);
    });

    testWidgets('Thematic flow shows available chapters', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Career'), findsOneWidget);
    });

    testWidgets('Thematic flow shows memory count per chapter', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      expect(find.text('12 memories'), findsOneWidget);
      expect(find.text('5 memories'), findsOneWidget);
    });

    testWidgets('Thematic create button disabled when no chapters selected',
        (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      expect(find.text('Select at least one chapter'), findsOneWidget);
    });

    testWidgets('Thematic create button enabled after selecting a chapter',
        (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      // Tap the Family chapter tile
      await tester.tap(find.text('Family'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Create Book (1 chapters)'), findsOneWidget);
    });

    testWidgets('Thematic shows empty state when no chapters exist',
        (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: [],
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      expect(find.text('No chapters yet'), findsOneWidget);
      expect(find.textContaining('Create chapters in the Chapters tab'), findsOneWidget);
    });

    testWidgets('Thematic back button returns to selection', (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chronological'), findsOneWidget);
      expect(find.text('Thematic'), findsOneWidget);
    });

    testWidgets('Thematic CHAPTERS header shows selection count',
        (tester) async {
      await tester.pumpWidget(buildApp(overrides: bookOverrides(
        chapters: mockChapters,
      )));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Thematic').first);
      await tester.pumpAndSettle();

      // Initially 0 selected
      expect(find.textContaining('0 selected'), findsOneWidget);

      // Select one chapter
      await tester.tap(find.text('Family'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('1 selected'), findsOneWidget);
    });
  });
}
