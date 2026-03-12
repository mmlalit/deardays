import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Reading mode for the auto-generated "My Life Story" book.
enum BookViewMode { byYear, byChapter }

/// A year section within the By Year view.
class YearSection {
  final int year;
  final String aiTitle; // e.g., "Year of New Beginnings"
  final List<BookChapter> months; // each month is a "chapter" within the year

  const YearSection({
    required this.year,
    required this.aiTitle,
    required this.months,
  });
}

/// A theme-based chapter within the By Chapter view.
class ThemeChapter {
  final String category; // Family, Career, Travel, Celebrations, Reflections, Daily Life
  final String icon; // emoji
  final String aiSubtitle; // e.g., "The Ones Who Matter"
  final List<BookPage> pages;
  final int startPage;

  const ThemeChapter({
    required this.category,
    required this.icon,
    required this.aiSubtitle,
    required this.pages,
    required this.startPage,
  });
}

/// A page within a generated book.
class BookPage {
  final int pageNumber;
  final BookPageType type;
  final String content;
  final String? chapterTitle;
  final String? dateLabel;
  final String? mood;
  final String? locationName;

  const BookPage({
    required this.pageNumber,
    required this.type,
    required this.content,
    this.chapterTitle,
    this.dateLabel,
    this.mood,
    this.locationName,
  });
}

enum BookPageType {
  titlePage,
  tableOfContents,
  chapterDivider,
  entryContent,
}

/// A chapter within a generated book.
class BookChapter {
  final String title;
  final int startPage;
  final List<BookPage> pages;

  const BookChapter({
    required this.title,
    required this.startPage,
    required this.pages,
  });
}

/// A fully generated book ready for reading.
class GeneratedBook {
  final String id;
  final String title;
  final String author;
  final String dateRange;
  final DateTime createdAt;
  final List<BookChapter> chapters;
  final List<BookPage> allPages;
  final List<JournalEntry> sourceEntries;

  /// Auto-book fields: By Year view
  final List<YearSection> yearSections;

  /// Auto-book fields: By Chapter (theme) view
  final List<ThemeChapter> themeChapters;

  /// Separate page lists for each view mode
  final List<BookPage> yearPages;
  final List<BookPage> chapterPages;

  const GeneratedBook({
    required this.id,
    required this.title,
    required this.author,
    required this.dateRange,
    required this.createdAt,
    required this.chapters,
    required this.allPages,
    required this.sourceEntries,
    this.yearSections = const [],
    this.themeChapters = const [],
    this.yearPages = const [],
    this.chapterPages = const [],
  });

  int get pageCount => allPages.length;
  int get chapterCount => chapters.length;
}

/// Approach chosen for book creation.
enum BookCreationApproach {
  pickAndChoose,
  dailyDiary,
  aiSurprise,
}
