import 'package:intl/intl.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/book/data/models/book_page.dart';

/// Builds the ordered list of [BookPage]s for any [BookMode].
///
/// The page structure is always:
///   0  Cover  (with happiest memory photo as background)
///   1  Introduction
///   2  Table of Contents  (indices filled in after body is built)
///   3+ Body pages (dividers + time bridges + memory pages)
///   N  Closing page
///
/// DearDays story is NOT generated here. Monthly reflections are template-based
/// ("You wrote N times in Month.") — factual, zero hallucination risk.
class BookBuilderService {
  static final _monthFmt = DateFormat('MMMM');
  static final _shortFmt = DateFormat('MMM yyyy');
  static final _longFmt = DateFormat('MMMM d, yyyy');
  static final _weekFmt = DateFormat('MMM d');

  List<BookPage> build({
    required List<JournalEntry> entries,
    required BookMode mode,
    required String authorName,
    List<Chapter> chapters = const [],
  }) {
    if (entries.isEmpty) return [];

    final sorted = [...entries]
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    final dateRange = _dateRange(sorted);
    final pages = <BookPage>[];

    // ── Front matter ───────────────────────────────────────────────────────
    pages.add(CoverBookPage(
      title: 'My Life Book',
      authorName: authorName,
      dateRange: dateRange,
      memoryCount: sorted.length,
      coverPhotoPath: _happiestPhotoPath(sorted),
    ));

    pages.add(IntroductionBookPage(text: _introText(sorted, authorName)));

    // TOC placeholder — filled in below after we know body page indices
    final tocIndex = pages.length; // always 2
    pages.add(const TocBookPage(entries: []));

    // ── Body ───────────────────────────────────────────────────────────────
    final bodyStart = pages.length; // always 3
    switch (mode) {
      case BookMode.stream:
        pages.addAll(_streamPages(sorted));
      case BookMode.byTime:
        pages.addAll(_byTimePages(sorted));
      case BookMode.byChapter:
        pages.addAll(_byChapterPages(sorted, chapters));
    }

    // ── Closing ────────────────────────────────────────────────────────────
    pages.add(ClosingBookPage(
      totalMemories: sorted.length,
      startDateLabel: _shortFmt.format(sorted.first.entryDate),
    ));

    // ── Build TOC ─────────────────────────────────────────────────────────────
    final tocEntries = <TocEntry>[
      const TocEntry(label: 'Introduction', pageIndex: 1),
    ];

    if (mode == BookMode.byChapter) {
      // Chapter mode: chapter title rows only
      for (int i = bodyStart; i < pages.length; i++) {
        final p = pages[i];
        if (p is ChapterDividerPage) {
          tocEntries.add(TocEntry(
            label: p.chapter.title,
            meta: '${p.memoryCount} ${p.memoryCount == 1 ? 'memory' : 'memories'}',
            pageIndex: i,
          ));
        }
      }
    } else {
      // Stream / byTime: hierarchical year headers + week sub-entries
      // Pre-pass: group memory pages by year → week (insertion-ordered)
      final yearWeeks = <String, Map<String, ({int firstPage, int count})>>{};
      final yearCounts = <String, int>{};
      final yearFirstPages = <String, int>{};

      for (int i = bodyStart; i < pages.length; i++) {
        final p = pages[i];
        if (p is! MemoryBookPage) continue;
        final year = p.entry.entryDate.year.toString();
        final week = p.weekLabel ?? _weekRangeLabel(p.entry.entryDate);
        yearWeeks[year] ??= {};
        yearCounts[year] = (yearCounts[year] ?? 0) + 1;
        yearFirstPages[year] ??= i;
        if (yearWeeks[year]!.containsKey(week)) {
          final e = yearWeeks[year]![week]!;
          yearWeeks[year]![week] = (firstPage: e.firstPage, count: e.count + 1);
        } else {
          yearWeeks[year]![week] = (firstPage: i, count: 1);
        }
      }

      for (final year in yearWeeks.keys) {
        final total = yearCounts[year]!;
        tocEntries.add(TocEntry(
          label: year,
          meta: '$total ${total == 1 ? 'memory' : 'memories'}',
          pageIndex: yearFirstPages[year]!,
          isYearHeader: true,
        ));
        for (final we in yearWeeks[year]!.entries) {
          final c = we.value.count;
          tocEntries.add(TocEntry(
            label: we.key,
            meta: '$c ${c == 1 ? 'memory' : 'memories'}',
            pageIndex: we.value.firstPage,
            isSubEntry: true,
          ));
        }
      }
    }

    pages[tocIndex] = TocBookPage(entries: tocEntries);

    return pages;
  }

