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
  /// Storage path of the happiest memory photo — shown as full-bleed cover bg.
  final String? coverPhotoPath;
  /// Direct public URL for a user-uploaded custom cover photo (overrides coverPhotoPath).
  final String? coverImageUrl;
  const CoverBookPage({
    required this.title,
    required this.dateRange,
    required this.memoryCount,
    this.authorName,
    this.coverPhotoPath,
    this.coverImageUrl,
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
  final bool isYearHeader;
  const TocEntry({
    required this.label,
    this.meta,
    required this.pageIndex,
    this.isSubEntry = false,
    this.isYearHeader = false,
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
  /// Inline section banner — e.g. "2026 · MARCH". Set on the first memory of
  /// each month group (replaces full-page year/month dividers).
  final String? sectionLabel;
  /// Week-of-month label — e.g. "WEEK 2 OF MARCH". Always set.
  final String? weekLabel;
  const MemoryBookPage({
    required this.entry,
    required this.isFirstInSection,
    this.sectionLabel,
    this.weekLabel,
  });
}

class TimeBridgePage extends BookPage {
  final String label; // "12 days later", "A month later", etc.
  const TimeBridgePage({required this.label});
}

// ── Week opener page (inserted before each week's entries) ────────────────────

enum WeekOpenerLayout { singleHero, asymmetric, triptych, mosaic, polaroid, textOnly }

class WeekOpenerBookPage extends BookPage {
  /// Display label — e.g. "MAR 2–8, 2026"
  final String weekRange;
  final int memoryCount;
  /// AI weekly summary — null until populated from pages table.
  final String? summary;
  /// Storage paths of photos from entries in this week.
  final List<String> photoPaths;
  final WeekOpenerLayout layout;

  const WeekOpenerBookPage({
    required this.weekRange,
    required this.memoryCount,
    required this.layout,
    this.summary,
    this.photoPaths = const [],
  });
}

// ── Weekly narrative pages (AI-generated, with photos) ────────────────────────

enum PageLayout { weekOpener, rightFloat, leftFloat, midPage, photoStrip }

class PagePhoto {
  final String storagePath;
  final String entryId;
  final String caption;
  final int score;
  final PageLayout layout;
  final int afterParagraph; // 0 = hero/top; N = after paragraph N
  final bool isHero;
  /// Pre-generated 1-year signed URL stored at page-generation time.
  /// Use this directly in the reader — avoids a Storage API call per page turn.
  final String signedUrl;
  /// ISO-8601 expiry for [signedUrl]. Fall back to live signing if past this.
  final DateTime? signedUrlExpiresAt;

  const PagePhoto({
    required this.storagePath,
    required this.entryId,
    required this.caption,
    required this.score,
    required this.layout,
    required this.afterParagraph,
    required this.isHero,
    this.signedUrl = '',
    this.signedUrlExpiresAt,
  });

  /// Returns true if [signedUrl] is present and not expired (with 5-min buffer).
  bool get hasValidSignedUrl {
    if (signedUrl.isEmpty) return false;
    if (signedUrlExpiresAt == null) return false;
    return signedUrlExpiresAt!
        .isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  factory PagePhoto.fromJson(Map<String, dynamic> j) => PagePhoto(
        storagePath: j['storage_path'] as String? ?? '',
        entryId: j['entry_id'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        layout: _layoutFromString(j['layout'] as String? ?? 'midPage'),
        afterParagraph: (j['after_paragraph'] as num?)?.toInt() ?? 0,
        isHero: j['is_hero'] as bool? ?? false,
        signedUrl: j['signed_url'] as String? ?? '',
        signedUrlExpiresAt: j['signed_url_expires_at'] != null
            ? DateTime.tryParse(j['signed_url_expires_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'storage_path': storagePath,
        'entry_id': entryId,
        'caption': caption,
        'score': score,
        'layout': layout.name,
        'after_paragraph': afterParagraph,
        'is_hero': isHero,
        'signed_url': signedUrl,
        if (signedUrlExpiresAt != null)
          'signed_url_expires_at': signedUrlExpiresAt!.toIso8601String(),
      };

  static PageLayout _layoutFromString(String s) {
    return PageLayout.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PageLayout.midPage,
    );
  }
}

class WeeklyNarrativeBookPage extends BookPage {
  final String id;
  final String content;
  final String weekStart;
  final int pageNumber;
  final int wordCount;
  final List<PagePhoto> photos;

  const WeeklyNarrativeBookPage({
    required this.id,
    required this.content,
    required this.weekStart,
    required this.pageNumber,
    required this.wordCount,
    this.photos = const [],
  });

  factory WeeklyNarrativeBookPage.fromJson(Map<String, dynamic> j) =>
      WeeklyNarrativeBookPage(
        id: j['id'] as String,
        content: j['content'] as String? ?? '',
        weekStart: j['week_start'] as String? ?? '',
        pageNumber: (j['page_number'] as num?)?.toInt() ?? 0,
        wordCount: (j['word_count'] as num?)?.toInt() ?? 0,
        photos: ((j['photos'] as List<dynamic>?) ?? [])
            .map((e) => PagePhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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
