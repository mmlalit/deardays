import 'dart:math';

import 'package:intl/intl.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';

/// Thrown when book generation is attempted without an active subscription.
class SubscriptionRequiredException implements Exception {
  final String message;
  const SubscriptionRequiredException(this.message);
  @override
  String toString() => message;
}

/// Generates a [GeneratedBook] from selected journal entries.
///
/// Takes selected entries/chapters, generates book structure with:
/// - Title page
/// - Table of contents
/// - Chapters with entries as pages
/// - ~250 words per page (splits longer entries)
/// - Chapter divider pages between sections
class BookGeneratorService {
  static const int _wordsPerPage = 250;

  // ── Category keyword maps for auto-tagging ──────────────────────────────
  static const Map<String, List<String>> _categoryKeywords = {
    'Family': [
      'mom', 'dad', 'brother', 'sister', 'parents', 'family', 'home',
      'grandma', 'grandpa', 'uncle', 'aunt', 'cousin', 'wife', 'husband',
      'son', 'daughter', 'baby', 'kids', 'children',
    ],
    'Career': [
      'work', 'office', 'meeting', 'project', 'boss', 'client', 'deadline',
      'promotion', 'job', 'interview', 'colleague', 'salary', 'presentation',
      'startup', 'business',
    ],
    'Travel': [
      'trip', 'flight', 'hotel', 'vacation', 'beach', 'mountain', 'airport',
      'passport', 'journey', 'visited', 'explore', 'road trip', 'hiking',
      'backpack', 'destination',
    ],
    'Celebrations': [
      'birthday', 'anniversary', 'party', 'wedding', 'graduation', 'christmas',
      'new year', 'festival', 'celebrate', 'gift', 'surprise', 'engagement',
    ],
    'Reflections': [
      'feel', 'think', 'grateful', 'realize', 'learn', 'growth', 'reflect',
      'dream', 'goal', 'hope', 'fear', 'anxiety', 'peace', 'meditation',
      'journal', 'therapy',
    ],
  };

  // ── Category emoji icons ────────────────────────────────────────────────
  static const Map<String, String> _categoryIcons = {
    'Family': '\u{1F3E0}',       // 🏠
    'Career': '\u{1F4BC}',       // 💼
    'Travel': '\u{2708}\u{FE0F}', // ✈️
    'Celebrations': '\u{1F389}', // 🎉
    'Reflections': '\u{1F4AD}',  // 💭
    'Daily Life': '\u{2615}',    // ☕
  };

  // ── AI story transition phrases ────────────────────────────────────────
  static const List<String> _storyTransitions = [
    'As the days unfolded, ',
    'Looking back, ',
    'What followed was unexpected \u2014 ',
    'In the quiet moments that came after, ',
    'Life had a way of surprising \u2014 ',
    'The next chapter began when ',
    'Time moved forward, and with it ',
    'Before long, ',
    'It was during this time that ',
    'As one season gave way to the next, ',
    'The world shifted slightly when ',
    'Not long after, ',
    'And then, unexpectedly, ',
    'The rhythm of life continued \u2014 ',
    'With each passing day, ',
  ];

  // ── AI year title presets ───────────────────────────────────────────────
  static const List<String> _positiveTitles = [
    'Year of Joy',
    'Year of Growth',
    'Year of New Beginnings',
    'Year of Adventures',
  ];

  static const List<String> _balancedTitles = [
    'Year of Discovery',
    'Year of Change',
    'Year of Seasons',
  ];

  // ── Chapter subtitle presets ────────────────────────────────────────────
  static const Map<String, List<String>> _chapterSubtitles = {
    'Family': ['The Ones Who Matter', 'Where Love Lives', 'Roots & Wings'],
    'Career': ['Building Something Big', 'The Hustle', 'Dreams at Work'],
    'Travel': ['Miles & Memories', 'Wandering Hearts', 'Roads Less Traveled'],
    'Celebrations': [
      'Moments Worth Remembering',
      "Life's Little Parties",
      'Cheers & Tears',
    ],
    'Reflections': [
      'Looking Inward',
      'Quiet Conversations',
      'Soul Notes',
    ],
    'Daily Life': [
      'The Beautiful Ordinary',
      'Small Moments',
      'Day by Day',
    ],
  };

