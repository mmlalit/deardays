import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/timeline/presentation/widgets/milestone_card.dart';
import 'package:deardays/features/timeline/presentation/widgets/photo_collage_card.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Context-menu helper (shared with home_screen.dart via top-level function)
// ─────────────────────────────────────────────────────────────────────────────

void showMemoryContextMenu(
  BuildContext context,
  JournalEntry entry,
  AppPalette colors, {
  VoidCallback? onDelete,
}) {
  final title = _contextMenuTitle(entry);
  final dateStr = DateFormat('MMMM d, yyyy').format(entry.entryDate);

  showModalBottomSheet(
    context: context,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),

            // Header: title + date
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: colors.border, height: 1),

            // Options
            _ContextMenuOption(
              icon: Icons.edit_rounded,
              label: 'Edit Memory',
              colors: colors,
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/edit-memory', extra: entry);
              },
            ),
            _ContextMenuOption(
              icon: Icons.share_rounded,
              label: 'Share',
              colors: colors,
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/share-card', extra: entry);
              },
            ),
            Divider(color: colors.border, height: 1),
            _ContextMenuOption(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              colors: colors,
              isDestructive: true,
              onTap: () {
                Navigator.pop(sheetCtx);
                onDelete?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Memory deleted'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        // Undo not yet wired — placeholder for future implementation
                      },
                    ),
                  ),
                );
              },
            ),

            // Cancel button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(sheetCtx),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _contextMenuTitle(JournalEntry entry) {
  final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return 'Untitled Memory';
  final first = lines.first.trim();
  if (first.length < 80 && lines.length > 1) return first;
  return entry.content.length > 50 ? '${entry.content.substring(0, 50)}...' : entry.content;
}


