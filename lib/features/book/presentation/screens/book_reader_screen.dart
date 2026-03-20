import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
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
  bool _isDearDays = false; // toggle: false = Journal, true = ✦ Story
  final Set<int> _bookmarkedPages = {};
  int _themeIndex = 0; // index into _readingThemes

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
    final primaryBookId = booksAsync.valueOrNull?.isNotEmpty == true
        ? booksAsync.valueOrNull!.first.id
        : null;

    // Watch weekly narrative pages when Story mode is on and a book exists
    final weeklyPagesAsync = (_isDearDays && primaryBookId != null)
        ? ref.watch(weeklyNarrativePagesProvider(primaryBookId))
        : null;

    if (entries.isEmpty) return _buildEmpty(context);

    final builtPages = BookBuilderService().build(
      entries: entries,
      mode: widget.mode,
      authorName: authorName,
      chapters: chapters,
    );

    // In Story mode, replace body with AI-generated weekly narrative pages
    final weeklyPages = weeklyPagesAsync?.valueOrNull ?? [];
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
                    _buildPage(context, pages[index], index, pages, entries),
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
  ) {
    return switch (page) {
      CoverBookPage p           => _CoverPage(page: p),
      IntroductionBookPage p    => _IntroPage(page: p, pageNum: 'i', bgColor: _readingBg),
      TocBookPage p             => _TocPage(page: p, onTap: _jumpToPage, bgColor: _readingBg),
      YearDividerPage p         => _YearPage(page: p),
      MonthDividerPage p        => _MonthPage(page: p),
      ChapterDividerPage p      => _ChapterPage(page: p),
      WeekOpenerBookPage p      => _WeekOpenerPage(page: p, pageNum: index),
      MemoryBookPage p          => _MemoryPage(page: p, pageNum: index, isDearDays: _isDearDays),
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
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
                  ),
                  Expanded(
                    child: Text(
                      _sectionName(pages, _currentPage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: textColor.withAlpha(140),
                      ),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} / ${pages.length}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: textColor.withAlpha(90),
                    ),
                  ),
                  const SizedBox(width: 16),
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
    final isBookmarked = _bookmarkedPages.contains(_currentPage);
    final tocIndex = pages.indexWhere((p) => p is TocBookPage);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Row 1: Journal / ✦ Story mode toggle ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: textColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isDearDays = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: !_isDearDays
                                  ? (isDark ? Colors.white.withAlpha(220) : AppColors.readingText.withAlpha(210))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '📖  Journal',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_isDearDays ? Colors.white : textColor.withAlpha(110),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isDearDays = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _isDearDays ? accentColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '✦  Story',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _isDearDays ? Colors.white : textColor.withAlpha(110),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Row 2: Page color swatches ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_readingThemes.length, (i) {
                    final theme = _readingThemes[i];
                    final isActive = _themeIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _themeIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? accentColor : textColor.withAlpha(60),
                            width: isActive ? 2.5 : 1,
                          ),
                          boxShadow: isActive
                              ? [BoxShadow(color: accentColor.withAlpha(80), blurRadius: 6)]
                              : null,
                        ),
                        child: isActive
                            ? const Icon(Icons.check_rounded, size: 14, color: accentColor)
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              Divider(height: 1, thickness: 1, color: textColor.withAlpha(15)),

              // ── Row 3: Controls ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BarBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      label: 'Prev',
                      color: canGoPrev ? textColor : textColor.withAlpha(40),
                      onTap: canGoPrev
                          ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                    _BarBtn(
                      icon: isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: 'Bookmark',
                      color: isBookmarked ? accentColor : textColor.withAlpha(160),
                      onTap: () => setState(() {
                        if (isBookmarked) {
                          _bookmarkedPages.remove(_currentPage);
                        } else {
                          _bookmarkedPages.add(_currentPage);
                        }
                      }),
                    ),
                    _BarBtn(
                      icon: Icons.menu_book_rounded,
                      label: 'Contents',
                      color: tocIndex >= 0 ? textColor.withAlpha(160) : textColor.withAlpha(40),
                      onTap: tocIndex >= 0 ? () => _jumpToPage(tocIndex) : null,
                    ),
                    _BarBtn(
                      icon: Icons.ios_share_rounded,
                      label: 'Share',
                      color: textColor.withAlpha(160),
                      onTap: () => context.push('/export'),
                    ),
                    _BarBtn(
                      icon: Icons.arrow_forward_ios_rounded,
                      label: 'Next',
                      color: canGoNext ? textColor : textColor.withAlpha(40),
                      onTap: canGoNext
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
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
    WeekOpenerBookPage()  => true,
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

/// Inline section banner — "2026 · MARCH" — shown at top of first memory in each month.
class _SectionBanner extends StatelessWidget {
  final String label;
  const _SectionBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF5C3D1E).withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5C3D1E).withAlpha(30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
          color: const Color(0xFF5C3D1E).withAlpha(150),
        ),
      ),
    );
  }
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

