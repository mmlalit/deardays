import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';

/// Book detail screen — real book layout: Cover → Contents → Body → Back Matter.
/// Design matches the DearDays memoir HTML template.
class BookDetailScreen extends StatefulWidget {
  final GeneratedBook book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

enum _BookView { cover, toc, reading }

class _BookDetailScreenState extends State<BookDetailScreen> {
  _BookView _currentView = _BookView.toc;
  int _currentPageIndex = 0;
  late PageController _pageController;
  bool _showBars = true;
  bool _isFullscreen = false;

  BookViewMode _viewMode = BookViewMode.byYear;
  final Set<int> _expandedYears = {};

  // ── Color palette (from HTML) ───────────────────────────────────────────
  static const _bgLight = Color(0xFFF8FAFC);
  static const _accentTan = Color(0xFFC69C72);
  static const _primary = Color(0xFF195DE6);
  static const _inkDark = Color(0xFF1E293B); // slate-800
  static const _inkMedium = Color(0xFF64748B); // slate-500
  static const _inkLight = Color(0xFF94A3B8); // slate-400
  static const _inkFaint = Color(0xFFCBD5E1); // slate-300
  static const _divider = Color(0xFFF1F5F9); // slate-100
  static const _white95 = Color(0xF2FFFFFF);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.book.yearSections.isNotEmpty) {
      _expandedYears.add(widget.book.yearSections.first.year);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  List<BookPage> get _activePages {
    if (_viewMode == BookViewMode.byYear && widget.book.yearPages.isNotEmpty) {
      return widget.book.yearPages;
    }
    if (_viewMode == BookViewMode.byChapter &&
        widget.book.chapterPages.isNotEmpty) {
      return widget.book.chapterPages;
    }
    if (_viewMode == BookViewMode.byAi &&
        widget.book.aiStoryPages.isNotEmpty) {
      return widget.book.aiStoryPages;
    }
    return widget.book.allPages;
  }

  void _jumpToPage(int index) {
    final pages = _activePages;
    if (pages.isEmpty) return;
    final clamped = index.clamp(0, pages.length - 1);
    setState(() {
      _currentView = _BookView.reading;
      _currentPageIndex = clamped;
      _showBars = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(clamped);
      }
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _showBars = false;
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        _showBars = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case _BookView.cover:
      case _BookView.toc:
        return _buildScrollableBook(context);
      case _BookView.reading:
        return _buildReadingView(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Scrollable Book View (Cover → Contents → Body) — matches HTML template
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScrollableBook(BuildContext context) {
    final book = widget.book;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          // ── Main scrollable content ─────────────────────────────────────
          CustomScrollView(
            slivers: [
              // ── Sticky header ───────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: _bgLight.withAlpha(204),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  color: _inkDark,
                ),
                centerTitle: true,
                title: Text(
                  'DEARDAYS',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    color: _inkDark,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _showModeSelector(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _accentTan.withAlpha(50)),
                          color: _accentTan.withAlpha(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _viewModeLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _accentTan,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.expand_more,
                                size: 16, color: _accentTan),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── 1. FRONT MATTER: Hero Cover ─────────────────────────────
              SliverToBoxAdapter(child: _buildHeroCover(book)),

              // ── 2. FRONT MATTER: Contents ───────────────────────────────
              SliverToBoxAdapter(child: _buildContentsSection(book)),

              // ── 3. BODY MATTER: Entries ──────────────────────────────────
              _buildBodyEntries(book),

              // ── 4. BACK MATTER: Download + About ─────────────────────────
              SliverToBoxAdapter(child: _buildBackMatter(book, colors)),

              // Bottom padding for floating nav
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),

          // ── Floating Bottom Navigation ──────────────────────────────────
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildFloatingNav(context),
          ),
        ],
      ),
    );
  }

  String get _viewModeLabel {
    switch (_viewMode) {
      case BookViewMode.byYear:
        return 'Memoir';
      case BookViewMode.byChapter:
        return 'Chapters';
      case BookViewMode.byAi:
        return 'Story';
    }
  }

  void _showModeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _inkFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reading Mode',
                      style: GoogleFonts.newsreader(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _inkDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: _inkLight),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _modeTile(ctx, BookViewMode.byYear, Icons.calendar_today_rounded,
                  'Memoir', 'Chronological — by year and month'),
              _modeTile(ctx, BookViewMode.byChapter, Icons.folder_outlined,
                  'Chapters', 'Thematic — Family, Career, Travel...'),
              _modeTile(ctx, BookViewMode.byAi, Icons.auto_awesome_rounded,
                  'AI Story', 'Seamless narrative woven by AI'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTile(BuildContext ctx, BookViewMode mode, IconData icon,
      String title, String subtitle) {
    final isSelected = _viewMode == mode;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? _primary : _inkLight, size: 22),
      title: Text(title,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? _primary : _inkDark,
          )),
      subtitle: Text(subtitle,
          style: GoogleFonts.manrope(fontSize: 12, color: _inkLight)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: _primary, size: 20)
          : null,
      onTap: () {
        setState(() => _viewMode = mode);
        Navigator.pop(ctx);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. FRONT MATTER — Hero Cover (matches HTML hero section)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroCover(GeneratedBook book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: AspectRatio(
        aspectRatio: 3 / 4.5,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background — gradient fallback (or user photo if available)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF4A5568),
                      Color(0xFF2D3748),
                      Color(0xFF1A202C),
                    ],
                  ),
                ),
              ),
              // Author initial watermark
              Positioned(
                top: 20,
                left: 24,
                child: Text(
                  book.author.isNotEmpty ? book.author[0].toUpperCase() : '',
                  style: GoogleFonts.newsreader(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withAlpha(40),
                  ),
                ),
              ),
              // Gradient overlay from bottom
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(50),
                      Colors.black.withAlpha(200),
                    ],
                  ),
                ),
              ),
              // Text content at bottom
              Positioned(
                left: 28,
                right: 28,
                bottom: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: GoogleFonts.newsreader(
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.dateRange.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3,
                        color: Colors.white.withAlpha(200),
                      ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // 2. FRONT MATTER — Contents Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContentsSection(GeneratedBook book) {
    final chapters = _getContentChapters(book);

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Contents" header — italic serif in gold
          Text(
            'Contents',
            style: GoogleFonts.newsreader(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: _accentTan,
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _divider),
          const SizedBox(height: 20),

          // Chapter rows
          ...chapters.asMap().entries.map((e) {
            final idx = e.key;
            final ch = e.value;
            return _buildContentRow(
              number: '${(idx + 1).toString().padLeft(2, '0')}',
              title: ch['title'] as String,
              subtitle: ch['subtitle'] as String,
              onTap: () {
                final page = ch['startPage'] as int? ?? 0;
                _jumpToPage(page);
              },
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getContentChapters(GeneratedBook book) {
    if (_viewMode == BookViewMode.byYear && book.yearSections.isNotEmpty) {
      return book.yearSections.map((s) => {
            'title': '${s.year}: ${s.aiTitle}',
            'subtitle':
                'Chapter ${book.yearSections.indexOf(s) + 1} \u2022 ${s.months.fold<int>(0, (sum, m) => sum + m.pages.length)} Entries',
            'startPage': s.months.isNotEmpty ? s.months.first.startPage - 1 : 0,
          }).toList();
    }
    if (_viewMode == BookViewMode.byChapter && book.themeChapters.isNotEmpty) {
      return book.themeChapters.map((ch) => {
            'title': '${ch.icon} ${ch.category}',
            'subtitle': '${ch.aiSubtitle} \u2022 ${ch.pages.length} Entries',
            'startPage': ch.startPage - 1,
          }).toList();
    }
    // Fallback to generic chapters
    return book.chapters.asMap().entries.map((e) => {
          'title': e.value.title,
          'subtitle':
              'Chapter ${e.key + 1} \u2022 ${e.value.pages.length} Pages',
          'startPage': e.value.startPage - 1,
        }).toList();
  }

  Widget _buildContentRow({
    required String number,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter number — italic serif gold
            SizedBox(
              width: 32,
              child: Text(
                number,
                style: GoogleFonts.newsreader(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: _accentTan.withAlpha(130),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: _inkDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: _inkLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, size: 18, color: _inkFaint),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. BODY MATTER — Entry content with drop caps, images, dates
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBodyEntries(GeneratedBook book) {
    final pages = _activePages;
    if (pages.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Group into content entries only
    final entryPages =
        pages.where((p) => p.type == BookPageType.entryContent).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final page = entryPages[index];
          return _buildEntrySection(page, index, entryPages.length);
        },
        childCount: entryPages.length,
      ),
    );
  }

  Widget _buildEntrySection(BookPage page, int index, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Entry divider with metadata ─────────────────────────────────
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _divider)),
            ),
            child: Row(
              children: [
                // Date + mood
                Expanded(
                  child: Row(
                    children: [
                      if (page.dateLabel != null)
                        Text(
                          page.dateLabel!.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: _accentTan,
                          ),
                        ),
                      if (page.mood != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('\u2022',
                              style: TextStyle(
                                  fontSize: 8, color: _inkFaint)),
                        ),
                        Text(
                          'Mood: ${_moodLabel(page.mood)}',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.5,
                            color: _inkLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Page number
                Text(
                  'Page ${page.pageNumber}',
                  style: GoogleFonts.newsreader(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: _inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Main narrative content with drop cap ────────────────────────
          _buildDropCapParagraph(page.content),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Renders text with a large gold drop cap for the first letter.
  Widget _buildDropCapParagraph(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final firstLetter = text[0].toLowerCase();
    final rest = text.substring(1);

    // Split into paragraphs
    final paragraphs = rest.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First paragraph with drop cap
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop cap letter
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 4),
              child: Text(
                firstLetter,
                style: GoogleFonts.newsreader(
                  fontSize: 64,
                  fontWeight: FontWeight.w400,
                  height: 0.75,
                  color: _accentTan,
                ),
              ),
            ),
            // First paragraph text
            Expanded(
              child: Text(
                paragraphs.isNotEmpty ? paragraphs.first : rest,
                style: GoogleFonts.newsreader(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.8,
                  color: _inkDark,
                ),
              ),
            ),
          ],
        ),

        // Remaining paragraphs
        if (paragraphs.length > 1)
          ...paragraphs.skip(1).map((p) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  p.trim(),
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.8,
                    color: _inkDark,
                  ),
                ),
              )),
      ],
    );
  }

  String _moodLabel(String? mood) {
    switch (mood) {
      case 'great':
        return 'Radiant';
      case 'good':
        return 'Serene';
      case 'okay':
        return 'Thoughtful';
      case 'low':
        return 'Melancholy';
      case 'tough':
        return 'Stormy';
      default:
        return 'Reflective';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. BACK MATTER — Download PDF + About the Author
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBackMatter(GeneratedBook book, AppPalette appColors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 0),
      child: Column(
        children: [
          // ── Download as PDF button ──────────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/export'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: _accentTan.withAlpha(50),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      size: 20, color: _accentTan),
                  const SizedBox(width: 10),
                  Text(
                    'Download as PDF',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _accentTan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),

          // ── About the Author ────────────────────────────────────────────
          Container(height: 1, color: _divider),
          const SizedBox(height: 32),
          Text(
            'ABOUT THE AUTHOR',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: _inkLight,
            ),
          ),
          const SizedBox(height: 16),
          // Author avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentTan.withAlpha(30),
            ),
            child: Center(
              child: Text(
                book.author.isNotEmpty ? book.author[0].toUpperCase() : 'A',
                style: GoogleFonts.newsreader(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: _accentTan,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            book.author,
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This book was lovingly assembled from ${book.sourceEntries.length} journal entries, '
            'spanning ${book.dateRange}. Every word captures a moment lived, '
            'a thought felt, a memory worth keeping.',
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.7,
              color: _inkMedium,
            ),
          ),
          const SizedBox(height: 32),

          // ── Book info ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bookInfoChip(Icons.menu_book_rounded,
                  '${_activePages.length} pages'),
              const SizedBox(width: 16),
              _bookInfoChip(Icons.bookmark_outline,
                  '${widget.book.chapterCount} chapters'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Made with DearDays',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: _inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _inkLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _inkMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Floating Bottom Navigation (matches HTML nav)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFloatingNav(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: _white95,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.black.withAlpha(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Save
              _navButton(Icons.bookmark_outline, 'SAVE', () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Book saved!',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }),
              // Share
              _navButton(Icons.share_outlined, 'SHARE', () {
                HapticFeedback.selectionClick();
                _showShareSheet(context);
              }),
              // Play (large center button)
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _jumpToPage(0);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 30, color: Colors.white),
                ),
              ),
              // Listen
              _navButton(Icons.headphones_rounded, 'LISTEN', () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Audio coming soon',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: _inkMedium,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }),
              // Display
              _navButton(Icons.settings_outlined, 'DISPLAY', () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Display settings coming soon',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: _inkMedium,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: _inkMedium),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _inkMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _inkFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share Your Story',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _inkDark,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_rounded, color: _primary),
                title: Text('Export as PDF',
                    style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Download a beautifully formatted book',
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: _inkLight)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/export');
                },
              ),
              ListTile(
                leading: Icon(Icons.link_rounded, color: _primary),
                title: Text('Copy Link',
                    style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: Text('Share a read-only link',
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: _inkLight)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link sharing coming soon',
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _inkMedium,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Reading View — immersive page-by-page (swipe left/right)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReadingView(BuildContext context) {
    final pages = _activePages;
    if (pages.isEmpty) {
      return Scaffold(
        backgroundColor: _bgLight,
        body: Center(
          child: Text('No pages yet',
              style: GoogleFonts.newsreader(
                  fontSize: 18, color: _inkLight)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1), // cream paper
      body: SafeArea(
        child: Stack(
          children: [
            // ── Page content (swipeable) ──────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _showBars = !_showBars),
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) =>
                    setState(() => _currentPageIndex = i),
                itemBuilder: (_, index) {
                  final page = pages[index];
                  return _buildReadingPage(page, index, pages.length);
                },
              ),
            ),

            // ── Top bar ───────────────────────────────────────────────────
            if (_showBars)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F1).withAlpha(240),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE8DDD0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            setState(() => _currentView = _BookView.toc),
                        icon: const Icon(Icons.arrow_back_ios,
                            size: 18, color: _inkDark),
                      ),
                      Expanded(
                        child: Text(
                          _readingLabel(pages[_currentPageIndex]),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _inkMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleFullscreen,
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          size: 20,
                          color: _inkMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: _showGoToPageDialog,
                        icon: const Icon(Icons.menu_book_rounded,
                            size: 20, color: _inkMedium),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Bottom bar ────────────────────────────────────────────────
            if (_showBars)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F1).withAlpha(240),
                    border: const Border(
                      top: BorderSide(color: Color(0xFFE8DDD0)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _accentTan,
                          inactiveTrackColor: _divider,
                          thumbColor: _accentTan,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          trackHeight: 2,
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _currentPageIndex.toDouble(),
                          min: 0,
                          max: (pages.length - 1).toDouble().clamp(0, double.infinity),
                          onChanged: (v) {
                            final idx = v.round();
                            _pageController.jumpToPage(idx);
                            setState(() => _currentPageIndex = idx);
                          },
                        ),
                      ),
                      Text(
                        'Page ${_currentPageIndex + 1} of ${pages.length}',
                        style: GoogleFonts.newsreader(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: _inkLight,
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

  Widget _buildReadingPage(BookPage page, int index, int total) {
    switch (page.type) {
      case BookPageType.titlePage:
        return _buildTitleReadingPage(page);
      case BookPageType.tableOfContents:
        return _buildTocReadingPage(page);
      case BookPageType.chapterDivider:
        return _buildChapterDividerPage(page);
      case BookPageType.entryContent:
        return _buildEntryReadingPage(page, index, total);
    }
  }

  Widget _buildTitleReadingPage(BookPage page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decorative line
          Container(width: 40, height: 1, color: _accentTan.withAlpha(100)),
          const SizedBox(height: 24),
          Text(
            'A PERSONAL JOURNEY',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: _accentTan,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            page.content,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: _inkDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'by ${widget.book.author}',
            style: GoogleFonts.newsreader(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: _accentTan,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.book.dateRange,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: _inkLight,
            ),
          ),
          const SizedBox(height: 24),
          Container(width: 40, height: 1, color: _accentTan.withAlpha(100)),
        ],
      ),
    );
  }

  Widget _buildTocReadingPage(BookPage page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contents',
            style: GoogleFonts.newsreader(
              fontSize: 26,
              fontStyle: FontStyle.italic,
              color: _accentTan,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _divider),
          const SizedBox(height: 16),
          Text(
            page.content,
            style: GoogleFonts.newsreader(
              fontSize: 16,
              height: 2.0,
              color: _inkDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterDividerPage(BookPage page) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 1, color: _accentTan.withAlpha(80)),
            const SizedBox(height: 20),
            if (page.chapterTitle != null)
              Text(
                page.chapterTitle!.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: _accentTan,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              page.content,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: _inkDark,
              ),
            ),
            const SizedBox(height: 20),
            Container(width: 30, height: 1, color: _accentTan.withAlpha(80)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryReadingPage(BookPage page, int index, int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + mood header
          if (page.dateLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Text(
                    page.dateLabel!.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: _accentTan,
                    ),
                  ),
                  if (page.mood != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('\u2022',
                          style: TextStyle(fontSize: 8, color: _inkFaint)),
                    ),
                    Text(
                      'Mood: ${_moodLabel(page.mood)}',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.5,
                        color: _inkLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Body text with drop cap
          _buildDropCapParagraph(page.content),

          // Page number at bottom
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                '\u2014 ${page.pageNumber} \u2014',
                style: GoogleFonts.newsreader(
                  fontSize: 12,
                  color: _inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _readingLabel(BookPage page) {
    if (_viewMode == BookViewMode.byAi) return 'Your Story';
    if (page.chapterTitle != null) return page.chapterTitle!;
    if (page.dateLabel != null) return page.dateLabel!;
    return widget.book.title;
  }

  void _showGoToPageDialog() {
    final pages = _activePages;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Go to Page',
          style: GoogleFonts.newsreader(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _inkDark,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.manrope(fontSize: 16, color: _inkDark),
          decoration: InputDecoration(
            hintText: '1 - ${pages.length}',
            hintStyle: GoogleFonts.manrope(color: _inkFaint),
            filled: true,
            fillColor: _bgLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _divider),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null && page >= 1 && page <= pages.length) {
              Navigator.pop(ctx);
              _pageController.jumpToPage(page - 1);
              setState(() => _currentPageIndex = page - 1);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.manrope(color: _inkLight)),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= pages.length) {
                Navigator.pop(ctx);
                _pageController.jumpToPage(page - 1);
                setState(() => _currentPageIndex = page - 1);
              }
            },
            child: Text('Go',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: _primary,
                )),
          ),
        ],
      ),
    );
  }

}
