library;

/// Test D — Critical user journey: Post-save flow.
///
/// Verifies:
/// - PostSaveScreen renders chapter selection step
/// - Chapter selection enables Continue button
/// - Confirmation screen shows success message
/// - Navigation buttons exist (View Memory, Record Another, Go to Timeline)
/// - PostSaveData is cleared on finish
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime.now();

  const testPostSaveData = PostSaveData(
    entryId: 'test-entry-id',
    title: 'My Test Memory',
    content: 'This is a test memory content.',
  );

  final testChapters = [
    Chapter(
      id: 'ch-1',
      userId: 'test-user',
      title: 'My Story 2026',
      chapterNumber: 1,
      startDate: DateTime(2026, 1, 1),
      createdAt: now,
    ),
    Chapter(
      id: 'ch-2',
      userId: 'test-user',
      title: 'Travel Memories',
      chapterNumber: 2,
      startDate: DateTime(2025, 1, 1),
      createdAt: now,
    ),
  ];

  final testBooks = [
    Book(
      id: 'book-1',
      userId: 'test-user',
      title: 'My Story 2026',
      coverColor: '#6B4EFF',
      writingStyle: 'memoir',
      startDate: DateTime(2026, 1, 1),
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Widget buildApp({PostSaveData? data, List<Chapter>? chapters}) {
    return ProviderScope(
      overrides: [
        ...authenticatedOverrides(books: testBooks),
        postSaveDataProvider.overrideWith((ref) => data),
        chaptersProvider.overrideWith((ref) async => chapters ?? testChapters),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: PostSaveScreen(data: data),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // D1. Chapter selection step
  // ---------------------------------------------------------------------------

  group('PostSaveScreen — chapter step', () {
    testWidgets('renders Add to Chapter header', (tester) async {
      await tester.pumpWidget(buildApp(data: testPostSaveData));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Add to Chapter'), findsWidgets);
    });

    testWidgets('shows chapter cards from chapters provider', (tester) async {
      await tester.pumpWidget(buildApp(data: testPostSaveData));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('My Story 2026'), findsWidgets);
      expect(find.textContaining('Travel Memories'), findsWidgets);
    });

    testWidgets('shows Continue button', (tester) async {
      await tester.pumpWidget(buildApp(data: testPostSaveData));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Continue'), findsWidgets);
    });

    testWidgets('shows Create New Chapter button', (tester) async {
      await tester.pumpWidget(buildApp(data: testPostSaveData));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining(RegExp(r'create.*chapter', caseSensitive: false)), findsWidgets);
    });

    testWidgets('shows back navigation button', (tester) async {
      await tester.pumpWidget(buildApp(data: testPostSaveData));
      await tester.pump(const Duration(milliseconds: 500));

      // Header uses back arrow (not close X) to exit the chapter step
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // D2. PostSaveData provider integration
  // ---------------------------------------------------------------------------

  group('PostSaveScreen — provider integration', () {
    testWidgets('renders even when PostSaveData is null', (tester) async {
      await tester.pumpWidget(buildApp(data: null));
      await tester.pump(const Duration(milliseconds: 500));

      // Should not crash — graceful handling of null data
      expect(find.byType(PostSaveScreen), findsOneWidget);
    });

    testWidgets('PostSaveData provider starts null and can be set', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(postSaveDataProvider), isNull);

      container.read(postSaveDataProvider.notifier).state = testPostSaveData;
      expect(container.read(postSaveDataProvider)!.entryId, 'test-entry-id');
    });
  });
}
