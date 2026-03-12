import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/book/data/services/book_generator_service.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';

/// Helper to create a minimal JournalEntry for testing.
JournalEntry _makeEntry({
  required String id,
  required String content,
  required DateTime entryDate,
  String? mood,
  bool isMilestone = false,
  bool isAiPolished = false,
  bool hasPhoto = false,
  String? locationName,
  int? wordCount,
}) {
  return JournalEntry(
    id: id,
    userId: 'test-user',
    content: content,
    mood: mood,
    entryDate: entryDate,
    locationName: locationName,
    isMilestone: isMilestone,
    isAiPolished: isAiPolished,
    hasPhoto: hasPhoto,
    wordCount: wordCount ?? content.split(RegExp(r'\s+')).length,
    createdAt: entryDate,
    updatedAt: entryDate,
  );
}

void main() {
  late BookGeneratorService service;

  setUp(() {
    service = BookGeneratorService();
  });

  group('BookGeneratorService — generateAutoBook', () {
    test('creates a GeneratedBook with yearPages and chapterPages', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'Visited my family at home for the holidays.',
          entryDate: DateTime(2025, 3, 10),
          mood: 'great',
        ),
        _makeEntry(
          id: '2',
          content: 'Had a big meeting at the office with the boss.',
          entryDate: DateTime(2025, 6, 15),
          mood: 'good',
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Test Author',
      );

      expect(book, isA<GeneratedBook>());
      expect(book.title, 'My Life Story');
      expect(book.author, 'Test Author');
      expect(book.yearPages, isNotEmpty);
      expect(book.chapterPages, isNotEmpty);
      expect(book.yearSections, isNotEmpty);
      expect(book.themeChapters, isNotEmpty);
      expect(book.sourceEntries.length, 2);
    });

    test('auto-detects Travel category for entries with travel keywords', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'Took a trip to the airport and caught a flight to the beach destination.',
          entryDate: DateTime(2025, 1, 5),
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Author',
      );

      // The entry should appear in the Travel theme chapter
      final travelChapter = book.themeChapters.where(
        (c) => c.category == 'Travel',
      );
      expect(travelChapter, isNotEmpty);
    });

    test('auto-detects Family category for entries with family keywords', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'Spent the day with mom and dad and the kids at home.',
          entryDate: DateTime(2025, 2, 14),
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Author',
      );

      final familyChapter = book.themeChapters.where(
        (c) => c.category == 'Family',
      );
      expect(familyChapter, isNotEmpty);
    });

    test('generates year sections with AI titles', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'A wonderful start to the year.',
          entryDate: DateTime(2024, 1, 10),
          mood: 'great',
        ),
        _makeEntry(
          id: '2',
          content: 'Another great day.',
          entryDate: DateTime(2025, 5, 20),
          mood: 'good',
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Author',
      );

      expect(book.yearSections.length, 2);
      // Each year section should have an AI title
      for (final section in book.yearSections) {
        expect(section.aiTitle, isNotEmpty);
        expect(section.aiTitle, startsWith('Year of'));
      }
      // Years should be 2024 and 2025
      final years = book.yearSections.map((s) => s.year).toList();
      expect(years, contains(2024));
      expect(years, contains(2025));
    });

    test('generates theme chapters with subtitles', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'Family dinner with mom and dad and the kids.',
          entryDate: DateTime(2025, 3, 1),
        ),
        _makeEntry(
          id: '2',
          content: 'Office meeting with the boss about the project deadline.',
          entryDate: DateTime(2025, 3, 15),
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Author',
      );

      expect(book.themeChapters.length, greaterThanOrEqualTo(2));
      for (final chapter in book.themeChapters) {
        expect(chapter.category, isNotEmpty);
        expect(chapter.icon, isNotEmpty);
        expect(chapter.aiSubtitle, isNotEmpty);
      }
    });

    test('handles empty entry list gracefully', () {
      final book = service.generateAutoBook(
        allEntries: [],
        author: 'Author',
      );

      expect(book, isA<GeneratedBook>());
      expect(book.title, 'My Life Story');
      expect(book.sourceEntries, isEmpty);
      // Should still have title page and TOC
      expect(book.yearPages.length, greaterThanOrEqualTo(2));
      expect(book.yearSections, isEmpty);
      expect(book.themeChapters, isEmpty);
    });

    test('page splitting works for entries > 250 words', () {
      // Create content with more than 250 words
      final longContent = List.generate(300, (i) => 'word$i').join(' ');
      final entries = [
        _makeEntry(
          id: '1',
          content: longContent,
          entryDate: DateTime(2025, 4, 1),
          wordCount: 300,
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Author',
      );

      // Count entry content pages (excluding title, TOC, chapter dividers)
      final entryPages = book.yearPages.where(
        (p) => p.type == BookPageType.entryContent,
      );
      // 300 words / 250 per page = 2 pages
      expect(entryPages.length, greaterThanOrEqualTo(2));
    });

    test('all pages have valid page numbers', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'Family day with mom.',
          entryDate: DateTime(2025, 1, 1),
          mood: 'great',
        ),
        _makeEntry(
          id: '2',
          content: 'Trip to the beach hotel.',
          entryDate: DateTime(2025, 6, 1),
          mood: 'good',
        ),
        _makeEntry(
          id: '3',
          content: 'Office meeting with colleagues about the project.',
          entryDate: DateTime(2025, 9, 1),
        ),
      ];

      final book = service.generateAutoBook(
        allEntries: entries,
        author: 'Author',
      );

      // Year pages: sequential from 1
      for (int i = 0; i < book.yearPages.length; i++) {
        expect(book.yearPages[i].pageNumber, i + 1);
      }

      // Chapter pages: sequential from 1
      for (int i = 0; i < book.chapterPages.length; i++) {
        expect(book.chapterPages[i].pageNumber, i + 1);
      }
    });
  });

  group('BookGeneratorService — generateFromEntries', () {
    test('creates book with title page and table of contents', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'Hello world.',
          entryDate: DateTime(2025, 5, 1),
        ),
      ];

      final book = service.generateFromEntries(
        entries: entries,
        title: 'My Book',
        author: 'Author',
      );

      expect(book.allPages.first.type, BookPageType.titlePage);
      expect(book.allPages[1].type, BookPageType.tableOfContents);
      expect(book.title, 'My Book');
      expect(book.author, 'Author');
    });

    test('auto-organizes entries by month when no chapterMap provided', () {
      final entries = [
        _makeEntry(
          id: '1',
          content: 'January entry.',
          entryDate: DateTime(2025, 1, 10),
        ),
        _makeEntry(
          id: '2',
          content: 'March entry.',
          entryDate: DateTime(2025, 3, 15),
        ),
      ];

      final book = service.generateFromEntries(
        entries: entries,
        title: 'Test',
        author: 'Author',
      );

      // Should have 2 chapters (one per month)
      expect(book.chapters.length, 2);
    });

    test('uses provided chapterMap for organization', () {
      final jan = _makeEntry(
        id: '1',
        content: 'January.',
        entryDate: DateTime(2025, 1, 5),
      );
      final feb = _makeEntry(
        id: '2',
        content: 'February.',
        entryDate: DateTime(2025, 2, 10),
      );

      final book = service.generateFromEntries(
        entries: [jan, feb],
        title: 'Custom',
        author: 'Author',
        chapterMap: {
          'Chapter One': [jan, feb],
        },
      );

      expect(book.chapters.length, 1);
      expect(book.chapters.first.title, 'Chapter One');
    });

    test('sorts entries by date', () {
      final entries = [
        _makeEntry(
          id: '2',
          content: 'Later entry.',
          entryDate: DateTime(2025, 6, 1),
        ),
        _makeEntry(
          id: '1',
          content: 'Earlier entry.',
          entryDate: DateTime(2025, 1, 1),
        ),
      ];

      final book = service.generateFromEntries(
        entries: entries,
        title: 'Test',
        author: 'Author',
      );

      expect(book.sourceEntries.first.id, '1');
      expect(book.sourceEntries.last.id, '2');
    });
  });
}
