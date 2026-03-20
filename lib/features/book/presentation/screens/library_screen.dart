import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/widgets/app_avatar.dart';
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
          error: (e, __) {
            debugPrint('chaptersProvider error: $e');
            return _buildContent(context, []);
          },
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
                childAspectRatio: 0.85,
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
          const SizedBox(width: 4),
          const AppAvatar(),
          const SizedBox(width: 8),
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
            // 4:3 cover photo — taller for full image visibility
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
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
                  // Bottom scrim
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withAlpha(60)],
                        ),
                      ),
                    ),
                  ),
                  // dd watermark — bottom right
                  Positioned(
                    bottom: 10,
                    right: 14,
                    child: Text(
                      'dd',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withAlpha(120),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
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
                    'YOUR STORY',
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
                  const SizedBox(height: 14),

                  // Two equal buttons — By Timeline + By Chapter
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryButton(
                          icon: Icons.timeline_rounded,
                          label: 'By Timeline',
                          onTap: () => context.push(
                              '/book-reader', extra: BookMode.byTime),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PrimaryButton(
                          icon: Icons.auto_stories_rounded,
                          label: 'By Chapter',
                          onTap: () => context.push(
                              '/book-reader', extra: BookMode.byChapter),
                          colors: colors,
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

  // ── Chapter card — full-bleed photo with gradient scrim ──────────────────

  Widget _buildChapterCard(BuildContext context, Chapter chapter) {
    final visual = ChapterVisual.forTitle(chapter.title);
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
// Primary equal button used in hero card
// ─────────────────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppPalette colors;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
