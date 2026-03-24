import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/features/book/data/services/book_generator_service.dart';
import 'package:deardays/services/auth/auth_service.dart';

class BookCreationScreen extends ConsumerStatefulWidget {
  const BookCreationScreen({super.key});

  @override
  ConsumerState<BookCreationScreen> createState() => _BookCreationScreenState();
}

class _BookCreationScreenState extends ConsumerState<BookCreationScreen> {
  BookCreationApproach? _selectedApproach;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const DearDaysHeader(
              title: 'Create a Book',
              mode: HeaderMode.push,
            ),
            Expanded(
              child: _selectedApproach == null
                  ? _buildApproachSelection(context)
                  : _buildApproachFlow(context),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Approach Selection ───────────────────────────────────────────────

  Widget _buildApproachSelection(BuildContext context) {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'How should your book be organised?',
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a structure — you can always create more books later.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          _buildApproachCard(
            context,
            approach: BookCreationApproach.chronological,
            icon: Icons.auto_stories_rounded,
            title: 'Chronological',
            tagline: 'One continuous life story',
            description:
                'Memories are woven together week by week, month by month. '
                'AI carries the narrative thread from page to page — your life '
                'told as one flowing story.',
            bullets: const [
              'Chapters auto-created by month',
              'AI maintains continuity between pages',
              'Best for an ongoing life journal',
            ],
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 16),
          _buildApproachCard(
            context,
            approach: BookCreationApproach.thematic,
            icon: Icons.layers_rounded,
            title: 'Thematic',
            tagline: 'Separate stories by theme',
            description:
                'Each chapter tells its own story — Family, Career, Travel, '
                'or any theme you create. Memories are added to the chapter '
                'they belong to.',
            bullets: const [
              'You create and name chapters',
              'Each chapter has its own narrative arc',
              'Best for topic-focused books',
            ],
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApproachCard(
    BuildContext context, {
    required BookCreationApproach approach,
    required IconData icon,
    required String title,
    required String tagline,
    required String description,
    required List<String> bullets,
    required Color color,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedApproach = approach),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.newsreader(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        tagline,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: colors.textMuted),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // Bullet points
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          b,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ─── Approach Flow Router ─────────────────────────────────────────────

  Widget _buildApproachFlow(BuildContext context) {
    switch (_selectedApproach!) {
      case BookCreationApproach.chronological:
        return _ChronologicalFlow(
          onBack: () => setState(() => _selectedApproach = null),
          onCreateBook: _onBookCreated,
        );
      case BookCreationApproach.thematic:
        return _ThematicFlow(
          onBack: () => setState(() => _selectedApproach = null),
          onCreateBook: _onBookCreated,
        );
    }
  }

  void _onBookCreated(GeneratedBook book) {
    context.push('/book-detail', extra: book);
  }
}

// =============================================================================
// Chronological Flow
// User names the book; chapters are auto-created by month during page generation.
// =============================================================================

class _ChronologicalFlow extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(GeneratedBook) onCreateBook;

  const _ChronologicalFlow({
    required this.onBack,
    required this.onCreateBook,
  });

  @override
  ConsumerState<_ChronologicalFlow> createState() =>
      _ChronologicalFlowState();
}

class _ChronologicalFlowState extends ConsumerState<_ChronologicalFlow> {
  final _titleController = TextEditingController(text: 'My Story');
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);
    final entryCount = entriesAsync.valueOrNull?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              ),
              Text(
                'Chronological',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF6366F1).withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      'How it works',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Every Saturday, your week\'s memories are woven into pages '
                  'and added to your book automatically. Chapters are created '
                  'by month — no setup needed.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'BOOK TITLE',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'My Story',
              hintStyle: GoogleFonts.manrope(color: colors.textMuted),
              filled: true,
              fillColor: colors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF6366F1), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Stats row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(colors, '$entryCount', 'Memories'),
                Container(width: 1, height: 40, color: colors.border),
                _buildStat(colors, 'Monthly', 'Chapters'),
                Container(width: 1, height: 40, color: colors.border),
                _buildStat(colors, 'Weekly', 'New pages'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _createBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Create Book',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStat(AppPalette colors, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted),
        ),
      ],
    );
  }

  Future<void> _createBook() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'My Story'
          : _titleController.text.trim();
      final now = DateTime.now();
      final repo = ref.read(bookRepositoryProvider);

      // Save book to Supabase
      final savedBook = await repo.createBook(Book(
        id: '',
        userId: '',
        title: title,
        creationApproach: 'chronological',
        startDate: DateTime(now.year, 1, 1),
        createdAt: now,
        updatedAt: now,
      ));

      // Create a single auto-chapter that the weekly job will use
      await repo.createChronologicalChapter(savedBook.id, title);

      // C-07: Verify subscription before book generation
      final isSubscribed = await AuthService().hasActiveSubscription();
      if (!isSubscribed) throw const SubscriptionRequiredException('Book generation requires an active subscription');

      // Generate local view for immediate navigation
      final entries = ref.read(timelineEntriesProvider).valueOrNull ?? [];
      final generatedBook = BookGeneratorService().generateFromEntries(
        entries: entries,
        title: title,
        author: 'You',
      );

      if (mounted) widget.onCreateBook(generatedBook);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// =============================================================================