class _ContextMenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette colors;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ContextMenuOption({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFEF4444) : colors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline Screen
// ─────────────────────────────────────────────────────────────────────────────

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String? _categoryFilter;
  bool _isMonthly = false;
  String? _moodFilter;

  static const _categories = [
    (null, 'All'),
    ('Family', 'Family'),
    ('Travel', 'Travel'),
    ('Career', 'Career'),
    ('Personal Growth', 'Growth'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(timelineEntriesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: entriesAsync.when(
        data: (entries) {
          return _buildContent(entries, colors);
        },
        loading: () => _buildSkeleton(colors),
        error: (_, __) => _buildError(colors),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'timeline-write-fab',
        onPressed: () => context.push('/write'),
        backgroundColor: colors.accent,
        elevation: 4,
        child: Icon(Icons.edit_rounded, color: colors.bg, size: 22),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _getPhotoUrl(String storagePath) async {
    try {
      if (storagePath.startsWith('http')) return storagePath;
      return await ref.read(mediaServiceProvider).getSignedUrl(storagePath);
    } catch (_) {
      return '';
    }
  }

  Widget _buildContent(List<JournalEntry> entries, AppPalette colors) {
    var filtered = entries;
    if (_categoryFilter != null) {
      filtered = filtered.where((e) => _primaryCategory(e) == _categoryFilter).toList();
    }
    if (_moodFilter != null) {
      filtered = filtered.where((e) => e.mood == _moodFilter).toList();
    }
    final totalMemories = entries.length;
    final chapters = entries.map((e) => '${e.entryDate.year}-${e.entryDate.month}').toSet().length;
    final years = entries.map((e) => e.entryDate.year).toSet().length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    Text('Timeline', style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    const Spacer(),
                    // Mood calendar
                    Semantics(
                      label: 'Mood Calendar',
                      button: true,
                      child: GestureDetector(
                        onTap: () => _showCalendarOverlay(context, entries, colors),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accent.withAlpha(18),
                          ),
                          child: Icon(Icons.calendar_month_rounded, size: 20, color: colors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Search
                    Semantics(
                      label: 'Search',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.push('/search'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.highlightFaint,
                          ),
                          child: Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatsGrid(totalMemories, chapters, years, colors),
              if (totalMemories > 0) _buildWeeklySummaryCard(colors),
              const SizedBox(height: 16),
              _buildControlsRow(colors),
            ],
          ),
        ),

        if (filtered.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(colors))
        else if (_isMonthly)
          _buildMonthlySliver(filtered, colors)
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: _buildTimelineSliver(filtered, colors),
          ),
      ],
    );
  }

  void _showCalendarOverlay(BuildContext context, List<JournalEntry> entries, AppPalette colors) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MoodCalendarSheet(
        entries: entries,
        colors: colors,
        onDateTap: (date, dayEntries) {
          Navigator.pop(context);
          if (dayEntries.isNotEmpty) {
            this.context.push(
              '/memory',
              extra: MemoryDetailArgs(
                entry: dayEntries.first,
                allEntries: dayEntries,
                initialIndex: 0,
              ),
            );
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats Grid
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(int memories, int chapters, int years, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Memories', '$memories', colors,
              onTap: () => setState(() { _categoryFilter = null; _moodFilter = null; }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              'Months', '$chapters', colors,
              onTap: () => setState(() => _isMonthly = true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              'Years', '$years', colors,
              onTap: () => setState(() => _isMonthly = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, AppPalette colors, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Weekly Summary Card (AI-generated)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWeeklySummaryCard(AppPalette colors) {
    final summaryAsync = ref.watch(weeklySummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary == null || summary.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: GestureDetector(
            onTap: () => context.push('/reflection?period=weekly'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.accent.withAlpha(26)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'WEEKLY SUMMARY',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: colors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'View full report',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 16, color: colors.accent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colors.textPrimary,
                      height: 1.5,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Controls: Row 1 — [View by toggle] + [🔍] [⚙]
  //           Row 2 — full-width scrollable category chips
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildControlsRow(AppPalette colors) {
    final hasMoodFilter = _moodFilter != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            // ── View toggle (icon-only) ──────────────────────────────────────
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
                  _viewToggleTab(Icons.timeline_rounded, isMonthly: false, colors: colors),
                  _viewToggleTab(Icons.calendar_view_month_rounded, isMonthly: true, colors: colors),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Scrollable category chips ────────────────────────────────────
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final (category, label) = _categories[i];
                  final isActive = _categoryFilter == category;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryFilter = category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? colors.accent : colors.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? colors.accent : colors.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : colors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // ── Mood filter ──────────────────────────────────────────────────
            GestureDetector(
              onTap: () => _showMoodFilterSheet(colors),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hasMoodFilter ? colors.accent : colors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: hasMoodFilter ? colors.accent : colors.border),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: hasMoodFilter ? Colors.white : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  void _showMoodFilterSheet(AppPalette colors) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Filter by Mood',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _moodChip(null, 'All', colors),
                  _moodChip('great', '😄 Great', colors),
                  _moodChip('good', '😊 Good', colors),
                  _moodChip('okay', '😐 Okay', colors),
                  _moodChip('low', '😔 Low', colors),
                  _moodChip('tough', '😞 Tough', colors),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moodChip(String? mood, String label, AppPalette colors) {
    final isActive = _moodFilter == mood;
    return GestureDetector(
      onTap: () {
        setState(() => _moodFilter = mood);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : colors.cardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isActive ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : colors.textSecondary,
          ),
        ),
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
          return RepaintBoundary(
            child: _buildCardRow(
              item.entry!,
              isCurrentYear: item.entry!.entryDate.year == mostRecentYear,
              isLast: item.isLast,
              colors: colors,
              cardWidget: _buildCardForType(item.entry!, entries, colors),
            ),
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

  /// Picks the right card widget based on entry properties.
  /// Priority: Milestone > Photo Collage > Standard.
  Widget _buildCardForType(JournalEntry entry, List<JournalEntry> allEntries, AppPalette colors) {
    final photoCount = entry.media.where((m) => m.mediaType == 'photo').length;

    if (entry.isMilestone) {
      return MilestoneCard(
        entry: entry,
        colors: colors,
        onTap: () => context.push(
          '/memory',
          extra: MemoryDetailArgs(
            entry: entry,
            allEntries: allEntries,
            initialIndex: allEntries.indexOf(entry),
          ),
        ),
        photoUrlBuilder: _getPhotoUrl,
      );
    }

    if (photoCount >= 2) {
      return PhotoCollageCard(
        entry: entry,
        colors: colors,
        onTap: () => context.push(
          '/memory',
          extra: MemoryDetailArgs(
            entry: entry,
            allEntries: allEntries,
            initialIndex: allEntries.indexOf(entry),
          ),
        ),
        photoUrlBuilder: _getPhotoUrl,
      );
    }

    return _buildCard(entry, allEntries, isCurrentYear: false, colors: colors);
  }

  Widget _buildCardRow(
    JournalEntry entry, {
    required bool isCurrentYear,
    required bool isLast,
    required AppPalette colors,
    Widget? cardWidget,
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
                      color: ChapterVisual.forTitle(_extractTitle(entry)).primary,
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
              child: cardWidget,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Memory Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCard(JournalEntry entry, List<JournalEntry> allEntries, {required bool isCurrentYear, required AppPalette colors}) {
    final title = _extractTitle(entry);
    final excerpt = _extractExcerpt(entry);
    final timeStr = entry.entryTime != null
        ? '${entry.entryTime!.hour.toString().padLeft(2, '0')}:${entry.entryTime!.minute.toString().padLeft(2, '0')}'
        : DateFormat('HH:mm').format(entry.createdAt);
    final dateStr = '${DateFormat('MMM dd').format(entry.entryDate).toUpperCase()} • $timeStr';
    final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
    final tags = _entryTags(entry);
    final hasPhoto = photoMedia.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push(
        '/memory',
        extra: MemoryDetailArgs(
          entry: entry,
          allEntries: allEntries,
          initialIndex: allEntries.indexOf(entry),
        ),
      ),
      onLongPress: () => showMemoryContextMenu(context, entry, colors),
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo at top — bleeds to card edges for a unified look
            if (hasPhoto)
              _buildCardPhoto(photoMedia.first.storagePath, colors)
            // Mood-colour band when no photo — gives every card a visual anchor
            else if (entry.mood != null)
              _buildMoodBand(entry.mood!, colors),

            Padding(
              padding: EdgeInsets.fromLTRB(16, hasPhoto ? 14 : 18, 16, 16),
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
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

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

                  // Voice indicator + share icon row
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (entry.hasVoice) _buildVoiceIndicator(colors),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/share-card', extra: entry),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.ios_share_rounded,
                            size: 18,
                            color: colors.textMuted,
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
    return _TimelineCardPhoto(storagePath: storagePath, colors: colors);
  }

  Widget _buildMoodBand(String mood, AppPalette colors) {
    final moodColor = switch (mood) {
      'great' => AppColors.moodGreat,
      'good'  => AppColors.moodGood,
      'okay'  => AppColors.moodOkay,
      'low'   => AppColors.moodLow,
      'tough' => AppColors.moodTough,
      _       => colors.accent,
    };
    final moodEmoji = switch (mood) {
      'great' => '🌟',
      'good'  => '😊',
      'okay'  => '😌',
      'low'   => '😔',
      'tough' => '💪',
      _       => '✨',
    };
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            moodColor.withAlpha(38),
            moodColor.withAlpha(18),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, color: moodColor),
          const SizedBox(width: 12),
          Text(moodEmoji, style: const TextStyle(fontSize: 16)),
        ],
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
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 8),
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

  Widget _viewToggleTab(IconData icon, {required bool isMonthly, required AppPalette colors}) {
    final isActive = _isMonthly == isMonthly;
    return GestureDetector(
      onTap: () => setState(() => _isMonthly = isMonthly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        decoration: BoxDecoration(
          color: isActive ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: isActive ? Colors.white : colors.textSecondary),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Monthly View Sliver
  // ─────────────────────────────────────────────────────────────────────────

  SliverPadding _buildMonthlySliver(List<JournalEntry> entries, AppPalette colors) {
    final grouped = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final key = '${e.entryDate.year}-${e.entryDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final items = <Widget>[];
    for (final key in keys) {
      final monthEntries = grouped[key]!;
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      items.add(_buildMonthHeader(date, monthEntries.length, colors));
      for (final entry in monthEntries) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCardForType(entry, entries, colors),
        ));
      }
      items.add(const SizedBox(height: 8));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => items[i],
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date, int count, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(date),
            style: GoogleFonts.newsreader(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 120),
      child: Column(
        children: [
          Icon(Icons.timeline_rounded, size: 64, color: colors.textMuted.withAlpha(80)),
          const SizedBox(height: 20),
          Text(
            'Your timeline is empty',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording memories to see them here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/write'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Write your first memory',
                style: GoogleFonts.manrope(
                  fontSize: 14,
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

  Widget _buildSkeleton(AppPalette colors) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 60, 16, 32),
              child: Column(
                children: [
                  SkeletonBox(width: 200, height: 28, borderRadius: 8),
                  SizedBox(height: 8),
                  SkeletonBox(width: 160, height: 14, borderRadius: 6),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 80, height: 10, borderRadius: 5),
                            SizedBox(height: 10),
                            SkeletonBox(width: 220, height: 16, borderRadius: 7),
                            SizedBox(height: 8),
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
// Mood Calendar Sheet — bottom-sheet with month navigation & date tap
// ─────────────────────────────────────────────────────────────────────────────

class _MoodCalendarSheet extends StatefulWidget {
  final List<JournalEntry> entries;
  final AppPalette colors;
  final void Function(DateTime date, List<JournalEntry> dayEntries) onDateTap;

  const _MoodCalendarSheet({
    required this.entries,
    required this.colors,
    required this.onDateTap,
  });

  @override
  State<_MoodCalendarSheet> createState() => _MoodCalendarSheetState();
}

class _MoodCalendarSheetState extends State<_MoodCalendarSheet> {
  late DateTime _viewMonth;

  static const _moodColors = {
    'great': Color(0xFF10B981),
    'good': Color(0xFF3B82F6),
    'okay': Color(0xFFF59E0B),
    'low': Color(0xFFF97316),
    'tough': Color(0xFFEF4444),
  };

  static const _legend = [
    ('Great', Color(0xFF10B981)),
    ('Good', Color(0xFF3B82F6)),
    ('Okay', Color(0xFFF59E0B)),
    ('Low', Color(0xFFF97316)),
    ('Tough', Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month, 1);
  }

  void _goToPreviousMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    if (nextMonth.isAfter(DateTime(now.year, now.month + 1, 0))) return;
    setState(() {
      _viewMonth = nextMonth;
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    final nextMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    return !nextMonth.isAfter(DateTime(now.year, now.month + 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final monthName = DateFormat('MMMM yyyy').format(_viewMonth);
    final now = DateTime.now();

    final moodMap = <int, String>{};
    final dayEntriesMap = <int, List<JournalEntry>>{};
    for (final entry in widget.entries) {
      if (entry.entryDate.year == year && entry.entryDate.month == month) {
        dayEntriesMap.putIfAbsent(entry.entryDate.day, () => []).add(entry);
        if (entry.mood != null) {
          moodMap[entry.entryDate.day] = entry.mood!;
        } else {
          moodMap.putIfAbsent(entry.entryDate.day, () => '');
        }
      }
    }

    // Count entries for this month
    final monthEntryCount = dayEntriesMap.values.fold<int>(0, (sum, list) => sum + list.length);

    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday - 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _goToPreviousMonth,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.colors.accentFaint,
                    ),
                    child: Icon(Icons.chevron_left_rounded, size: 22, color: widget.colors.accent),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    monthName,
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: widget.colors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _canGoNext ? _goToNextMonth : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _canGoNext ? widget.colors.accentFaint : widget.colors.accentFaint.withAlpha(80),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: _canGoNext ? widget.colors.accent : widget.colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Entry count for this month
            Text(
              '$monthEntryCount ${monthEntryCount == 1 ? 'entry' : 'entries'} this month',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: widget.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Day-of-week header
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.colors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            _buildCalendarGrid(now, year, month, daysInMonth, firstWeekday, moodMap, dayEntriesMap),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _legend.map((item) {
                final (label, color) = item;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: widget.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    DateTime now,
    int year,
    int month,
    int daysInMonth,
    int firstWeekday,
    Map<int, String> moodMap,
    Map<int, List<JournalEntry>> dayEntriesMap,
  ) {
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final isCurrentMonth = now.year == year && now.month == month;

    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final day = cellIndex - firstWeekday + 1;

              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 40));
              }

              final mood = moodMap[day];
              final isToday = isCurrentMonth && day == now.day;
              final hasMood = mood != null && mood.isNotEmpty;
              final hasEntry = dayEntriesMap.containsKey(day);
              final moodColor = hasMood ? (_moodColors[mood] ?? widget.colors.accent) : null;

              return Expanded(
                child: GestureDetector(
                  onTap: hasEntry
                      ? () => widget.onDateTap(
                            DateTime(year, month, day),
                            dayEntriesMap[day]!,
                          )
                      : null,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasMood
                            ? moodColor
                            : isToday
                                ? widget.colors.accent.withAlpha(30)
                                : hasEntry
                                    ? widget.colors.accent.withAlpha(15)
                                    : Colors.transparent,
                        border: isToday && !hasMood
                            ? Border.all(color: widget.colors.accent, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasMood
                                ? (moodColor!.computeLuminance() > 0.35
                                    ? const Color(0xFF1F2937)
                                    : Colors.white)
                                : isToday
                                    ? widget.colors.accent
                                    : widget.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item model
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Card photo widget — StatefulWidget so the signed-URL future is created once
// in initState and not recreated on every parent rebuild.
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineCardPhoto extends ConsumerStatefulWidget {
  const _TimelineCardPhoto({
    required this.storagePath,
    required this.colors,
  });

  final String storagePath;
  final AppPalette colors;

  @override
  ConsumerState<_TimelineCardPhoto> createState() => _TimelineCardPhotoState();
}

class _TimelineCardPhotoState extends ConsumerState<_TimelineCardPhoto> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _fetchUrl();
  }

  @override
  void didUpdateWidget(_TimelineCardPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _urlFuture = _fetchUrl();
    }
  }

  Future<String> _fetchUrl() async {
    if (widget.storagePath.startsWith('http')) return widget.storagePath;
    try {
      return await ref.read(mediaServiceProvider).getSignedUrl(widget.storagePath);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 140,
            width: double.infinity,
            color: colors.accentFaint,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.textMuted,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.hasError || snapshot.data!.isEmpty) {
          return Container(
            height: 100,
            color: colors.accentFaint,
            child: Icon(Icons.image_outlined, size: 32, color: colors.textMuted),
          );
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheWidth: 600,
          memCacheHeight: 280,
          errorWidget: (_, __, ___) => Container(
            height: 100,
            color: colors.accentFaint,
            child: Icon(Icons.image_outlined, size: 32, color: colors.textMuted),
          ),
        );
      },
    );
  }
}

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
