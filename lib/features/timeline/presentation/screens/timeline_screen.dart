import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/l10n/app_localizations.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/widgets/skeleton.dart';
import 'package:deardays/core/widgets/memory_card.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/timeline/presentation/widgets/milestone_card.dart';
import 'package:deardays/features/timeline/presentation/widgets/photo_collage_card.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/core/utils/entry_categories.dart';
import 'package:deardays/services/analytics/analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Context-menu helper (shared with home_screen.dart via top-level function)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showMemoryContextMenu(
  BuildContext context,
  JournalEntry entry,
  AppPalette colors, {
  VoidCallback? onDelete,
}) async {
  final title = _contextMenuTitle(entry);
  final dateStr = DateFormat.yMMMMd(Localizations.localeOf(context).toString()).format(entry.entryDate);

  final result = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
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
            const SizedBox(height: 12),

            // Header: title + date + close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.textMuted),
                    onPressed: () => Navigator.pop(sheetCtx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
                // Return 'delete' to the caller so it can handle deletion
                // using its own (still-mounted) context.
                Navigator.pop(sheetCtx, 'delete');
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  // Handle delete action using the caller's (still-mounted) context.
  if (result == 'delete' && context.mounted) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete memory?',
          style: GoogleFonts.newsreader(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'This memory will be permanently deleted and cannot be recovered.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onDelete?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
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
  bool _isGrid = false;
  String? _moodFilter;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService().trackScreen('timeline');
  }

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
        tooltip: 'Write entry',
        child: Icon(Icons.edit_rounded, color: colors.bg, size: 22),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _safeGetSignedUrl(String path) async {
    try {
      return await ref.read(mediaServiceProvider).getSignedUrl(path);
    } catch (e) {
      debugPrint('[TimelineScreen] getSignedUrl failed: $e');
      return '';
    }
  }

  Future<String> _getPhotoUrl(String storagePath) async {
    if (storagePath.startsWith('http')) return storagePath;
    return _safeGetSignedUrl(storagePath);
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
    final chaptersCount = ref.watch(chaptersProvider).valueOrNull?.length ?? 0;
    final years = entries.map((e) => e.entryDate.year).toSet().length;

    return CustomScrollView(
      controller: _scrollController,
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
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _showCalendarOverlay(context, entries, colors),
                          child: Center(
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
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Search pill button
                    Semantics(
                      label: 'Search memories',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.push('/search'),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.highlightFaint,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, size: 16, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Search',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              _buildStatsBar(totalMemories, chaptersCount, years, colors),
              if (totalMemories > 0) _buildWeeklySummaryCard(colors),
              const SizedBox(height: 16),
              _buildControlsRow(colors),
            ],
          ),
        ),

        if (filtered.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(colors))
        else if (_isGrid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
            sliver: _buildGridSliver(filtered, colors),
          )
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

  Widget _buildStatsBar(int memories, int chapters, int years, AppPalette colors) {
    Widget chip(int value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
              Text(
                label,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          chip(memories, 'memories'),
          const SizedBox(width: 8),
          chip(chapters, 'chapters'),
          const SizedBox(width: 8),
          chip(years, 'years'),
        ],
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
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent.withAlpha(20)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 10, borderRadius: 5),
              SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 12, borderRadius: 5),
              SizedBox(height: 6),
              SkeletonBox(width: double.infinity, height: 12, borderRadius: 5),
              SizedBox(height: 6),
              SkeletonBox(width: 180, height: 12, borderRadius: 5),
            ],
          ),
        ),
      ),
      error: (e, st) {
        debugPrint('[Timeline] weeklySummary error: $e');
        return const SizedBox.shrink();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Controls: Row 1 — [View by toggle] + [🔍] [⚙]
  //           Row 2 — full-width scrollable category chips
  // ─────────────────────────────────────────────────────────────────────────

  // ── View mode labels for the dropdown chip ──────────────────────────────
  static const _viewModes = [
    (0, 'Timeline', Icons.timeline_rounded),
    (1, 'Monthly', Icons.calendar_view_month_rounded),
    (2, 'Grid', Icons.grid_view_rounded),
  ];

  int get _viewModeIndex => _isGrid ? 2 : (_isMonthly ? 1 : 0);

  Widget _buildControlsRow(AppPalette colors) {
    final hasMoodFilter = _moodFilter != null;
    final (_, viewLabel, viewIcon) = _viewModes[_viewModeIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // ── View mode dropdown chip (first position) ─────────────────
            GestureDetector(
              onTap: () => _showViewModePicker(colors),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(viewIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      viewLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Category chips ───────────────────────────────────────────
            for (final (category, label) in _categories) ...[
              _filterChip(
                label: label,
                isActive: _categoryFilter == category,
                onTap: () => setState(() => _categoryFilter = category),
                colors: colors,
              ),
              const SizedBox(width: 6),
            ],

            // ── Mood chip ────────────────────────────────────────────────
            _filterChip(
              label: hasMoodFilter ? 'Mood ✓' : 'Mood',
              isActive: hasMoodFilter,
              onTap: () => _showMoodFilterSheet(colors),
              colors: colors,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required AppPalette colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? colors.accent : colors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _showViewModePicker(AppPalette colors) {
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
                'View Mode',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              for (final (idx, label, icon) in _viewModes)
                _viewModeOption(idx, label, icon, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewModeOption(int idx, String label, IconData icon, AppPalette colors) {
    final isActive = _viewModeIndex == idx;
    return GestureDetector(
      onTap: () {
        setState(() {
          switch (idx) {
            case 0:
              _isGrid = false;
              _isMonthly = false;
            case 1:
              _isGrid = false;
              _isMonthly = true;
            case 2:
              _isGrid = true;
              _isMonthly = false;
          }
        });
        Navigator.pop(context);
        // Reset scroll position to top — prevents blank screen when
        // switching from a long timeline to a shorter grid/monthly view.
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isActive ? colors.accent.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: isActive ? colors.accent : colors.textSecondary),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? colors.accent : colors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isActive)
              Icon(Icons.check_rounded, size: 18, color: colors.accent),
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
                  ExcludeSemantics(
                  child: Container(
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
                          color: isCurrentYear ? Colors.white : const Color(0xFF4A4540),
                        ),
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
    // IntrinsicHeight is needed so CrossAxisAlignment.stretch gets bounded
    // height inside slivers. Without it, Android debug mode throws
    // "BoxConstraints forces an infinite height".
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
                    color: ChapterVisual.forTitle(MemoryCard.extractTitle(entry)).primary,
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
            padding: const EdgeInsets.only(bottom: 12),
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
    return MemoryCard(
      entry: entry,
      onTap: () => context.push(
        '/memory',
        extra: MemoryDetailArgs(
          entry: entry,
          allEntries: allEntries,
          initialIndex: allEntries.indexOf(entry),
        ),
      ),
      onLongPress: () => showMemoryContextMenu(context, entry, colors,
        onDelete: () async {
          await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
          ref.invalidate(timelineEntriesProvider);
          ref.invalidate(todayEntryProvider);
        },
      ),
      onShare: () => context.push('/share-card', extra: entry),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Grid View Sliver (2-col portrait grid with title + date overlay)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGridSliver(List<JournalEntry> entries, AppPalette colors) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 3 / 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final entry = entries[i];
          final photoMedia = entry.media.where((m) => m.mediaType == 'photo').toList();
          final hasPhoto = photoMedia.isNotEmpty;
          final dateStr = DateFormat.MMMd(Localizations.localeOf(context).toString()).format(entry.entryDate).toUpperCase();
          final title = MemoryCard.extractTitle(entry);

          return GestureDetector(
            onTap: () => context.push('/memory',
                extra: MemoryDetailArgs(entry: entry, allEntries: entries, initialIndex: i)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo or mood gradient background
                  if (hasPhoto)
                    _GridPhoto(
                      storagePath: photoMedia.first.storagePath,
                      focalAlignment: photoMedia.first.focalAlignment,
                    )
                  else
                    _GridMoodTile(entry: entry, colors: colors),

                  // Bottom gradient + title + date
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 32, 8, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xDD000000), Colors.transparent],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.newsreader(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Voice indicator dot
                  if (entry.hasVoice)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        childCount: entries.length,
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

    // Build a flat list of lightweight descriptors so the SliverChildBuilderDelegate
    // can lazily build widgets by index instead of pre-materializing them all.
    // Each descriptor is one of: ('header', key), ('entry', JournalEntry), ('gap', null).
    final descriptors = <(String, Object?)>[];
    for (final key in keys) {
      descriptors.add(('header', key));
      for (final entry in grouped[key]!) {
        descriptors.add(('entry', entry));
      }
      descriptors.add(('gap', null));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final (type, data) = descriptors[i];
            switch (type) {
              case 'header':
                final k = data! as String;
                final parts = k.split('-');
                final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                return _buildMonthHeader(date, grouped[k]!.length, colors);
              case 'entry':
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildCardForType(data! as JournalEntry, entries, colors),
                );
              default:
                return const SizedBox(height: 8);
            }
          },
          childCount: descriptors.length,
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
            DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(date),
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
            AppLocalizations.of(context)?.timelineEmptyTitle ?? 'Your timeline is empty',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.timelineEmptySubtitle ?? 'Start recording memories to see them here.',
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
                AppLocalizations.of(context)?.writeFirstMemory ?? 'Write your first memory',
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

  String? _primaryCategory(JournalEntry entry) => EntryCategories.primary(entry);

}

// ─────────────────────────────────────────────────────────────────────────────
// Grid helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GridPhoto extends ConsumerStatefulWidget {
  const _GridPhoto({required this.storagePath, this.focalAlignment});
  final String storagePath;
  final Alignment? focalAlignment;

  @override
  ConsumerState<_GridPhoto> createState() => _GridPhotoState();
}

class _GridPhotoState extends ConsumerState<_GridPhoto> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _fetchUrl();
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
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data ?? '';
        if (url.isEmpty) {
          return Container(color: Colors.black12);
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          alignment: widget.focalAlignment ?? Alignment.center,
          memCacheWidth: 400,
          memCacheHeight: 530,
          errorWidget: (_, __, ___) => Container(color: Colors.black12),
        );
      },
    );
  }
}

class _GridMoodTile extends StatelessWidget {
  const _GridMoodTile({required this.entry, required this.colors});
  final JournalEntry entry;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    final moodColor = switch (entry.mood) {
      'great' => AppColors.moodGreat,
      'good'  => AppColors.moodGood,
      'okay'  => AppColors.moodOkay,
      'low'   => AppColors.moodLow,
      'tough' => AppColors.moodTough,
      _       => colors.accent,
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [moodColor.withAlpha(180), moodColor.withAlpha(100)],
        ),
      ),
    );
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
    final monthName = DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(_viewMonth);
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
                        color: const Color(0xFF595550),
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
