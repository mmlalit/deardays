import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';

enum BookMode {
  stream,    // All memories chronologically, no grouping
  byTime,    // Grouped year → month
  byChapter, // Grouped by user-defined chapters
}

/// A single page in the book reader.
sealed class BookPage {
  const BookPage();
}

// ── Front matter ──────────────────────────────────────────────────────────────

class CoverBookPage extends BookPage {
  final String title;
  final String? authorName;
  final String dateRange;
  final int memoryCount;
  const CoverBookPage({
    required this.title,
    required this.dateRange,
    required this.memoryCount,
    this.authorName,
  });
}

class TitleBookPage extends BookPage {
  final String title;
  final String subtitle;
  final String dateRange;
  const TitleBookPage({
    required this.title,
    required this.subtitle,
    required this.dateRange,
  });
}

class IntroductionBookPage extends BookPage {
  final String text;
  const IntroductionBookPage({required this.text});
}

// ── Table of contents ─────────────────────────────────────────────────────────

class TocEntry {
  final String label;
  final String? meta;
  final int pageIndex;
  final bool isSubEntry;
  const TocEntry({
    required this.label,
    this.meta,
    required this.pageIndex,
    this.isSubEntry = false,
  });
}

class TocBookPage extends BookPage {
  final List<TocEntry> entries;
  const TocBookPage({required this.entries});
}

// ── Section dividers ──────────────────────────────────────────────────────────

class YearDividerPage extends BookPage {
  final int year;
  final int memoryCount;
  const YearDividerPage({required this.year, required this.memoryCount});
}

class MonthDividerPage extends BookPage {
  final int year;
  final int month;
  final int memoryCount;
  final String reflection; // factual: "You wrote N times in Month."
  const MonthDividerPage({
    required this.year,
    required this.month,
    required this.memoryCount,
    required this.reflection,
  });
}

class ChapterDividerPage extends BookPage {
  final Chapter chapter;
  final int chapterIndex; // 0-based, used for "CHAPTER ONE" label
  final int memoryCount;
  const ChapterDividerPage({
    required this.chapter,
    required this.chapterIndex,
    required this.memoryCount,
  });
}

// ── Body pages ────────────────────────────────────────────────────────────────

class MemoryBookPage extends BookPage {
  final JournalEntry entry;
  final bool isFirstInSection; // receives drop cap when true
  const MemoryBookPage({
    required this.entry,
    required this.isFirstInSection,
  });
}

class TimeBridgePage extends BookPage {
  final String label; // "12 days later", "A month later", etc.
  const TimeBridgePage({required this.label});
}

// ── Back matter ───────────────────────────────────────────────────────────────

class ClosingBookPage extends BookPage {
  final int totalMemories;
  final String startDateLabel; // "March 2023"
  const ClosingBookPage({
    required this.totalMemories,
    required this.startDateLabel,
  });
}