// Thematic Flow
// User selects which existing chapters to include in the book.
// =============================================================================

class _ThematicFlow extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(GeneratedBook) onCreateBook;

  const _ThematicFlow({
    required this.onBack,
    required this.onCreateBook,
  });

  @override
  ConsumerState<_ThematicFlow> createState() => _ThematicFlowState();
}

class _ThematicFlowState extends ConsumerState<_ThematicFlow> {
  final _titleController = TextEditingController(text: 'My Chapters');
  final _selectedChapterIds = <String>{};
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chaptersAsync = ref.watch(chaptersProvider);

    return chaptersAsync.when(
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load chapters',
          style: GoogleFonts.manrope(color: colors.textSecondary),
        ),
      ),
      data: (chapters) => _buildContent(context, colors, chapters),
    );
  }

  Widget _buildContent(
      BuildContext context, AppPalette colors, List<Chapter> chapters) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              ),
              Text(
                'Thematic',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Select which chapters to include in this book.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'BOOK TITLE',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'My Chapters',
                    hintStyle:
                        GoogleFonts.manrope(color: colors.textMuted),
                    filled: true,
                    fillColor: colors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'CHAPTERS  (${_selectedChapterIds.length} selected)',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                if (chapters.isEmpty)
                  _buildEmptyChapters(colors)
                else
                  ...chapters.map((c) => _buildChapterTile(c, colors)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        // Create button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_selectedChapterIds.isEmpty || _isSaving)
                    ? null
                    : _createBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.border,
                  disabledForegroundColor: colors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selectedChapterIds.isEmpty
                            ? 'Select at least one chapter'
                            : 'Create Book (${_selectedChapterIds.length} chapters)',
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
    );
  }

  Widget _buildChapterTile(Chapter chapter, AppPalette colors) {
    final isSelected = _selectedChapterIds.contains(chapter.id);
    final entryCount = chapter.entryCount;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedChapterIds.remove(chapter.id);
          } else {
            _selectedChapterIds.add(chapter.id);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withAlpha(15)
              : colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981).withAlpha(80)
                : colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF10B981).withAlpha(25)
                    : colors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Ch.${chapter.chapterNumber}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : colors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
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
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : colors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChapters(AppPalette colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.layers_outlined, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No chapters yet',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create chapters in the Chapters tab first, then come back here to build a thematic book.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBook() async {
    if (_isSaving || _selectedChapterIds.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'My Chapters'
          : _titleController.text.trim();
      final now = DateTime.now();
      final repo = ref.read(bookRepositoryProvider);

      // Save book to Supabase
      final savedBook = await repo.createBook(Book(
        id: '',
        userId: '',
        title: title,
        creationApproach: 'thematic',
        startDate: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Link selected chapters to this book
      await repo.linkChaptersToBook(savedBook.id, _selectedChapterIds.toList());

      // Generate local view for immediate navigation
      final allEntries = ref.read(timelineEntriesProvider).valueOrNull ?? [];
      final selectedEntries = allEntries
          .where((e) =>
              e.chapterId != null && _selectedChapterIds.contains(e.chapterId))
          .toList()
        ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

      // C-07: Verify subscription before book generation
      final isSubscribed = await AuthService().hasActiveSubscription();
      if (!isSubscribed) throw const SubscriptionRequiredException('Book generation requires an active subscription');

      final generatedBook = BookGeneratorService().generateFromEntries(
        entries: selectedEntries,
        title: title,
        author: 'You',
      );

      if (mounted) widget.onCreateBook(generatedBook);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
