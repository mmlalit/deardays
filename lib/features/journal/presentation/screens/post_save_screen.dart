import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/services/ai/tag_suggestion_service.dart';

/// Lightweight data object passed from ReviewSaveScreen → PostSaveScreen.
class PostSaveData {
  final String entryId;
  final String title;
  final String content;

  const PostSaveData({
    required this.entryId,
    required this.title,
    required this.content,
  });
}

class PostSaveScreen extends ConsumerStatefulWidget {
  final PostSaveData data;

  const PostSaveScreen({super.key, required this.data});

  @override
  ConsumerState<PostSaveScreen> createState() => _PostSaveScreenState();
}

class _PostSaveScreenState extends ConsumerState<PostSaveScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0 = tags, 1 = chapter, 2 = book

  // Step 1 — Tags
  late List<String> _suggestedTags;
  final Set<String> _selectedTags = {};
  final TextEditingController _customTagController = TextEditingController();

  // Step 2 — Chapter
  String? _selectedChapterId;

  // Step 3 — Book
  String? _selectedBookId;

  @override
  void initState() {
    super.initState();
    _suggestedTags = TagSuggestionService.suggest(widget.data.content);
    _selectedTags.addAll(_suggestedTags);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() {
    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _skip() {
    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _skipAll() {
    _finish();
  }

  void _finish() {
    HapticFeedback.lightImpact();
    // Pop back to home (through any intermediate screens)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        if (!_suggestedTags.contains(tag)) {
          _suggestedTags.add(tag);
        }
        _selectedTags.add(tag);
        _customTagController.clear();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildHeader(colors),
          _buildProgressIndicator(colors),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTagStep(colors),
                _buildChapterStep(colors),
                _buildBookStep(colors),
              ],
            ),
          ),
          _buildBottomBar(colors),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: _skipAll,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.close_rounded, size: 22, color: colors.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  'Organize Memory',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _skipAll,
                child: Text(
                  'Skip All',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress indicator
  // ---------------------------------------------------------------------------

  Widget _buildProgressIndicator(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive ? colors.accent : colors.border,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Tags
  // ---------------------------------------------------------------------------

  Widget _buildTagStep(AppPalette colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry title preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_stories_rounded, size: 20, color: colors.accent),
                const SizedBox(height: 8),
                Text(
                  widget.data.title,
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'We found these tags for your memory:',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Tap to toggle. Tags help you find memories later.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Tag chips
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              // Suggested + custom tags
              ..._suggestedTags.map((tag) => _buildTagChip(tag, colors)),
              // Remaining available tags not already suggested
              ...TagSuggestionService.allTags
                  .where((t) => !_suggestedTags.contains(t))
                  .map((tag) => _buildTagChip(tag, colors)),
            ],
          ),

          const SizedBox(height: 20),

          // Custom tag input
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: _customTagController,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add custom tag...',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 14,
                        color: colors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addCustomTag(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addCustomTag,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag, AppPalette colors) {
    final isSelected = _selectedTags.contains(tag);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedTags.remove(tag);
          } else {
            _selectedTags.add(tag);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
          ),
        ),
        child: Text(
          tag,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Chapters
  // ---------------------------------------------------------------------------

  Widget _buildChapterStep(AppPalette colors) {
    final chaptersAsync = ref.watch(chaptersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add to a chapter?',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Chapters organize your memories into life themes.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          chaptersAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => _buildMockChapters(colors),
            data: (chapters) {
              if (chapters.isEmpty) return _buildMockChapters(colors);
              return Column(
                children: chapters
                    .map((c) => _buildChapterCard(c.id, c.title, c.entryCount, colors))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 12),

          // Create new chapter option
          GestureDetector(
            onTap: () {
              // Placeholder — would open a create chapter dialog
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Create chapter coming soon',
                    style: GoogleFonts.manrope(fontSize: 13),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withAlpha(80),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Create New Chapter',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback mock chapters when no real data is available.
  Widget _buildMockChapters(AppPalette colors) {
    final mockChapters = [
      ('ch-travel', 'Travel & Adventures', 12),
      ('ch-family', 'Family Moments', 8),
      ('ch-growth', 'Personal Growth', 5),
      ('ch-career', 'Career Milestones', 6),
    ];

    return Column(
      children: mockChapters
          .map((c) => _buildChapterCard(c.$1, c.$2, c.$3, colors))
          .toList(),
    );
  }

  Widget _buildChapterCard(
    String id,
    String title,
    int entryCount,
    AppPalette colors,
  ) {
    final isSelected = _selectedChapterId == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedChapterId = isSelected ? null : id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentFaint : colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : colors.accentFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bookmark_rounded,
                size: 20,
                color: isSelected ? Colors.white : colors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$entryCount ${entryCount == 1 ? 'memory' : 'memories'}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 22, color: colors.accent),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Books
  // ---------------------------------------------------------------------------

  Widget _buildBookStep(AppPalette colors) {
    final booksAsync = ref.watch(booksProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add to a book?',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Books collect your memories into beautiful life stories.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          booksAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => _buildBookList([], colors),
            data: (books) => _buildBookList(books, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList(List<Book> books, AppPalette colors) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.auto_stories_rounded, size: 48, color: colors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No books yet',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your first book will be created automatically.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: books.map((book) {
        final isSelected = _selectedBookId == book.id;
        final bookColor = _parseHexColor(book.coverColor);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedBookId = isSelected ? null : book.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? colors.accentFaint : colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? colors.accent : colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bookColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: bookColor.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.writingStyle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 22, color: colors.accent),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(AppPalette colors) {
    final isLastStep = _currentStep == 2;
    final buttonLabel = isLastStep ? 'Done' : 'Next';

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              // Skip button
              GestureDetector(
                onTap: _skip,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Next / Done button
              GestureDetector(
                onTap: _next,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withAlpha(50),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    buttonLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _parseHexColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF6366F1);
  }
}
