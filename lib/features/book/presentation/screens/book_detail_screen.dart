import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';

/// Book detail screen with cover, TOC (By Year / By Chapter), and immersive reading UI.
class BookDetailScreen extends StatefulWidget {
  final GeneratedBook book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

enum _BookView { cover, toc, reading }

class _BookDetailScreenState extends State<BookDetailScreen> {
  _BookView _currentView = _BookView.cover;
  int _currentPageIndex = 0;
  late PageController _pageController;
  bool _showBars = true;

  /// Current reading/TOC mode: by year (chronological) or by chapter (thematic).
  BookViewMode _viewMode = BookViewMode.byYear;

  /// Tracks which year sections are expanded in the By Year TOC.
  final Set<int> _expandedYears = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Expand first year by default if available.
    if (widget.book.yearSections.isNotEmpty) {
      _expandedYears.add(widget.book.yearSections.first.year);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// The active page list depends on the selected view mode.
  List<BookPage> get _activePages {
    if (_viewMode == BookViewMode.byYear &&
        widget.book.yearPages.isNotEmpty) {
      return widget.book.yearPages;
    }
    if (_viewMode == BookViewMode.byChapter &&
        widget.book.chapterPages.isNotEmpty) {
      return widget.book.chapterPages;
    }
    // Fallback to allPages when mode-specific lists are empty.
    return widget.book.allPages;
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case _BookView.cover:
        return _buildCoverView(context);
      case _BookView.toc:
        return _buildTocView(context);
      case _BookView.reading:
        return _buildReadingView(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Cover View
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCoverView(BuildContext context) {
    final colors = AppColors.of(context);
    final book = widget.book;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        size: 20, color: colors.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _openSearch,
                    icon: Icon(Icons.search,
                        size: 22, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            // Book cover
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cover card
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(-0.08),
                      child: Container(
                        width: 220,
                        height: 310,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B4FE8), Color(0xFF5B6CF9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withAlpha(40),
                              blurRadius: 28,
                              offset: const Offset(8, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Decorative circle
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withAlpha(80),
                                    Colors.white.withAlpha(10),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'A PERSONAL JOURNEY',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              book.title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.newsreader(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              book.author,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.dateRange,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: Colors.white.withAlpha(140),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Info row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _infoChip(Icons.menu_book_rounded,
                            '${book.pageCount} pages', colors),
                        const SizedBox(width: 16),
                        _infoChip(Icons.bookmark_outline,
                            '${book.chapterCount} chapters', colors),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Read button
                    SizedBox(
                      width: 200,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => _currentView = _BookView.toc),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Read',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, AppPalette colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Table of Contents View (By Year / By Chapter tabs)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTocView(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _currentView = _BookView.cover),
                    icon: Icon(Icons.arrow_back_ios_new,
                        size: 20, color: colors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Table of Contents',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Segmented control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSegmentedControl(colors),
            ),
            const SizedBox(height: 12),
            // Tab content
            Expanded(
              child: _viewMode == BookViewMode.byYear
                  ? _buildByYearContent(colors)
                  : _buildByChapterContent(colors),
            ),
            // Start reading button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _jumpToPage(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Start Reading',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(AppPalette colors) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.accentFaint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentTab(
            icon: Icons.calendar_today_rounded,
            label: 'By Year',
            isSelected: _viewMode == BookViewMode.byYear,
            onTap: () => setState(() => _viewMode = BookViewMode.byYear),
            colors: colors,
          ),
          _buildSegmentTab(
            icon: Icons.folder_outlined,
            label: 'By Chapter',
            isSelected: _viewMode == BookViewMode.byChapter,
            onTap: () => setState(() => _viewMode = BookViewMode.byChapter),
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppPalette colors,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? colors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.textPrimary.withAlpha(12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colors.accent : colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.accent : colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── By Year content ──────────────────────────────────────────────────

  Widget _buildByYearContent(AppPalette colors) {
    final yearSections = widget.book.yearSections;

    // Fallback: if no yearSections, show classic chapter list.
    if (yearSections.isEmpty) {
      return _buildFallbackChapterList(colors);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: yearSections.length,
      itemBuilder: (context, index) {
        final section = yearSections[index];
        final isExpanded = _expandedYears.contains(section.year);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year header (tap to expand/collapse)
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedYears.remove(section.year);
                  } else {
                    _expandedYears.add(section.year);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    // Year badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${section.year}',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // AI title
                    Expanded(
                      child: Text(
                        '"${section.aiTitle}"',
                        style: GoogleFonts.newsreader(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Months (shown when expanded)
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Column(
                  children: section.months.map((month) {
                    return InkWell(
                      onTap: () {
                        // Find the page index in the active page list.
                        final targetPage = month.startPage - 1;
                        _jumpToPage(targetPage.clamp(0, _activePages.length - 1));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.article_outlined,
                                size: 18, color: colors.textMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                month.title,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${month.pages.length} ${month.pages.length == 1 ? 'page' : 'pages'}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Divider(color: colors.border, height: 1),
          ],
        );
      },
    );
  }

  // ─── By Chapter content ───────────────────────────────────────────────

  Widget _buildByChapterContent(AppPalette colors) {
    final themeChapters = widget.book.themeChapters;

    // Fallback: if no themeChapters, show classic chapter list.
    if (themeChapters.isEmpty) {
      return _buildFallbackChapterList(colors);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: themeChapters.length,
      separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
      itemBuilder: (context, index) {
        final chapter = themeChapters[index];
        return InkWell(
          onTap: () {
            final targetPage = chapter.startPage - 1;
            // Switch to byChapter mode for reading.
            setState(() => _viewMode = BookViewMode.byChapter);
            _jumpToPage(targetPage.clamp(0, _activePages.length - 1));
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                // Emoji icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.accentFaint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chapter.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                // Category + AI subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.category,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '"${chapter.aiSubtitle}"',
                        style: GoogleFonts.newsreader(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Page count
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentFaint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${chapter.pages.length} ${chapter.pages.length == 1 ? 'page' : 'pages'}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Fallback chapter list (legacy format) ────────────────────────────

  Widget _buildFallbackChapterList(AppPalette colors) {
    final book = widget.book;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: book.chapters.length,
      separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
      itemBuilder: (context, index) {
        final chapter = book.chapters[index];
        return InkWell(
          onTap: () => _jumpToPage(chapter.startPage - 1),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.accentFaint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    chapter.title,
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'p. ${chapter.startPage}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _jumpToPage(int pageIndex) {
    final pages = _activePages;
    final clampedIndex = pages.isEmpty ? 0 : pageIndex.clamp(0, pages.length - 1);
    setState(() {
      _currentView = _BookView.reading;
      _currentPageIndex = clampedIndex;
      _showBars = true;
    });
    // Rebuild page controller for new initial page
    _pageController.dispose();
    _pageController = PageController(initialPage: clampedIndex);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Reading View (fullscreen immersive)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReadingView(BuildContext context) {
    final book = widget.book;
    final pages = _activePages;
    const pageBg = Color(0xFFFFF8F0);

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          // Page view
          GestureDetector(
            onTap: () => setState(() => _showBars = !_showBars),
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _currentPageIndex = i),
              itemBuilder: (context, index) {
                final page = pages[index];
                return _buildPage(page, book);
              },
            ),
          ),
          // Top bar
          if (_showBars) _buildReadingTopBar(context, book),
          // Bottom bar
          if (_showBars) _buildReadingBottomBar(context, book),
        ],
      ),
    );
  }

  Widget _buildPage(BookPage page, GeneratedBook book) {
    switch (page.type) {
      case BookPageType.titlePage:
        return _buildTitlePageContent(page);
      case BookPageType.tableOfContents:
        return _buildTocPageContent(book);
      case BookPageType.chapterDivider:
        return _buildChapterDividerContent(page);
      case BookPageType.entryContent:
        return _buildEntryPageContent(page);
    }
  }

  Widget _buildTitlePageContent(BookPage page) {
    return Container(
      color: const Color(0xFFFFF8F0),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A PERSONAL JOURNEY',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                color: const Color(0xFF9C8B7A),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 60,
              height: 1,
              color: const Color(0xFFD4C4B0),
            ),
            const SizedBox(height: 24),
            Text(
              page.content,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: const Color(0xFF3D3228),
              ),
            ),
            const SizedBox(height: 16),
            if (page.chapterTitle != null)
              Text(
                'by ${page.chapterTitle}',
                style: GoogleFonts.newsreader(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF9C8B7A),
                ),
              ),
            if (page.dateLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                page.dateLabel!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFFB0A090),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTocPageContent(GeneratedBook book) {
    return Container(
      color: const Color(0xFFFFF8F0),
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contents',
            style: GoogleFonts.newsreader(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3D3228),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 2,
            color: const Color(0xFFD4C4B0),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: book.chapters.length,
              itemBuilder: (context, index) {
                final chapter = book.chapters[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chapter.title,
                          style: GoogleFonts.newsreader(
                            fontSize: 16,
                            color: const Color(0xFF3D3228),
                          ),
                        ),
                      ),
                      // Dotted line
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          height: 1,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFD4C4B0),
                                width: 1,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${chapter.startPage}',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: const Color(0xFF9C8B7A),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterDividerContent(BookPage page) {
    return Container(
      color: const Color(0xFFFFF8F0),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 1,
              color: const Color(0xFFD4C4B0),
            ),
            const SizedBox(height: 24),
            Text(
              page.content,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3D3228),
              ),
            ),
            if (page.dateLabel != null && page.dateLabel!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                page.dateLabel!,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF9C8B7A),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              width: 40,
              height: 1,
              color: const Color(0xFFD4C4B0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryPageContent(BookPage page) {
    return Container(
      color: const Color(0xFFFFF8F0),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter title on first page of chapter
            if (page.chapterTitle != null) ...[
              Text(
                page.chapterTitle!,
                style: GoogleFonts.newsreader(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: const Color(0xFFB0A090),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Date & metadata
            if (page.dateLabel != null) ...[
              Row(
                children: [
                  Text(
                    page.dateLabel!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9C8B7A),
                    ),
                  ),
                  if (page.mood != null) ...[
                    const SizedBox(width: 8),
                    _readingMoodDot(page.mood!),
                  ],
                  if (page.locationName != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on,
                        size: 12, color: Color(0xFFB0A090)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        page.locationName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFFB0A090),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                height: 0.5,
                color: const Color(0xFFE0D5C8),
              ),
              const SizedBox(height: 16),
            ],
            // Content
            Text(
              page.content,
              style: GoogleFonts.newsreader(
                fontSize: 17,
                height: 1.7,
                color: const Color(0xFF3D3228),
              ),
            ),
            const SizedBox(height: 32),
            // Page number
            Center(
              child: Text(
                '${page.pageNumber}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFFB0A090),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readingMoodDot(String mood) {
    final color = switch (mood) {
      'great' => AppColors.moodGreat,
      'good' => AppColors.moodGood,
      'okay' => AppColors.moodOkay,
      'low' => AppColors.moodLow,
      'tough' => AppColors.moodTough,
      _ => Colors.grey,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // ─── Reading top bar ──────────────────────────────────────────────────

  Widget _buildReadingTopBar(BuildContext context, GeneratedBook book) {
    final pages = _activePages;
    final modeLabel =
        _viewMode == BookViewMode.byYear ? 'By Year' : 'By Chapter';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showBars ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFF8F0),
                const Color(0xFFFFF8F0).withAlpha(0),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      setState(() => _currentView = _BookView.toc),
                  icon: const Icon(Icons.close,
                      size: 22, color: Color(0xFF3D3228)),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Page ${_currentPageIndex + 1} of ${pages.length}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9C8B7A),
                        ),
                      ),
                      Text(
                        modeLabel,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: const Color(0xFFB0A090),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search,
                      size: 22, color: Color(0xFF3D3228)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Reading bottom bar ───────────────────────────────────────────────

  Widget _buildReadingBottomBar(BuildContext context, GeneratedBook book) {
    final pages = _activePages;
    final progress =
        pages.isEmpty ? 0.0 : (_currentPageIndex + 1) / pages.length;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showBars ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFFF8F0),
                const Color(0xFFFFF8F0).withAlpha(0),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress slider
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: const Color(0xFF3D3228),
                    inactiveTrackColor: const Color(0xFFE0D5C8),
                    thumbColor: const Color(0xFF3D3228),
                  ),
                  child: Slider(
                    value: _currentPageIndex.toDouble(),
                    min: 0,
                    max: (pages.length - 1).toDouble().clamp(0, double.infinity),
                    onChanged: (v) {
                      final page = v.round();
                      _pageController.jumpToPage(page);
                      setState(() => _currentPageIndex = page);
                    },
                  ),
                ),
                // Percentage
                Text(
                  '${(progress * 100).round()}% complete',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: const Color(0xFFB0A090),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════════════════════════════════════

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookSearchSheet(
        book: widget.book,
        pages: _activePages,
        onPageSelected: (pageIndex) {
          Navigator.pop(ctx);
          _jumpToPage(pageIndex);
        },
      ),
    );
  }
}

// =============================================================================
// Search Bottom Sheet
// =============================================================================

class _BookSearchSheet extends StatefulWidget {
  final GeneratedBook book;
  final List<BookPage> pages;
  final void Function(int pageIndex) onPageSelected;

  const _BookSearchSheet({
    required this.book,
    required this.pages,
    required this.onPageSelected,
  });

  @override
  State<_BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<_BookSearchSheet> {
  final _searchController = TextEditingController();
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = <_SearchResult>[];

    for (int i = 0; i < widget.pages.length; i++) {
      final page = widget.pages[i];
      final content = page.content.toLowerCase();
      if (content.contains(lowerQuery)) {
        // Extract snippet around the match
        final matchIndex = content.indexOf(lowerQuery);
        final snippetStart = (matchIndex - 40).clamp(0, content.length);
        final snippetEnd =
            (matchIndex + query.length + 60).clamp(0, content.length);
        final snippet = (snippetStart > 0 ? '...' : '') +
            page.content.substring(snippetStart, snippetEnd) +
            (snippetEnd < content.length ? '...' : '');

        results.add(_SearchResult(
          pageIndex: i,
          pageNumber: page.pageNumber,
          snippet: snippet,
          chapterTitle: page.chapterTitle,
        ));
      }
    }

    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _search,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search in book...',
                    hintStyle: GoogleFonts.manrope(color: colors.textMuted),
                    prefixIcon:
                        Icon(Icons.search, color: colors.textMuted, size: 20),
                    filled: true,
                    fillColor: colors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Results
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Type to search'
                              : 'No results found',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: colors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: colors.border, height: 1),
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return InkWell(
                            onTap: () =>
                                widget.onPageSelected(result.pageIndex),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Page ${result.pageNumber}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colors.accent,
                                        ),
                                      ),
                                      if (result.chapterTitle != null) ...[
                                        Text(
                                          '  |  ${result.chapterTitle}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    result.snippet,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResult {
  final int pageIndex;
  final int pageNumber;
  final String snippet;
  final String? chapterTitle;

  const _SearchResult({
    required this.pageIndex,
    required this.pageNumber,
    required this.snippet,
    this.chapterTitle,
  });
}
