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
  bool _overlayVisible = true;
  bool _isDearDays = false; // toggle: false = Original, true = ✦ DearDays

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

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(timelineEntriesProvider);
    final chaptersAsync = ref.watch(chaptersProvider);
    final profileAsync = ref.watch(profileProvider);

    final entries = entriesAsync.valueOrNull ?? [];
    final chapters = chaptersAsync.valueOrNull ?? [];
    final authorName = profileAsync.valueOrNull?.displayName ?? 'You';

    if (entries.isEmpty) return _buildEmpty(context);

    final pages = BookBuilderService().build(
      entries: entries,
      mode: widget.mode,
      authorName: authorName,
      chapters: chapters,
    );

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

              // Thin progress bar — always visible
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ProgressBar(
                  value: pages.length > 1 ? _currentPage / (pages.length - 1) : 0,
                ),
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
      CoverBookPage p        => _CoverPage(page: p),
      IntroductionBookPage p => _IntroPage(page: p, pageNum: 'i'),
      TocBookPage p          => _TocPage(page: p, onTap: _jumpToPage),
      YearDividerPage p      => _YearPage(page: p),
      MonthDividerPage p     => _MonthPage(page: p),
      ChapterDividerPage p   => _ChapterPage(page: p),
      MemoryBookPage p       => _MemoryPage(page: p, pageNum: index, isDearDays: _isDearDays),
      WeeklyNarrativeBookPage p => _WeeklyNarrativePage(page: p, pageNum: index, isDearDays: _isDearDays, allEntries: entries),
      TimeBridgePage p       => _TimeBridgePage(page: p),
      ClosingBookPage p      => _ClosingPage(page: p, onRecord: () => context.push('/record'), onWrite: () => context.push('/write')),
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
                  // JOURNAL | ✦ DEARDAYS STORY segmented toggle
                  _SegmentedToggle(
                    isDearDays: _isDearDays,
                    textColor: textColor,
                    accentColor: const Color(0xFF6366F1),
                    onChanged: (val) => setState(() => _isDearDays = val),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => context.push('/export'),
                    icon: Icon(Icons.download_rounded, size: 20, color: textColor.withAlpha(180)),
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
        ? Colors.black.withAlpha(100)
        : AppColors.readingBg.withAlpha(220);

    final sectionName = _sectionName(pages, _currentPage);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _overlayVisible ? 1.0 : 0.0,
        child: Container(
          color: bgColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sectionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: textColor.withAlpha(100),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} / ${pages.length}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: textColor.withAlpha(100),
                      fontStyle: FontStyle.italic,
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isDarkPage(BookPage? page) => switch (page) {
    CoverBookPage()      => true,
    YearDividerPage()    => true,
    MonthDividerPage()   => true,
    ChapterDividerPage() => true,
    TimeBridgePage()     => false,
    _                    => false,
  };

  String _sectionName(List<BookPage> pages, int currentIndex) {
    final current = currentIndex < pages.length ? pages[currentIndex] : null;
    // Front-matter pages — show their own label
    if (current is CoverBookPage) return '';
    if (current is IntroductionBookPage) return 'Introduction';
    if (current is TocBookPage) return 'Contents';
    if (current is ClosingBookPage) return 'Closing';

    // Walk backwards to find the nearest section divider
    for (int i = currentIndex; i >= 0; i--) {
      final p = pages[i];
      if (p is ChapterDividerPage) return p.chapter.title;
      if (p is MonthDividerPage) {
        return DateFormat('MMMM yyyy').format(DateTime(p.year, p.month));
      }
      if (p is YearDividerPage) return p.year.toString();
    }
    // Stream mode — derive from the current memory page date
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
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value,
      backgroundColor: Colors.transparent,
      valueColor: AlwaysStoppedAnimation<Color>(
        AppColors.of(context).accent.withAlpha(180),
      ),
      minHeight: 2,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared reading typography helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Full page with warm reading background — used for front/back matter & memory pages.
Widget _readingShell({required Widget child}) {
  return Container(
    width: double.infinity,
    height: double.infinity,
    color: AppColors.readingBg,
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

        // Gradient scrim — light top tint, strong dark bottom 40%
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
              colors: [
                Colors.black.withAlpha(50),
                Colors.black.withAlpha(20),
                Colors.black.withAlpha(230),
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
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
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
  const _IntroPage({required this.page, required this.pageNum});

  // Warm sepia — pairs with the cream reading background
  static const _titleColor = Color(0xFF5C3D1E);

  @override
  Widget build(BuildContext context) {
    return _readingShell(
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
  const _TocPage({required this.page, required this.onTap});

  static const _titleColor = Color(0xFF5C3D1E);

  @override
  Widget build(BuildContext context) {
    return _readingShell(
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
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: page.entries.length,
                  itemBuilder: (context, i) => _TocRow(
                    entry: page.entries[i],
                    onTap: () => onTap(page.entries[i].pageIndex),
                  ),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(entry.isSubEntry ? 16 : 0, 0, 0, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: GoogleFonts.newsreader(
                      fontSize: entry.isSubEntry ? 14 : 15,
                      fontWeight: entry.isSubEntry ? FontWeight.w400 : FontWeight.w600,
                      color: AppColors.readingText,
                    ),
                  ),
                  if (entry.meta != null)
                    Text(
                      entry.meta!,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: AppColors.readingText.withAlpha(100),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // Dot leader
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 40,
                child: Divider(
                  color: AppColors.readingText.withAlpha(30),
                  thickness: 1,
                ),
              ),
            ),
            // Page number
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
    final dateLabel = DateFormat('MMMM d, yyyy').format(entry.entryDate);

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
              // Elegant date line — no app-style UI elements
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
// Closing page
// ─────────────────────────────────────────────────────────────────────────────

class _ClosingPage extends StatelessWidget {
  final ClosingBookPage page;
  final VoidCallback onRecord;
  final VoidCallback onWrite;
  const _ClosingPage({
    required this.page,
    required this.onRecord,
    required this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _readingShell(
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
  const _WeeklyNarrativePage({
    required this.page,
    required this.pageNum,
    required this.isDearDays,
    required this.allEntries,
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
// Segmented toggle: JOURNAL | ✦ DEARDAYS STORY
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final bool isDearDays;
  final Color textColor;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _SegmentedToggle({
    required this.isDearDays,
    required this.textColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: textColor.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegTab(
            label: 'Journal',
            active: !isDearDays,
            activeColor: textColor.withAlpha(200),
            textColor: textColor,
            onTap: () => onChanged(false),
          ),
          _SegTab(
            label: '✦ Story',
            active: isDearDays,
            activeColor: accentColor,
            textColor: textColor,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color textColor;
  final VoidCallback onTap;

  const _SegTab({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : textColor.withAlpha(100),
          ),
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
