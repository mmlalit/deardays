import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/media/media_service.dart';

extension _StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _moodFilter;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildStickyHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildLifeStatsCard(),
                  const SizedBox(height: 32),
                  _buildTimeline(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Sticky header — frosted, search, filters
  // ──────────────────────────────────────────────

  Widget _buildStickyHeader() {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: colors.accent.withAlpha(26)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              Center(
                child: Text(
                  'Timeline',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
                  const SizedBox(height: 12),
                  // Row 2: Search bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).accent.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      style: GoogleFonts.manrope(fontSize: 14, color: AppColors.of(context).textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search keywords, dates, or moods',
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppColors.of(context).textPrimary.withAlpha(102),
                        ),
                        prefixIcon: Icon(Icons.search, color: AppColors.of(context).accent.withAlpha(153), size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Row 3: Active filter chips
                  Row(
                    children: [
                      _filterChip(
                        _moodFilter != null ? _moodFilter!.capitalize() : 'Mood',
                        Icons.mood,
                        isActive: _moodFilter != null,
                        onTap: _showMoodFilterSheet,
                      ),
                      if (_moodFilter != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _moodFilter = null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.of(context).accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close, size: 14, color: AppColors.of(context).accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, {required VoidCallback onTap, bool isActive = false}) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : colors.accent.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? colors.accent : colors.accent.withAlpha(51)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : colors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 14, color: isActive ? Colors.white : colors.textPrimary),
          ],
        ),
      ),
    );
  }

  void _showMoodFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filter by mood', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  _moodChip(null, 'All'),
                  _moodChip('great', 'Great'),
                  _moodChip('good', 'Good'),
                  _moodChip('okay', 'Okay'),
                  _moodChip('low', 'Low'),
                  _moodChip('tough', 'Tough'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moodChip(String? mood, String label) {
    final isActive = _moodFilter == mood;
    return GestureDetector(
      onTap: () {
        setState(() => _moodFilter = mood);
        Navigator.pop(context);
      },
      child: Chip(
        label: Text(label),
        backgroundColor: isActive ? AppColors.of(context).accent : AppColors.of(context).accent.withAlpha(26),
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isActive ? Colors.white : AppColors.of(context).textPrimary,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Life Stats Card — dark navy
  // ──────────────────────────────────────────────

  Widget _buildLifeStatsCard() {
    final totalAsync = ref.watch(totalEntriesProvider);
    final chaptersAsync = ref.watch(chaptersProvider);
    final moodStatsAsync = ref.watch(moodStatsProvider);
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [colors.card, colors.card.withAlpha(230)]
              : [colors.accent.withAlpha(220), colors.accent],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIFE STATS',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? colors.accent : Colors.white.withAlpha(200),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  totalAsync.when(
                    data: (total) => Text(
                      '$total entries',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? colors.textPrimary : Colors.white,
                      ),
                    ),
                    loading: () => Text(
                      '...',
                      style: GoogleFonts.manrope(fontSize: 18, color: isDark ? colors.textPrimary : Colors.white),
                    ),
                    error: (_, __) => Text(
                      '0 entries',
                      style: GoogleFonts.manrope(fontSize: 18, color: isDark ? colors.textPrimary : Colors.white),
                    ),
                  ),
                  Text(
                    ' · ',
                    style: GoogleFonts.manrope(fontSize: 18, color: isDark ? colors.textMuted : Colors.white.withAlpha(180)),
                  ),
                  chaptersAsync.when(
                    data: (chapters) => Text(
                      '${chapters.length} chapters',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? colors.textPrimary : Colors.white,
                      ),
                    ),
                    loading: () => Text(
                      '...',
                      style: GoogleFonts.manrope(fontSize: 18, color: isDark ? colors.textPrimary : Colors.white),
                    ),
                    error: (_, __) => Text(
                      '0 chapters',
                      style: GoogleFonts.manrope(fontSize: 18, color: isDark ? colors.textPrimary : Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.favorite, size: 14, color: isDark ? colors.accent : Colors.white.withAlpha(200)),
                  const SizedBox(width: 6),
                  moodStatsAsync.when(
                    data: (stats) {
                      final happiestMonth = _getHappiestLabel(stats);
                      return Text(
                        happiestMonth,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark ? colors.textSecondary : Colors.white.withAlpha(220),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
          // Watermark icon
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              Icons.insights,
              size: 80,
              color: isDark ? colors.accent.withAlpha(30) : Colors.white.withAlpha(40),
            ),
          ),
        ],
      ),
    );
  }

  String _getHappiestLabel(Map<String, int> stats) {
    if (stats.isEmpty) return 'Start journaling to track moods';
    final greatCount = stats['great'] ?? 0;
    final goodCount = stats['good'] ?? 0;
    if (greatCount + goodCount > 0) {
      return 'Mostly feeling great';
    }
    return 'Keep journaling for insights';
  }

  // ──────────────────────────────────────────────
  // Vertical timeline
  // ──────────────────────────────────────────────

  Widget _buildTimeline() {
    final entriesAsync = ref.watch(timelineEntriesProvider);
    final onThisDayAsync = ref.watch(onThisDayProvider);

    return entriesAsync.when(
      data: (entries) {
        final onThisDayEntries = onThisDayAsync.valueOrNull ?? [];

        // Apply filters
        var filtered = entries;
        if (_moodFilter != null) {
          filtered = filtered.where((e) => e.mood == _moodFilter).toList();
        }
        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((e) =>
            e.content.toLowerCase().contains(_searchQuery) ||
            (e.locationName?.toLowerCase().contains(_searchQuery) ?? false)
          ).toList();
        }

        if (filtered.isEmpty && onThisDayEntries.isEmpty) {
          return _buildEmptyState();
        }

        return Stack(
          children: [
            // Vertical timeline line
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: AppColors.of(context).accent.withAlpha(51),
              ),
            ),
            // Timeline items
            Column(
              children: [
                // On This Day card (if available)
                if (onThisDayEntries.isNotEmpty)
                  _buildOnThisDayCard(onThisDayEntries.first),
                // Standard entries
                ...filtered.map((entry) => _buildEntryItem(entry)),
              ],
            ),
          ],
        );
      },
      loading: () => _buildTimelineSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.of(context).textMuted),
              const SizedBox(height: 12),
              Text(
                'Could not load entries',
                style: GoogleFonts.manrope(fontSize: 14, color: AppColors.of(context).textMuted),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.invalidate(timelineEntriesProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Widget _buildTimelineSkeleton() {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        Positioned(
          left: 4,
          top: 0,
          bottom: 0,
          child: Container(width: 1, color: colors.accent.withAlpha(51)),
        ),
        Column(
          children: List.generate(4, (i) => _buildSkeletonEntry(i)),
        ),
      ],
    );
  }

  Widget _buildSkeletonEntry(int index) {
    final colors = AppColors.of(context);
    // Vary widths slightly to look natural
    final lineWidths = [
      [160.0, 120.0],
      [140.0, 100.0],
      [180.0, 90.0],
      [150.0, 110.0],
    ];
    final w = lineWidths[index % lineWidths.length];
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date chip skeleton
          SkeletonBox(width: 80, height: 11, borderRadius: 6),
          const SizedBox(height: 10),
          // Card skeleton
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: w[0], height: 13),
                      const SizedBox(height: 8),
                      SkeletonBox(width: w[1], height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            // Stacked cards illustration
            SizedBox(
              height: 120,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 16,
                    child: Transform.rotate(
                      angle: -0.06,
                      child: Container(
                        width: 140,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).accent.withAlpha(13),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.of(context).accent.withAlpha(26)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    child: Transform.rotate(
                      angle: 0.04,
                      child: Container(
                        width: 140,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.of(context).accent.withAlpha(38)),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 140,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.of(context).accent.withAlpha(51)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_stories, size: 28, color: AppColors.of(context).accent.withAlpha(128)),
                        const SizedBox(height: 4),
                        Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).accent.withAlpha(38),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 80,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).accent.withAlpha(26),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your story starts here',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every entry becomes a part of your timeline.\nStart capturing your moments.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.of(context).textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Write your first entry',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // On This Day highlight card
  // ──────────────────────────────────────────────

  Widget _buildOnThisDayCard(JournalEntry entry) {
    final yearsAgo = DateTime.now().year - entry.entryDate.year;
    final preview = entry.content.length > 100
        ? '${entry.content.substring(0, 100)}...'
        : entry.content;
    final title = entry.content.length > 30
        ? '${entry.content.substring(0, 30)}...'
        : entry.content;

    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dot on timeline
          Positioned(
            left: -20,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.of(context).accent,
                border: Border.all(color: AppColors.of(context).accent.withAlpha(51), width: 4),
              ),
            ),
          ),
          // Card
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.of(context).accent.withAlpha(13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.of(context).accent.withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'ON THIS DAY \u2014 ${entry.entryDate.year}',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.star, size: 16, color: AppColors.of(context).accent),
                  ],
                ),
                const SizedBox(height: 8),
                // Content + thumbnail
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.of(context).textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.of(context).textPrimary.withAlpha(178),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (photoMedia.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      _buildThumbnail(photoMedia.first.storagePath, size: 64),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Standard entry item
  // ──────────────────────────────────────────────

  Widget _buildEntryItem(JournalEntry entry) {
    final dateStr = DateFormat('EEEE, MMM d').format(entry.entryDate).toUpperCase();
    final preview = entry.content.length > 120
        ? '${entry.content.substring(0, 120)}...'
        : entry.content;
    final moodIcon = _moodIcon(entry.mood);
    final moodOpacity = _moodOpacity(entry.mood);

    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 20),
      child: GestureDetector(
        onTap: () => _showEntryBottomSheet(entry),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Dot on timeline
            Positioned(
              left: -18,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.of(context).accent.withAlpha(102),
                ),
              ),
            ),
            // Entry content
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + mood icon row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateStr,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.of(context).textPrimary.withAlpha(153),
                          ),
                        ),
                      ),
                      if (moodIcon != null)
                        Icon(
                          moodIcon,
                          size: 20,
                          color: AppColors.of(context).accent.withAlpha(moodOpacity),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Preview text + photo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppColors.of(context).textPrimary.withAlpha(210),
                            height: 1.6,
                          ),
                        ),
                      ),
                      if (photoMedia.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _buildThumbnail(photoMedia.first.storagePath, size: 56, grayscale: true),
                      ],
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

  void _showEntryBottomSheet(JournalEntry entry) {
    final colors = AppColors.of(context);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(entry.entryDate);
    final displayText = entry.polishedContent ?? entry.content;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (entry.mood != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.accentFaint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              entry.mood!.capitalize(),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (entry.isAiPolished)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.accentFaint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high, size: 10, color: colors.accent),
                          const SizedBox(width: 3),
                          Text('AI', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: colors.accent)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Text(
                  displayText,
                  style: GoogleFonts.merriweather(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: colors.textPrimary,
                    height: 1.85,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Photo thumbnail
  // ──────────────────────────────────────────────

  Widget _buildThumbnail(String storagePath, {double size = 56, bool grayscale = false}) {
    final mediaService = ref.read(mediaServiceProvider);
    final url = mediaService.getPublicUrl(storagePath);

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.of(context).accent.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.image, size: size * 0.4, color: AppColors.of(context).accent.withAlpha(76)),
        ),
      ),
    );

    if (grayscale) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: image,
      );
    }

    return image;
  }

  // ──────────────────────────────────────────────
  // Mood helpers
  // ──────────────────────────────────────────────

  IconData? _moodIcon(String? mood) {
    switch (mood) {
      case 'great':
        return Icons.sentiment_very_satisfied;
      case 'good':
        return Icons.sentiment_satisfied;
      case 'okay':
        return Icons.sentiment_neutral;
      case 'low':
        return Icons.sentiment_dissatisfied;
      case 'tough':
        return Icons.sentiment_very_dissatisfied;
      default:
        return null;
    }
  }

  int _moodOpacity(String? mood) {
    switch (mood) {
      case 'great':
      case 'good':
        return 255;
      case 'okay':
        return 153;
      case 'low':
        return 102;
      case 'tough':
        return 102;
      default:
        return 128;
    }
  }
}
