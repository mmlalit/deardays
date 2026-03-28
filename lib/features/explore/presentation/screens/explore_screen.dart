
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/core/utils/chapter_visuals.dart';
import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
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

// ── Time window model for past-era blocks ────────────────────────────────
class _TimeWindow {
  final DateTime start;
  final DateTime end;
  final String label;         // "September 2024" or "2023"
  final String relativeLabel; // "2 months ago"
  final int entryCount;

  const _TimeWindow({
    required this.start,
    required this.end,
    required this.label,
    required this.relativeLabel,
    required this.entryCount,
  });
}

// Multi-label category detection — returns ALL matching category ids
Set<String> _detectCategories(JournalEntry entry) {
  final text = entry.content.toLowerCase();
  final result = <String>{};
  for (final cat in [_familyCategory, _travelCategory, _milestoneCategory]) {
    for (final kw in cat.keywords) {
      if (text.contains(kw)) { result.add(cat.id); break; }
    }
  }
  return result;
}

/// H-11: safe mood capitalizer — handles null/empty mood.
String _capitalizeMood(String? mood) {
  if (mood == null || mood.isEmpty) return '';
  return '${mood[0].toUpperCase()}${mood.length > 1 ? mood.substring(1) : ''}';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check before completing so we know if this is the first visit
      final alreadyComplete = ref
          .read(onboardingProvider)
          .checklistTasks
          .where((t) => t.id == 'explore_themes')
          .firstOrNull
          ?.isCompleted ?? false;

      ref.read(onboardingProvider.notifier).completeTask('explore_themes');

      // If opened from the Getting Started checklist (has a previous route on the
      // stack) and this is the first completion, pop back to HOME after a brief
      // delay so the user sees the checklist item tick off.
      if (!alreadyComplete && context.canPop()) {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted && context.canPop()) context.pop();
        });
      }
    });
  }

  // Filter state
  String? _filterMood;
  bool _filterHasPhoto = false;
  DateTimeRange? _filterDateRange;
  final bool _showFilters = false;

  // ── Memoized multi-label category map — only recomputes when entries change ──
  Map<String, Set<String>>? _categoryCache;
  List<JournalEntry>? _lastCategorizedEntries;

  Map<String, Set<String>> _getCategories(List<JournalEntry> entries) {
    if (_categoryCache != null && identical(_lastCategorizedEntries, entries)) {
      return _categoryCache!;
    }
    _lastCategorizedEntries = entries;
    _categoryCache = {};
    for (final entry in entries) {
      _categoryCache![entry.id] = _detectCategories(entry);
    }
    return _categoryCache!;
  }

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
            // Mood chip — BEFORE photo chip
            _buildMoodChip(colors),
            const SizedBox(width: 8),
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

  Widget _buildMoodChip(AppPalette colors) {
    final selected = _filterMood != null;
    final label = selected ? '${_moodEmoji(_filterMood)} ${_capitalizeMood(_filterMood)}' : '😊 Mood';
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showMoodFilterSheet(colors);
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

  void _showMoodFilterSheet(AppPalette colors) {
    const moods = ['great', 'good', 'okay', 'low', 'tough'];
    const moodLabels = {
      'great': '🤩 Great', 'good': '😊 Good', 'okay': '😐 Okay',
      'low': '😔 Low', 'tough': '😢 Tough',
    };
    const moodColors = {
      'great': Color(0xFF10B981), 'good': Color(0xFF3B82F6),
      'okay': Color(0xFFF59E0B), 'low': Color(0xFFF97316),
      'tough': Color(0xFFEF4444),
    };
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
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
              Text('Filter by Mood', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () { setState(() => _filterMood = null); Navigator.pop(context); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _filterMood == null ? colors.accent : colors.cardBg,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: _filterMood == null ? colors.accent : colors.border),
                      ),
                      child: Text('All', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600,
                        color: _filterMood == null ? Colors.white : colors.textSecondary)),
                    ),
                  ),
                  ...moods.map((mood) {
                    final isActive = _filterMood == mood;
                    final c = moodColors[mood]!;
                    return GestureDetector(
                      onTap: () { setState(() => _filterMood = mood); Navigator.pop(context); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? c : colors.cardBg,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: isActive ? c : colors.border),
                        ),
                        child: Text(moodLabels[mood]!, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : colors.textSecondary)),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
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
              const Icon(Icons.chevron_right_rounded, color: Colors.orange),
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
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    const moodScore = {'great': 5, 'good': 4, 'okay': 3, 'low': 2, 'tough': 1};
    const moodColors = {
      'great': Color(0xFF10B981), 'good': Color(0xFF34D399),
      'okay': Color(0xFFF59E0B), 'low': Color(0xFFF97316),
      'tough': Color(0xFFEF4444),
    };
    const moodEmojis = {
      'great': '🤩', 'good': '😊', 'okay': '😐', 'low': '😔', 'tough': '😢',
    };
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final dayEntry = <int, JournalEntry>{};
    for (final e in entries) {
      final ed = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
      for (int i = 0; i < days.length; i++) {
        if (ed == days[i]) {
          final prev = dayEntry[i];
          final curScore = moodScore[e.mood?.toLowerCase()] ?? -1;
          final prevScore = moodScore[prev?.mood?.toLowerCase()] ?? -1;
          if (curScore > prevScore) dayEntry[i] = e;
        }
      }
    }

    final allRecent = entries
        .where((e) => !e.entryDate.isBefore(today.subtract(const Duration(days: 6))))
        .toList();
    final counts = <String, int>{};
    for (final e in allRecent) {
      if (e.mood != null) counts[e.mood!] = (counts[e.mood!] ?? 0) + 1;
    }
    final dominant = counts.isEmpty
        ? null
        : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS WEEK\'S MOOD',
                style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: colors.textMuted, letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              if (dominant != null)
                Text(
                  '${moodEmojis[dominant] ?? ''} mostly ${_capitalizeMood(dominant)}',
                  style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: moodColors[dominant] ?? colors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final entry = dayEntry[i];
              final mood = entry?.mood?.toLowerCase();
              final moodColor = mood != null ? (moodColors[mood] ?? colors.accent) : null;
              final isToday = i == 6;

              return Column(
                children: [
                  // Emoji above dot — only for days that have a mood
                  SizedBox(
                    height: 18,
                    child: mood != null
                        ? Text(moodEmojis[mood] ?? '', style: const TextStyle(fontSize: 13))
                        : null,
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: moodColor?.withAlpha(mood != null ? 220 : 0) ??
                          colors.highlightFaint.withAlpha(80),
                      border: isToday
                          ? Border.all(
                              color: moodColor ?? colors.accent,
                              width: 2,
                            )
                          : mood != null
                              ? null
                              : Border.all(color: colors.border, width: 1),
                      boxShadow: mood != null
                          ? [BoxShadow(color: moodColor!.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2))]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabels[i],
                    style: GoogleFonts.manrope(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: isToday ? colors.accent : colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Overview — main curated feed with global deduplication
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverview(List<JournalEntry> entries, AppPalette colors) {
    // ── Global deduplication ─────────────────────────────────────────────────
    final seen = <String>{};
    List<JournalEntry> claim(Iterable<JournalEntry> candidates, {int limit = 8}) {
      final result = <JournalEntry>[];
      for (final e in candidates) {
        if (seen.add(e.id)) {
          result.add(e);
          if (result.length >= limit) break;
        }
      }
      return result;
    }

    final cats = _getCategories(entries);
    final onThisDayEntries = ref.watch(onThisDayProvider).valueOrNull ?? [];
    // On This Day never deduped — always shown
    for (final e in onThisDayEntries) { seen.add(e.id); }

    // Happiest featured card gets first priority
    final allHappy = entries.where((e) => e.mood == 'great' || e.mood == 'good').toList();
    final featured = _highestSentimentEntry(allHappy);
    if (featured != null) seen.add(featured.id);

    // Recent (top 3 for current block — user scrolls past blocks for more)
    final recent = claim(entries, limit: 3);

    // Category sections
    final familyEntries = claim(entries.where((e) => cats[e.id]?.contains('family') == true));
    final travelEntries = claim(entries.where((e) => cats[e.id]?.contains('travel') == true));
    final milestoneEntries = claim(entries.where((e) => cats[e.id]?.contains('milestone') == true));

    // Happiest pool (after featured, recent, categories)
    final happyPool = <JournalEntry>[];
    if (featured != null && allHappy.isNotEmpty) {
      final family2 = allHappy.where((e) => _detectCategories(e).contains('family') && seen.add(e.id)).take(2).toList();
      final travel2 = allHappy.where((e) => _detectCategories(e).contains('travel') && seen.add(e.id)).take(2).toList();
      final mile2   = allHappy.where((e) => _detectCategories(e).contains('milestone') && seen.add(e.id)).take(2).toList();
      final extra   = allHappy.where((e) => seen.add(e.id)).take(8).toList();
      final poolSeen = <String>{};
      for (final e in [...family2, ...travel2, ...mile2, ...extra]) {
        if (poolSeen.add(e.id)) happyPool.add(e);
        if (happyPool.length >= 8) break;
      }
    }
    // ────────────────────────────────────────────────────────────────────────

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // ── Social (action items — shown first) ──
        _buildSharedWithMeSection(colors),
        _buildPendingApprovalsSection(colors),

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

        // ── Your Highlights ──
        _buildHighlightsSection(entries, colors),

        // ── Featured Chapter Postcard ──
        _buildFeaturedChapterPostcard(entries, colors),

        // ── Memory of the Day ──
        _buildMemoryOfTheDaySection(entries, colors),

        // ── Mood Summary ──
        _buildMoodSummary(entries, colors),

        // ── Recent Memories ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Recent Memories', colors, onSeeAll: () {
            // Switch to Timeline tab (index 2) for full chronological list
            final shell = context.findAncestorStateOfType<State>();
            if (shell != null) context.go('/timeline');
          }),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Text(
              'Your memories will appear here once you start journaling.',
              style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted, height: 1.5),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _buildEditorialEntryCard(recent[i], colors),
                  if (i < recent.length - 1) const SizedBox(height: 36),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],

        // ── Happiest Memories ──
        if (featured != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildSectionHeader('Happiest Memories', colors, onSeeAll: () {
              context.push('/explore/see-all/${SeeAllSection.happiest.name}');
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFeaturedHappyCard(featured, entries, colors),
          ),
          if (happyPool.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: happyPool.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _buildHappyCard(happyPool[i], colors,
                  pool: happyPool,
                  sectionColor: const Color(0xFF10B981),
                  sectionIcon: Icons.favorite_rounded,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],

        // ── Family Moments ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Family Moments', colors,
              onSeeAll: familyEntries.isNotEmpty ? () {
                context.push('/explore/see-all/${SeeAllSection.family.name}');
              } : null),
        ),
        if (familyEntries.isEmpty)
          _buildCategoryTeaser(colors: colors, icon: Icons.family_restroom_rounded,
              message: 'Write about family moments — they\'ll show up here.')
        else ...[
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: familyEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(familyEntries[i], colors,
                pool: familyEntries,
                sectionColor: const Color(0xFFEC4899),
                sectionIcon: Icons.family_restroom_rounded,
              ),
            ),
          ),
          const SizedBox(height: 40),
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
          _buildCategoryTeaser(colors: colors, icon: Icons.flight_rounded,
              message: 'Log your next trip or adventure — it\'ll live here.')
        else ...[
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: travelEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(travelEntries[i], colors,
                pool: travelEntries,
                sectionColor: const Color(0xFFF59E0B),
                sectionIcon: Icons.flight_takeoff_rounded,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],

        // ── Milestones ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Milestones', colors,
              onSeeAll: milestoneEntries.isNotEmpty ? () {
                context.push('/explore/see-all/${SeeAllSection.milestone.name}');
              } : null),
        ),
        if (milestoneEntries.isEmpty)
          _buildCategoryTeaser(colors: colors, icon: Icons.star_rounded,
              message: 'Birthdays, promotions, firsts — write about them and they\'ll appear here.')
        else ...[
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: milestoneEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildHappyCard(milestoneEntries[i], colors,
                pool: milestoneEntries,
                sectionColor: const Color(0xFF8B5CF6),
                sectionIcon: Icons.emoji_events_rounded,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],

        // ═══════════════════════════════════════════════════════════════════
        // PAST BLOCKS — each time window gets its own era section
        // ═══════════════════════════════════════════════════════════════════
        ...() {
          final windows = _buildTimeWindows(entries);
          final chapters =
              ref.watch(chaptersProvider).valueOrNull ?? <Chapter>[];
          final items = <Widget>[];
          for (final window in windows) {
            items.add(_buildBlockSeparator(window, colors));
            items.addAll(_buildPastBlock(window, entries, colors, chapters));
          }
          return items;
        }(),

        // End-of-feed
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Column(
            children: [
              Center(child: Container(width: 1, height: 72,
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [colors.accent.withAlpha(120), Colors.transparent],
                )))),
              const SizedBox(height: 12),
              Center(child: Text(
                'You\'ve explored your whole story',
                style: GoogleFonts.newsreader(fontSize: 14, fontStyle: FontStyle.italic,
                  color: colors.textMuted.withAlpha(120)))),
            ],
          ),
        ),
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
  // Featured Chapter Postcard
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFeaturedChapterPostcard(
      List<JournalEntry> entries, AppPalette colors) {
    final chaptersAsync = ref.watch(chaptersProvider);
    return chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        // Pick the chapter with the most entries
        final chapter =
            chapters.reduce((a, b) => a.entryCount >= b.entryCount ? a : b);
        // Find first photo entry whose date falls inside this chapter
        final photoEntry = entries.firstWhere(
          (e) {
            final d = e.entryDate;
            return e.hasPhoto &&
                !d.isBefore(chapter.startDate) &&
                (chapter.endDate == null || !d.isAfter(chapter.endDate!));
          },
          orElse: () => entries.firstWhere((e) => e.hasPhoto,
              orElse: () => entries.first),
        );
        final accentColor = ChapterVisual.forTitle(chapter.title,
            colorValue: chapter.colorValue).primary;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: _ChapterPostcard(
            chapter: chapter,
            photoEntry: photoEntry.hasPhoto ? photoEntry : null,
            accent: accentColor,
            colors: colors,
            onTap: () =>
                context.push('/book-reader', extra: BookMode.byChapter),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Memory of the Day
  // ─────────────────────────────────────────────────────────────────────────

  JournalEntry? _pickMemoryOfTheDay(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final withPhotos = entries.where((e) => e.hasPhoto).toList();
    final pool = withPhotos.isNotEmpty ? withPhotos : entries;
    return pool[seed % pool.length];
  }

  Widget _buildMemoryOfTheDaySection(
      List<JournalEntry> entries, AppPalette colors) {
    final entry = _pickMemoryOfTheDay(entries);
    if (entry == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: _MemoryOfTheDayCard(
        entry: entry,
        colors: colors,
        getPhotoUrl: _getPhotoUrl,
        onTap: () => context.push(
          '/memory',
          extra: MemoryDetailArgs(entry: entry, allEntries: entries,
              initialIndex: entries.indexOf(entry)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Time-windowed past blocks
  // ─────────────────────────────────────────────────────────────────────────

  List<_TimeWindow> _buildTimeWindows(List<JournalEntry> entries) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    // Only entries BEFORE the current month
    final pastEntries = entries
        .where((e) => e.entryDate.isBefore(currentMonthStart))
        .toList();
    if (pastEntries.isEmpty) return [];

    final cutoffForMonthly = DateTime(now.year - 2, now.month, 1);
    final monthGroups = <String, List<JournalEntry>>{};
    final yearGroups = <int, List<JournalEntry>>{};

    for (final entry in pastEntries) {
      final d = entry.entryDate;
      if (!d.isBefore(cutoffForMonthly)) {
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        monthGroups.putIfAbsent(key, () => []).add(entry);
      } else {
        yearGroups.putIfAbsent(d.year, () => []).add(entry);
      }
    }

    final windows = <_TimeWindow>[];

    // Monthly windows (descending)
    final sortedMonths = monthGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final key in sortedMonths) {
      final group = monthGroups[key]!;
      if (group.length < 3) continue; // skip sparse months
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0);
      final monthsDiff = (now.year - year) * 12 + now.month - month;

      windows.add(_TimeWindow(
        start: start,
        end: end,
        label: DateFormat('MMMM yyyy').format(start),
        relativeLabel:
            monthsDiff == 1 ? '1 month ago' : '$monthsDiff months ago',
        entryCount: group.length,
      ));
    }

    // Yearly windows (descending)
    final sortedYears = yearGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final year in sortedYears) {
      final group = yearGroups[year]!;
      if (group.length < 3) continue;
      final yearsDiff = now.year - year;

      windows.add(_TimeWindow(
        start: DateTime(year, 1, 1),
        end: DateTime(year, 12, 31),
        label: year.toString(),
        relativeLabel: yearsDiff == 1 ? '1 year ago' : '$yearsDiff years ago',
        entryCount: group.length,
      ));
    }

    return windows;
  }

  Widget _buildBlockSeparator(_TimeWindow window, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
              child: Divider(color: colors.border.withAlpha(120), height: 1)),
          const SizedBox(width: 16),
          Column(
            children: [
              Text(
                window.label,
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${window.relativeLabel} · ${window.entryCount} memories',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Divider(color: colors.border.withAlpha(120), height: 1)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  List<Widget> _buildPastBlock(
    _TimeWindow window,
    List<JournalEntry> allEntries,
    AppPalette colors,
    List<Chapter> chapters,
  ) {
    final windowEntries = allEntries
        .where((e) =>
            !e.entryDate.isBefore(window.start) &&
            !e.entryDate.isAfter(window.end))
        .toList();
    if (windowEntries.isEmpty) return [];

    final widgets = <Widget>[];

    // ── Featured chapter for this time window ──
    final matchingChapter = _findChapterForWindow(chapters, window);
    if (matchingChapter != null) {
      final photoEntry = windowEntries.firstWhere(
        (e) => e.hasPhoto,
        orElse: () => windowEntries.first,
      );
      final accentColor = ChapterVisual.forTitle(matchingChapter.title,
              colorValue: matchingChapter.colorValue)
          .primary;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: _ChapterPostcard(
          chapter: matchingChapter,
          photoEntry: photoEntry.hasPhoto ? photoEntry : null,
          accent: accentColor,
          colors: colors,
          onTap: () =>
              context.push('/book-reader', extra: BookMode.byChapter),
        ),
      ));
    }

    // ── Top 3 memories from this window ──
    final topEntries = windowEntries.take(3).toList();
    widgets.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _buildSectionHeader('Memories', colors),
    ));
    widgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (int i = 0; i < topEntries.length; i++) ...[
            _buildEditorialEntryCard(topEntries[i], colors),
            if (i < topEntries.length - 1) const SizedBox(height: 36),
          ],
        ],
      ),
    ));
    widgets.add(const SizedBox(height: 28));

    // ── Category scrolls (only if ≥2 entries per category) ──
    for (final catDef in [
      (
        label: 'Family Moments',
        id: 'family',
        color: const Color(0xFFEC4899),
        icon: Icons.family_restroom_rounded,
      ),
      (
        label: 'Travel Stories',
        id: 'travel',
        color: const Color(0xFFF59E0B),
        icon: Icons.flight_takeoff_rounded,
      ),
      (
        label: 'Milestones',
        id: 'milestone',
        color: const Color(0xFF8B5CF6),
        icon: Icons.emoji_events_rounded,
      ),
    ]) {
      final catEntries = windowEntries
          .where((e) => _detectCategories(e).contains(catDef.id))
          .toList();
      if (catEntries.length < 2) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _buildSectionHeader(catDef.label, colors),
      ));
      widgets.add(SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: catEntries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _buildHappyCard(
            catEntries[i],
            colors,
            pool: catEntries,
            sectionColor: catDef.color,
            sectionIcon: catDef.icon,
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 28));
    }

    return widgets;
  }

  Chapter? _findChapterForWindow(
      List<Chapter> chapters, _TimeWindow window) {
    // Find the chapter whose date range overlaps most with this window
    Chapter? best;
    int bestOverlap = 0;
    for (final ch in chapters) {
      final chEnd = ch.endDate ?? DateTime.now();
      final overlapStart =
          ch.startDate.isAfter(window.start) ? ch.startDate : window.start;
      final overlapEnd = chEnd.isBefore(window.end) ? chEnd : window.end;
      final overlap = overlapEnd.difference(overlapStart).inDays;
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = ch;
      }
    }
    return best;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Your Highlights section — week / month / year photo cards
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHighlightsSection(List<JournalEntry> entries, AppPalette colors) {
    final now = DateTime.now();
    final weekStart  = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart  = DateTime(now.year, 1, 1);

    final weekEntries  = entries.where((e) => !e.entryDate.isBefore(weekStart)).toList();
    final monthEntries = entries.where((e) => !e.entryDate.isBefore(monthStart)).toList();
    final yearEntries  = entries.where((e) => !e.entryDate.isBefore(yearStart)).toList();

    // Date range sublabels
    final weekEnd       = weekStart.add(const Duration(days: 6));
    final weekSubLabel  = '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('d').format(weekEnd)}';
    final monthSubLabel = DateFormat('MMMM yyyy').format(monthStart);
    final yearSubLabel  = '${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSectionHeader('Your Highlights', colors),
        ),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _HighlightCard(
                label: 'This Week',
                sublabel: weekSubLabel,
                period: _HighlightPeriod.week,
                periodStart: weekStart,
                entryDates: weekEntries.map((e) => e.entryDate).toList(),
                count: weekEntries.length,
                colors: colors,
                onTap: () => context.push('/story?period=weekly'),
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                label: 'This Month',
                sublabel: monthSubLabel,
                period: _HighlightPeriod.month,
                periodStart: monthStart,
                entryDates: monthEntries.map((e) => e.entryDate).toList(),
                count: monthEntries.length,
                colors: colors,
                onTap: () => context.push('/story?period=monthly'),
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                label: 'This Year',
                sublabel: yearSubLabel,
                period: _HighlightPeriod.year,
                periodStart: yearStart,
                entryDates: yearEntries.map((e) => e.entryDate).toList(),
                count: yearEntries.length,
                colors: colors,
                onTap: () => context.push('/story?period=yearly'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildFeaturedHappyCard(
      JournalEntry entry, List<JournalEntry> allEntries, AppPalette colors) {
    final hasMedia = entry.media.any((m) => m.mediaType == 'photo');
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 100
        ? '${entry.content.substring(0, 100)}...'
        : entry.content;

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
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colors.textPrimary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-width photo background (or mood gradient if no photo)
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
                child: Center(
                  child: Text(
                    _moodEmoji(entry.mood),
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              ),
            // Bottom gradient scrim — clear top, strong dark bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(20),
                      Colors.black.withAlpha(215),
                    ],
                  ),
                ),
              ),
            ),
            // Text overlay anchored at bottom-left
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDatePill(entry.entryDate, colors),
                  const SizedBox(height: 6),
                  Text(
                    'FEATURED MEMORY',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withAlpha(180),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    excerpt,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.white.withAlpha(160),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Left spine accent
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withAlpha(40), Colors.black.withAlpha(60)],
                  ),
                ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: colors.textMuted,
            letterSpacing: 2.0,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSeeAll();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'See all →',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Date pill helper
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDatePill(DateTime date, AppPalette colors, {Color? accentColor}) {
    final formatted = DateFormat('MMM d · yyyy').format(date).toUpperCase();
    final color = accentColor ?? colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatted,
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mood border color helper
  // ─────────────────────────────────────────────────────────────────────────

  Color _moodBorderColor(String? mood, AppPalette colors) {
    switch (mood) {
      case 'great': return const Color(0xFF10B981);
      case 'good':  return const Color(0xFF3B82F6);
      case 'okay':  return const Color(0xFFF59E0B);
      case 'low':   return const Color(0xFFF97316);
      case 'tough': return const Color(0xFFEF4444);
      default:      return colors.border;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Happiest Memory card (horizontal scroll)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHappyCard(JournalEntry entry, AppPalette colors, {
    List<JournalEntry>? pool,
    Color? sectionColor,
    IconData? sectionIcon,
  }) {
    final title = _entryTitle(entry);
    final hasMedia = entry.media.where((m) => m.mediaType == 'photo').isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final allEntries = pool ?? [entry];
        context.push('/memory', extra: MemoryDetailArgs(
          entry: entry,
          allEntries: allEntries,
          initialIndex: allEntries.indexOf(entry),
        ));
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colors.cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 40,
              offset: const Offset(0, 8),
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
                    // Gradient overlay at bottom (tinted by sectionColor)
                    Positioned(
                      left: 0, right: 0, bottom: 0, height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (sectionColor ?? Colors.black).withAlpha(130),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Section icon badge — top left
                    if (sectionIcon != null)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: (sectionColor ?? colors.accent).withAlpha(220),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(sectionIcon, size: 14, color: Colors.white),
                        ),
                      ),
                    // Mood emoji badge — top right
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_moodEmoji(entry.mood), style: const TextStyle(fontSize: 13)),
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
                  _buildDatePill(entry.entryDate, colors, accentColor: sectionColor),
                  const SizedBox(height: 4),
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
  // Editorial entry cards — used in overview Recent Memories feed
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEditorialEntryCard(JournalEntry entry, AppPalette colors) {
    final hasAudio = entry.media.any((m) => m.mediaType == 'audio');
    final hasPhoto = entry.media.any((m) => m.mediaType == 'photo');
    if (hasAudio && !hasPhoto) return _buildAudioEntryCard(entry, colors);
    if (hasPhoto) return _buildPhotoEditorialCard(entry, colors);
    return _buildTextEditorialCard(entry, colors);
  }

  Widget _buildPhotoEditorialCard(JournalEntry entry, AppPalette colors) {
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 160
        ? '${entry.content.substring(0, 160)}...'
        : entry.content;
    final hasAudio = entry.media.any((m) => m.mediaType == 'audio');

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo bleeds to card top edge
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildEntryPhoto(entry, colors),
                  // Subtle bottom scrim
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withAlpha(60)],
                          stops: const [0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Frosted glass source badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(200),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasAudio ? Icons.mic_rounded : Icons.photo_camera_rounded,
                                size: 11,
                                color: const Color(0xFF1C1917),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasAudio ? 'AUDIO' : 'PHOTO',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1917),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text section — clearly inside the same card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDatePill(entry.entryDate, colors),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  if (excerpt.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: colors.highlightFaint,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border(left: BorderSide(color: colors.accent, width: 3)),
                      ),
                      child: Text(
                        '"$excerpt"',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.newsreader(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: colors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextEditorialCard(JournalEntry entry, AppPalette colors) {
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 180
        ? '${entry.content.substring(0, 180)}...'
        : entry.content;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12), bottomRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
          border: Border(left: BorderSide(color: colors.accent, width: 3)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDatePill(entry.entryDate, colors),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.25,
              ),
            ),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.65,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioEntryCard(JournalEntry entry, AppPalette colors) {
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 120
        ? '${entry.content.substring(0, 120)}...'
        : entry.content;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/memory', extra: entry);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Waveform panel
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [0.0, 0.2, 0.4, 0.1, 0.3, 0.5, 0.15].map((delay) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _AudioWaveBar(color: colors.accent, delay: delay),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 8),
                Text('AUDIO', style: GoogleFonts.manrope(
                  fontSize: 8, fontWeight: FontWeight.w800,
                  color: colors.accent, letterSpacing: 1.5,
                )),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDatePill(entry.entryDate, colors),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Listen to reflection',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.accent.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEntryCard(JournalEntry entry, AppPalette colors) {
    final title = _entryTitle(entry);
    final excerpt = entry.content.length > 160
        ? '${entry.content.substring(0, 160)}...'
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
          border: Border(
            left: BorderSide(
              color: _moodBorderColor(entry.mood, colors),
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDatePill(entry.entryDate, colors),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.newsreader(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
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

    // Use stored focal alignment so faces stay in frame
    final alignment = photo.focalAlignment;

    Widget shimmer() => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.highlightFaint, colors.highlightFaint.withAlpha(50), colors.highlightFaint],
        ),
      ),
    );

    // If storagePath is already a full URL (demo data), use directly
    if (photo.storagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photo.storagePath,
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 400,
        memCacheHeight: 400,
        placeholder: (_, __) => shimmer(),
        errorWidget: (_, __, ___) => shimmer(),
      );
    }

    return FutureBuilder<String>(
      future: ref.read(mediaServiceProvider).getSignedUrl(photo.storagePath).catchError((_) => ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return shimmer();
        if (!snapshot.hasData || snapshot.hasError || snapshot.data!.isEmpty) return shimmer();
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 400,
          memCacheHeight: 400,
          placeholder: (_, __) => shimmer(),
          errorWidget: (_, __, ___) => shimmer(),
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
// Highlight card — thematic gradient for week/month/year
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Highlight card period type
// ─────────────────────────────────────────────────────────────────────────────

enum _HighlightPeriod { week, month, year }

// ─────────────────────────────────────────────────────────────────────────────
// Highlight card — activity dot grid cover (GitHub-style, personal)
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final _HighlightPeriod period;
  final DateTime periodStart;
  final List<DateTime> entryDates;
  final int count;
  final AppPalette colors;
  final VoidCallback onTap;

  const _HighlightCard({
    required this.label,
    required this.sublabel,
    required this.period,
    required this.periodStart,
    required this.entryDates,
    required this.count,
    required this.colors,
    required this.onTap,
  });

  List<Color> get _gradient => switch (period) {
    _HighlightPeriod.week  => [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    _HighlightPeriod.month => [const Color(0xFF0EA5E9), const Color(0xFF2DD4BF)],
    _HighlightPeriod.year  => [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Opacity(
        opacity: count == 0 ? 0.55 : 1.0,
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _gradient.first.withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradient,
                  ),
                ),
              ),

              // Activity dot grid — top section
              Positioned(
                top: 16,
                left: 14,
                right: 14,
                child: _buildDotGrid(),
              ),

              // Bottom scrim for text legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(140)],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Bottom text block
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.newsreader(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(190),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'No entries yet'
                          : '$count ${count == 1 ? 'memory' : 'memories'}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(170),
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

  Widget _buildDotGrid() {
    return switch (period) {
      _HighlightPeriod.week  => _buildWeekGrid(),
      _HighlightPeriod.month => _buildMonthGrid(),
      _HighlightPeriod.year  => _buildYearGrid(),
    };
  }

  /// Week: 7 dots (Mon–Sun) with day-initial labels above.
  Widget _buildWeekGrid() {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final activeDays = entryDates.map((d) => d.weekday).toSet(); // 1=Mon…7=Sun

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Day labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayLabels
              .map((l) => SizedBox(
                    width: 18,
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(130),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 5),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            7,
            (i) => _dot(active: activeDays.contains(i + 1), size: 14),
          ),
        ),
      ],
    );
  }

  /// Month: days-of-month in a 7-column grid (one dot per day).
  Widget _buildMonthGrid() {
    final daysInMonth =
        DateUtils.getDaysInMonth(periodStart.year, periodStart.month);
    final activeDays = entryDates.map((d) => d.day).toSet();

    final allDots = List.generate(
      daysInMonth,
      (i) => _dot(active: activeDays.contains(i + 1), size: 11),
    );

    const cols = 7;
    final rows = <Widget>[];
    for (int i = 0; i < allDots.length; i += cols) {
      final slice = allDots.sublist(i, (i + cols).clamp(0, allDots.length));
      // Pad last row so spaceBetween stays uniform
      final row = [
        ...slice,
        ...List.generate(cols - slice.length,
            (_) => const SizedBox(width: 11, height: 11)),
      ];
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: row,
      ));
      if (i + cols < allDots.length) rows.add(const SizedBox(height: 4));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  /// Year: 52 dots (one per week), in a 13×4 grid.
  Widget _buildYearGrid() {
    const totalWeeks = 52;
    const cols = 13;
    const rows = 4;

    final activeWeeks = <int>{};
    for (final d in entryDates) {
      final offset = d.difference(periodStart).inDays;
      if (offset >= 0) {
        final week = offset ~/ 7;
        if (week < totalWeeks) activeWeeks.add(week);
      }
    }

    final allDots = List.generate(
      totalWeeks,
      (i) => _dot(active: activeWeeks.contains(i), size: 8),
    );

    final rowWidgets = <Widget>[];
    for (int r = 0; r < rows; r++) {
      final start = r * cols;
      final end = (start + cols).clamp(0, totalWeeks);
      rowWidgets.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: allDots.sublist(start, end),
      ));
      if (r < rows - 1) rowWidgets.add(const SizedBox(height: 4));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rowWidgets,
    );
  }

  Widget _dot({required bool active, required double size}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Colors.white.withAlpha(230)
              : Colors.white.withAlpha(40),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated audio waveform bar
// ─────────────────────────────────────────────────────────────────────────────

class _AudioWaveBar extends StatefulWidget {
  final Color color;
  final double delay;
  const _AudioWaveBar({required this.color, required this.delay});
  @override
  State<_AudioWaveBar> createState() => _AudioWaveBarState();
}

class _AudioWaveBarState extends State<_AudioWaveBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 4, end: 20).animate(
      CurvedAnimation(parent: _ctrl, curve: Interval(widget.delay, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 3,
        height: _anim.value,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured Chapter Postcard
// ─────────────────────────────────────────────────────────────────────────────

class _ChapterPostcard extends ConsumerStatefulWidget {
  final Chapter chapter;
  final JournalEntry? photoEntry;
  final Color accent;
  final AppPalette colors;
  final VoidCallback onTap;

  const _ChapterPostcard({
    required this.chapter,
    required this.photoEntry,
    required this.accent,
    required this.colors,
    required this.onTap,
  });

  @override
  ConsumerState<_ChapterPostcard> createState() => _ChapterPostcardState();
}

class _ChapterPostcardState extends ConsumerState<_ChapterPostcard> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final entry = widget.photoEntry;
    if (entry == null) return;
    final photoMedia =
        entry.media.where((m) => m.mediaType == 'photo').toList();
    if (photoMedia.isEmpty) return;
    try {
      final url = await ref
          .read(mediaServiceProvider)
          .getSignedUrl(photoMedia.first.storagePath);
      if (mounted) setState(() => _photoUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final accent = widget.accent;
    // Dark card background — blend accent toward black for a rich feel
    final cardBg = Color.lerp(accent, Colors.black, 0.55) ?? accent;
    const textColor = Colors.white;

    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    // Rich count: "12 memories · 4 photos · 2 voice"
    final countLabel = '${chapter.entryCount} ${chapter.entryCount == 1 ? 'memory' : 'memories'}';

    return Semantics(
      label: 'Featured chapter: ${chapter.title}. $countLabel. Tap to read.',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-bleed photo behind the entire card ────────────────
                if (hasPhoto)
                  CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: (_, __, ___) => _gradientBg(accent, cardBg),
                  )
                else
                  _gradientBg(accent, cardBg),

                // ── Left glass panel: semi-transparent tint over the photo ──
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Glass overlay — photo subtly shows through
                      Expanded(
                        flex: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                cardBg.withAlpha(218), // ~85% opaque left edge
                                cardBg.withAlpha(190), // ~75% opaque centre
                                cardBg.withAlpha(140), // ~55% opaque right edge → blends into photo
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Book spine (left edge)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        accent.withAlpha(220),
                                        accent.withAlpha(90),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Text content
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'FEATURED CHAPTER',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: accent.withAlpha(230),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      chapter.title,
                                      style: GoogleFonts.newsreader(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        height: 1.2,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      countLabel,
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: textColor.withAlpha(180),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Filled Read Story button
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: accent.withAlpha(220),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Read Story',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.auto_stories_rounded,
                                              size: 14, color: textColor),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right side: fully transparent — photo shows through clearly
                      const Expanded(flex: 48, child: SizedBox.shrink()),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientBg(Color accent, Color dark) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [accent.withAlpha(180), dark],
          ),
        ),
      );
}

// ── Memory of the Day card ────────────────────────────────────────────────────

class _MemoryOfTheDayCard extends ConsumerStatefulWidget {
  final JournalEntry entry;
  final AppPalette colors;
  final Future<String> Function(String) getPhotoUrl;
  final VoidCallback onTap;

  const _MemoryOfTheDayCard({
    required this.entry,
    required this.colors,
    required this.getPhotoUrl,
    required this.onTap,
  });

  @override
  ConsumerState<_MemoryOfTheDayCard> createState() =>
      _MemoryOfTheDayCardState();
}

class _MemoryOfTheDayCardState extends ConsumerState<_MemoryOfTheDayCard> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final photo = widget.entry.media
        .where((m) => m.mediaType == 'photo')
        .firstOrNull;
    if (photo == null) return;
    final url = await widget.getPhotoUrl(photo.storagePath);
    if (mounted && url.isNotEmpty) setState(() => _photoUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final entry = widget.entry;
    final hasPhoto = _photoUrl != null;

    final dateLabel = DateFormat('MMMM d, yyyy').format(entry.entryDate);
    final now = DateTime.now();
    final diff = now.difference(entry.entryDate);
    final agoLabel = diff.inDays == 0
        ? 'Today'
        : diff.inDays == 1
            ? 'Yesterday'
            : diff.inDays < 30
                ? '${diff.inDays} days ago'
                : diff.inDays < 365
                    ? '${(diff.inDays / 30).round()} months ago'
                    : '${(diff.inDays / 365).round()} years ago';

    final excerpt = entry.content.trim().replaceAll('\n', ' ');
    final preview = excerpt.length > 100
        ? '${excerpt.substring(0, 100).trimRight()}…'
        : excerpt;

    return Semantics(
      label: 'Memory of the day: $dateLabel. Tap to view.',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eyebrow
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'MEMORY OF THE DAY',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: colors.accent,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Date + ago
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          agoLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Excerpt
                    Text(
                      preview,
                      style: GoogleFonts.newsreader(
                        fontSize: 14,
                        height: 1.55,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // View link
                    Row(
                      children: [
                        Text(
                          'View memory',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 13, color: colors.accent),
                      ],
                    ),
                  ],
                ),
              ),
              // Photo thumbnail
              if (hasPhoto) ...[
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
