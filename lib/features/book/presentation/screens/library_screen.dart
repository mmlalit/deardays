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

// Hero cover image — warm, cinematic life-journey feel
const _heroCoverUrl =
    'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&h=450&fit=crop';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: chaptersAsync.when(
          data: (chapters) => _buildContent(context, chapters),
          loading: () => _buildLoadingContent(context),
          error: (_, __) => _buildContent(context, []),
        ),
      ),
    );
  }

  List<Chapter> _filterChapters(List<Chapter> chapters) {
    if (_searchQuery.isEmpty) return chapters;
    final q = _searchQuery.toLowerCase();
    return chapters.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  Widget _buildContent(BuildContext context, List<Chapter> chapters) {
    final filtered = _filterChapters(chapters);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        if (!_searchActive) ...[
          SliverToBoxAdapter(child: _buildHeroCard(context)),
          SliverToBoxAdapter(child: _buildSectionTitle(context, chapters.length)),
        ],
        if (filtered.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(context))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildChapterCard(context, filtered[index]),
                childCount: filtered.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);

    if (_searchActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        child: Row(
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
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.manrope(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search chapters...',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                    prefixIcon: Icon(Icons.search, size: 18, color: colors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _searchActive = false;
                _searchQuery = '';
                _searchController.clear();
              }),
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Row(
        children: [
          Text(
            'Chapters',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _searchActive = true),
            tooltip: 'Search chapters',
            icon: Icon(Icons.search, color: colors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Hero card (replaces 3 dark book-mode cards) ───────────────────────────

  Widget _buildHeroCard(BuildContext context) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);
    final memoryCount = entriesAsync.valueOrNull?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 cover photo
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: _heroCoverUrl,
                fit: BoxFit.cover,
                memCacheWidth: 800,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF1E3A5F),
                  child: const Center(
                    child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 40),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 40),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  Text(
                    'FEATURED COLLECTION',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    'Continue Your Journey',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Memory count
                  Text(
                    '$memoryCount ${memoryCount == 1 ? 'memory' : 'memories'} across your lifetime',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Primary button — full width
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/book-reader', extra: BookMode.stream),
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: Text(
                        'Read Autobiography',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary buttons — side by side
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          icon: Icons.timeline,
                          label: 'By Timeline',
                          onTap: () => context.push(
                              '/book-reader', extra: BookMode.byTime),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SecondaryButton(
                          icon: Icons.auto_awesome,
                          label: 'By Chapter',
                          onTap: () => context.push(
                              '/book-reader', extra: BookMode.byChapter),
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

  // ── Chapter card (icon badge + title + count) ─────────────────────────────

  Widget _buildChapterCard(BuildContext context, Chapter chapter) {
    final colors = AppColors.of(context);
    final visual = ChapterVisual.forTitle(chapter.title);

    return GestureDetector(
      onTap: () => context.push('/chapter/${chapter.id}', extra: chapter),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visual.primary.withAlpha(28),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                visual.icon,
                color: visual.primary,
                size: 22,
              ),
            ),
            const Spacer(),
            // Chapter title
            Text(
              chapter.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.newsreader(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            // Memory count
            Text(
              chapter.entryCount == 0
                  ? 'No memories yet'
                  : '${chapter.entryCount} ${chapter.entryCount == 1 ? 'memory' : 'memories'}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No chapters yet',
              style: GoogleFonts.newsreader(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start recording memories to create your first chapter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading skeleton ──────────────────────────────────────────────────────

  Widget _buildLoadingContent(BuildContext context) {
    final colors = AppColors.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
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
              childAspectRatio: 1.05,
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
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.border.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Spacer(),
          const SkeletonBox(width: 80, height: 14),
          const SizedBox(height: 6),
          const SkeletonBox(width: 55, height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary outline button used in hero card
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: colors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