  // ── Week range label: Mon–Sun ISO week, e.g. "MAR 16–22" ─────────────────
  static String _weekRangeLabel(DateTime d) {
    final weekStart = d.subtract(Duration(days: d.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final s = _weekFmt.format(weekStart).toUpperCase();
    if (weekStart.month == weekEnd.month) {
      return '$s–${weekEnd.day}';
    }
    return '$s – ${_weekFmt.format(weekEnd).toUpperCase()}';
  }

  /// Full week label with year, used on WeekOpenerBookPage, e.g. "MAR 2–8, 2026"
  static String _fullWeekLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final s = _weekFmt.format(weekStart).toUpperCase();
    final year = weekEnd.year;
    if (weekStart.month == weekEnd.month) {
      return '$s–${weekEnd.day}, $year';
    }
    return '$s – ${_weekFmt.format(weekEnd).toUpperCase()}, $year';
  }

  /// Deterministic layout for a week opener based on week index and photo count.
  static WeekOpenerLayout _pickLayout(int weekIndex, int photoCount) {
    if (photoCount == 0) return WeekOpenerLayout.textOnly;
    if (photoCount == 1) return WeekOpenerLayout.singleHero;
    if (photoCount == 2) {
      return weekIndex.isEven ? WeekOpenerLayout.asymmetric : WeekOpenerLayout.polaroid;
    }
    if (photoCount == 3) return WeekOpenerLayout.triptych;
    const multi = [
      WeekOpenerLayout.mosaic,
      WeekOpenerLayout.asymmetric,
      WeekOpenerLayout.triptych,
      WeekOpenerLayout.polaroid,
    ];
    return multi[weekIndex % multi.length];
  }

  /// Returns a canonical ISO week key "YYYY-MM-DD" for the Monday of the week
  /// that contains [d].
  static String _weekKey(DateTime d) {
    final ws = d.subtract(Duration(days: d.weekday - 1));
    return '${ws.year}-${ws.month.toString().padLeft(2, '0')}-${ws.day.toString().padLeft(2, '0')}';
  }

  // ── Stream: WeekOpenerBookPage before each week, then memory pages ─────────
  List<BookPage> _streamPages(List<JournalEntry> entries) {
    final out = <BookPage>[];
    String? lastMonthKey;
    int weekIndex = 0;

    final weekGroups = <String, List<JournalEntry>>{};
    final weekOrder = <String>[];
    for (final entry in entries) {
      final wk = _weekKey(entry.entryDate);
      if (!weekGroups.containsKey(wk)) {
        weekGroups[wk] = [];
        weekOrder.add(wk);
      }
      weekGroups[wk]!.add(entry);
    }

    for (final wk in weekOrder) {
      final weekEntries = weekGroups[wk]!;
      final weekStartDate = DateTime.parse(wk);
      final photos = weekEntries
          .expand((e) => e.media.where((m) => m.mediaType == 'photo'))
          .map((m) => m.storagePath)
          .toList();

      out.add(WeekOpenerBookPage(
        weekRange: _fullWeekLabel(weekStartDate),
        memoryCount: weekEntries.length,
        layout: _pickLayout(weekIndex, photos.length),
        photoPaths: photos,
      ));
      weekIndex++;

      for (final entry in weekEntries) {
        final d = entry.entryDate;
        final mk = '${d.year}-${d.month}';
        final isNewMonth = mk != lastMonthKey;
        if (isNewMonth) lastMonthKey = mk;
        out.add(MemoryBookPage(
          entry: entry,
          isFirstInSection: isNewMonth,
          sectionLabel: isNewMonth ? '${d.year} · ${_monthFmt.format(d).toUpperCase()}' : null,
          weekLabel: _weekRangeLabel(d),
        ));
      }
    }
    return out;
  }

  // ── By time: WeekOpenerBookPage per week, with month section banners ────────
  List<BookPage> _byTimePages(List<JournalEntry> entries) {
    final out = <BookPage>[];
    int weekIndex = 0;

    final Map<int, Map<int, List<JournalEntry>>> grouped = {};
    for (final e in entries) {
      (grouped[e.entryDate.year] ??= {})[e.entryDate.month] ??= [];
      grouped[e.entryDate.year]![e.entryDate.month]!.add(e);
    }
    for (final year in (grouped.keys.toList()..sort())) {
      final months = grouped[year]!;
      for (final month in (months.keys.toList()..sort())) {
        final mes = months[month]!..sort((a, b) => a.entryDate.compareTo(b.entryDate));
        final monthName = _monthFmt.format(DateTime(year, month));
        final sectionLabel = '$year · ${monthName.toUpperCase()}';

        // Group entries in this month by week
        final weekGroups = <String, List<JournalEntry>>{};
        final weekOrder = <String>[];
        for (final entry in mes) {
          final wk = _weekKey(entry.entryDate);
          if (!weekGroups.containsKey(wk)) {
            weekGroups[wk] = [];
            weekOrder.add(wk);
          }
          weekGroups[wk]!.add(entry);
        }

        bool sectionLabelEmitted = false;
        for (final wk in weekOrder) {
          final weekEntries = weekGroups[wk]!;
          final weekStartDate = DateTime.parse(wk);
          final photos = weekEntries
              .expand((e) => e.media.where((m) => m.mediaType == 'photo'))
              .map((m) => m.storagePath)
              .toList();

          out.add(WeekOpenerBookPage(
            weekRange: _fullWeekLabel(weekStartDate),
            memoryCount: weekEntries.length,
            layout: _pickLayout(weekIndex, photos.length),
            photoPaths: photos,
          ));
          weekIndex++;

          for (final entry in weekEntries) {
            final showSection = !sectionLabelEmitted;
            if (!sectionLabelEmitted) sectionLabelEmitted = true;
            out.add(MemoryBookPage(
              entry: entry,
              isFirstInSection: showSection,
              sectionLabel: showSection ? sectionLabel : null,
              weekLabel: _weekRangeLabel(entry.entryDate),
            ));
          }
        }
      }
    }
    return out;
  }

  // ── By chapter: chapter divider → entries ─────────────────────────────────
  List<BookPage> _byChapterPages(
    List<JournalEntry> entries,
    List<Chapter> chapters,
  ) {
    final out = <BookPage>[];
    final byChapter = <String, List<JournalEntry>>{};
    for (final e in entries) {
      if (e.chapterId != null) (byChapter[e.chapterId!] ??= []).add(e);
    }
    for (int ci = 0; ci < chapters.length; ci++) {
      final ch = chapters[ci];
      final ces = (byChapter[ch.id] ?? [])
        ..sort((a, b) => a.entryDate.compareTo(b.entryDate));
      out.add(ChapterDividerPage(
        chapter: ch,
        chapterIndex: ci,
        memoryCount: ces.length,
      ));
      for (int i = 0; i < ces.length; i++) {
        final entry = ces[i];
        out.add(MemoryBookPage(
          entry: entry,
          isFirstInSection: i == 0,
          weekLabel: _weekRangeLabel(entry.entryDate),
        ));
      }
    }
    return out;
  }

  // ── Happiest memory photo — used as cover page background ─────────────────
  static String? _happiestPhotoPath(List<JournalEntry> entries) {
    const moodScore = {'great': 4, 'good': 3, 'okay': 2, 'low': 1, 'tough': 0};
    final withPhotos = entries
        .where((e) => e.hasPhoto && e.media.any((m) => m.mediaType == 'photo'))
        .toList();
    if (withPhotos.isEmpty) return null;
    withPhotos.sort((a, b) {
      final sa = a.sentimentScore?.toDouble() ??
          (moodScore[a.mood?.toLowerCase()] ?? 0).toDouble();
      final sb = b.sentimentScore?.toDouble() ??
          (moodScore[b.mood?.toLowerCase()] ?? 0).toDouble();
      return sb.compareTo(sa);
    });
    return withPhotos.first.media
        .firstWhere((m) => m.mediaType == 'photo')
        .storagePath;
  }

  // ── Introduction — template only, no AI ───────────────────────────────────
  String _introText(List<JournalEntry> entries, String authorName) {
    final first = entries.first.entryDate;
    final last = entries.last.entryDate;
    final years = last.year - first.year;
    final yearStr = years == 0
        ? 'less than a year'
        : years == 1
            ? 'one year'
            : '$years years';
    final startStr = _longFmt.format(first);
    final endStr = _longFmt.format(last);
    return 'This is the story of $authorName, told in ${entries.length} '
        'memories spanning $yearStr.\n\n'
        'It begins on $startStr and continues through $endStr.\n\n'
        'These pages hold the moments worth keeping — the quiet mornings, '
        'the celebrations, the difficult days, and the ordinary afternoons '
        'that turned out to matter.\n\n'
        'Turn the page to begin.';
  }

  String _dateRange(List<JournalEntry> entries) {
    final s = _shortFmt.format(entries.first.entryDate);
    final e = _shortFmt.format(entries.last.entryDate);
    return s == e ? s : '$s — $e';
  }

  /// Human-readable chapter ordinal: 0 → "One", 1 → "Two", etc.
  static String chapterOrdinal(int zeroBasedIndex) {
    const ordinals = [
      'One', 'Two', 'Three', 'Four', 'Five',
      'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    ];
    if (zeroBasedIndex < ordinals.length) return ordinals[zeroBasedIndex];
    return (zeroBasedIndex + 1).toString();
  }
}