  /// Generate a book from manually selected entries, organized into chapters.
  /// C-07: Callers must verify subscription before invoking this method.
  GeneratedBook generateFromEntries({
    required List<JournalEntry> entries,
    required String title,
    required String author,
    Map<String, List<JournalEntry>>? chapterMap,
  }) {
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    final chapters = <BookChapter>[];
    final allPages = <BookPage>[];

    // Title page
    final dateRange = _dateRange(sorted);
    allPages.add(BookPage(
      pageNumber: 1,
      type: BookPageType.titlePage,
      content: title,
      chapterTitle: author,
      dateLabel: dateRange,
    ));

    // Table of contents (placeholder - populated after chapters built)
    allPages.add(const BookPage(
      pageNumber: 2,
      type: BookPageType.tableOfContents,
      content: 'Table of Contents',
    ));

    int currentPage = 3;

    if (chapterMap != null && chapterMap.isNotEmpty) {
      // Use provided chapter grouping
      for (final entry in chapterMap.entries) {
        final chapterResult = _buildChapter(
          title: entry.key,
          entries: entry.value,
          startPage: currentPage,
        );
        chapters.add(chapterResult.chapter);
        allPages.addAll(chapterResult.pages);
        currentPage += chapterResult.pages.length;
      }
    } else {
      // Auto-organize by month
      final grouped = _groupByMonth(sorted);
      for (final entry in grouped.entries) {
        final chapterResult = _buildChapter(
          title: entry.key,
          entries: entry.value,
          startPage: currentPage,
        );
        chapters.add(chapterResult.chapter);
        allPages.addAll(chapterResult.pages);
        currentPage += chapterResult.pages.length;
      }
    }

    // Re-number all pages
    for (int i = 0; i < allPages.length; i++) {
      allPages[i] = BookPage(
        pageNumber: i + 1,
        type: allPages[i].type,
        content: allPages[i].content,
        chapterTitle: allPages[i].chapterTitle,
        dateLabel: allPages[i].dateLabel,
        mood: allPages[i].mood,
        locationName: allPages[i].locationName,
      );
    }

    return GeneratedBook(
      id: 'gen-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: author,
      dateRange: dateRange,
      createdAt: DateTime.now(),
      chapters: chapters,
      allPages: allPages,
      sourceEntries: sorted,
    );
  }

  /// Generate a daily diary book from a date range.
  GeneratedBook generateDailyDiary({
    required List<JournalEntry> entries,
    required DateTime startDate,
    required DateTime endDate,
    required String author,
  }) {
    final filtered = entries
        .where((e) =>
            !e.entryDate.isBefore(startDate) && !e.entryDate.isAfter(endDate))
        .toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    // Group by week then month for chapter organization
    final monthGroups = _groupByMonth(filtered);
    final chapterMap = <String, List<JournalEntry>>{};
    for (final entry in monthGroups.entries) {
      chapterMap[entry.key] = entry.value;
    }

    final rangeStr =
        '${DateFormat.yMMM().format(startDate)} - ${DateFormat.yMMM().format(endDate)}';

    return generateFromEntries(
      entries: filtered,
      title: 'Daily Diary: $rangeStr',
      author: author,
      chapterMap: chapterMap,
    );
  }