class _CoverPage extends ConsumerWidget {
  final CoverBookPage page;
  const _CoverPage({required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.coverPhotoPath != null) {
      return FutureBuilder<String>(
        future: ref.read(mediaServiceProvider).getSignedUrl(page.coverPhotoPath!),
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
        // Background: happiest memory photo or fallback gradient
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
                // Author above title
                if (page.authorName != null)
                  Text(
                    'By ${page.authorName}',
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
                  page.title,
                  style: GoogleFonts.newsreader(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                // Metadata chips
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(60)),
                      ),
                      child: Text(
                        page.dateRange.toUpperCase(),
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
                        '${page.memoryCount} ${page.memoryCount == 1 ? 'memory' : 'memories'}',
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
      ],
    );
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
  const _IntroPage({required this.page, required this.pageNum, required this.bgColor});

  // Warm sepia — pairs with the cream reading background
  static const _titleColor = Color(0xFF5C3D1E);

  @override
  Widget build(BuildContext context) {
    return _readingShell(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 48, 36, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ornamental divider above title
              Row(children: [
                Container(width: 24, height: 1, color: _titleColor.withAlpha(80)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('❧',
                      style: TextStyle(fontSize: 14, color: _titleColor.withAlpha(120))),
                ),
                Container(width: 24, height: 1, color: _titleColor.withAlpha(80)),
              ]),
              const SizedBox(height: 16),
              Text(
                'Introduction',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 40, height: 2, color: _titleColor.withAlpha(100)),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _bodyText(page.text),
                ),
              ),
              Center(
                child: Text(
                  pageNum,
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

// ─────────────────────────────────────────────────────────────────────────────
// 3. Table of contents
// ─────────────────────────────────────────────────────────────────────────────

class _TocPage extends StatelessWidget {
  final TocBookPage page;
  final ValueChanged<int> onTap;
  final Color bgColor;
  const _TocPage({required this.page, required this.onTap, required this.bgColor});

  static const _titleColor = Color(0xFF5C3D1E);

  @override
  Widget build(BuildContext context) {
    return _readingShell(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 48, 36, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contents',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 40, height: 2, color: _titleColor.withAlpha(100)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: page.entries.length,
                  itemBuilder: (context, i) => _TocRow(
                    entry: page.entries[i],
                    onTap: () => onTap(page.entries[i].pageIndex),
                  ),
                ),
              ),
              // Start Reading — jumps to first content page (entries[1])
              if (page.entries.length > 1) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => onTap(page.entries[1].pageIndex),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _titleColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start Reading',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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

  // ── Year header: "── 2026  ·  50 memories ──────────────"
  Widget _buildYearHeader(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Row(
          children: [
            Container(width: 16, height: 1, color: _titleColor.withAlpha(60)),
            const SizedBox(width: 8),
            Text(
              entry.label,
              style: GoogleFonts.newsreader(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            if (entry.meta != null) ...[
              Text(
                '  ·  ',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: _titleColor.withAlpha(80),
                ),
              ),
              Text(
                entry.meta!,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _titleColor.withAlpha(120),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Container(height: 1, color: _titleColor.withAlpha(30)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Week row: "  MAR 1–7  ───────  4" (indented)
  Widget _buildWeekRow(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.readingText.withAlpha(180),
                ),
              ),
            ),
            if (entry.meta != null)
              Text(
                entry.meta!,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: AppColors.readingText.withAlpha(80),
                ),
              ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 28,
                child: Divider(color: AppColors.readingText.withAlpha(25), thickness: 1),
              ),
            ),
            Text(
              '${entry.pageIndex + 1}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: accent.withAlpha(180),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  const _MemoryPage({required this.page, required this.pageNum, required this.isDearDays});

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
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(36, 36, 36, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inline section banner — "2026 · MARCH" (first of each month)
              if (page.sectionLabel != null) ...[
                _SectionBanner(label: page.sectionLabel!),
                const SizedBox(height: 24),
              ],

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
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                // Try local file path
                final path = photoMedia.first.storagePath;
                if (path.startsWith('/') || path.contains(':\\')) {
                  return Image.file(File(path), fit: BoxFit.cover);
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
  const _WeekOpenerPage({required this.page, required this.pageNum});

  static const _bg     = Color(0xFF1E1209); // deep warm brown
  static const _gold   = Color(0xFFD4A46A);
  static const _text   = Color(0xFFF2ECE3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhotos = page.photoPaths.isNotEmpty &&
        page.layout != WeekOpenerLayout.textOnly;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 20, height: 1, color: _gold.withAlpha(100)),
                    const SizedBox(width: 8),
                    Text(
                      'WEEK',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: _gold.withAlpha(160),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    page.weekRange,
                    style: GoogleFonts.newsreader(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _text,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${page.memoryCount} ${page.memoryCount == 1 ? "memory" : "memories"}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _text.withAlpha(100),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              height: 1,
              color: _gold.withAlpha(40),
            ),
            const SizedBox(height: 16),

            // ── Photos ─────────────────────────────────────────────────────
            if (hasPhotos)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildPhotoSection(ref),
                ),
              ),

            // ── Text-only decoration ────────────────────────────────────────
            if (!hasPhotos)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 1, color: _gold.withAlpha(60)),
                      const SizedBox(height: 20),
                      Text(
                        '· · ·',
                        style: GoogleFonts.newsreader(
                          fontSize: 20,
                          letterSpacing: 6,
                          color: _gold.withAlpha(100),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(width: 40, height: 1, color: _gold.withAlpha(60)),
                    ],
                  ),
                ),
              ),

            // ── Weekly summary ──────────────────────────────────────────────
            if (page.summary != null && page.summary!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  '"${page.summary}"',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: _text.withAlpha(160),
                    height: 1.6,
                  ),
                ),
              ),
            ],

            // ── Page number ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  '${pageNum + 1}',
                  style: GoogleFonts.newsreader(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: _text.withAlpha(60),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(WidgetRef ref) {
    return switch (page.layout) {
      WeekOpenerLayout.singleHero  => _SingleHeroGrid(paths: page.photoPaths),
      WeekOpenerLayout.asymmetric  => _AsymmetricGrid(paths: page.photoPaths),
      WeekOpenerLayout.triptych    => _TriptychGrid(paths: page.photoPaths),
      WeekOpenerLayout.mosaic      => _MosaicGrid(paths: page.photoPaths),
      WeekOpenerLayout.polaroid    => _PolaroidGrid(paths: page.photoPaths),
      WeekOpenerLayout.textOnly    => const SizedBox.shrink(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared photo cell — fetches signed URL from storage path
// ─────────────────────────────────────────────────────────────────────────────

class _BookPhotoCell extends ConsumerWidget {
  final String storagePath;
  final BorderRadius borderRadius;

  const _BookPhotoCell({
    required this.storagePath,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
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
                child: Image.file(File(storagePath), fit: BoxFit.cover),
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

// ── Layout A: single full-width hero ─────────────────────────────────────────

class _SingleHeroGrid extends StatelessWidget {
  final List<String> paths;
  const _SingleHeroGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: _BookPhotoCell(
          storagePath: paths.first,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ── Layout B: large left (60%) + tall portrait right (40%) ───────────────────

class _AsymmetricGrid extends StatelessWidget {
  final List<String> paths;
  const _AsymmetricGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _BookPhotoCell(
            storagePath: paths[0],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomLeft: Radius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          flex: 4,
          child: paths.length > 1
              ? _BookPhotoCell(
                  storagePath: paths[1],
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                )
              : ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: Container(color: Colors.white.withAlpha(5)),
                ),
        ),
      ],
    );
  }
}

// ── Layout C: three equal panels (triptych) ───────────────────────────────────

class _TriptychGrid extends StatelessWidget {
  final List<String> paths;
  const _TriptychGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    final count = paths.length.clamp(1, 3);
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: _BookPhotoCell(
              storagePath: paths[i],
              borderRadius: BorderRadius.only(
                topLeft: i == 0 ? const Radius.circular(10) : Radius.zero,
                bottomLeft: i == 0 ? const Radius.circular(10) : Radius.zero,
                topRight: i == count - 1 ? const Radius.circular(10) : Radius.zero,
                bottomRight: i == count - 1 ? const Radius.circular(10) : Radius.zero,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Layout D: large hero top 70% + two small squares bottom 30% ──────────────

class _MosaicGrid extends StatelessWidget {
  final List<String> paths;
  const _MosaicGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 7,
          child: _BookPhotoCell(
            storagePath: paths[0],
            borderRadius: BorderRadius.circular(10).copyWith(
              bottomLeft: Radius.zero,
              bottomRight: Radius.zero,
            ),
          ),
        ),
        if (paths.length > 1) ...[
          const SizedBox(height: 3),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: _BookPhotoCell(
                    storagePath: paths[1],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: paths.length > 2
                      ? _BookPhotoCell(
                          storagePath: paths[2],
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(10),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(10),
                          ),
                          child: Container(color: Colors.white.withAlpha(5)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Layout E: stacked polaroid photos with rotation ───────────────────────────

class _PolaroidGrid extends StatelessWidget {
  final List<String> paths;
  const _PolaroidGrid({required this.paths});

  static const _rotations = <double>[-0.04, 0.05, -0.02];

  @override
  Widget build(BuildContext context) {
    final count = paths.length.clamp(1, 3);
    final w = MediaQuery.of(context).size.width * 0.52;
    final h = w * 1.3;
    return Center(
      child: SizedBox(
        height: h,
        child: Stack(
          alignment: Alignment.center,
          // Render back-to-front so photo 0 is on top
          children: List.generate(count, (i) {
            final offset = (i - (count - 1) / 2) * 22.0;
            return Transform(
              transform: Matrix4.identity()
                ..translateByDouble(offset, 0.0, 0.0, 1.0)
                ..rotateZ(_rotations[i % _rotations.length]),
              alignment: Alignment.center,
              child: Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 36),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _BookPhotoCell(storagePath: paths[i]),
                  ),
                ),
              ),
            );
          }).reversed.toList(),
        ),
      ),
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
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
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
          fontSize: 16,
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
