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
                    _buildPage(context, pages[index], index, pages),
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
  ) {
    return switch (page) {
      CoverBookPage p     => _CoverPage(page: p),
      TitleBookPage p     => _TitlePage(page: p),
      IntroductionBookPage p => _IntroPage(page: p, pageNum: 'i'),
      TocBookPage p       => _TocPage(page: p, onTap: _jumpToPage),
      YearDividerPage p   => _YearPage(page: p),
      MonthDividerPage p  => _MonthPage(page: p),
      ChapterDividerPage p => _ChapterPage(page: p),
      MemoryBookPage p    => _MemoryPage(page: p, pageNum: index),
      TimeBridgePage p    => _TimeBridgePage(page: p),
      ClosingBookPage p   => _ClosingPage(page: p, onRecord: () => context.push('/record'), onWrite: () => context.push('/write')),
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
                      _modeLabel(widget.mode),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: textColor.withAlpha(160),
                      ),
                    ),
                  ),
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

  String _modeLabel(BookMode mode) => switch (mode) {
    BookMode.stream    => 'MY LIFE BOOK',
    BookMode.byTime    => 'YEAR BY YEAR',
    BookMode.byChapter => 'BY CHAPTER',
  };

  String _sectionName(List<BookPage> pages, int currentIndex) {
    // Walk backwards to find the nearest section divider
    for (int i = currentIndex; i >= 0; i--) {
      final p = pages[i];
      if (p is ChapterDividerPage) return p.chapter.title;
      if (p is MonthDividerPage) {
        return DateFormat('MMMM yyyy').format(DateTime(p.year, p.month));
      }
      if (p is YearDividerPage) return p.year.toString();
    }
    return 'My Life Book';
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
            color: AppColors.of(context).accent,
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

/// Thin ornamental rule: — · —
Widget _ornament({Color? color}) {
  return Text(
    '— · —',
    style: TextStyle(
      fontSize: 14,
      color: (color ?? AppColors.readingText).withAlpha(80),
      letterSpacing: 4,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 0. Cover page
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPage extends StatelessWidget {
  final CoverBookPage page;
  const _CoverPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 48, height: 1, color: accent.withAlpha(100)),
              const SizedBox(height: 32),
              Text(
                page.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A personal memoir',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withAlpha(140),
                ),
              ),
              const SizedBox(height: 32),
              Container(width: 48, height: 1, color: accent.withAlpha(100)),
              const SizedBox(height: 32),
              Text(
                page.dateRange.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                  color: Colors.white.withAlpha(100),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withAlpha(80)),
                ),
                child: Text(
                  '${page.memoryCount} ${page.memoryCount == 1 ? 'memory' : 'memories'}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (page.authorName != null) ...[
                const SizedBox(height: 40),
                Text(
                  'By ${page.authorName}',
                  style: GoogleFonts.newsreader(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withAlpha(80),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Title page
// ─────────────────────────────────────────────────────────────────────────────

class _TitlePage extends StatelessWidget {
  final TitleBookPage page;
  const _TitlePage({required this.page});

  @override
  Widget build(BuildContext context) {
    return _readingShell(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.readingText,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              _ornament(),
              const SizedBox(height: 16),
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: AppColors.readingText.withAlpha(140),
                ),
              ),
              const Spacer(flex: 2),
              Text(
                page.dateRange.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                  color: AppColors.readingText.withAlpha(80),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Introduction page
// ─────────────────────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final IntroductionBookPage page;
  final String pageNum;
  const _IntroPage({required this.page, required this.pageNum});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return _readingShell(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Introduction',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 40, height: 2, color: accent.withAlpha(120)),
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

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.of(context).accent;
    return _readingShell(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contents',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 40, height: 2, color: accent.withAlpha(120)),
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
  const _MemoryPage({required this.page, required this.pageNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = page.entry;
    final displayText = (entry.polishedContent?.isNotEmpty == true)
        ? entry.polishedContent!
        : entry.content;
    final dateLabel = DateFormat('MMMM d, yyyy').format(entry.entryDate);
    final timeLabel = entry.entryTime != null
        ? ' · ${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}'
        : '';

    final paragraphs = displayText
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return _readingShell(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + mood row
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$dateLabel$timeLabel'.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.of(context).accent,
                    ),
                  ),
                  if (entry.mood != null) ...[
                    const SizedBox(width: 8),
                    Text(_moodEmoji(entry.mood!), style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
              const SizedBox(height: 24),

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
                      height: 1.75,
                      color: AppColors.readingText,
                    ),
                  ),
                ...paragraphs.skip(1).map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          p,
                          style: GoogleFonts.newsreader(
                            fontSize: 17,
                            height: 1.75,
                            color: AppColors.readingText,
                          ),
                        ),
                      ),
                    ),
              ],

              const SizedBox(height: 32),
              Center(
                child: Text(
                  '${pageNum + 1}',
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

  String _moodEmoji(String mood) => switch (mood.toLowerCase()) {
    'great' => '😄',
    'good'  => '🙂',
    'okay'  => '😐',
    'low'   => '😔',
    'tough' => '😢',
    _       => '',
  };
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
              _ornament(),
              const SizedBox(height: 32),
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
              _ornament(),
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
