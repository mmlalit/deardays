
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';
import 'package:deardays/features/timeline/presentation/widgets/on_this_day_card.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';

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

const _milestoneCategory = _Category(
  id: 'milestone',
  label: 'Milestones',
  keywords: [
    'birthday', 'anniversary', 'graduation', 'promotion', 'wedding',
    'engaged', 'engagement', 'new job', 'first day', 'moved', 'born',
    'achievement', 'milestone', 'celebrate', 'celebration', 'graduated',
    'promoted', 'got the job', 'passed', 'finished',
  ],
);

String? _detectCategory(JournalEntry entry) {
  final text = entry.content.toLowerCase();
  for (final cat in [_familyCategory, _travelCategory, _milestoneCategory]) {
    for (final kw in cat.keywords) {
      if (text.contains(kw)) return cat.id;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Explore Screen
// ─────────────────────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  // Filter state
  String? _filterMood;
  bool _filterHasPhoto = false;
  DateTimeRange? _filterDateRange;
  bool _showFilters = false;


  bool get _hasActiveFilter =>
      _filterMood != null || _filterHasPhoto || _filterDateRange != null;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Explore', style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/search'),
                  child: SizedBox(width: 44, height: 44, child: Center(child: Icon(Icons.search_rounded, size: 22, color: colors.textSecondary))),
                ),
              ],
            ),
          ),
          if (_showFilters) _buildFilterRow(colors),
          if (_hasActiveFilter && !_showFilters) _buildActiveFiltersBadge(colors),
          Expanded(child: _buildBody(colors)),
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
        final range = await showDateRangePicker(
          initialDateRange: _filterDateRange,
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
        // Filter-only mode
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

  Future<String> _getPhotoUrl(String storagePath) async {
    try {
      if (storagePath.startsWith('http')) return storagePath;
      return await ref.read(mediaServiceProvider).getSignedUrl(storagePath);
    } catch (_) {
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared with me — only shown if user has ever received a share
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSharedWithMeSection(AppPalette colors) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final hasReceived = profile?.hasReceivedShare ?? false;
    if (!hasReceived) return const SizedBox.shrink();

    final itemsAsync = ref.watch(sharedWithMeProvider);
    final unreadCount = itemsAsync.valueOrNull
            ?.where((i) => i.share.viewCount == 0 && i.share.isActive)
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: GestureDetector(
        onTap: () => context.push('/shared-with-me'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accent.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mark_email_unread_rounded, color: colors.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared with me',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      itemsAsync.when(
                        data: (items) {
                          final active = items.where((i) => i.share.isActive).length;
                          return active == 0
                              ? 'No memories shared yet'
                              : '$active memor${active == 1 ? 'y' : 'ies'} shared with you';
                        },
                        loading: () => 'Loading…',
                        error: (_, __) => '',
                      ),
                      style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unreadCount new',
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pending approvals — shown when someone is waiting for Sarah's approval
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPendingApprovalsSection(AppPalette colors) {
    final requestsAsync = ref.watch(pendingShareRequestsProvider);
    final pending = requestsAsync.valueOrNull ?? [];
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GestureDetector(
        onTap: () => context.push('/share-approvals'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pending.length} request${pending.length == 1 ? '' : 's'} waiting',
                      style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    Text(
                      pending.length == 1
                          ? '${pending.first.recipientName} wants to view a memory'
                          : '${pending.first.recipientName} and ${pending.length - 1} other${pending.length - 1 == 1 ? '' : 's'}',
                      style: GoogleFonts.manrope(fontSize: 12, color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mood Summary — last 7 days bar chart
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMoodSummary(List<JournalEntry> entries, AppPalette colors) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = entries.where((e) => !e.entryDate.isBefore(cutoff)).toList();

    final counts = <String, int>{
      'great': 0, 'good': 0, 'okay': 0, 'low': 0, 'tough': 0,
    };
    for (final e in recent) {
      if (e.mood != null && counts.containsKey(e.mood)) {
        counts[e.mood!] = counts[e.mood!]! + 1;
      }
    }
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
    final hasData = maxCount > 0;

    const moodEmojis = {
      'great': '🤩', 'good': '😊', 'okay': '😐', 'low': '😔', 'tough': '😢',
    };
    const moodColors = {
      'great': Color(0xFF10B981),
      'good':  Color(0xFF34D399),
      'okay':  Color(0xFFF59E0B),
      'low':   Color(0xFFF97316),
      'tough': Color(0xFFEF4444),
    };

    final dominant = hasData
        ? counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'How you\'ve been feeling',
                  style: GoogleFonts.newsreader(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (dominant != null)
                  Text(
                    '${moodEmojis[dominant]} Mostly',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: moodColors[dominant],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Start journaling to see your mood patterns here.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.textMuted,
                    height: 1.5,
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: counts.entries.map((entry) {
                  final count = entry.value;
                  final barHeight = count > 0
                      ? (count / maxCount * 48).clamp(4.0, 48.0)
                      : 4.0;
                  final color = moodColors[entry.key]!;
                  return Expanded(
                    child: GestureDetector(
                      onTap: count > 0
                          ? () {
                              HapticFeedback.selectionClick();
                              context.push('/explore/mood/${entry.key}');
                            }
                          : null,
                      child: Column(
                        children: [
                          // Count above bar — hidden when 0
                          SizedBox(
                            height: 16,
                            child: count > 0
                                ? Text(
                                    '$count',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 48,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              height: barHeight,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? color.withAlpha(200)
                                    : colors.highlightFaint,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            moodEmojis[entry.key]!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(List<JournalEntry> entries, AppPalette colors) {
    final recent = entries.take(6).toList();
    final familyEntries = entries
        .where((e) => _detectCategory(e) == 'family')
        .take(8)
        .toList();
    final travelEntries = entries
        .where((e) => _detectCategory(e) == 'travel')
        .take(8)
        .toList();
    final milestoneEntries = entries
        .where((e) => _detectCategory(e) == 'milestone')
        .take(8)
        .toList();
    final onThisDayEntries = ref.watch(onThisDayProvider).valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // ── On This Day ──
        if (onThisDayEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: OnThisDaySection(
              entries: onThisDayEntries,
              colors: colors,
              onEntryTap: (entry) => context.push(
                '/memory',
                extra: MemoryDetailArgs(
                  entry: entry,
                  allEntries: onThisDayEntries,
                  initialIndex: onThisDayEntries.indexOf(entry),
                ),
              ),
              photoUrlBuilder: _getPhotoUrl,
            ),
          ),

        // ── Your Highlights (week / month / year) ──
        _buildHighlightsSection(entries, colors),

        // ── Mood Summary ──
        _buildMoodSummary(entries, colors),

        // ── Recent Memories (always shown) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Recent Memories', colors),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Text(
              'Your memories will appear here once you start journaling.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textMuted,
                height: 1.5,
              ),
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCompactEntryCard(recent[i], colors),
          ),
          const SizedBox(height: 28),
        ],

        // ── Shared with me + Pending approvals (social/actionable) ──
        _buildSharedWithMeSection(colors),
        _buildPendingApprovalsSection(colors),

        // ── Happiest Memories — featured + mixed pool ──
        _buildHappiestSection(entries, colors),

        // ── Family Moments ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Family Moments', colors,
              onSeeAll: familyEntries.isNotEmpty ? () {
                context.push('/explore/see-all/${SeeAllSection.family.name}');
              } : null),
        ),
        if (familyEntries.isEmpty)
          _buildCategoryTeaser(
            colors: colors,
            icon: Icons.family_restroom_rounded,
            message: 'Write about family moments — they\'ll show up here.',
          )
        else ...[
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: familyEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(familyEntries[i], colors),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ── Travel Stories ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Travel Stories', colors,
              onSeeAll: travelEntries.isNotEmpty ? () {
                context.push('/explore/see-all/${SeeAllSection.travel.name}');
              } : null),
        ),
        if (travelEntries.isEmpty)
          _buildCategoryTeaser(
            colors: colors,
            icon: Icons.flight_rounded,
            message: 'Log your next trip or adventure — it\'ll live here.',
          )
        else ...[
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: travelEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(travelEntries[i], colors),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ── Milestones ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Milestones', colors),
        ),
        if (milestoneEntries.isEmpty)
          _buildCategoryTeaser(
            colors: colors,
            icon: Icons.star_rounded,
            message: 'Birthdays, promotions, firsts — write about them and they\'ll appear here.',
          )
        else ...[
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: milestoneEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(milestoneEntries[i], colors),
            ),
          ),
          const SizedBox(height: 28),
        ],

      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper — pick happiest entry (photo preferred, then sentiment score)
  // ─────────────────────────────────────────────────────────────────────────

  static JournalEntry? _highestSentimentEntry(List<JournalEntry> pool) {
    if (pool.isEmpty) return null;
    const moodScore = {'great': 4, 'good': 3, 'okay': 2, 'low': 1, 'tough': 0};
    final withPhoto = pool.where((e) => e.media.any((m) => m.mediaType == 'photo')).toList();
    final ranked = (withPhoto.isNotEmpty ? withPhoto : pool).toList();
    ranked.sort((a, b) {
      final sa = a.sentimentScore?.toDouble() ??
          (moodScore[a.mood?.toLowerCase()] ?? 0).toDouble();
      final sb = b.sentimentScore?.toDouble() ??
          (moodScore[b.mood?.toLowerCase()] ?? 0).toDouble();
      return sb.compareTo(sa);
    });
    return ranked.isNotEmpty ? ranked.first : null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Your Highlights section — week / month / year photo cards
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHighlightsSection(List<JournalEntry> entries, AppPalette colors) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month,
        now.day - now.weekday + 1); // ISO Monday
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    final weekEntries = entries.where((e) => !e.entryDate.isBefore(weekStart)).toList();
    final monthEntries = entries.where((e) => !e.entryDate.isBefore(monthStart)).toList();
    final yearEntries = entries.where((e) => !e.entryDate.isBefore(yearStart)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Your Highlights', colors),
        ),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _HighlightCard(
                label: 'This Week',
                icon: Icons.calendar_view_week_rounded,
                entry: _highestSentimentEntry(weekEntries),
                count: weekEntries.length,
                colors: colors,
                photoUrlBuilder: _getPhotoUrl,
                onTap: () => context.push('/story'),
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                label: 'This Month',
                icon: Icons.calendar_month_rounded,
                entry: _highestSentimentEntry(monthEntries),
                count: monthEntries.length,
                colors: colors,
                photoUrlBuilder: _getPhotoUrl,
                onTap: () => context.push('/story'),
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                label: 'This Year',
                icon: Icons.auto_stories_rounded,
                entry: _highestSentimentEntry(yearEntries),
                count: yearEntries.length,
                colors: colors,
                photoUrlBuilder: _getPhotoUrl,
                onTap: () => context.push('/story'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Happiest Memories — featured card + mixed pool row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHappiestSection(List<JournalEntry> entries, AppPalette colors) {
    final allHappy = entries
        .where((e) => e.mood == 'great' || e.mood == 'good')
        .toList();
    if (allHappy.isEmpty) return const SizedBox.shrink();

    final featured = _highestSentimentEntry(allHappy);
    if (featured == null) return const SizedBox.shrink();

    // Build mixed pool: top-2 from each category, then fill with happy entries
    final family = entries
        .where((e) => _detectCategory(e) == 'family' && e.id != featured.id)
        .take(2)
        .toList();
    final travel = entries
        .where((e) => _detectCategory(e) == 'travel' && e.id != featured.id)
        .take(2)
        .toList();
    final milestone = entries
        .where((e) => _detectCategory(e) == 'milestone' && e.id != featured.id)
        .take(2)
        .toList();
    final extra = allHappy.where((e) => e.id != featured.id).take(8).toList();

    final seen = <String>{featured.id};
    final pool = <JournalEntry>[];
    for (final e in [...family, ...travel, ...milestone, ...extra]) {
      if (seen.add(e.id)) pool.add(e);
      if (pool.length >= 8) break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Happiest Memories', colors, onSeeAll: () {
            context.push('/explore/see-all/${SeeAllSection.happiest.name}');
          }),
        ),

        // Featured card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildFeaturedHappyCard(featured, entries, colors),
        ),

        // Pool row
        if (pool.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: pool.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(pool[i], colors),
            ),
          ),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildFeaturedHappyCard(
      JournalEntry entry, List<JournalEntry> allEntries, AppPalette colors) {
    final hasMedia = entry.media.any((m) => m.mediaType == 'photo');
    final dateStr = DateFormat('MMM d, yyyy').format(entry.entryDate);
    final title = _entryTitle(entry);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(
          '/memory',
          extra: MemoryDetailArgs(
            entry: entry,
            allEntries: allEntries,
            initialIndex: allEntries.indexOf(entry),
          ),
        );
      },
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colors.card,
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            if (hasMedia)
              _buildEntryPhoto(entry, colors)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _moodGradient(entry.mood),
                  ),
                ),
              ),

            // Bottom scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(210),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),

            // FEATURED badge (top-left)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 11, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      'FEATURED',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Mood emoji (top-right)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(220),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _moodEmoji(entry.mood),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            // Title + date (bottom)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w500,
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

  Widget _buildCategoryTeaser({
    required AppPalette colors,
    required IconData icon,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textMuted.withAlpha(120)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: colors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
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
            // Image area — FIXED height so all cards are identical regardless of text
            SizedBox(
              height: 140,
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
                      left: 0, right: 0, bottom: 0, height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withAlpha(100)],
                          ),
                        ),
                      ),
                    ),
                    // Mood emoji
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_moodEmoji(entry.mood),
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text area — fixed padding so height is consistent
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 13,
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
  // Compact entry card (used in see-all and filter results)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCompactEntryCard(JournalEntry entry, AppPalette colors) {
    final dateStr = DateFormat('MMM d, yyyy').format(entry.entryDate);
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 120
        ? '${entry.content.substring(0, 120)}...'
        : entry.content;
    final hasPhoto = entry.media.any((m) => m.mediaType == 'photo');

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
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo thumbnail (or mood-colored placeholder)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: hasPhoto
                      ? _buildEntryPhoto(entry, colors)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _moodGradient(entry.mood),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _moodEmoji(entry.mood),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _moodEmoji(entry.mood),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.newsreader(
                              fontSize: 15,
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
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.55,
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
              'Start journaling and DearDays will organize your happiest moments, family stories, and adventures.',
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
    if (photo.storagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photo.storagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 400,
        memCacheHeight: 400,
        errorWidget: (_, __, ___) => Container(color: colors.highlightFaint),
      );
    }

    return FutureBuilder<String>(
      future: ref.read(mediaServiceProvider).getSignedUrl(photo.storagePath).catchError((_) => ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return Container(color: colors.highlightFaint);
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 400,
          memCacheHeight: 400,
          errorWidget: (_, __, ___) => Container(color: colors.highlightFaint),
        );
      },
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

// ─────────────────────────────────────────────────────────────────────────────
// Highlight card — full-bleed photo for week/month/year
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final JournalEntry? entry;
  final int count;
  final AppPalette colors;
  final Future<String> Function(String path) photoUrlBuilder;
  final VoidCallback onTap;

  const _HighlightCard({
    required this.label,
    required this.icon,
    required this.entry,
    required this.count,
    required this.colors,
    required this.photoUrlBuilder,
    required this.onTap,
  });

  @override
  State<_HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<_HighlightCard> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final entry = widget.entry;
    if (entry == null) return;
    final photo = entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    if (photo == null) return;
    try {
      final url = photo.storagePath.startsWith('http')
          ? photo.storagePath
          : await widget.photoUrlBuilder(photo.storagePath);
      if (mounted) setState(() { _photoUrl = url; });
    } catch (_) {
      // leave _photoUrl null → falls back to gradient
    }
  }

  List<Color> _periodGradient() {
    switch (widget.label) {
      case 'This Week':
        return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
      case 'This Month':
        return [const Color(0xFF0EA5E9), const Color(0xFF2DD4BF)];
      default: // This Year
        return [const Color(0xFFF59E0B), const Color(0xFFEF4444)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: photo or gradient
            if (hasPhoto)
              CachedNetworkImage(
                imageUrl: _photoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 340,
                errorWidget: (_, __, ___) => _gradientBg(),
              )
            else
              _gradientBg(),

            // Bottom scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(190),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Count badge (top-right)
            if (widget.count > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(220),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),

            // Period label + memory count (bottom-left)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.newsreader(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.count == 0
                        ? 'No entries yet'
                        : '${widget.count} ${widget.count == 1 ? 'memory' : 'memories'}',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(200),
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

  Widget _gradientBg() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _periodGradient(),
        ),
      ),
      child: Center(
        child: Icon(widget.icon, size: 40, color: Colors.white.withAlpha(80)),
      ),
    );
  }
}
