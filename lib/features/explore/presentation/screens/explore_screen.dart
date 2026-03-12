import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category definitions for keyword matching
// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String id;
  final String label;
  final List<String> keywords;

  const _Category({
    required this.id,
    required this.label,
    required this.keywords,
  });
}

const _familyCategory = _Category(
  id: 'family',
  label: 'Family',
  keywords: [
    'family', 'mom', 'dad', 'mother', 'father', 'daughter', 'son',
    'brother', 'sister', 'parent', 'child', 'baby', 'husband', 'wife',
  ],
);

const _travelCategory = _Category(
  id: 'travel',
  label: 'Travel',
  keywords: [
    'travel', 'trip', 'vacation', 'flight', 'hotel', 'beach', 'mountain',
    'journey', 'explore', 'visited', 'airport', 'road trip', 'hike',
  ],
);

String? _detectCategory(JournalEntry entry) {
  final text = entry.content.toLowerCase();
  for (final cat in [_familyCategory, _travelCategory]) {
    for (final kw in cat.keywords) {
      if (text.contains(kw)) return cat.id;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood chip config
// ─────────────────────────────────────────────────────────────────────────────

const _moodChips = [
  _MoodChip(value: 'great', label: 'Great', emoji: '🤩', color: Color(0xFF10B981)),
  _MoodChip(value: 'good',  label: 'Good',  emoji: '😊', color: Color(0xFF3B82F6)),
  _MoodChip(value: 'okay',  label: 'Okay',  emoji: '😐', color: Color(0xFFF59E0B)),
  _MoodChip(value: 'low',   label: 'Low',   emoji: '😔', color: Color(0xFFF97316)),
  _MoodChip(value: 'tough', label: 'Tough', emoji: '😢', color: Color(0xFFEF4444)),
];

class _MoodChip {
  final String value;
  final String label;
  final String emoji;
  final Color color;
  const _MoodChip({
    required this.value,
    required this.label,
    required this.emoji,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Explore Screen
// ─────────────────────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';

  // Filter state
  String? _filterMood;
  bool _filterHasPhoto = false;
  DateTimeRange? _filterDateRange;
  bool _showFilters = false;

  bool get _hasActiveFilter =>
      _filterMood != null || _filterHasPhoto || _filterDateRange != null;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<JournalEntry> _applyFilters(List<JournalEntry> entries) {
    var filtered = entries;
    if (_filterMood != null) {
      filtered = filtered.where((e) => e.mood == _filterMood).toList();
    }
    if (_filterHasPhoto) {
      filtered = filtered.where((e) => e.media.any((m) => m.mediaType == 'photo')).toList();
    }
    if (_filterDateRange != null) {
      filtered = filtered.where((e) {
        final d = e.entryDate;
        return !d.isBefore(_filterDateRange!.start) &&
               !d.isAfter(_filterDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          _buildHeader(colors),
          _buildSearchBar(colors),
          if (_showFilters) _buildFilterRow(colors),
          if (_hasActiveFilter && !_showFilters) _buildActiveFiltersBadge(colors),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppPalette colors) {
    return Container(
      color: colors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bubble_chart_rounded, color: colors.accent, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Aura',
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.notifications_outlined, size: 20, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, colors.accentLight],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Search bar (with filter icon)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSearchBar(AppPalette colors) {
    return Container(
      color: colors.bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.highlightFaint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                style: GoogleFonts.manrope(fontSize: 14, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search memories...',
                  hintStyle: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter icon button with active indicator
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showFilters = !_showFilters);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _showFilters
                        ? colors.accent.withAlpha(30)
                        : colors.highlightFaint,
                    borderRadius: BorderRadius.circular(14),
                    border: _showFilters
                        ? Border.all(color: colors.accent.withAlpha(80))
                        : null,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 22,
                    color: _showFilters ? colors.accent : colors.textMuted,
                  ),
                ),
                if (_hasActiveFilter)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter row (horizontal chips)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFilterRow(AppPalette colors) {
    return Container(
      color: colors.bg,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            // Mood chips
            for (final mc in _moodChips) ...[
              _buildMoodChip(mc, colors),
              const SizedBox(width: 8),
            ],
            // Has Photo chip
            _buildPhotoChip(colors),
            const SizedBox(width: 8),
            // Date range chip
            _buildDateRangeChip(colors),
            // Clear all (only if filters active)
            if (_hasActiveFilter) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _filterMood = null;
                    _filterHasPhoto = false;
                    _filterDateRange = null;
                  });
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Clear all',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChip(_MoodChip mc, AppPalette colors) {
    final selected = _filterMood == mc.value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterMood = selected ? null : mc.value);
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? mc.color : colors.highlightFaint,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mc.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              mc.label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoChip(AppPalette colors) {
    final selected = _filterHasPhoto;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterHasPhoto = !selected);
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.highlightFaint,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          '📷 Has Photo',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeChip(AppPalette colors) {
    final selected = _filterDateRange != null;
    final label = selected
        ? '${DateFormat('MMM d').format(_filterDateRange!.start)} – ${DateFormat('MMM d').format(_filterDateRange!.end)}'
        : '📅 Date range';

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (selected) {
          setState(() => _filterDateRange = null);
          return;
        }
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2010),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: colors.accent),
            ),
            child: child!,
          ),
        );
        if (range != null && mounted) {
          setState(() => _filterDateRange = range);
        }
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.highlightFaint,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBadge(AppPalette colors) {
    final count = (_filterMood != null ? 1 : 0) +
        (_filterHasPhoto ? 1 : 0) +
        (_filterDateRange != null ? 1 : 0);
    return Container(
      color: colors.bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count filter${count > 1 ? 's' : ''} active',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _filterMood = null;
                _filterHasPhoto = false;
                _filterDateRange = null;
              });
            },
            child: Text(
              'Clear',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body — routes to overview, see-all list, or search results
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(AppPalette colors) {
    final entriesAsync = ref.watch(timelineEntriesProvider);
    return entriesAsync.when(
      data: (entries) {
        final filtered = _applyFilters(entries);
        // Search mode
        if (_searchQuery.isNotEmpty) {
          return _buildSearchResults(filtered, colors);
        }
        // Filter-only mode (no search but filters active)
        if (_hasActiveFilter && filtered.isEmpty) {
          return _buildNoFilterResults(colors);
        }
        if (_hasActiveFilter) {
          return _buildFilteredResults(filtered, colors);
        }
        // Default overview
        if (entries.isEmpty) return _buildEmptyState(colors);
        return _buildOverview(entries, colors);
      },
      loading: () => _buildSkeleton(colors),
      error: (_, __) => Center(
        child: Text('Could not load', style: GoogleFonts.manrope(color: colors.textMuted)),
      ),
    );
  }

  Widget _buildNoFilterResults(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_rounded, size: 48, color: colors.textMuted.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            'No memories match your filters',
            style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _filterMood = null;
              _filterHasPhoto = false;
              _filterDateRange = null;
            }),
            child: Text(
              'Clear filters',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredResults(List<JournalEntry> filtered, AppPalette colors) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildCompactEntryCard(filtered[i], colors),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Overview — main curated sections
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverview(List<JournalEntry> entries, AppPalette colors) {
    final happiest = entries
        .where((e) => e.mood == 'great' || e.mood == 'good')
        .take(8)
        .toList();
    final familyEntries = entries
        .where((e) => _detectCategory(e) == 'family')
        .take(5)
        .toList();
    final travelEntries = entries
        .where((e) => _detectCategory(e) == 'travel')
        .take(6)
        .toList();

    // Find family book for the featured card
    final booksAsync = ref.watch(booksProvider);
    final familyBook = booksAsync.valueOrNull?.where((b) {
      final t = b.title.toLowerCase();
      return _familyCategory.keywords.any((kw) => t.contains(kw));
    }).firstOrNull;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // ── Surprise Me button ──
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _buildSurpriseMe(entries, colors),
          ),

        // ── Happiest Memories ──
        if (happiest.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Happiest Memories', colors, onSeeAll: () {
              context.push('/explore/see-all/${SeeAllSection.happiest.name}');
            }),
          ),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: happiest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(happiest[i], colors),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ── Family Moments ──
        if (familyEntries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Family Moments', colors, onSeeAll: () {
              if (familyBook != null) {
                context.push('/book/${familyBook.id}');
              } else {
                context.push('/explore/see-all/${SeeAllSection.family.name}');
              }
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFamilyGrid(familyEntries, familyBook, colors),
          ),
          const SizedBox(height: 28),
        ],

        // ── Travel Stories ──
        if (travelEntries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Travel Stories', colors, onSeeAll: () {
              context.push('/explore/see-all/${SeeAllSection.travel.name}');
            }),
          ),
          ...travelEntries.take(4).map((e) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _buildTravelRow(e, colors),
              )),
          const SizedBox(height: 8),
        ],

        // Fallback if no curated sections have data
        if (happiest.isEmpty && familyEntries.isEmpty && travelEntries.isEmpty)
          _buildEmptyState(colors),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Surprise Me button (Feature 4)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSurpriseMe(List<JournalEntry> entries, AppPalette colors) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        final random = entries[Random().nextInt(entries.length)];
        context.push('/memory', extra: random);
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.accent.withAlpha(180), colors.accentLight],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shuffle_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              '✨ Surprise Me',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section header with "See all >"
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, AppPalette colors, {VoidCallback? onSeeAll}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.newsreader(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSeeAll();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See all',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: colors.accent),
              ],
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Happiest Memory card (horizontal scroll)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHappyCard(JournalEntry entry, AppPalette colors) {
    final dateStr = DateFormat('MMM d').format(entry.entryDate);
    final title = _entryTitle(entry);
    final hasMedia = entry.media.where((m) => m.mediaType == 'photo').isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colors.cardBg,
          border: Border.all(color: colors.border.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image / gradient area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _moodGradient(entry.mood),
                  ),
                ),
                child: Stack(
                  children: [
                    if (hasMedia)
                      Positioned.fill(
                        child: _buildEntryPhoto(entry, colors),
                      ),
                    // Gradient overlay at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(120),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Mood emoji
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _moodEmoji(entry.mood),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text area
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Family Moments grid — 1 featured + 2 small cards
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFamilyGrid(
    List<JournalEntry> entries,
    dynamic familyBook,
    AppPalette colors,
  ) {
    final featured = entries.first;
    final small = entries.skip(1).take(2).toList();

    return Column(
      children: [
        // Featured full-width card → goes to family book or memory
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (familyBook != null) {
              context.push('/book/${familyBook.id}');
            } else {
              context.push('/memory', extra: featured);
            }
          },
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colors.cardBg,
              border: Border.all(color: colors.border.withAlpha(80)),
              boxShadow: [
                BoxShadow(
                  color: colors.textPrimary.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFFEC4899).withAlpha(40), const Color(0xFFF9A8D4).withAlpha(30)],
                    ),
                  ),
                ),
                if (featured.media.where((m) => m.mediaType == 'photo').isNotEmpty)
                  Positioned.fill(child: _buildEntryPhoto(featured, colors)),
                // Gradient overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(160)],
                      ),
                    ),
                  ),
                ),
                // Label
                Positioned(
                  left: 16,
                  bottom: 14,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_stories_rounded, size: 16, color: Colors.white.withAlpha(220)),
                          const SizedBox(width: 6),
                          Text(
                            familyBook?.title ?? 'Family Life',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entries.length} memories',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Small cards row
        if (small.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < small.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _buildFamilySmallCard(small[i], colors)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFamilySmallCard(JournalEntry entry, AppPalette colors) {
    final dateStr = DateFormat('MMM d').format(entry.entryDate);
    final title = _entryTitle(entry);
    final hasMedia = entry.media.where((m) => m.mediaType == 'photo').isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.cardBg,
          border: Border.all(color: colors.border.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFEC4899).withAlpha(30), const Color(0xFFF9A8D4).withAlpha(20)],
                  ),
                ),
                child: hasMedia
                    ? _buildEntryPhoto(entry, colors)
                    : Center(
                        child: Icon(Icons.family_restroom_rounded, size: 28, color: const Color(0xFFEC4899).withAlpha(120)),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.textMuted,
                      letterSpacing: 1.5,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Travel Stories row (compact card)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTravelRow(JournalEntry entry, AppPalette colors) {
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 80
        ? '${entry.content.substring(0, 80)}...'
        : entry.content;
    final hasMedia = entry.media.where((m) => m.mediaType == 'photo').isNotEmpty;
    final photoCount = entry.media.where((m) => m.mediaType == 'photo').length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.cardBg,
          border: Border.all(color: colors.border.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFF59E0B).withAlpha(30), const Color(0xFFFBBF24).withAlpha(20)],
                ),
              ),
              child: hasMedia
                  ? _buildEntryPhoto(entry, colors)
                  : Center(
                      child: Icon(Icons.flight_rounded, size: 28, color: const Color(0xFFF59E0B).withAlpha(150)),
                    ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Meta row: location + photo count
                    Row(
                      children: [
                        if (entry.locationName != null) ...[
                          Icon(Icons.location_on_outlined, size: 13, color: colors.textMuted),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              entry.locationName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                            ),
                          ),
                        ],
                        if (entry.locationName != null && photoCount > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·', style: GoogleFonts.manrope(color: colors.textMuted)),
                          ),
                        if (photoCount > 0) ...[
                          Icon(Icons.photo_camera_outlined, size: 13, color: colors.textMuted),
                          const SizedBox(width: 2),
                          Text(
                            '$photoCount',
                            style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      excerpt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Search results
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSearchResults(List<JournalEntry> entries, AppPalette colors) {
    final results = entries
        .where((e) => e.content.toLowerCase().contains(_searchQuery))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: colors.textMuted.withAlpha(100)),
            const SizedBox(height: 12),
            Text(
              'No memories match "$_searchQuery"',
              style: GoogleFonts.manrope(fontSize: 14, color: colors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildCompactEntryCard(results[i], colors),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Compact entry card (used in see-all and search)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCompactEntryCard(JournalEntry entry, AppPalette colors) {
    final dateStr = DateFormat('MMM d, yyyy').format(entry.entryDate);
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 100
        ? '${entry.content.substring(0, 100)}...'
        : entry.content;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.cardBg,
          border: Border.all(color: colors.border.withAlpha(80)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _moodEmoji(entry.mood),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.newsreader(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.explore_rounded, size: 36, color: colors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'Your memories will appear here',
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start journaling and Aura will organize your happiest moments, family stories, and adventures.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.go('/home'),
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
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(demoModeProvider.notifier).state = true;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Browse sample data',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading skeleton
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSkeleton(AppPalette colors) {
    Widget shimmer({double width = double.infinity, double height = 16, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.highlightFaint,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        shimmer(width: 180, height: 22),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: Row(
            children: [
              shimmer(width: 160, height: 220, radius: 16),
              const SizedBox(width: 12),
              shimmer(width: 160, height: 220, radius: 16),
            ],
          ),
        ),
        const SizedBox(height: 28),
        shimmer(width: 160, height: 22),
        const SizedBox(height: 14),
        shimmer(height: 180, radius: 16),
        const SizedBox(height: 28),
        shimmer(width: 140, height: 22),
        const SizedBox(height: 14),
        shimmer(height: 80, radius: 14),
        const SizedBox(height: 12),
        shimmer(height: 80, radius: 14),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEntryPhoto(JournalEntry entry, AppPalette colors) {
    final photo = entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    if (photo == null) return const SizedBox.shrink();

    // If storagePath is already a full URL (demo data), use directly
    final url = photo.storagePath.startsWith('http')
        ? photo.storagePath
        : Supabase.instance.client.storage
            .from('entry-media')
            .getPublicUrl(photo.storagePath);

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(color: colors.highlightFaint),
    );
  }

  String _entryTitle(JournalEntry entry) {
    final text = entry.content;
    // Use first sentence or first ~40 chars
    final firstSentence = RegExp(r'^[^.!?\n]+[.!?]?').firstMatch(text)?.group(0);
    if (firstSentence != null && firstSentence.length <= 60) return firstSentence;
    if (text.length <= 40) return text;
    return '${text.substring(0, 40)}...';
  }

  List<Color> _moodGradient(String? mood) {
    switch (mood) {
      case 'great':
        return [const Color(0xFF10B981), const Color(0xFF34D399)];
      case 'good':
        return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)];
      case 'okay':
        return [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
      case 'low':
        return [const Color(0xFFF97316), const Color(0xFFFB923C)];
      case 'tough':
        return [const Color(0xFFEF4444), const Color(0xFFF87171)];
      default:
        return [const Color(0xFF6366F1), const Color(0xFF818CF8)];
    }
  }

  String _moodEmoji(String? mood) {
    switch (mood) {
      case 'great':
        return '\u{1F929}'; // star-struck
      case 'good':
        return '\u{1F60A}'; // smiling
      case 'okay':
        return '\u{1F610}'; // neutral
      case 'low':
        return '\u{1F614}'; // pensive
      case 'tough':
        return '\u{1F622}'; // crying
      default:
        return '\u{1F4AD}'; // thought bubble
    }
  }
}
