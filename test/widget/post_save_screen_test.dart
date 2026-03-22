import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime.now();

  const testData = PostSaveData(
    entryId: 'test-entry-id',
    title: 'A Great Day at the Beach',
    content: 'Today I went on a trip to the beach with my family. It was a great adventure and I felt grateful for the experience.',
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
      title: 'Beach Memories',
      chapterNumber: 2,
      startDate: DateTime(2025, 1, 1),
      createdAt: now,
    ),
  ];

  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        ...authenticatedOverrides(),
        chaptersProvider.overrideWith((ref) async => testChapters),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PostSaveScreen(data: testData),
      ),
    );
  }

  group('PostSaveScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(PostSaveScreen), findsOneWidget);
    });

    testWidgets('shows Add to Chapter header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // PostSaveScreen now shows chapter selection as step 0
      expect(find.text('Add to Chapter'), findsOneWidget);
    });

    testWidgets('shows Continue button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows chapter cards from provider', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('My Story 2026'), findsWidgets);
      expect(find.textContaining('Beach Memories'), findsWidgets);
    });

    testWidgets('shows Create New Chapter button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Create New Chapter'), findsOneWidget);
    });
  });

  group('PostSaveScreen - Header', () {
    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows chapter selection prompt', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('chapter'),
        findsWidgets,
      );
    });
  });
}