  /// Generate an AI Surprise book (simulated - picks most meaningful entries).
  GeneratedBook generateAiSurprise({
    required List<JournalEntry> allEntries,
    required String author,
  }) {
    // Simulate AI curation: pick milestone entries first, then longest/richest
    final scored = allEntries.map((e) {
      double score = 0;
      if (e.isMilestone) score += 50;
      if (e.mood == 'great') score += 20;
      if (e.mood == 'good') score += 10;
      if (e.isAiPolished) score += 5;
      if (e.hasPhoto) score += 5;
      score += e.wordCount * 0.1;
      return MapEntry(e, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Pick top entries (max 15)
    final selected =
        scored.take(15).map((e) => e.key).toList()
          ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    return generateFromEntries(
      entries: selected,
      title: 'Your Story: A Curated Collection',
      author: author,
    );
  }

  /// Generate the auto-book "My Life Story" with both By Year and By Chapter views.
  /// C-07: Callers must verify subscription before invoking this method.
  GeneratedBook generateAutoBook({
    required List<JournalEntry> allEntries,
    required String author,
  }) {
    final sorted = List<JournalEntry>.from(allEntries)
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    final dateRange = _dateRange(sorted);

    // ── Tag each entry with a category ──────────────────────────────────
    final entryCategories = <String, String>{}; // entryId → category
    for (final entry in sorted) {
      entryCategories[entry.id] = _detectCategory(entry);
    }

    // ══════════════════════════════════════════════════════════════════════
    // Build BY YEAR structure + yearPages
    // ══════════════════════════════════════════════════════════════════════
    final yearGroups = <int, List<JournalEntry>>{};
    for (final e in sorted) {
      yearGroups.putIfAbsent(e.entryDate.year, () => []).add(e);
    }

    final yearSections = <YearSection>[];
    final yearChapters = <BookChapter>[]; // flat list for GeneratedBook.chapters
    final yearPages = <BookPage>[];

    // Title page
    yearPages.add(BookPage(
      pageNumber: 1,
      type: BookPageType.titlePage,
      content: 'My Life Story',
      chapterTitle: author,
      dateLabel: dateRange,
    ));
    // TOC placeholder
    yearPages.add(const BookPage(
      pageNumber: 2,
      type: BookPageType.tableOfContents,
      content: 'Table of Contents',
    ));

    int yearPageNum = 3;

    for (final year in yearGroups.keys.toList()..sort()) {
      final yearEntries = yearGroups[year]!;
      final aiTitle = _generateYearTitle(year, yearEntries);

      // Group entries within the year by month
      final monthGroups = _groupByMonth(yearEntries);
      final monthChapters = <BookChapter>[];

      // Year divider page
      yearPages.add(BookPage(
        pageNumber: yearPageNum,
        type: BookPageType.chapterDivider,
        content: '$year \u2014 $aiTitle',
        chapterTitle: '$year \u2014 $aiTitle',
        dateLabel: '${yearEntries.length} ${yearEntries.length == 1 ? 'entry' : 'entries'}',
      ));
      yearPageNum++;

      for (final monthEntry in monthGroups.entries) {
        final chapterResult = _buildChapter(
          title: monthEntry.key,
          entries: monthEntry.value,
          startPage: yearPageNum,
        );
        monthChapters.add(chapterResult.chapter);
        yearChapters.add(chapterResult.chapter);
        yearPages.addAll(chapterResult.pages);
        yearPageNum += chapterResult.pages.length;
      }

      yearSections.add(YearSection(
        year: year,
        aiTitle: aiTitle,
        months: monthChapters,
      ));
    }

    // Re-number year pages
    for (int i = 0; i < yearPages.length; i++) {
      yearPages[i] = BookPage(
        pageNumber: i + 1,
        type: yearPages[i].type,
        content: yearPages[i].content,
        chapterTitle: yearPages[i].chapterTitle,
        dateLabel: yearPages[i].dateLabel,
        mood: yearPages[i].mood,
        locationName: yearPages[i].locationName,
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // Build BY CHAPTER (theme) structure + chapterPages
    // ══════════════════════════════════════════════════════════════════════
    final categoryGroups = <String, List<JournalEntry>>{};
    for (final entry in sorted) {
      final cat = entryCategories[entry.id]!;
      categoryGroups.putIfAbsent(cat, () => []).add(entry);
    }

    // Define display order
    const categoryOrder = [
      'Family',
      'Career',
      'Travel',
      'Celebrations',
      'Reflections',
      'Daily Life',
    ];

    final themeChapters = <ThemeChapter>[];
    final chapterPagesList = <BookPage>[];

    // Title page
    chapterPagesList.add(BookPage(
      pageNumber: 1,
      type: BookPageType.titlePage,
      content: 'My Life Story',
      chapterTitle: author,
      dateLabel: dateRange,
    ));
    // TOC placeholder
    chapterPagesList.add(const BookPage(
      pageNumber: 2,
      type: BookPageType.tableOfContents,
      content: 'Table of Contents',
    ));

    int chapterPageNum = 3;

    for (final category in categoryOrder) {
      final entries = categoryGroups[category];
      if (entries == null || entries.isEmpty) continue;

      final icon = _categoryIcons[category] ?? '\u{2615}';
      final subtitle = _generateChapterSubtitle(category);

      // Chapter divider
      chapterPagesList.add(BookPage(
        pageNumber: chapterPageNum,
        type: BookPageType.chapterDivider,
        content: '$icon $category',
        chapterTitle: category,
        dateLabel: subtitle,
      ));
      final themeStartPage = chapterPageNum;
      chapterPageNum++;

      final themePages = <BookPage>[chapterPagesList.last];

      for (final entry in entries) {
        final entryPages = _splitEntryToPages(entry, category, chapterPageNum);
        themePages.addAll(entryPages);
        chapterPagesList.addAll(entryPages);
        chapterPageNum += entryPages.length;
      }

      themeChapters.add(ThemeChapter(
        category: category,
        icon: icon,
        aiSubtitle: subtitle,
        pages: themePages,
        startPage: themeStartPage,
      ));
    }

    // Re-number chapter pages
    for (int i = 0; i < chapterPagesList.length; i++) {
      chapterPagesList[i] = BookPage(
        pageNumber: i + 1,
        type: chapterPagesList[i].type,
        content: chapterPagesList[i].content,
        chapterTitle: chapterPagesList[i].chapterTitle,
        dateLabel: chapterPagesList[i].dateLabel,
        mood: chapterPagesList[i].mood,
        locationName: chapterPagesList[i].locationName,
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // Build BY AI (seamless story) structure + aiStoryPages
    // ══════════════════════════════════════════════════════════════════════
    final aiStoryPages = _buildAiStoryPages(sorted, author, dateRange);

    return GeneratedBook(
      id: 'auto-${DateTime.now().millisecondsSinceEpoch}',
      title: 'My Life Story',
      author: author,
      dateRange: dateRange,
      createdAt: DateTime.now(),
      chapters: yearChapters,
      allPages: yearPages, // default flat view is chronological
      sourceEntries: sorted,
      yearSections: yearSections,
      themeChapters: themeChapters,
      yearPages: yearPages,
      chapterPages: chapterPagesList,
      aiStoryPages: aiStoryPages,
    );
  }

  /// Build AI story pages: entries woven into flowing narrative arcs.
  List<BookPage> _buildAiStoryPages(
    List<JournalEntry> sorted,
    String author,
    String dateRange,
  ) {
    if (sorted.isEmpty) return const [];

    final pages = <BookPage>[];
    final rng = Random(sorted.length); // seeded for consistency

    // Title page
    pages.add(BookPage(
      pageNumber: 1,
      type: BookPageType.titlePage,
      content: 'Your Story',
      chapterTitle: author,
      dateLabel: dateRange,
    ));

    // TOC placeholder
    pages.add(const BookPage(
      pageNumber: 2,
      type: BookPageType.tableOfContents,
      content: 'A seamless narrative woven from your life',
    ));

    int pageNum = 3;

    // Group entries into narrative arcs of 3-5 entries each
    final arcs = <List<JournalEntry>>[];
    int i = 0;
    while (i < sorted.length) {
      final arcSize = (3 + rng.nextInt(3)).clamp(1, sorted.length - i); // 3-5
      arcs.add(sorted.sublist(i, i + arcSize));
      i += arcSize;
    }

    int transitionIndex = 0;

    for (int arcIdx = 0; arcIdx < arcs.length; arcIdx++) {
      final arc = arcs[arcIdx];
      final firstDate = arc.first.entryDate;
      final lastDate = arc.last.entryDate;

      // Arc divider page
      final arcTitle = arcIdx == 0
          ? 'The Beginning'
          : _storyTransitions[transitionIndex % _storyTransitions.length]
              .trimRight()
              .replaceAll(RegExp(r'[,\s\u2014]+$'), '');
      transitionIndex++;

      final arcDateLabel = firstDate.year == lastDate.year
          ? DateFormat.yMMMM().format(firstDate)
          : '${DateFormat.yMMMM().format(firstDate)} \u2014 ${DateFormat.yMMMM().format(lastDate)}';

      pages.add(BookPage(
        pageNumber: pageNum,
        type: BookPageType.chapterDivider,
        content: arcTitle,
        chapterTitle: 'Your Story',
        dateLabel: arcDateLabel,
      ));
      pageNum++;

      // Combine entries into flowing pages (2-3 entries per page)
      int entryIdx = 0;
      while (entryIdx < arc.length) {
        final entriesPerPage = (2 + rng.nextInt(2)).clamp(1, arc.length - entryIdx);
        final pageEntries = arc.sublist(entryIdx, entryIdx + entriesPerPage);

        final buffer = StringBuffer();

        for (int j = 0; j < pageEntries.length; j++) {
          final entry = pageEntries[j];

          // Add transition between entries within a page
          if (j > 0) {
            final transition =
                _storyTransitions[transitionIndex % _storyTransitions.length];
            transitionIndex++;
            buffer.write('\n\n');
            buffer.write(transition);
          }

          buffer.write(entry.content);
        }

        // Split the combined text into ~250-word pages
        final combinedText = buffer.toString();
        final words = combinedText.split(RegExp(r'\s+'));

        if (words.length <= _wordsPerPage) {
          pages.add(BookPage(
            pageNumber: pageNum,
            type: BookPageType.entryContent,
            content: combinedText,
            chapterTitle: 'Your Story',
            dateLabel: DateFormat.yMMMMd().format(pageEntries.first.entryDate),
            mood: pageEntries.first.mood,
          ));
          pageNum++;
        } else {
          int wordIdx = 0;
          bool isFirst = true;
          while (wordIdx < words.length) {
            final end = (wordIdx + _wordsPerPage).clamp(0, words.length);
            final pageWords = words.sublist(wordIdx, end);
            pages.add(BookPage(
              pageNumber: pageNum,
              type: BookPageType.entryContent,
              content: pageWords.join(' '),
              chapterTitle: isFirst ? 'Your Story' : null,
              dateLabel: isFirst
                  ? DateFormat.yMMMMd().format(pageEntries.first.entryDate)
                  : null,
              mood: isFirst ? pageEntries.first.mood : null,
            ));
            pageNum++;
            wordIdx = end;
            isFirst = false;
          }
        }

        entryIdx += entriesPerPage;
      }
    }

    // Re-number all pages
    for (int idx = 0; idx < pages.length; idx++) {
      pages[idx] = BookPage(
        pageNumber: idx + 1,
        type: pages[idx].type,
        content: pages[idx].content,
        chapterTitle: pages[idx].chapterTitle,
        dateLabel: pages[idx].dateLabel,
        mood: pages[idx].mood,
        locationName: pages[idx].locationName,
      );
    }

    return pages;
  }

  /// Detect the best category for an entry using keyword matching.
  String _detectCategory(JournalEntry entry) {
    final text = entry.content.toLowerCase();
    int bestScore = 0;
    String bestCategory = 'Daily Life';

    for (final catEntry in _categoryKeywords.entries) {
      int score = 0;
      for (final keyword in catEntry.value) {
        // Use word boundary-aware check for multi-word keywords
        if (keyword.contains(' ')) {
          if (text.contains(keyword)) score++;
        } else {
          // Match whole words and partial (e.g., "family" in "family's")
          if (RegExp('\\b${RegExp.escape(keyword)}').hasMatch(text)) score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = catEntry.key;
      }
    }

    return bestCategory;
  }

  /// Generate an AI year title based on dominant mood of entries in that year.
  String _generateYearTitle(int year, List<JournalEntry> entries) {
    int positive = 0;
    int total = 0;
    for (final e in entries) {
      if (e.mood != null) {
        total++;
        if (e.mood == 'great' || e.mood == 'good') positive++;
      }
    }

    final rng = Random(year); // seeded by year for consistency
    if (total == 0 || positive / total > 0.6) {
      return _positiveTitles[rng.nextInt(_positiveTitles.length)];
    } else {
      return _balancedTitles[rng.nextInt(_balancedTitles.length)];
    }
  }

  /// Pick a chapter subtitle from presets, seeded by category name for consistency.
  String _generateChapterSubtitle(String category) {
    final subtitles = _chapterSubtitles[category] ?? _chapterSubtitles['Daily Life']!;
    final rng = Random(category.hashCode);
    return subtitles[rng.nextInt(subtitles.length)];
  }

  /// Build a single chapter from entries.
  _ChapterResult _buildChapter({
    required String title,
    required List<JournalEntry> entries,
    required int startPage,
  }) {
    final pages = <BookPage>[];

    // Chapter divider page
    pages.add(BookPage(
      pageNumber: startPage,
      type: BookPageType.chapterDivider,
      content: title,
      chapterTitle: title,
      dateLabel: entries.isNotEmpty
          ? '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}'
          : '',
    ));

    int pageNum = startPage + 1;

    for (final entry in entries) {
      final entryPages = _splitEntryToPages(entry, title, pageNum);
      pages.addAll(entryPages);
      pageNum += entryPages.length;
    }

    return _ChapterResult(
      chapter: BookChapter(
        title: title,
        startPage: startPage,
        pages: pages,
      ),
      pages: pages,
    );
  }

  /// Split a single entry into one or more pages based on word count.
  List<BookPage> _splitEntryToPages(
    JournalEntry entry,
    String chapterTitle,
    int startPage,
  ) {
    final words = entry.content.split(RegExp(r'\s+'));
    final dateLabel = DateFormat.yMMMMd().format(entry.entryDate);
    final pages = <BookPage>[];

    if (words.length <= _wordsPerPage) {
      pages.add(BookPage(
        pageNumber: startPage,
        type: BookPageType.entryContent,
        content: entry.content,
        chapterTitle: pages.isEmpty ? chapterTitle : null,
        dateLabel: dateLabel,
        mood: entry.mood,
        locationName: entry.locationName,
      ));
    } else {
      int wordIndex = 0;
      int pageIndex = 0;
      while (wordIndex < words.length) {
        final end = (wordIndex + _wordsPerPage).clamp(0, words.length);
        final pageWords = words.sublist(wordIndex, end);
        pages.add(BookPage(
          pageNumber: startPage + pageIndex,
          type: BookPageType.entryContent,
          content: pageWords.join(' '),
          chapterTitle: pageIndex == 0 ? chapterTitle : null,
          dateLabel: pageIndex == 0 ? dateLabel : null,
          mood: pageIndex == 0 ? entry.mood : null,
          locationName: pageIndex == 0 ? entry.locationName : null,
        ));
        wordIndex = end;
        pageIndex++;
      }
    }

    return pages;
  }

  /// Group entries by month.
  Map<String, List<JournalEntry>> _groupByMonth(List<JournalEntry> entries) {
    final map = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final key = DateFormat.yMMMM().format(e.entryDate);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  /// Compute date range string.
  String _dateRange(List<JournalEntry> sorted) {
    if (sorted.isEmpty) return '';
    final first = DateFormat.yMMM().format(sorted.first.entryDate);
    final last = DateFormat.yMMM().format(sorted.last.entryDate);
    if (first == last) return first;
    return '$first - $last';
  }
}

class _ChapterResult {
  final BookChapter chapter;
  final List<BookPage> pages;
  const _ChapterResult({required this.chapter, required this.pages});
}
