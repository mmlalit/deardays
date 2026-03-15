import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/routes.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/widgets/skeleton.dart';
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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(chapterEntriesProvider(widget.chapter.id));
    final colors = AppColors.of(context);
    final visual = ChapterVisual.forTitle(widget.chapter.title);

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: _buildFAB(context, colors),
      body: SafeArea(
        child: entriesAsync.when(
          data: (entries) => _buildContent(context, entries, visual, colors),
          loading: () => _buildLoading(context, visual, colors),
          error: (_, __) => _buildError(context, colors),
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context, AppPalette colors) {
    return FloatingActionButton(
      onPressed: () => context.push(AppRoutes.write),
      backgroundColor: colors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 28),
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
                    'Most Meaningful Moment',
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

  // ── Timeline (existing dot-line style) ────────────────────────────────────

  Widget _buildTimeline(
    BuildContext context,
    List<JournalEntry> entries,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          Positioned(
            left: 19,
            top: 20,
            bottom: 20,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Column(
            children: List.generate(entries.length, (i) {
              return _buildTimelineItem(
                context, entries[i], visual, colors,
                isLast: i == entries.length - 1,
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Monthly grouped view ──────────────────────────────────────────────────

  Widget _buildMonthlyTimeline(
    BuildContext context,
    List<JournalEntry> entries,
    ChapterVisual visual,
    AppPalette colors,
  ) {
    final grouped = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final key = '${e.entryDate.year}-${e.entryDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in keys) ...[
            _buildMonthHeader(key, grouped[key]!.length, visual, colors),
            ...grouped[key]!.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTimelineItem(
                context, entry, visual, colors,
                isLast: false,
                showLine: false,
              ),
            )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String key, int count, ChapterVisual visual, AppPalette colors) {
    final parts = key.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(date),
            style: GoogleFonts.newsreader(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: visual.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: visual.primary,
              ),
            ),
          ),
        ],
      ),
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

  // ── Timeline item ─────────────────────────────────────────────────────────

  Widget _buildTimelineItem(
    BuildContext context,
    JournalEntry entry,
    ChapterVisual visual,
    AppPalette colors, {
    required bool isLast,
    bool showLine = true,
  }) {
    final title = _deriveTitle(entry);
    final excerpt = _deriveExcerpt(entry, maxChars: 100);
    final dateLabel = DateFormat('MMM d, y').format(entry.entryDate);
    final emotion = entry.emotion;
    final badgeColors = _emotionBadgeColors(emotion, visual);
    final emotionIcon = _emotionIcon(emotion, visual);
    final emotionLabel = _emotionLabel(emotion, entry.mood);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle (sits on the vertical line)
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: visual.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: visual.primary.withAlpha(25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(emotionIcon, size: 18, color: visual.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.memory, extra: entry),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.textPrimary.withAlpha(8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.newsreader(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (emotionLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColors.$1,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              emotionLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: badgeColors.$2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateLabel.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      excerpt,
                      style: GoogleFonts.newsreader(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
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
              'Tap + to add a memory to this chapter.',
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Rename Chapter', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text('Share Chapter', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Delete Chapter',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.error)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  String _deriveTitle(JournalEntry entry) {
    final text = (entry.polishedContent?.isNotEmpty == true
            ? entry.polishedContent!
            : entry.content)
        .trim();
    final match = RegExp(r'[.!?]').firstMatch(text);
    if (match != null && match.start > 8 && match.start <= 72) {
      return text.substring(0, match.start);
    }
    if (text.length <= 65) return text;
    final cut = text.substring(0, 62);
    final lastSpace = cut.lastIndexOf(' ');
    return lastSpace > 20 ? '${cut.substring(0, lastSpace)}…' : '$cut…';
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

  (Color, Color) _emotionBadgeColors(String? emotion, ChapterVisual visual) {
    switch (emotion?.toLowerCase()) {
      case 'joy':
      case 'excitement':
        return (const Color(0xFFFEF9C3), const Color(0xFF854D0E));
      case 'gratitude':
      case 'contentment':
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
      case 'love':
        return (const Color(0xFFFFE4E6), const Color(0xFF9F1239));
      case 'pride':
        return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
      case 'nostalgia':
        return (const Color(0xFFEDE9FE), const Color(0xFF5B21B6));
      case 'anxiety':
      case 'frustration':
      case 'anger':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case 'sadness':
      case 'loneliness':
        return (const Color(0xFFE0E7FF), const Color(0xFF3730A3));
      default:
        return (visual.primary.withAlpha(20), visual.primary);
    }
  }

  String? _emotionLabel(String? emotion, String? mood) {
    if (emotion != null && emotion != 'neutral') {
      return emotion[0].toUpperCase() + emotion.substring(1);
    }
    if (mood != null) {
      switch (mood.toLowerCase()) {
        case 'great': return 'Joyful';
        case 'good': return 'Happy';
        case 'okay': return 'Okay';
        case 'low': return 'Low';
        case 'tough': return 'Tough';
      }
    }
    return null;
  }

  IconData _emotionIcon(String? emotion, ChapterVisual visual) {
    switch (emotion?.toLowerCase()) {
      case 'joy': return Icons.star_rounded;
      case 'excitement': return Icons.celebration_rounded;
      case 'gratitude': return Icons.favorite_rounded;
      case 'contentment': return Icons.spa_rounded;
      case 'love': return Icons.favorite_rounded;
      case 'pride': return Icons.emoji_events_rounded;
      case 'nostalgia': return Icons.history_rounded;
      case 'anxiety': return Icons.psychology_rounded;
      case 'frustration': return Icons.sentiment_dissatisfied_rounded;
      case 'anger': return Icons.warning_amber_rounded;
      case 'sadness': return Icons.cloud_rounded;
      case 'loneliness': return Icons.person_outline_rounded;
      default: return visual.icon;
    }
  }
}
