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

    // ── Build TOC by scanning body pages ──────────────────────────────────────
    final tocEntries = <TocEntry>[
      const TocEntry(label: 'Introduction', pageIndex: 1),
    ];

    if (mode == BookMode.stream) {
      // Stream mode has no dividers — group first memory of each month
      String? lastMonthKey;
      for (int i = bodyStart; i < pages.length; i++) {
        final p = pages[i];
        if (p is MemoryBookPage) {
          final d = p.entry.entryDate;
          final mk = '${d.year}-${d.month}';
          if (mk != lastMonthKey) {
            lastMonthKey = mk;
            final label = DateFormat('MMMM yyyy').format(d);
            tocEntries.add(TocEntry(label: label, pageIndex: i));
          }
        }
      }
    } else {
      for (int i = bodyStart; i < pages.length; i++) {
        final p = pages[i];
        if (p is YearDividerPage) {
          tocEntries.add(TocEntry(
            label: p.year.toString(),
            meta: '${p.memoryCount} ${p.memoryCount == 1 ? 'memory' : 'memories'}',
            pageIndex: i,
          ));
        } else if (p is MonthDividerPage) {
          tocEntries.add(TocEntry(
            label: _monthFmt.format(DateTime(p.year, p.month)),
            meta: '${p.memoryCount} ${p.memoryCount == 1 ? 'memory' : 'memories'}',
            pageIndex: i,
            isSubEntry: true,
          ));
        } else if (p is ChapterDividerPage) {
          tocEntries.add(TocEntry(
            label: p.chapter.title,
            meta: '${p.memoryCount} ${p.memoryCount == 1 ? 'memory' : 'memories'}',
            pageIndex: i,
          ));
        }
      }
    }
    pages[tocIndex] = TocBookPage(entries: tocEntries);

    return pages;
  }

  // ── Stream: all entries in order ───────────────────────────────────────────
  List<BookPage> _streamPages(List<JournalEntry> entries) {
    return entries
        .asMap()
        .entries
        .map((e) => MemoryBookPage(entry: e.value, isFirstInSection: e.key == 0))
        .toList();
  }

  // ── By time: year divider → month divider → entries ───────────────────────
  List<BookPage> _byTimePages(List<JournalEntry> entries) {
    final out = <BookPage>[];
    final Map<int, Map<int, List<JournalEntry>>> grouped = {};
    for (final e in entries) {
      (grouped[e.entryDate.year] ??= {})[e.entryDate.month] ??= [];
      grouped[e.entryDate.year]![e.entryDate.month]!.add(e);
    }
    for (final year in (grouped.keys.toList()..sort())) {
      final months = grouped[year]!;
      final yearTotal = months.values.fold(0, (s, l) => s + l.length);
      out.add(YearDividerPage(year: year, memoryCount: yearTotal));
      for (final month in (months.keys.toList()..sort())) {
        final mes = months[month]!..sort((a, b) => a.entryDate.compareTo(b.entryDate));
        out.add(MonthDividerPage(
          year: year,
          month: month,
          memoryCount: mes.length,
          reflection: _monthReflection(mes, month, year),
        ));
        for (int i = 0; i < mes.length; i++) {
          out.add(MemoryBookPage(entry: mes[i], isFirstInSection: i == 0));
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
        out.add(MemoryBookPage(entry: ces[i], isFirstInSection: i == 0));
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

  // ── Monthly reflection — template only, no AI, no hallucination ───────────
  String _monthReflection(List<JournalEntry> entries, int month, int year) {
    final name = _monthFmt.format(DateTime(year, month));
    final n = entries.length;
    final countStr = n == 1
        ? 'You wrote once in $name.'
        : n == 2
            ? 'You wrote twice in $name.'
            : 'You wrote $n times in $name.';
    final moods = <String, int>{};
    for (final e in entries) {
      if (e.mood != null) moods[e.mood!] = (moods[e.mood!] ?? 0) + 1;
    }
    if (moods.isEmpty) return countStr;
    final top = moods.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return '$countStr Your most common mood: $top.';
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
