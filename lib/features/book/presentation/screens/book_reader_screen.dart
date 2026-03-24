import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/routes.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/book/data/services/book_builder_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BookReaderScreen extends ConsumerStatefulWidget {
  final BookMode mode;
  const BookReaderScreen({super.key, required this.mode});

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _overlayVisible = false; // starts hidden — tap to reveal
  bool _isDearDays = true; // toggle: false = Journal, true = ✦ Story
  int _themeIndex = 0; // index into _readingThemes
  int? _resumePage; // last bookmarked page — persisted to Hive

  static const _readingThemes = [
    (label: 'Parchment', color: Color(0xFFFBF7F0)), // warm cream — default
    (label: 'Sepia',     color: Color(0xFFF4E3C1)), // amber
    (label: 'White',     color: Color(0xFFFAFAFC)), // clean white
    (label: 'Sage',      color: Color(0xFFEDF3EA)), // soft green
    (label: 'Lavender',  color: Color(0xFFF0EDF8)), // soft purple
  ];

  Color get _readingBg => _readingThemes[_themeIndex].color;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadTheme();
    _loadResumePage();
  }

  Future<void> _loadTheme() async {
    final box = await Hive.openBox<int>('reader_prefs');
    final saved = box.get('themeIndex', defaultValue: 0)!;
    if (mounted && saved != _themeIndex) {
      setState(() => _themeIndex = saved.clamp(0, _readingThemes.length - 1));
    }
  }

  Future<void> _saveTheme(int index) async {
    final box = await Hive.openBox<int>('reader_prefs');
    await box.put('themeIndex', index);
  }

  Future<void> _loadResumePage() async {
    final box = await Hive.openBox<int>('reader_prefs');
    final saved = box.get('resumePage');
    if (mounted && saved != null) {
      setState(() => _resumePage = saved);
    }
  }

  Future<void> _saveResumePage(int page) async {
    final box = await Hive.openBox<int>('reader_prefs');
    await box.put('resumePage', page);
    if (mounted) setState(() => _resumePage = page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() => _overlayVisible = false);
  }

  /// Builds the Story-mode page list: keeps front/back matter from [builtPages]
  /// and replaces the body with the continuous AI-generated [weeklyPages].
  List<BookPage> _storyModePages(
    List<BookPage> builtPages,
    List<WeeklyNarrativeBookPage> weeklyPages,
  ) {
    final out = <BookPage>[];

    // Keep front matter (cover, intro)
    for (final p in builtPages) {
      if (p is CoverBookPage || p is IntroductionBookPage) {
        out.add(p);
      } else {
        break;
      }
    }

    // TOC placeholder
    final tocIdx = out.length;
    out.add(const TocBookPage(entries: []));

    // Body: AI-generated continuous weekly narrative pages (already sorted
    // by week_start + page_number by the repository query)
    final bodyStart = out.length;
    out.addAll(weeklyPages);

    // Back matter (closing)
    final closing = builtPages.whereType<ClosingBookPage>().firstOrNull;
    if (closing != null) out.add(closing);

    // Build a simple TOC: group weekly pages by month
    final tocEntries = <TocEntry>[
      const TocEntry(label: 'Introduction', pageIndex: 1),
    ];
    String? lastMonthKey;
    for (int i = bodyStart; i < out.length; i++) {
      final p = out[i];
      if (p is! WeeklyNarrativeBookPage) continue;
      try {
        final d = DateTime.parse(p.weekStart);
        final mk = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        if (mk != lastMonthKey) {
          lastMonthKey = mk;
          final label =
              '${d.year} · ${_monthName(d.month).toUpperCase()}';
          int count = 0;
          for (int j = i; j < out.length; j++) {
            final q = out[j];
            if (q is! WeeklyNarrativeBookPage) break;
            try {
              final qd = DateTime.parse(q.weekStart);
              if (qd.year == d.year && qd.month == d.month) {
                count++;
              } else {
                break;
              }
            } catch (_) {}
          }
          tocEntries.add(TocEntry(
            label: label,
            meta: '$count ${count == 1 ? 'page' : 'pages'}',
            pageIndex: i,
          ));
        }
      } catch (_) {}
    }
    out[tocIdx] = TocBookPage(entries: tocEntries);

    return out;
  }

  static String _monthName(int month) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][month];

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(timelineEntriesProvider);
    final chaptersAsync = ref.watch(chaptersProvider);
    final profileAsync = ref.watch(profileProvider);
    final booksAsync = ref.watch(booksProvider);

    final entries = entriesAsync.valueOrNull ?? [];
    final chapters = chaptersAsync.valueOrNull ?? [];
    final authorName = profileAsync.valueOrNull?.displayName ?? 'You';
    final primaryBook = booksAsync.valueOrNull?.isNotEmpty == true
        ? booksAsync.valueOrNull!.first
        : null;
    final primaryBookId = primaryBook?.id;

    // Pre-fetch weekly summary so it's ready before the user swipes to week opener
    ref.watch(reflectionSummaryProvider(ReflectionPeriod.weekly));

    // Always watch weekly pages so we can auto-switch to Story if available
    final weeklyPagesAsync = primaryBookId != null
        ? ref.watch(weeklyNarrativePagesProvider(primaryBookId))
        : null;
    final weeklyPages = weeklyPagesAsync?.valueOrNull ?? [];

    if (entries.isEmpty) return _buildEmpty(context);

    final builtPages = BookBuilderService().build(
      entries: entries,
      mode: widget.mode,
      authorName: authorName,
      chapters: chapters,
      customTitle: primaryBook?.title,
      customCoverImageUrl: primaryBook?.coverImageUrl,
    );

    // In Story mode, replace body with AI-generated weekly narrative pages
    final pages = (_isDearDays && weeklyPages.isNotEmpty)
        ? _storyModePages(builtPages, weeklyPages)
        : builtPages;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _overlayVisible = !_overlayVisible),
          child: Stack(
            children: [
              // Full-screen page view
              PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = i);
                },
                itemBuilder: (context, index) =>
                    _buildPage(context, pages[index], index, pages, entries, primaryBookId),
              ),

              // Overlay: top + bottom bars
              if (_overlayVisible) ...[
                _buildTopBar(context, pages),
                _buildBottomBar(context, pages),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Page dispatcher ───────────────────────────────────────────────────────

  Widget _buildPage(
    BuildContext context,
    BookPage page,
    int index,
    List<BookPage> pages,
    List<JournalEntry> entries,
    String? bookId,
  ) {
    return switch (page) {
      CoverBookPage p           => _CoverPage(page: p, bookId: bookId),
      IntroductionBookPage p    => _IntroPage(
          page: p,
          pageNum: 'i',
          bgColor: _readingBg,
          themeIndex: _themeIndex,
          onThemeChanged: (i) {
            setState(() => _themeIndex = i);
            _saveTheme(i);
          },
        ),
      TocBookPage p             => _TocPage(page: p, onTap: _jumpToPage, bgColor: _readingBg),
      YearDividerPage p         => _YearPage(page: p),
      MonthDividerPage p        => _MonthPage(page: p),
      ChapterDividerPage p      => _ChapterPage(page: p),
      WeekOpenerBookPage p      => _WeekOpenerPage(page: p, pageNum: index, bgColor: _readingBg),
      MemoryBookPage p          => _MemoryPage(page: p, pageNum: index, isDearDays: _isDearDays, bgColor: _readingBg),
      WeeklyNarrativeBookPage p => _WeeklyNarrativePage(page: p, pageNum: index, isDearDays: _isDearDays, allEntries: entries, bgColor: _readingBg),
      TimeBridgePage p          => _TimeBridgePage(page: p),
      ClosingBookPage p         => _ClosingPage(page: p, onRecord: () => context.push('/record'), onWrite: () => context.push('/write'), bgColor: _readingBg),
    };
  }

  // ── Overlay: top bar ──────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, List<BookPage> pages) {
    final currentPage = _currentPage < pages.length ? pages[_currentPage] : null;
    final isDark = _isDarkPage(currentPage);
    final textColor = isDark ? Colors.white : AppColors.readingText;
    final bgColor = isDark
        ? Colors.black.withAlpha(100)
        : AppColors.readingBg.withAlpha(220);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _overlayVisible ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(
                color: textColor.withAlpha(20),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Contents — top left
                  _BarBtn(
                    icon: Icons.menu_rounded,
                    label: 'Contents',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      final tocIndex = pages.indexWhere((p) => p is TocBookPage);
                      if (tocIndex >= 0) _jumpToPage(tocIndex);
                    },
                  ),
                  // Date — center
                  Expanded(
                    child: Text(
                      _pageDate(currentPage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: textColor.withAlpha(140),
                      ),
                    ),
                  ),
                  // X — close reader → Books
                  _BarBtn(
                    icon: Icons.close_rounded,
                    label: 'Close',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () => context.go(AppRoutes.book),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Overlay: bottom bar ───────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, List<BookPage> pages) {
    final currentPage = _currentPage < pages.length ? pages[_currentPage] : null;
    final isDark = _isDarkPage(currentPage);
    final textColor = isDark ? Colors.white : AppColors.readingText;
    final bgColor = isDark
        ? Colors.black.withAlpha(180)
        : AppColors.readingBg.withAlpha(245);
    const accentColor = Color(0xFF6366F1);

    final canGoPrev = _currentPage > 0;
    final canGoNext = _currentPage < pages.length - 1;
    final tocIndex = pages.indexWhere((p) => p is TocBookPage);
    final hideControls = currentPage is CoverBookPage ||
        currentPage is IntroductionBookPage ||
        currentPage is WeekOpenerBookPage ||
        currentPage is MonthDividerPage ||
        currentPage is YearDividerPage ||
        currentPage is ChapterDividerPage ||
        currentPage is TocBookPage ||
        currentPage is ClosingBookPage;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: textColor.withAlpha(20))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // ── Prev ─────────────────────────────────────────────────────
                Expanded(
                  child: _BarBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: 'Prev',
                    color: canGoPrev ? textColor : textColor.withAlpha(35),
                    onTap: canGoPrev
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                        : null,
                  ),
                ),

                // ── Journal / Story / More ────────────────────────────────
                if (!hideControls) ...[
                  Expanded(
                    child: _BarBtn(
                      icon: Icons.menu_book_outlined,
                      label: 'Journal',
                      color: !_isDearDays ? accentColor : textColor.withAlpha(100),
                      onTap: () => setState(() => _isDearDays = false),
                    ),
                  ),
                  Expanded(
                    child: _BarBtn(
                      icon: Icons.auto_stories_rounded,
                      label: 'Story',
                      color: _isDearDays ? accentColor : textColor.withAlpha(100),
                      onTap: () => setState(() => _isDearDays = true),
                    ),
                  ),
                  Expanded(
                    child: _BarBtn(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      color: textColor.withAlpha(160),
                      onTap: () => _showMoreSheet(context, pages, textColor, accentColor, isDark),
                    ),
                  ),
                ] else ...[
                  // Cover page: show Contents + optional Resume
                  if (currentPage is CoverBookPage) ...[
                    const Spacer(),
                    _BarBtn(
                      icon: Icons.menu_book_rounded,
                      label: 'Contents',
                      color: tocIndex >= 0 ? textColor.withAlpha(160) : textColor.withAlpha(40),
                      onTap: tocIndex >= 0 ? () => _jumpToPage(tocIndex) : null,
                    ),
                    if (_resumePage != null && _resumePage! > 0) ...[
                      const SizedBox(width: 8),
                      _BarBtn(
                        icon: Icons.play_arrow_rounded,
                        label: 'Resume',
                        color: accentColor,
                        onTap: () => _jumpToPage(_resumePage!),
                      ),
                    ],
                    const Spacer(),
                  ] else
                    // Week opener / dividers: just spacer (Prev + Next already shown)
                    const Spacer(),
                ],

                // ── Next ─────────────────────────────────────────────────────
                Expanded(
                  child: _BarBtn(
                    icon: Icons.arrow_forward_ios_rounded,
                    label: 'Next',
                    color: canGoNext ? textColor : textColor.withAlpha(35),
                    onTap: canGoNext
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── More bottom sheet ─────────────────────────────────────────────────────

  void _showMoreSheet(
    BuildContext context,
    List<BookPage> pages,
    Color textColor,
    Color accentColor,
    bool isDark,
  ) {
    final bgColor = isDark ? const Color(0xFF1C1C1E) : AppColors.readingBg;
    final labelColor = isDark ? Colors.white70 : AppColors.readingText.withAlpha(160);
    final isBookmarked = _resumePage == _currentPage;
    final tocIndex = pages.indexWhere((p) => p is TocBookPage);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle + close
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: labelColor.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: labelColor.withAlpha(160)),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reading theme
                Text(
                  'READING THEME',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (int i = 0; i < _readingThemes.length; i++)
                      GestureDetector(
                        onTap: () {
                          setState(() => _themeIndex = i);
                          _saveTheme(i);
                          setSheet(() {});
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: _readingThemes[i].color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _themeIndex == i
                                  ? accentColor
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: labelColor.withAlpha(40), height: 1),
                const SizedBox(height: 16),

                // Actions row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Bookmark
                    _BarBtn(
                      icon: isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: isBookmarked ? 'Bookmarked' : 'Bookmark',
                      color: isBookmarked ? accentColor : textColor,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (!isBookmarked) {
                          _saveResumePage(_currentPage);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Page bookmarked — tap Resume on the cover to return'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),

                    // Contents
                    _BarBtn(
                      icon: Icons.menu_book_rounded,
                      label: 'Contents',
                      color: tocIndex >= 0 ? textColor : textColor.withAlpha(60),
                      onTap: tocIndex >= 0
                          ? () {
                              Navigator.of(ctx).pop();
                              _jumpToPage(tocIndex);
                            }
                          : null,
                    ),

                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isDarkPage(BookPage? page) => switch (page) {
    CoverBookPage()       => true,
    YearDividerPage()     => true,
    MonthDividerPage()    => true,
    ChapterDividerPage()  => true,
    TimeBridgePage()      => false,
    _                     => false,
  };

  String _sectionName(List<BookPage> pages, int currentIndex) {
    final current = currentIndex < pages.length ? pages[currentIndex] : null;
    if (current is CoverBookPage) return '';
    if (current is IntroductionBookPage) return 'Introduction';
    if (current is TocBookPage) return 'Contents';
    if (current is ClosingBookPage) return 'Closing';
    if (current is ChapterDividerPage) return current.chapter.title;

    // Walk backwards to find the nearest section context
    for (int i = currentIndex; i >= 0; i--) {
      final p = pages[i];
      if (p is ChapterDividerPage) return p.chapter.title;
      if (p is MemoryBookPage && p.sectionLabel != null) return p.sectionLabel!;
    }
    if (current is MemoryBookPage) {
      return DateFormat('MMMM yyyy').format(current.entry.entryDate);
    }
    return '';
  }

  /// Returns the date label shown in the top bar center for the current page.
  String _pageDate(BookPage? page) {
    if (page is MemoryBookPage) {
      return DateFormat('MMMM yyyy').format(page.entry.entryDate).toUpperCase();
    }
    if (page is WeekOpenerBookPage) return page.weekRange;
    if (page is WeeklyNarrativeBookPage) {
      try {
        return DateFormat('MMMM yyyy').format(DateTime.parse(page.weekStart)).toUpperCase();
      } catch (_) {}
    }
    if (page is IntroductionBookPage) return 'INTRODUCTION';
    if (page is TocBookPage) return 'CONTENTS';
    if (page is ClosingBookPage) return 'CLOSING';
    if (page is ChapterDividerPage) return page.chapter.title.toUpperCase();
    return '';
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.textPrimary),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 56, color: colors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No memories yet',
                        style: GoogleFonts.newsreader(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record or write a memory to start\nbuilding your life book.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/record'),
                        icon: const Icon(Icons.mic_rounded),
                        label: const Text('Record a Memory'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Shared reading typography helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Full page with warm reading background — used for front/back matter & memory pages.
Widget _readingShell({required Widget child, Color color = AppColors.readingBg}) {
  return Container(
    width: double.infinity,
    height: double.infinity,
    color: color,
    child: child,
  );
}


/// Drop cap + rest of first paragraph.
Widget _dropCap(BuildContext context, String text) {
  if (text.length < 2) {
    return Text(
      text,
      style: GoogleFonts.newsreader(
        fontSize: 17,
        height: 1.75,
        color: AppColors.readingText,
      ),
    );
  }
  final first = text[0].toUpperCase();
  final rest = text.substring(1);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 6, top: 2),
        child: Text(
          first,
          style: GoogleFonts.newsreader(
            fontSize: 66,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF5C3D1E),
            height: 0.82,
          ),
        ),
      ),
      Expanded(
        child: Text(
          rest,
          style: GoogleFonts.newsreader(
            fontSize: 17,
            height: 1.75,
            color: AppColors.readingText,
          ),
        ),
      ),
    ],
  );
}

/// Body paragraphs without drop cap.
Widget _bodyText(String text) {
  final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
  if (paragraphs.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: paragraphs
        .map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                p,
                style: GoogleFonts.newsreader(
                  fontSize: 17,
                  height: 1.75,
                  color: AppColors.readingText,
                ),
              ),
            ))
        .toList(),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// 0. Cover page
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPage extends ConsumerStatefulWidget {
  final CoverBookPage page;
  final String? bookId;
  const _CoverPage({required this.page, this.bookId});

  @override
  ConsumerState<_CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends ConsumerState<_CoverPage> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    // Use direct URL (user-uploaded) or fall back to signed storage path
    if (widget.page.coverImageUrl != null && widget.page.coverImageUrl!.isNotEmpty) {
      return _buildCover(context, widget.page.coverImageUrl);
    }
    if (widget.page.coverPhotoPath != null) {
      return FutureBuilder<String>(
        future: ref.read(mediaServiceProvider).getSignedUrl(widget.page.coverPhotoPath!),
        builder: (context, snap) => _buildCover(context, snap.data),
      );
    }
    return _buildCover(context, null);
  }

  Widget _buildCover(BuildContext context, String? photoUrl) {
    final accent = AppColors.of(context).accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background photo or fallback gradient
        if (photoUrl != null && photoUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => _fallbackGradient(),
            errorWidget: (_, __, ___) => _fallbackGradient(),
          )
        else
          _fallbackGradient(),

        // Gradient scrim — clear top, strong dark bottom
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(60),
                Colors.black.withAlpha(220),
              ],
            ),
          ),
        ),

        // Text content — anchored to bottom
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.page.authorName != null)
                  Text(
                    'By ${widget.page.authorName}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: Colors.white.withAlpha(160),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(width: 40, height: 1, color: accent.withAlpha(200)),
                const SizedBox(height: 14),
                Text(
                  widget.page.title,
                  style: GoogleFonts.newsreader(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: Text(
                        widget.page.dateRange.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Colors.white.withAlpha(160),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withAlpha(140)),
                      ),
                      child: Text(
                        '${widget.page.memoryCount} ${widget.page.memoryCount == 1 ? 'memory' : 'memories'}',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Edit button — top right, always visible
        Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _uploading
                ? const SizedBox(
                    width: 36, height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : GestureDetector(
                    onTap: () => _showEditSheet(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    ),
                  ),
          ),
      ],
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle + close row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(60),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                      onPressed: () => Navigator.pop(sheetCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.title_rounded, color: Colors.white, size: 20),
                ),
                title: Text('Edit Title',
                    style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Change your book\'s name',
                    style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _showTitleDialog(context);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                ),
                title: Text('Change Cover Photo',
                    style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Pick a photo from your gallery',
                    style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickCoverPhoto(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the existing book or creates a new one if none exists yet.
  Future<Book> _getOrCreateBook() async {
    final repo = ref.read(bookRepositoryProvider);
    final books = await repo.getBooks();
    if (books.isNotEmpty) return books.first;
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final now = DateTime.now();
    return repo.createBook(Book(
      id: '',
      userId: userId,
      title: widget.page.title,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    ));
  }

  void _showTitleDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.page.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Book Title',
            style: GoogleFonts.newsreader(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.manrope(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'My Life Book',
            hintStyle: GoogleFonts.manrope(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white60)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              Navigator.pop(ctx);
              if (newTitle.isEmpty || newTitle == widget.page.title) return;
              final book = await _getOrCreateBook();
              await ref.read(bookRepositoryProvider).updateBook(book.copyWith(title: newTitle));
              ref.invalidate(booksProvider);
            },
            child: Text('Save', style: GoogleFonts.manrope(color: const Color(0xFF6366F1), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverPhoto(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final book = await _getOrCreateBook();
      final repo = ref.read(bookRepositoryProvider);
      final url = await repo.uploadCoverImage(book.id, File(picked.path));
      await repo.updateBook(book.copyWith(coverImageUrl: url));
      ref.invalidate(booksProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update cover: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _fallbackGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C1810), Color(0xFF1A2E1A), Color(0xFF0D1F2D)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      );
}


// ─────────────────────────────────────────────────────────────────────────────
// 2. Introduction page
// ─────────────────────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final IntroductionBookPage page;
  final String pageNum;
  final Color bgColor;
  final int themeIndex;
  final ValueChanged<int> onThemeChanged;
  const _IntroPage({
    required this.page,
    required this.pageNum,
    required this.bgColor,
    required this.themeIndex,
    required this.onThemeChanged,
  });

  static const _titleColor = Color(0xFF5C3D1E);
  static const _accentColor = Color(0xFF8B6340);

  @override
  Widget build(BuildContext context) {
    return _readingShell(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 48, 36, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Top ornamental rule ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 1, color: _accentColor.withAlpha(60)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('◆',
                        style: TextStyle(fontSize: 8, color: _accentColor.withAlpha(100))),
                  ),
                  Container(width: 40, height: 1, color: _accentColor.withAlpha(60)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Title ───────────────────────────────────────────────────
              Text(
                'Introduction',
                style: GoogleFonts.newsreader(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(width: 32, height: 1.5, color: _accentColor.withAlpha(120)),
              const SizedBox(height: 24),

              // ── Body text (scrollable so long text never overflows) ─────
              Expanded(
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _bodyText(page.text),
                  ),
                ),
              ),

              // ── Theme picker ────────────────────────────────────────────
              Column(
                children: [
                  Text(
                    'READING THEME',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _accentColor.withAlpha(120),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _BookReaderScreenState._readingThemes.length; i++)
                        GestureDetector(
                          onTap: () => onThemeChanged(i),
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: _BookReaderScreenState._readingThemes[i].color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: themeIndex == i
                                    ? const Color(0xFF6366F1)
                                    : _accentColor.withAlpha(60),
                                width: themeIndex == i ? 2.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(25),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _BookReaderScreenState._readingThemes[themeIndex].label,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: _accentColor.withAlpha(140),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Ornamental footer ───────────────────────────────────────
              Column(
                children: [
                  Text(
                    '·  ·  ·',
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      letterSpacing: 6,
                      color: _accentColor.withAlpha(80),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    pageNum,
                    style: GoogleFonts.newsreader(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.readingText.withAlpha(80),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Table of contents
// ─────────────────────────────────────────────────────────────────────────────

class _TocPage extends StatelessWidget {
  final TocBookPage page;
  final ValueChanged<int> onTap;
  final Color bgColor;
  const _TocPage({required this.page, required this.onTap, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return _readingShell(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 72, 36, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contents',
                style: GoogleFonts.newsreader(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 48, height: 2, color: Colors.black.withAlpha(160)),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: page.entries.length,
                  itemBuilder: (context, i) => _TocRow(
                    entry: page.entries[i],
                    onTap: () => onTap(page.entries[i].pageIndex),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'ii',
                  style: GoogleFonts.newsreader(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.readingText.withAlpha(80),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TocRow extends StatelessWidget {
  final TocEntry entry;
  final VoidCallback onTap;
  const _TocRow({required this.entry, required this.onTap});

  static const _titleColor = Color(0xFF5C3D1E);

  @override
  Widget build(BuildContext context) {
    if (entry.isYearHeader) return _buildYearHeader(context);
    return _buildWeekRow(context);
  }

  // ── Year header: "2026" + memory count pill + divider line
  Widget _buildYearHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            entry.label,
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          if (entry.meta != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry.meta!,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: _titleColor.withAlpha(35)),
          ),
        ],
      ),
    );
  }

  // ── Week row: "  MAR 1–7 ············· 4" (indented, with dotted leader)
  Widget _buildWeekRow(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        splashColor: _titleColor.withAlpha(18),
        highlightColor: _titleColor.withAlpha(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 0, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Week label
              Text(
                entry.label,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              if (entry.meta != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.meta!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
              // Dotted leader fills remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _DottedLeader(color: AppColors.readingText.withAlpha(50)),
                ),
              ),
              // Page number
              Text(
                '${entry.pageIndex + 1}',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a row of evenly-spaced dots to fill available width (TOC leader).
class _DottedLeader extends StatelessWidget {
  final Color color;
  const _DottedLeader({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 12),
      painter: _DottedLeaderPainter(color: color),
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  final Color color;
  const _DottedLeaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dotSpacing = 5.0;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += dotSpacing) {
      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeaderPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Year divider
// ─────────────────────────────────────────────────────────────────────────────

class _YearPage extends StatelessWidget {
  final YearDividerPage page;
  const _YearPage({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 1, color: Colors.white.withAlpha(40)),
            const SizedBox(height: 28),
            Text(
              page.year.toString().split('').join(' '),
              style: GoogleFonts.newsreader(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 28),
            Container(width: 40, height: 1, color: Colors.white.withAlpha(40)),
            const SizedBox(height: 20),
            Text(
              '${page.memoryCount} ${page.memoryCount == 1 ? 'memory' : 'memories'}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Colors.white.withAlpha(80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month divider
// ─────────────────────────────────────────────────────────────────────────────

class _MonthPage extends StatelessWidget {
  final MonthDividerPage page;
  const _MonthPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(DateTime(page.year, page.month));
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF263348),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthName,
                style: GoogleFonts.newsreader(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                page.year.toString(),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(120),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 48,
                height: 1,
                color: Colors.white.withAlpha(40),
              ),
              const SizedBox(height: 24),
              Text(
                page.reflection,
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withAlpha(160),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chapter divider (Mode A only)
// ─────────────────────────────────────────────────────────────────────────────

class _ChapterPage extends StatelessWidget {
  final ChapterDividerPage page;
  const _ChapterPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final visual = ChapterVisual.forTitle(page.chapter.title);
    final ordinal = BookBuilderService.chapterOrdinal(page.chapterIndex);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: visual.gradient),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(60),
              Colors.black.withAlpha(160),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHAPTER $ordinal'.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(width: 60, height: 1, color: Colors.white.withAlpha(100)),
                  const SizedBox(height: 20),
                  Text(
                    page.chapter.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(width: 60, height: 1, color: Colors.white.withAlpha(100)),
                  const SizedBox(height: 20),
                  Text(
                    '${page.memoryCount} ${page.memoryCount == 1 ? 'memory' : 'memories'}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.white.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Memory page
// ─────────────────────────────────────────────────────────────────────────────

class _MemoryPage extends ConsumerWidget {
  final MemoryBookPage page;
  final int pageNum;
  final bool isDearDays;
  final Color bgColor;
  const _MemoryPage({required this.page, required this.pageNum, required this.isDearDays, required this.bgColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = page.entry;
    final hasPolished = entry.polishedContent?.isNotEmpty == true;
    final displayText = (isDearDays && hasPolished)
        ? entry.polishedContent!
        : entry.content;
    // When weekLabel is present it already shows the month — only show day + year
    final dateLabel = page.weekLabel != null
        ? DateFormat('d, yyyy').format(entry.entryDate)
        : DateFormat('MMMM d, yyyy').format(entry.entryDate);

    final paragraphs = displayText
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return _readingShell(
      color: bgColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(36, 72, 36, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Week + date header
              if (page.weekLabel != null)
                Text(
                  page.weekLabel!,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                    color: AppColors.readingText.withAlpha(70),
                  ),
                ),
              Text(
                dateLabel.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.readingText.withAlpha(100),
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 28, height: 1, color: AppColors.readingText.withAlpha(60)),
              const SizedBox(height: 20),

              // Photo
              if (entry.media.isNotEmpty)
                _MemoryPhoto(entry: entry, ref: ref),

              // Body text — drop cap on first para if isFirstInSection
              if (paragraphs.isNotEmpty) ...[
                if (page.isFirstInSection)
                  _dropCap(context, paragraphs.first)
                else
                  Text(
                    paragraphs.first,
                    style: GoogleFonts.newsreader(
                      fontSize: 17,
                      height: 1.6,
                      color: AppColors.readingText,
                    ),
                  ),
                ...paragraphs.skip(1).map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          p,
                          style: GoogleFonts.newsreader(
                            fontSize: 17,
                            height: 1.6,
                            color: AppColors.readingText,
                          ),
                        ),
                      ),
                    ),
              ],

              // DearDays polish indicator
              if (isDearDays && hasPolished) ...[
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '✦',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.readingText.withAlpha(80),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

}

class _MemoryPhoto extends ConsumerWidget {
  final JournalEntry entry;
  final WidgetRef ref;
  const _MemoryPhoto({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    if (photoMedia.isEmpty) return const SizedBox.shrink();

    final mediaService = ref.read(mediaServiceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: FutureBuilder<String>(
            future: mediaService.getSignedUrl(photoMedia.first.storagePath),
            builder: (context, snapshot) {
              final alignment = photoMedia.first.focalAlignment;
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                // Try local file path
                final path = photoMedia.first.storagePath;
                if (path.startsWith('/') || path.contains(':\\')) {
                  return Image.file(File(path), fit: BoxFit.cover, alignment: alignment);
                }
                return Container(
                  color: AppColors.readingText.withAlpha(15),
                  child: Icon(Icons.image_outlined,
                      color: AppColors.readingText.withAlpha(60), size: 32),
                );
              }
              return CachedNetworkImage(
                imageUrl: snapshot.data!,
                fit: BoxFit.cover,
                alignment: alignment,
                placeholder: (_, __) =>
                    Container(color: AppColors.readingText.withAlpha(15)),
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.readingText.withAlpha(15)),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time bridge — factual, no AI
// ─────────────────────────────────────────────────────────────────────────────

class _TimeBridgePage extends StatelessWidget {
  final TimeBridgePage page;
  const _TimeBridgePage({required this.page});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: colors.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '· · ·',
              style: GoogleFonts.newsreader(
                fontSize: 24,
                letterSpacing: 8,
                color: colors.textMuted.withAlpha(120),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              page.label,
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week opener page — shown before each week's entries
// ─────────────────────────────────────────────────────────────────────────────

class _WeekOpenerPage extends ConsumerWidget {
  final WeekOpenerBookPage page;
  final int pageNum;
  final Color bgColor;
  const _WeekOpenerPage({required this.page, required this.pageNum, required this.bgColor});

  static const _ink = AppColors.readingText; // same as all other book pages

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = page.photoPaths.isNotEmpty;

    // Use page summary if available, else try weekly reflection provider, else fallback
    final weeklySummaryAsync = ref.watch(reflectionSummaryProvider(ReflectionPeriod.weekly));
    final summaryText = (page.summary != null && page.summary!.isNotEmpty)
        ? page.summary!
        : weeklySummaryAsync.maybeWhen(
            data: (s) => (s != null && s.isNotEmpty) ? s : null,
            orElse: () => null,
          ) ?? '${page.memoryCount} ${page.memoryCount == 1 ? "memory" : "memories"} this week';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: ◆ WEEK ◆ label ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                children: [
                  Text('◆', style: GoogleFonts.manrope(fontSize: 8, color: _ink.withAlpha(80))),
                  const SizedBox(width: 6),
                  Text(
                    'WEEK',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: _ink.withAlpha(140),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('◆', style: GoogleFonts.manrope(fontSize: 8, color: _ink.withAlpha(80))),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Date + memory pill ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      page.weekRange,
                      style: GoogleFonts.newsreader(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6366F1).withAlpha(60)),
                    ),
                    child: Text(
                      '${page.memoryCount} ${page.memoryCount == 1 ? "memory" : "memories"}',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Hero photo — single full-width 4:3 ─────────────────────────
            if (hasPhoto)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _BookPhotoCell(
                      storagePath: page.photoPaths.first,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

            if (!hasPhoto)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: _ink.withAlpha(8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _ink.withAlpha(20)),
                  ),
                  child: Center(
                    child: Text(
                      '· · ·',
                      style: GoogleFonts.newsreader(
                        fontSize: 22,
                        letterSpacing: 8,
                        color: _ink.withAlpha(60),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Summary / fallback ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 32, height: 1, color: _ink.withAlpha(40)),
                  const SizedBox(height: 14),
                  Text(
                    summaryText,
                    style: GoogleFonts.newsreader(
                      fontSize: 17,
                      color: _ink.withAlpha(200),
                      height: 1.75,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Page number ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  '${pageNum + 1}',
                  style: GoogleFonts.newsreader(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: _ink.withAlpha(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared photo cell — fetches signed URL from storage path
// ─────────────────────────────────────────────────────────────────────────────

class _BookPhotoCell extends ConsumerWidget {
  final String storagePath;
  final BorderRadius borderRadius;
  final Alignment focalAlignment;

  const _BookPhotoCell({
    required this.storagePath,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.focalAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaService = ref.read(mediaServiceProvider);
    return FutureBuilder<String>(
      future: mediaService.getSignedUrl(storagePath),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          // Try local path
          if (storagePath.startsWith('/') || storagePath.contains(':\\')) {
            return ClipRRect(
              borderRadius: borderRadius,
              child: SizedBox.expand(
                child: Image.file(File(storagePath), fit: BoxFit.cover, alignment: focalAlignment),
              ),
            );
          }
          return ClipRRect(
            borderRadius: borderRadius,
            child: Container(
              color: Colors.white.withAlpha(10),
              child: Icon(Icons.image_outlined,
                  color: Colors.white.withAlpha(40), size: 24),
            ),
          );
        }
        return ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: snap.data!,
              fit: BoxFit.cover,
              alignment: focalAlignment,
              placeholder: (_, __) =>
                  Container(color: Colors.white.withAlpha(10)),
              errorWidget: (_, __, ___) =>
                  Container(color: Colors.white.withAlpha(10)),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Closing page
// ─────────────────────────────────────────────────────────────────────────────

class _ClosingPage extends StatelessWidget {
  final ClosingBookPage page;
  final VoidCallback onRecord;
  final VoidCallback onWrite;
  final Color bgColor;
  const _ClosingPage({
    required this.page,
    required this.onRecord,
    required this.onWrite,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _readingShell(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Your story continues.',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.readingText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${page.totalMemories} ${page.totalMemories == 1 ? 'memory' : 'memories'} written\nsince ${page.startDateLabel}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 14,
                  color: AppColors.readingText.withAlpha(140),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: onRecord,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Record a Memory',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onWrite,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.readingText.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_rounded,
                          color: AppColors.readingText.withAlpha(160), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Write a Memory',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.readingText.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly narrative page (AI-generated story with optional photos)
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyNarrativePage extends ConsumerStatefulWidget {
  final WeeklyNarrativeBookPage page;
  final int pageNum;
  final bool isDearDays;
  final List<JournalEntry> allEntries;
  final Color bgColor;
  const _WeeklyNarrativePage({
    required this.page,
    required this.pageNum,
    required this.isDearDays,
    required this.allEntries,
    required this.bgColor,
  });

  @override
  ConsumerState<_WeeklyNarrativePage> createState() =>
      _WeeklyNarrativePageState();
}

class _WeeklyNarrativePageState
    extends ConsumerState<_WeeklyNarrativePage> {
  late WeeklyNarrativeBookPage _page;
  bool _entriesExpanded = false;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
  }

  List<JournalEntry> get _weekEntries {
    try {
      final start = DateTime.parse(_page.weekStart);
      final end = start.add(const Duration(days: 7));
      return widget.allEntries
          .where((e) =>
              !e.entryDate.isBefore(start) && e.entryDate.isBefore(end))
          .toList()
        ..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // In Journal mode — show a gentle prompt to switch
    if (!widget.isDearDays) {
      return _readingShell(
        color: widget.bgColor,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✦',
                    style: TextStyle(
                      fontSize: 28,
                      color: AppColors.of(context).accent.withAlpha(120),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'DearDays Story',
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.readingText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch to ✦ Story mode\nto read the narrative for this week.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.readingText.withAlpha(120),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final paragraphs = _page.content
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    final weekLabel = _formatWeekLabel(_page.weekStart);
    final layout =
        _page.photos.isNotEmpty ? _page.photos.first.layout : null;
    final weekEntries = _weekEntries;

    return _readingShell(
      color: widget.bgColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 72, 32, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _weekHeader(context, weekLabel),
              const SizedBox(height: 28),
              ..._buildLayout(context, paragraphs, layout),
              const SizedBox(height: 32),
              // Collapsible original entries
              if (weekEntries.isNotEmpty) ...[
                _buildCollapseRow(context, weekEntries.length),
                if (_entriesExpanded) ...[
                  const SizedBox(height: 12),
                  ...weekEntries.map((e) => _buildEntryCard(context, e)),
                ],
                const SizedBox(height: 24),
              ],
              Center(
                child: Text(
                  '${widget.pageNum + 1}',
                  style: GoogleFonts.newsreader(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.readingText.withAlpha(80),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekHeader(BuildContext context, String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.of(context).accent.withAlpha(180),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.of(context).accent.withAlpha(180),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapseRow(BuildContext context, int count) {
    final accent = AppColors.of(context).accent;
    return GestureDetector(
      onTap: () => setState(() => _entriesExpanded = !_entriesExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(
              _entriesExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: accent.withAlpha(160),
            ),
            const SizedBox(width: 6),
            Text(
              _entriesExpanded
                  ? 'Hide original entries'
                  : 'See original entries ($count)',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, JournalEntry entry) {
    final dateLabel = DateFormat('MMM d').format(entry.entryDate);
    final firstLine = (entry.rawContent ?? entry.content)
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => entry.content);
    final snippet = firstLine.length > 80
        ? '${firstLine.substring(0, 80)}…'
        : firstLine;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.readingBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, ctrl) => _EntryDetailSheet(
            entry: entry,
            isDearDays: widget.isDearDays,
            scrollController: ctrl,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.readingText.withAlpha(6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.readingText.withAlpha(18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.of(context).accent,
                  ),
                ),
                if (entry.mood != null)
                  Text(
                    _moodEmoji(entry.mood!),
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                snippet,
                style: GoogleFonts.newsreader(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.readingText.withAlpha(160),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.readingText.withAlpha(60)),
          ],
        ),
      ),
    );
  }

  String _moodEmoji(String mood) => switch (mood.toLowerCase()) {
    'great' => '😄',
    'good'  => '🙂',
    'okay'  => '😐',
    'low'   => '😔',
    'tough' => '😢',
    _       => '',
  };

  // ── Layout builders ────────────────────────────────────────────────────────

  List<Widget> _buildLayout(
    BuildContext context,
    List<String> paragraphs,
    PageLayout? layout,
  ) {
    if (_page.photos.isEmpty) return _textParagraphs(paragraphs);

    return switch (layout) {
      PageLayout.weekOpener  => _weekOpenerLayout(paragraphs),
      PageLayout.rightFloat  => _floatLayout(paragraphs, floatRight: true),
      PageLayout.leftFloat   => _floatLayout(paragraphs, floatRight: false),
      PageLayout.photoStrip  => _photoStripLayout(paragraphs),
      _                      => _midPageLayout(paragraphs),
    };
  }

  /// Hero photo full-width at top, all text below.
  List<Widget> _weekOpenerLayout(List<String> paragraphs) {
    final hero = _page.photos.first;
    return [
      _NarrativePhotoWidget(
        photo: hero,
        aspectRatio: 16 / 9,
        onEdit: () => _showPhotoEditSheet(hero),
      ),
      const SizedBox(height: 24),
      ..._textParagraphs(paragraphs),
    ];
  }

  /// Photo inserted after paragraph N, text above and below.
  List<Widget> _midPageLayout(List<String> paragraphs) {
    final photo = _page.photos.first;
    final splitAt = photo.afterParagraph.clamp(0, paragraphs.length);
    final before = paragraphs.sublist(0, splitAt);
    final after = splitAt < paragraphs.length
        ? paragraphs.sublist(splitAt)
        : <String>[];
    return [
      ..._textParagraphs(before),
      if (before.isNotEmpty) const SizedBox(height: 18),
      _NarrativePhotoWidget(
        photo: photo,
        aspectRatio: 4 / 3,
        onEdit: () => _showPhotoEditSheet(photo),
      ),
      if (after.isNotEmpty) const SizedBox(height: 18),
      ..._textParagraphs(after),
    ];
  }

  /// Photo floated beside first paragraph, rest of text below.
  List<Widget> _floatLayout(
    List<String> paragraphs, {
    required bool floatRight,
  }) {
    final photo = _page.photos.first;
    final firstPara = paragraphs.isNotEmpty ? paragraphs.first : '';
    final rest =
        paragraphs.length > 1 ? paragraphs.sublist(1) : <String>[];

    final photoBox = SizedBox(
      width: 130,
      child: _NarrativePhotoWidget(
        photo: photo,
        aspectRatio: 3 / 4,
        onEdit: () => _showPhotoEditSheet(photo),
      ),
    );
    final textBox = Expanded(
      child: Text(
        firstPara,
        style: GoogleFonts.newsreader(
          fontSize: 17,
          height: 1.75,
          color: AppColors.readingText,
        ),
      ),
    );

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: floatRight
            ? [textBox, const SizedBox(width: 14), photoBox]
            : [photoBox, const SizedBox(width: 14), textBox],
      ),
      ..._textParagraphs(rest),
    ];
  }

  /// All text first, then a horizontal strip of up to 3 photos at the bottom.
  List<Widget> _photoStripLayout(List<String> paragraphs) {
    final photos = _page.photos.take(3).toList();
    return [
      ..._textParagraphs(paragraphs),
      const SizedBox(height: 24),
      SizedBox(
        height: 130,
        child: Row(
          children: photos.map((photo) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _NarrativePhotoWidget(
                  photo: photo,
                  aspectRatio: 1,
                  showCaption: false,
                  onEdit: () => _showPhotoEditSheet(photo),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: photos.map((photo) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                photo.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: AppColors.readingText.withAlpha(110),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _textParagraphs(List<String> paragraphs) {
    return paragraphs.asMap().entries.map((e) {
      return Padding(
        padding: EdgeInsets.only(top: e.key == 0 ? 0 : 18),
        child: Text(
          e.value,
          style: GoogleFonts.newsreader(
            fontSize: 17,
            height: 1.75,
            color: AppColors.readingText,
          ),
        ),
      );
    }).toList();
  }

  String _formatWeekLabel(String weekStart) {
    try {
      final d = DateTime.parse(weekStart);
      final end = d.add(const Duration(days: 6));
      if (d.month == end.month) {
        return '${DateFormat('MMM d').format(d)}–${DateFormat('d, yyyy').format(end)}';
      }
      return '${DateFormat('MMM d').format(d)} – ${DateFormat('MMM d, yyyy').format(end)}';
    } catch (_) {
      return weekStart;
    }
  }

  void _showPhotoEditSheet(PagePhoto photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.readingBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PhotoEditSheet(
        photo: photo,
        page: _page,
        onPhotosUpdated: (updated) => setState(() => _page = updated),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Narrative photo widget — fetches a signed URL from the storage path
// ─────────────────────────────────────────────────────────────────────────────

class _NarrativePhotoWidget extends ConsumerWidget {
  final PagePhoto photo;
  final double aspectRatio;
  final bool showCaption;
  final VoidCallback onEdit;

  const _NarrativePhotoWidget({
    required this.photo,
    required this.aspectRatio,
    required this.onEdit,
    this.showCaption = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaService = ref.read(mediaServiceProvider);

    return GestureDetector(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<String>(
                    // Use pre-generated signed URL if valid — avoids a Storage
                    // API call per page turn (critical at scale).
                    future: photo.hasValidSignedUrl
                        ? Future.value(photo.signedUrl)
                        : mediaService.getSignedUrl(photo.storagePath),
                    builder: (ctx, snap) {
                      if (!snap.hasData || snap.data!.isEmpty) {
                        return Container(
                          color: AppColors.readingText.withAlpha(12),
                          child: Icon(Icons.image_outlined,
                              color: AppColors.readingText.withAlpha(50),
                              size: 28),
                        );
                      }
                      return CachedNetworkImage(
                        imageUrl: snap.data!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: AppColors.readingText.withAlpha(12)),
                        errorWidget: (_, __, ___) => Container(
                            color: AppColors.readingText.withAlpha(12)),
                      );
                    },
                  ),
                  // Edit hint
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showCaption && photo.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              photo.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.readingText.withAlpha(120),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo edit bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoEditSheet extends ConsumerStatefulWidget {
  final PagePhoto photo;
  final WeeklyNarrativeBookPage page;
  final void Function(WeeklyNarrativeBookPage updated) onPhotosUpdated;

  const _PhotoEditSheet({
    required this.photo,
    required this.page,
    required this.onPhotosUpdated,
  });

  @override
  ConsumerState<_PhotoEditSheet> createState() => _PhotoEditSheetState();
}

class _PhotoEditSheetState extends ConsumerState<_PhotoEditSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.readingText.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Edit Photo',
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.readingText,
            ),
          ),
          if (widget.photo.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.photo.caption,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.readingText.withAlpha(140),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Remove this photo',
            color: Colors.red.shade600,
            loading: _loading,
            onTap: _removePhoto,
          ),
          const SizedBox(height: 8),
          _SheetOption(
            icon: Icons.close_rounded,
            label: 'Cancel',
            color: AppColors.readingText.withAlpha(120),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _removePhoto() async {
    setState(() => _loading = true);
    try {
      final updatedPhotos = widget.page.photos
          .where((p) =>
              p.storagePath != widget.photo.storagePath ||
              p.entryId != widget.photo.entryId)
          .toList();
      await ref
          .read(bookRepositoryProvider)
          .updatePagePhotos(widget.page.id, updatedPhotos);
      final updatedPage = WeeklyNarrativeBookPage(
        id: widget.page.id,
        content: widget.page.content,
        weekStart: widget.page.weekStart,
        pageNumber: widget.page.pageNumber,
        wordCount: widget.page.wordCount,
        photos: updatedPhotos,
      );
      widget.onPhotosUpdated(updatedPage);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry detail bottom sheet — shown when tapping an original entry card
// ─────────────────────────────────────────────────────────────────────────────

class _EntryDetailSheet extends ConsumerWidget {
  final JournalEntry entry;
  final bool isDearDays;
  final ScrollController scrollController;

  const _EntryDetailSheet({
    required this.entry,
    required this.isDearDays,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPolished = entry.polishedContent?.isNotEmpty == true;
    final displayText = (isDearDays && hasPolished)
        ? entry.polishedContent!
        : entry.content;
    final dateLabel = DateFormat('MMMM d, yyyy').format(entry.entryDate);
    final paragraphs = displayText
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final accent = AppColors.of(context).accent;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.readingText.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Date + mood + ✦ indicator
          Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: accent,
                ),
              ),
              if (entry.mood != null) ...[
                const SizedBox(width: 8),
                Text(
                  _moodEmoji(entry.mood!),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              if (isDearDays && hasPolished) ...[
                const SizedBox(width: 6),
                Text('✦', style: TextStyle(fontSize: 10, color: accent)),
              ],
            ],
          ),
          const SizedBox(height: 24),
          ...paragraphs.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              p,
              style: GoogleFonts.newsreader(
                fontSize: 17,
                height: 1.75,
                color: AppColors.readingText,
              ),
            ),
          )),
        ],
      ),
    );
  }

  String _moodEmoji(String mood) => switch (mood.toLowerCase()) {
    'great' => '😄',
    'good'  => '🙂',
    'okay'  => '😐',
    'low'   => '😔',
    'tough' => '😢',
    _       => '',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar icon button
// ─────────────────────────────────────────────────────────────────────────────

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _BarBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.readingText.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
