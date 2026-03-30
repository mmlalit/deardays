import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/routes.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/core/utils/photo_crop_helper.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/core/widgets/timeline_list.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

class ChapterDetailScreen extends ConsumerStatefulWidget {
  final Chapter chapter;

  const ChapterDetailScreen({super.key, required this.chapter});

  @override
  ConsumerState<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends ConsumerState<ChapterDetailScreen> {
  bool _isMonthly = false;
  bool _searchActive = false;
  String _searchQuery = '';
  String? _moodFilter;
  bool _fabExpanded = false;
  late Chapter _chapter;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chapter = widget.chapter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(chapterEntriesProvider(_chapter.id));
    final colors = AppColors.of(context);
    final visual = ChapterVisual.forTitle(_chapter.title, colorValue: _chapter.colorValue);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: entriesAsync.when(
              data: (entries) => _buildContent(context, entries, visual, colors),
              loading: () => _buildLoading(context, visual, colors),
              error: (_, __) => _buildError(context, colors),
            ),
          ),
          // Dim overlay when FAB expanded
          if (_fabExpanded)
            GestureDetector(
              onTap: () => setState(() => _fabExpanded = false),
              child: Container(color: Colors.black.withAlpha(60)),
            ),
          // FAB stack
          Positioned(
            bottom: 24,
            right: 20,
            child: _buildFAB(context, colors),
          ),
        ],
      ),
    );
  }

  // ── FAB — expandable: 4 capture modes ─────────────────────────────────────

  Widget _buildFAB(BuildContext context, AppPalette colors) {
    final visual = ChapterVisual.forTitle(_chapter.title, colorValue: _chapter.colorValue);
    final accent = visual.primary;

    void go(String route) {
      setState(() => _fabExpanded = false);
      context.push(route);
    }

    Future<void> openPhoto() async {
      setState(() => _fabExpanded = false);
      final picker = ImagePicker();
      XFile? photo;
      if (Platform.isAndroid || Platform.isIOS) {
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          backgroundColor: colors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.camera_alt_rounded, color: accent),
                    title: Text('Take a photo', style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  ListTile(
                    leading: Icon(Icons.photo_library_rounded, color: accent),
                    title: Text('Choose from gallery', style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
        if (source == null) return;
        photo = await picker.pickImage(source: source, imageQuality: 85);
      } else {
        photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      }
      if (photo != null && mounted) {
        final cropped = await cropPhoto(photo.path);
        final finalPath = cropped ?? photo.path;
        // ignore: use_build_context_synchronously
        if (mounted) context.push('/photo-entry', extra: finalPath);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _FabOption(icon: Icons.mic_rounded,          label: 'Record',   color: accent, onTap: () => go(AppRoutes.record)),
          const SizedBox(height: 10),
          _FabOption(icon: Icons.photo_camera_rounded, label: 'Picture',  color: accent, onTap: openPhoto),
          const SizedBox(height: 10),
          _FabOption(icon: Icons.edit_rounded,         label: 'Write',    color: accent, onTap: () => go(AppRoutes.write)),
          const SizedBox(height: 10),
          _FabOption(icon: Icons.auto_awesome_rounded, label: 'AI Chat',  color: accent, onTap: () => go(AppRoutes.checkin)),
          const SizedBox(height: 14),
        ],
        FloatingActionButton(
          heroTag: 'chapter-detail-fab',
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          backgroundColor: _fabExpanded ? colors.textSecondary : accent,
          foregroundColor: Colors.white,
          elevation: 4,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _fabExpanded
                ? const Icon(Icons.close_rounded, key: ValueKey('close'), size: 26)
                : const Icon(Icons.add_rounded,   key: ValueKey('add'),   size: 28),
          ),
        ),
      ],
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    List<JournalEntry> entries,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    // Apply filters
    var filtered = entries;
    if (_moodFilter != null) {
      filtered = filtered.where((e) => e.mood == _moodFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((e) =>
        e.content.toLowerCase().contains(q) ||
        (e.polishedContent?.toLowerCase().contains(q) ?? false) ||
        e.tags.any((t) => t.toLowerCase().contains(q)) ||
        (e.locationName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    final highlight = _pickHighlight(entries);

    return Column(
      children: [
        _buildStickyHeader(context, visual, colors),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlight != null)
                  _buildHighlightCard(context, highlight, visual, colors),
                if (entries.isNotEmpty) ...[
                  _buildStatsStrip(entries, colors),
                  _buildTimelineControls(filtered.length, visual, colors),
                  if (filtered.isEmpty)
                    _buildSearchEmptyState(colors)
                  else if (_isMonthly)
                    _buildMonthlyTimeline(context, filtered, visual, colors)
                  else
                    _buildTimeline(context, filtered, visual, colors),
                ] else
                  _buildEmptyState(context, colors),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Sticky header ─────────────────────────────────────────────────────────

  Widget _buildStickyHeader(
    BuildContext context,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: visual.primary.withAlpha(18),
        border: Border(bottom: BorderSide(color: visual.primary.withAlpha(30))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: visual.primary),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: visual.primary.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(visual.icon, size: 15, color: visual.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.chapter.title,
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: visual.primary,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => _showOptions(context, colors),
            icon: Icon(Icons.more_horiz_rounded, size: 22, color: visual.primary),
          ),
        ],
      ),
    );
  }

  // ── Highlight card ────────────────────────────────────────────────────────

  Widget _buildHighlightCard(
    BuildContext context,
    JournalEntry entry,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    final excerpt = _deriveExcerpt(entry, maxChars: 160);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: _buildChapterCover(visual),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: visual.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 11, color: visual.primary),
                        const SizedBox(width: 4),
                        Text(
                          'HIGHLIGHT',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: visual.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _highlightLabel(entry),
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    excerpt,
                    style: GoogleFonts.newsreader(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: colors.textSecondary,
                      height: 1.55,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRoutes.memory, extra: entry),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: visual.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Open Memory',
                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
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

  Widget _buildChapterCover(ChapterVisual visual) {
    final url = visual.stockImageUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        placeholder: (_, __) => _buildGradientCover(visual),
        errorWidget: (_, __, ___) => _buildGradientCover(visual),
      );
    }
    return _buildGradientCover(visual);
  }

  Widget _buildGradientCover(ChapterVisual visual) {
    return Container(
      decoration: BoxDecoration(gradient: visual.gradient),
      child: Center(
        child: Icon(visual.icon, color: Colors.white.withAlpha(120), size: 44),
      ),
    );
  }

  // ── Stats strip ───────────────────────────────────────────────────────────

  Widget _buildStatsStrip(List<JournalEntry> entries, AppPalette colors) {
    final count = entries.length;
    final range = _dateRange(entries);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Icon(Icons.auto_stories_rounded, size: 14, color: colors.textMuted),
          const SizedBox(width: 6),
          Text(
            '$count ${count == 1 ? 'memory' : 'memories'}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          if (range.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('·', style: GoogleFonts.manrope(fontSize: 12, color: colors.textMuted)),
            ),
            Icon(Icons.calendar_today_outlined, size: 12, color: colors.textMuted),
            const SizedBox(width: 5),
            Text(
              range,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Timeline controls (header + view toggle + search) ─────────────────────

  Widget _buildTimelineControls(int filteredCount, ChapterVisual visual, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Timeline of Memories',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              // Search toggle
              GestureDetector(
                onTap: () => setState(() {
                  _searchActive = !_searchActive;
                  if (!_searchActive) {
                    _searchController.clear();
                    _searchQuery = '';
                    _moodFilter = null;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _searchActive ? visual.primary : colors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _searchActive ? visual.primary : colors.border,
                    ),
                  ),
                  child: Icon(
                    _searchActive ? Icons.close_rounded : Icons.search_rounded,
                    size: 17,
                    color: _searchActive ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // View mode toggle
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewToggleTab(Icons.timeline_rounded, 'Timeline', isMonthly: false, accentColor: visual.primary, colors: colors),
                _viewToggleTab(Icons.calendar_view_month_rounded, 'Monthly', isMonthly: true, accentColor: visual.primary, colors: colors),
              ],
            ),
          ),
          if (_searchActive) ...[
            const SizedBox(height: 10),
            _buildSearchBar(visual.primary, colors),
            const SizedBox(height: 8),
            _buildMoodFilterChips(visual.primary, colors),
          ],
        ],
      ),
    );
  }

  Widget _viewToggleTab(IconData icon, String label, {required bool isMonthly, required Color accentColor, required AppPalette colors}) {
    final isActive = _isMonthly == isMonthly;
    return GestureDetector(
      onTap: () => setState(() => _isMonthly = isMonthly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? Colors.white : colors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color accentColor, AppPalette colors) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 17, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.manrope(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search in chapter…',
                hintStyle: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.cancel_rounded, size: 16, color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoodFilterChips(Color accentColor, AppPalette colors) {
    const moods = [
      (null, 'All'),
      ('great', '😄 Great'),
      ('good', '😊 Good'),
      ('okay', '😐 Okay'),
      ('low', '😔 Low'),
      ('tough', '😞 Tough'),
    ];
    const moodColors = {
      'great': Color(0xFF10B981),
      'good': Color(0xFF3B82F6),
      'okay': Color(0xFFF59E0B),
      'low': Color(0xFFF97316),
      'tough': Color(0xFFEF4444),
    };
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (mood, label) = moods[i];
          final isActive = _moodFilter == mood;
          final activeColor = mood != null ? moodColors[mood]! : accentColor;
          return GestureDetector(
            onTap: () => setState(() => _moodFilter = mood),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? activeColor : colors.cardBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: isActive ? activeColor : colors.border),
              ),
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : colors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Timeline (dot + line + year headers) ─────────────────────────────────

  Widget _buildTimeline(
    BuildContext context,
    List<JournalEntry> entries,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    return TimelineList(
      entries: entries,
      colors: colors,
      accentColor: visual.primary,
      horizontalPadding: 16,
      onEntryTap: (entry, all, index) => context.push(
        AppRoutes.memory,
        extra: MemoryDetailArgs(entry: entry, allEntries: all, initialIndex: index),
      ),
      onShare: (entry) => context.push('/share-card', extra: entry),
    );
  }

  // ── Monthly grouped view ──────────────────────────────────────────────────

  Widget _buildMonthlyTimeline(
    BuildContext context,
    List<JournalEntry> entries,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    return TimelineMonthlyList(
      entries: entries,
      colors: colors,
      accentColor: visual.primary,
      horizontalPadding: 16,
      onEntryTap: (entry, all, index) => context.push(
        AppRoutes.memory,
        extra: MemoryDetailArgs(entry: entry, allEntries: all, initialIndex: index),
      ),
      onShare: (entry) => context.push('/share-card', extra: entry),
    );
  }

  // ── Search empty state ────────────────────────────────────────────────────

  Widget _buildSearchEmptyState(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No memories match your search',
            style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.auto_stories_rounded, size: 56, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No memories yet',
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to capture a memory — record, write, photo or AI chat.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
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

  Widget _buildLoading(BuildContext context, ChapterVisual visual, AppPalette colors) {
    return Column(
      children: [
        _buildStickyHeader(context, visual, colors),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Container(color: colors.border.withAlpha(80)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonBox(width: 80, height: 22),
                              const SizedBox(height: 10),
                              const SkeletonBox(width: 220, height: 18),
                              const SizedBox(height: 8),
                              const SkeletonBox(width: 300, height: 13),
                              const SizedBox(height: 4),
                              const SkeletonBox(width: 250, height: 13),
                              const SizedBox(height: 14),
                              Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.border.withAlpha(80),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SkeletonBox(width: 180, height: 18),
                  const SizedBox(height: 20),
                  ...List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.border.withAlpha(80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              height: 90,
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.border),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonBox(width: 160, height: 14),
                                  SizedBox(height: 8),
                                  SkeletonBox(width: 90, height: 10),
                                  SizedBox(height: 8),
                                  SkeletonBox(width: 240, height: 11),
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
          ),
        ),
      ],
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Could not load chapter',
            style: GoogleFonts.newsreader(fontSize: 18, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ── More options sheet ────────────────────────────────────────────────────

  void _showOptions(BuildContext context, AppPalette colors) {
    final visual = ChapterVisual.forTitle(_chapter.title, colorValue: _chapter.colorValue);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle + close
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                      onPressed: () => Navigator.pop(sheetCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: colors.textPrimary),
                title: Text('Rename Chapter', style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, colors);
                },
              ),
              ListTile(
                leading: Icon(Icons.palette_outlined, color: colors.textPrimary),
                title: Text('Change Color', style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showColorSheet(context, colors, visual);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Delete Chapter',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, colors);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, AppPalette colors) async {
    final ctrl = TextEditingController(text: _chapter.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Chapter',
            style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.manrope(fontSize: 15, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Chapter title',
            hintStyle: GoogleFonts.manrope(color: colors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: colors.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newTitle = ctrl.text.trim();
    if (newTitle.isEmpty || newTitle == _chapter.title) return;
    try {
      final updated = await ref.read(profileRepositoryProvider).updateChapter(_chapter.id, title: newTitle);
      if (mounted) setState(() => _chapter = updated);
      ref.invalidate(appInitProvider);
    } catch (e) {
      debugPrint('rename chapter error: $e');
    }
  }

  static const _kPresetColors = [
    Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFF97316),
    Color(0xFF22C55E), Color(0xFF8B5CF6), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF64748B), Color(0xFF06B6D4),
  ];

  Future<void> _showColorSheet(BuildContext context, AppPalette colors, ChapterVisual currentVisual) async {
    Color? selected = _chapter.colorValue != null ? Color(_chapter.colorValue!) : null;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: BoxDecoration(color: colors.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Chapter Color', style: GoogleFonts.newsreader(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary))),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _kPresetColors.map((c) {
                  final isActive = selected == c;
                  return GestureDetector(
                    onTap: () => setSS(() => selected = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: isActive ? Border.all(color: colors.accent, width: 3) : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: isActive ? [BoxShadow(color: c.withAlpha(100), blurRadius: 8, offset: const Offset(0, 2))] : null,
                      ),
                      child: isActive ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: selected == null ? null : () async {
                    Navigator.pop(ctx);
                    try {
                      final updated = await ref.read(profileRepositoryProvider).updateChapter(
                        _chapter.id, colorValue: selected!.toARGB32(),
                      );
                      if (mounted) setState(() => _chapter = updated);
                      ref.invalidate(appInitProvider);
                    } catch (e) { debugPrint('color update error: $e'); }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Apply Color', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppPalette colors) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Chapter?',
            style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        content: Text(
          'This will delete "${_chapter.title}". Memories inside will not be deleted.',
          style: GoogleFonts.manrope(fontSize: 14, color: colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(profileRepositoryProvider).deleteChapter(_chapter.id);
      ref.invalidate(appInitProvider);
      if (mounted) this.context.pop();
    } catch (e) {
      debugPrint('delete chapter error: $e');
    }
  }


  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Derives a meaningful label for the highlight card based on the entry's emotion/mood.
  String _highlightLabel(JournalEntry entry) {
    switch (entry.emotion?.toLowerCase()) {
      case 'joy': return 'Most Joyful Moment';
      case 'excitement': return 'Most Exciting Moment';
      case 'gratitude': return 'Most Grateful Moment';
      case 'love': return 'Most Loving Moment';
      case 'pride': return 'Proudest Moment';
      case 'nostalgia': return 'Most Nostalgic Moment';
      case 'contentment': return 'Most Peaceful Moment';
      case 'sadness': return 'Most Reflective Moment';
      case 'anxiety':
      case 'frustration':
      case 'anger': return 'Most Challenging Moment';
      default: break;
    }
    switch (entry.mood?.toLowerCase()) {
      case 'great': return 'Best Day';
      case 'good': return 'Good Day Highlight';
      case 'tough':
      case 'low': return 'Most Reflective Moment';
      default: break;
    }
    return 'Most Meaningful Moment';
  }

  JournalEntry? _pickHighlight(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    final withScores = entries.where((e) => e.sentimentScore != null).toList();
    if (withScores.isNotEmpty) {
      withScores.sort((a, b) => b.sentimentScore!.compareTo(a.sentimentScore!));
      return withScores.first;
    }
    final sorted = [...entries]..sort((a, b) => b.wordCount.compareTo(a.wordCount));
    return sorted.first;
  }

  String _deriveExcerpt(JournalEntry entry, {required int maxChars}) {
    final text = (entry.polishedContent?.isNotEmpty == true
            ? entry.polishedContent!
            : entry.content)
        .trim();
    if (text.length <= maxChars) return text;
    final cut = text.substring(0, maxChars - 1);
    final lastSpace = cut.lastIndexOf(' ');
    return lastSpace > 20 ? '${cut.substring(0, lastSpace)}…' : '$cut…';
  }

  String _dateRange(List<JournalEntry> entries) {
    if (entries.isEmpty) return '';
    final dates = entries.map((e) => e.entryDate).toList()..sort();
    final first = DateFormat('MMM yyyy').format(dates.first);
    final last = DateFormat('MMM yyyy').format(dates.last);
    return first == last ? first : '$first – $last';
  }

}

// ── FAB option pill (label + icon, floats above main FAB) ────────────────────

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FabOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: color.withAlpha(80), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
