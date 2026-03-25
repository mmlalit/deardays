import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/book/data/models/book_page.dart';


class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: FloatingActionButton(
        heroTag: 'library-add-fab',
        onPressed: () => _showCreateChapterSheet(context),
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'New chapter',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: chaptersAsync.when(
          skipLoadingOnRefresh: true,
          data: (chapters) => _buildContent(context, chapters),
          loading: () => _buildLoadingContent(context),
          error: (e, __) {
            debugPrint('chaptersProvider error: $e');
            return _buildChaptersErrorState(context);
          },
        ),
      ),
    );
  }

  // ── Create chapter sheet ──────────────────────────────────────────────────

  static const _kPresetColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
    Color(0xFF22C55E), // green
    Color(0xFF8B5CF6), // purple
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // rose
    Color(0xFF64748B), // slate
    Color(0xFF06B6D4), // cyan
  ];

  Future<void> _showCreateChapterSheet(BuildContext context) async {
    final titleController = TextEditingController();
    Color? selectedColor;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'New Chapter',
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Title field
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: GoogleFonts.manrope(fontSize: 15, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Chapter title...',
                    hintStyle: GoogleFonts.manrope(fontSize: 15, color: colors.textMuted),
                    filled: true,
                    fillColor: colors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Color label
                Text(
                  'Color',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                // Color swatches
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _kPresetColors.map((c) {
                    final isSelected = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: colors.accent, width: 3)
                              : Border.all(color: Colors.transparent, width: 3),
                          boxShadow: isSelected
                              ? [BoxShadow(color: c.withAlpha(100), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      Navigator.of(ctx).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final repo = ref.read(profileRepositoryProvider);
                        final chapter = await repo.createChapter(title);
                        if (selectedColor != null) {
                          await repo.updateChapter(
                            chapter.id,
                            colorValue: selectedColor!.toARGB32(),
                          );
                        }
                        ref.invalidate(chaptersProvider);
                      } catch (e) {
                        debugPrint('createChapter error: $e');
                        if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Failed to create chapter. Please try again.')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Create Chapter',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildContent(BuildContext context, List<Chapter> chapters) {
    final colors = AppColors.of(context);
    return CustomScrollView(
      slivers: [
        // Page title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'My Books',
              style: GoogleFonts.newsreader(fontSize: 26, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ),
        ),

        // Hero card
        SliverToBoxAdapter(child: _buildHeroCard(context)),
        SliverToBoxAdapter(child: _buildSectionTitle(context, chapters.length)),

        if (chapters.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(context))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildChapterCard(context, chapters[index]),
                childCount: chapters.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── My Life Book hero card ────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context) {
    final colors = AppColors.of(context);
    final memoryCount = ref.watch(timelineEntriesProvider).valueOrNull?.length ?? 0;
    final chapterCount = ref.watch(chaptersProvider).valueOrNull?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.accentFaint, colors.highlightFaint],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.accent.withAlpha(45)),
          boxShadow: [
            BoxShadow(color: colors.accent.withAlpha(18), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Premium label ──
            Text(
              'PREMIUM COLLECTION',
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: const Color(0xFF4A4540)),
            ),
            const SizedBox(height: 6),

            // ── Title ──
            Text(
              'My Life Book',
              style: GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 1.1),
            ),
            const SizedBox(height: 6),

            // ── Subtitle ──
            Text(
              'Read your entire life story, chapter by chapter, in one place.',
              style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF4A4540), height: 1.5),
            ),
            const SizedBox(height: 18),

            // ── Stats row (above books so user sees content size first) ──
            Row(
              children: [
                _buildStatCell('$memoryCount', 'MEMORIES', colors),
                Container(
                  width: 1, height: 36,
                  color: colors.accent.withAlpha(40),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                ),
                _buildStatCell('$chapterCount', 'CHAPTERS', colors),
              ],
            ),
            const SizedBox(height: 18),

            // ── Divider ──
            Container(height: 1, color: colors.accent.withAlpha(30)),
            const SizedBox(height: 18),

            // ── Two mini book cards ──
            Row(
              children: [
                Expanded(
                  child: _buildMiniBookCard(
                    context,
                    title: 'By Timeline',
                    countLabel: '$memoryCount MEMORIES',
                    description: 'A continuous life story from your first memory to your latest.',
                    icon: Icons.show_chart_rounded,
                    color: colors.accent,
                    bgColor: colors.accentFaint,
                    mode: BookMode.byTime,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniBookCard(
                    context,
                    title: 'By Chapter',
                    countLabel: '$chapterCount CHAPTERS',
                    description: 'Your story organized by themes like Family, Career, and Travel.',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFFEC4899),
                    bgColor: const Color(0xFFFFF0F5),
                    mode: BookMode.byChapter,
                    colors: colors,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Mini book card (tinted content card) ─────────────────────────────────

  Widget _buildMiniBookCard(
    BuildContext context, {
    required String title,
    required String countLabel,
    required String description,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required BookMode mode,
    required AppPalette colors,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: GestureDetector(
      onTap: () => context.push('/book-reader', extra: mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: GoogleFonts.newsreader(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),

            // Count label (e.g. "45 MEMORIES")
            Text(
              countLabel,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),

            // Full-width Read button
            SizedBox(
              width: double.infinity,
              child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () => context.push('/book-reader', extra: mode),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Read',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
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

  // ── Stat cell ─────────────────────────────────────────────────────────────

  Widget _buildStatCell(String value, String label, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.newsreader(fontSize: 32, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 1.0),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: const Color(0xFF595550)),
        ),
      ],
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(BuildContext context, int chapterCount) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Life Chapters',
              style: GoogleFonts.newsreader(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (chapterCount > 0)
            Text(
              '$chapterCount ${chapterCount == 1 ? 'chapter' : 'chapters'}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  // ── Chapter card — full-bleed photo with gradient scrim ──────────────────

  Widget _buildChapterCard(BuildContext context, Chapter chapter) {
    final visual = ChapterVisual.forTitle(chapter.title, colorValue: chapter.colorValue);
    final countLabel = chapter.entryCount == 0
        ? 'No memories'
        : '${chapter.entryCount} ${chapter.entryCount == 1 ? 'memory' : 'memories'}';

    return GestureDetector(
      onTap: () => context.push('/chapter/${chapter.id}', extra: chapter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: stock photo or gradient fallback
            if (visual.stockImageUrl != null)
              CachedNetworkImage(
                imageUrl: visual.stockImageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                memCacheHeight: 400,
                placeholder: (_, __) => _cardGradient(visual),
                errorWidget: (_, __, ___) => _cardGradient(visual),
              )
            else
              _cardGradient(visual),

            // Bottom gradient scrim
            Positioned(
              left: 0, right: 0, bottom: 0, height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(180),
                    ],
                  ),
                ),
              ),
            ),

            // Top-left icon badge
            Positioned(
              top: 10, left: 10,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Icon(visual.icon, color: Colors.white, size: 17),
              ),
            ),

            // Bottom: title + memory count pill
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chapter.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Text(
                      countLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(200),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardGradient(ChapterVisual visual) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [visual.primary, visual.secondary],
          ),
        ),
      );

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.menu_book_rounded, size: 30, color: colors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'No chapters yet',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                'Chapters are born from your memories. Save a few entries and your first chapter will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: const Color(0xFF4A4540),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Capture a memory',
              child: GestureDetector(
                onTap: () => context.go('/home'),
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Capture a memory',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  // ── Loading skeleton ──────────────────────────────────────────────────────

  Widget _buildChaptersErrorState(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load chapters',
              style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => ref.invalidate(chaptersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    final colors = AppColors.of(context);
    return CustomScrollView(
      slivers: [
        // Hero skeleton
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(color: colors.border.withAlpha(80)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonBox(width: 120, height: 10),
                        const SizedBox(height: 10),
                        const SkeletonBox(width: 200, height: 20),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 160, height: 12),
                        const SizedBox(height: 16),
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: colors.border.withAlpha(80),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: colors.border.withAlpha(60),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: colors.border.withAlpha(60),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildSectionTitle(context, 0)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => _buildSkeletonChapterCard(context),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonChapterCard(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: colors.border.withAlpha(80)),
          Positioned(
            top: 10, left: 10,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: colors.border.withAlpha(120),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            left: 12, right: 12, bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBox(height: 14),
                const SizedBox(height: 6),
                const SkeletonBox(width: 70, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
