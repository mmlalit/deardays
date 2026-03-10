import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String? _categoryFilter; // null = All

  static const _categories = [
    (null, 'All Memories'),
    ('Family', 'Family'),
    ('Travel', 'Travel'),
    ('Career', 'Career'),
    ('Personal Growth', 'Personal Growth'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: entriesAsync.when(
        data: (entries) => _buildContent(entries, colors),
        loading: () => _buildSkeleton(colors),
        error: (_, __) => _buildError(colors),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent(List<JournalEntry> entries, AppPalette colors) {
    var filtered = entries;
    if (_categoryFilter != null) {
      filtered = filtered.where((e) => _primaryCategory(e) == _categoryFilter).toList();
    }

    final totalMemories = entries.length;
    final chapters = entries.map((e) => '${e.entryDate.year}-${e.entryDate.month}').toSet().length;
    final years = entries.map((e) => e.entryDate.year).toSet().length;

    return CustomScrollView(
      slivers: [
        // Top bar + hero + stats + filters
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildTopBar(colors),
              _buildHeroSection(colors),
              _buildStatsGrid(totalMemories, chapters, years, colors),
              const SizedBox(height: 24),
              _buildFilterChips(colors),
              const SizedBox(height: 16),
            ],
          ),
        ),

        if (filtered.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(colors))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: _buildTimelineSliver(filtered, colors),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top Bar — "Aura" branding
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(AppPalette colors) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.menu_rounded, size: 24, color: colors.accent),
            const SizedBox(width: 10),
            Text(
              'Aura',
              style: GoogleFonts.merriweather(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
            const Spacer(),
            Icon(Icons.search_rounded, size: 24, color: colors.textSecondary),
            const SizedBox(width: 16),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withAlpha(25),
                border: Border.all(color: colors.accent.withAlpha(50)),
              ),
              child: Icon(Icons.person_rounded, size: 18, color: colors.accent),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hero Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroSection(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Text(
            'Your Life Timeline',
            textAlign: TextAlign.center,
            style: GoogleFonts.merriweather(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A journey through your memories',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats Grid
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(int memories, int chapters, int years, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(child: _statCard('Memories', '$memories', colors)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Chapters', '$chapters', colors)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Years', '$years', colors)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, AppPalette colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter Chips
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFilterChips(AppPalette colors) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (category, label) = _categories[i];
          final isActive = _categoryFilter == category;
          return GestureDetector(
            onTap: () => setState(() => _categoryFilter = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? colors.accent : colors.cardBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? colors.accent : colors.border,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: colors.accent.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Timeline Sliver
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTimelineSliver(List<JournalEntry> entries, AppPalette colors) {
    // Group by year
    final grouped = <int, List<JournalEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.entryDate.year, () => []).add(e);
    }
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final mostRecentYear = years.isNotEmpty ? years.first : DateTime.now().year;

    // Build flat list of items
    final items = <_TimelineItem>[];
    for (final year in years) {
      final yearEntries = grouped[year]!;
      items.add(_TimelineItem.year(year));
      for (int i = 0; i < yearEntries.length; i++) {
        final isLast = (year == years.last) && (i == yearEntries.length - 1);
        items.add(_TimelineItem.entry(yearEntries[i], isLast: isLast));
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final item = items[i];
          if (item.isYearHeader) {
            return _buildYearHeaderRow(
              item.year!,
              isCurrentYear: item.year == mostRecentYear,
              colors: colors,
            );
          }
          return _buildCardRow(
            item.entry!,
            isCurrentYear: item.entry!.entryDate.year == mostRecentYear,
            isLast: item.isLast,
            colors: colors,
          );
        },
        childCount: items.length,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Year Header Row (circle badge + horizontal line)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildYearHeaderRow(int year, {required bool isCurrentYear, required AppPalette colors}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: year circle badge (sits on top of vertical line)
            SizedBox(
              width: 40,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vertical line through center
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 19,
                    child: Container(width: 2, color: colors.border),
                  ),
                  // Year badge on top
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentYear ? colors.accent : colors.border,
                      boxShadow: isCurrentYear
                          ? [
                              BoxShadow(
                                color: colors.accent.withAlpha(60),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$year',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Horizontal divider
            Expanded(child: Container(height: 1, color: colors.border)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card Row (dot + vertical line + card)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCardRow(
    JournalEntry entry, {
    required bool isCurrentYear,
    required bool isLast,
    required AppPalette colors,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column: vertical line + dot
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Continuous vertical line
                if (!isLast)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 19,
                    child: Container(width: 2, color: colors.border),
                  )
                else
                  Positioned(
                    top: 0,
                    bottom: 24, // stop before padding
                    left: 19,
                    child: Container(width: 2, color: colors.border),
                  ),
                // Dot at top of card (offset 22px down)
                Positioned(
                  top: 22,
                  left: 14,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentYear ? colors.accent : colors.border,
                      // White ring effect (covers the line behind the dot)
                      border: Border.all(color: colors.bg, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildCard(entry, isCurrentYear: isCurrentYear, colors: colors),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Memory Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCard(JournalEntry entry, {required bool isCurrentYear, required AppPalette colors}) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final dateStr = DateFormat('MMM dd').format(entry.entryDate).toUpperCase();
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final tags = _entryTags(entry);

    return GestureDetector(
      onTap: () => context.push('/memory', extra: entry),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + tag chips row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Up to 2 tag chips
                ...tags.take(2).map((t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _buildTagChip(t.$1, t.$2),
                    )),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: GoogleFonts.merriweather(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Excerpt
            Text(
              excerpt,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Photo (full-width inside card, rounded corners)
            if (photoMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCardPhoto(photoMedia.first.storagePath, colors),
            ],

            // Voice indicator
            if (entry.hasVoice) ...[
              const SizedBox(height: 12),
              _buildVoiceIndicator(colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardPhoto(String storagePath, AppPalette colors) {
    final mediaService = ref.read(mediaServiceProvider);
    final url = mediaService.getPublicUrl(storagePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        height: 128,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 80,
          decoration: BoxDecoration(
            color: colors.accentFaint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.image_outlined, size: 32, color: colors.textMuted),
        ),
      ),
    );
  }

  Widget _buildVoiceIndicator(AppPalette colors) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.accentFaint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          // Mini waveform bars
          ...List.generate(7, (i) {
            const heights = [4.0, 8.0, 12.0, 8.0, 4.0, 8.0, 12.0];
            const alphas = [100, 160, 255, 160, 100, 160, 255];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 2.5,
                height: heights[i],
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(alphas[i]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
          const Spacer(),
          Text(
            'Voice',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty / Error / Loading
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.accentFaint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories_outlined, size: 40, color: colors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'Your story starts here',
              style: GoogleFonts.merriweather(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Every entry becomes a part of your timeline.\nStart capturing your moments.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.push('/record'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Record First Memory',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  Widget _buildSkeleton(AppPalette colors) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 32),
              child: Column(
                children: [
                  SkeletonBox(width: 200, height: 28, borderRadius: 8),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 160, height: 14, borderRadius: 6),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          const SizedBox(height: 22),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 80, height: 10, borderRadius: 5),
                            const SizedBox(height: 10),
                            SkeletonBox(width: 220, height: 16, borderRadius: 7),
                            const SizedBox(height: 8),
                            SkeletonBox(width: 180, height: 11, borderRadius: 5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Could not load timeline',
            style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => ref.invalidate(timelineEntriesProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colors.accent,
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _extractTitle(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Memory';
    final first = lines.first.trim();
    if (first.length < 80 && lines.length > 1) return first;
    return entry.content.length > 50 ? '${entry.content.substring(0, 50)}...' : entry.content;
  }

  String _extractExcerpt(JournalEntry entry) {
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    final first = lines.first.trim();
    final isTitle = first.length < 80 && lines.length > 1;
    final body = isTitle ? lines.skip(1).join(' ') : entry.content;
    return body.length > 120 ? '${body.substring(0, 120)}...' : body;
  }

  String? _primaryCategory(JournalEntry entry) {
    final text = entry.content.toLowerCase();
    if (text.contains('travel') || text.contains('trip') || text.contains('vacation') || text.contains('flight')) {
      return 'Travel';
    }
    if (text.contains('work') || text.contains('job') || text.contains('career') || text.contains('promotion')) {
      return 'Career';
    }
    if (text.contains('family') || text.contains('mom') || text.contains('dad') ||
        text.contains('daughter') || text.contains('son') || text.contains('child')) {
      return 'Family';
    }
    if (entry.mood == 'great' || entry.mood == 'good') return 'Personal Growth';
    return null;
  }

  List<(String, Color)> _entryTags(JournalEntry entry) {
    final tags = <(String, Color)>[];

    // Mood tag
    switch (entry.mood) {
      case 'great':
        tags.add(('Joy', AppColors.moodOkay));
      case 'good':
        tags.add(('Happy', AppColors.moodGood));
      case 'okay':
        tags.add(('Serene', AppColors.moodGood));
      case 'low':
        tags.add(('Sad', AppColors.indigo));
      case 'tough':
        tags.add(('Growth', AppColors.orange));
    }

    // Category tag
    final text = entry.content.toLowerCase();
    if (text.contains('travel') || text.contains('trip') || text.contains('vacation')) {
      tags.add(('Travel', AppColors.blue));
    } else if (text.contains('work') || text.contains('job') || text.contains('career') || text.contains('promotion')) {
      tags.add(('Career', AppColors.blue));
    } else if (text.contains('family') || text.contains('mom') || text.contains('dad')) {
      tags.add(('Family', AppColors.blue));
    }

    return tags.take(2).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item model
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineItem {
  final bool isYearHeader;
  final bool isLast;
  final int? year;
  final JournalEntry? entry;

  const _TimelineItem._({
    required this.isYearHeader,
    this.isLast = false,
    this.year,
    this.entry,
  });

  factory _TimelineItem.year(int year) =>
      _TimelineItem._(isYearHeader: true, year: year);

  factory _TimelineItem.entry(JournalEntry entry, {bool isLast = false}) =>
      _TimelineItem._(isYearHeader: false, entry: entry, isLast: isLast);

  bool get isCurrentYear => !isYearHeader && entry != null;
}
