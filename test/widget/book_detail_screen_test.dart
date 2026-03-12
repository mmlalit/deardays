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

    testWidgets('shows book cover with title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('My Life Story'), findsOneWidget);
    });

    testWidgets('shows author name on cover', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Test Author'), findsOneWidget);
    });

    testWidgets('shows date range on cover', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Jan 2026 - Mar 2026'), findsOneWidget);
    });
  });

  group('BookDetailScreen - Actions', () {
    testWidgets('shows Read button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('shows search icon', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.search,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows page and chapter count', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('3 pages'), findsOneWidget);
      expect(find.text('1 chapters'), findsOneWidget);
    });
  });
}
