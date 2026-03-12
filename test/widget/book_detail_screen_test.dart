import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/book/presentation/screens/book_detail_screen.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final mockGeneratedBook = GeneratedBook(
    id: 'gen-book-id',
    title: 'My Life Story',
    author: 'Test Author',
    dateRange: 'Jan 2026 - Mar 2026',
    createdAt: DateTime.now(),
    chapters: const [
      BookChapter(
        title: 'Chapter 1',
        startPage: 1,
        pages: [
          BookPage(
            pageNumber: 1,
            type: BookPageType.chapterDivider,
            content: 'Chapter 1',
            chapterTitle: 'Chapter 1',
          ),
          BookPage(
            pageNumber: 2,
            type: BookPageType.entryContent,
            content: 'This is a wonderful memory from my life.',
            dateLabel: 'January 15, 2026',
          ),
        ],
      ),
    ],
    allPages: const [
      BookPage(
        pageNumber: 0,
        type: BookPageType.titlePage,
        content: 'My Life Story',
      ),
      BookPage(
        pageNumber: 1,
        type: BookPageType.chapterDivider,
        content: 'Chapter 1',
        chapterTitle: 'Chapter 1',
      ),
      BookPage(
        pageNumber: 2,
        type: BookPageType.entryContent,
        content: 'This is a wonderful memory from my life.',
        dateLabel: 'January 15, 2026',
      ),
    ],
    sourceEntries: const [],
  );

  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.light,
      home: BookDetailScreen(book: mockGeneratedBook),
    );
  }

  group('BookDetailScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BookDetailScreen), findsOneWidget);
    });

    testWidgets('shows DEARDAYS header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('DEARDAYS'), findsOneWidget);
    });

    testWidgets('shows book title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('My Life Story'), findsWidgets);
    });

    testWidgets('shows date range', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Date range is uppercased in the cover section
      expect(find.text('JAN 2026 - MAR 2026'), findsOneWidget);
    });
  });

  group('BookDetailScreen - Actions', () {
    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.arrow_back_ios,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Memoir mode selector', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Memoir'), findsOneWidget);
    });
  });
}
