import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/repositories/reflection_override_repository.dart';
import 'package:deardays/services/ai/feature_picker_service.dart';
import 'package:deardays/services/ai/highlight_service.dart';

/// Unified reflection screen for weekly, monthly, and yearly reviews.
class ReflectionScreen extends ConsumerWidget {
  final ReflectionPeriod period;
  const ReflectionScreen({super.key, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(reflectionEntriesProvider(period));
    final summaryAsync = ref.watch(reflectionSummaryProvider(period));
    final themesAsync = ref.watch(reflectionThemesProvider(period));
    final moodsAsync = ref.watch(reflectionMoodsProvider(period));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: entriesAsync.when(
                data: (entries) => _buildContent(
                  context,
                  ref,
                  colors,
                  entries,
                  summaryAsync.valueOrNull,
                  themesAsync.valueOrNull ?? [],
                  moodsAsync.valueOrNull ?? [],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildContent(
                  context,
                  ref,
                  colors,
                  [],
                  null,
                  [],
                  [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  String get _title => switch (period) {
        ReflectionPeriod.weekly => 'Your Week in Review',
        ReflectionPeriod.monthly => 'Your Month in Review',
        ReflectionPeriod.yearly => 'Your Year in Review',
      };

  String get _dateRange {
    final now = DateTime.now();
    return switch (period) {
      ReflectionPeriod.weekly =>
        '${DateFormat('MMM d').format(now.subtract(const Duration(days: 6)))} – ${DateFormat('MMM d').format(now)}',
      ReflectionPeriod.monthly => DateFormat('MMMM yyyy').format(now),
      ReflectionPeriod.yearly =>
        '${DateFormat('MMM yyyy').format(DateTime(now.year - 1, now.month, now.day))} – ${DateFormat('MMM yyyy').format(now)}',
    };
  }

  Widget _buildHeader(BuildContext context, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.cardBg,
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: colors.textPrimary),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _title,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  _dateRange,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────

  int get _maxHighlights => switch (period) {
        ReflectionPeriod.weekly => 3,
        ReflectionPeriod.monthly => 5,
        ReflectionPeriod.yearly => 10,
      };

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppPalette colors,
    List<JournalEntry> entries,
    String? summary,
    List<String> themes,
    List<Map<String, String>> moods,
  ) {
    if (entries.isEmpty) return _buildEmptyState(context, colors);

    final highlights = HighlightService()
        .extractWeeklyHighlights(entries, maxHighlights: _maxHighlights);

    // Best entry for the hero: the one whose highlight scored highest, with a photo preferred.
    final heroEntry = highlights.isNotEmpty
        ? entries.where((e) => e.id == highlights.first.entryId).firstOrNull ??
            entries.first
        : entries.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ────────────────────────────────────────────────────
          _HeroCard(entry: heroEntry, period: period, dateRange: _dateRange),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                _buildStatsRow(colors, entries, moods),
                const SizedBox(height: 28),

                // AI Summary
                if (summary != null && summary.isNotEmpty) ...[
                  _buildSectionTitle(
                      colors, _summaryLabel, Icons.auto_awesome_rounded),
                  const SizedBox(height: 10),
                  _SummaryCard(summary: summary, colors: colors),
                  const SizedBox(height: 28),
                ],

                // Mood visualization
                _buildSectionTitle(
                    colors, 'Mood Overview', Icons.favorite_rounded),
                const SizedBox(height: 12),
                _buildMoodVisualization(colors, moods),
                const SizedBox(height: 28),

                // Yearly-only: monthly breakdown
                if (period == ReflectionPeriod.yearly) ...[
                  _buildSectionTitle(colors, 'Month by Month',
                      Icons.calendar_month_rounded),
                  const SizedBox(height: 12),
                  _buildMonthlyBreakdown(colors, entries),
                  const SizedBox(height: 28),
                ],

                // Photo highlight cards
                if (highlights.isNotEmpty) ...[
                  _buildSectionTitle(
                      colors, _highlightsLabel, Icons.format_quote_rounded),
                  const SizedBox(height: 12),
                  ...highlights.map((h) => _PhotoHighlightCard(
                        highlight: h,
                        entry: entries
                                .where((e) => e.id == h.entryId)
                                .firstOrNull ??
                            entries.first,
                        allEntries: entries,
                        colors: colors,
                      )),
                  const SizedBox(height: 28),
                ],

                // Themes
                if (themes.isNotEmpty) ...[
                  _buildSectionTitle(
                      colors, _themesLabel, Icons.tag_rounded),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: themes
                        .map((t) => Chip(
                              label: Text(t,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accent,
                                  )),
                              backgroundColor: colors.accent.withAlpha(15),
                              side:
                                  BorderSide(color: colors.accent.withAlpha(30)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Memory section ────────────────────────────────────────
                const SizedBox(height: 28),
                _buildSectionTitle(
                    colors, _memoriesLabel, Icons.photo_library_rounded),
                const SizedBox(height: 12),
                _buildMemorySection(context, ref, colors, entries),
                const SizedBox(height: 28),

                // Yearly: year-in-numbers summary card
                if (period == ReflectionPeriod.yearly)
                  _buildYearInNumbers(colors, entries, moods),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Labels ─────────────────────────────────────────────────────────────────

  String get _summaryLabel => switch (period) {
        ReflectionPeriod.weekly => 'Weekly Summary',
        ReflectionPeriod.monthly => 'Monthly Reflection',
        ReflectionPeriod.yearly => 'Your Year in Words',
      };

  String get _highlightsLabel => switch (period) {
        ReflectionPeriod.weekly => 'Key Moments',
        ReflectionPeriod.monthly => 'Best Moments',
        ReflectionPeriod.yearly => 'Top Moments of the Year',
      };

  String get _themesLabel => switch (period) {
        ReflectionPeriod.weekly => "This Week's Themes",
        ReflectionPeriod.monthly => "This Month's Themes",
        ReflectionPeriod.yearly => 'Themes of Your Year',
      };

  String get _memoriesLabel => switch (period) {
        ReflectionPeriod.weekly => "This Week's Memories",
        ReflectionPeriod.monthly => 'Moments of the Month',
        ReflectionPeriod.yearly => 'Your Year in Photos',
      };

  Widget _buildMemorySection(
    BuildContext context,
    WidgetRef ref,
    AppPalette colors,
    List<JournalEntry> entries,
  ) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return switch (period) {
      ReflectionPeriod.weekly => _WeeklyMemoryStrip(
          entries: entries,
          colors: colors,
        ),
      ReflectionPeriod.monthly => _MonthlyWeekCards(
          entries: entries,
          colors: colors,
          year: now.year,
          month: now.month,
        ),
      ReflectionPeriod.yearly => _YearlyPhotoMosaic(
          entries: entries,
          colors: colors,
          year: now.year,
        ),
    };
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(
    AppPalette colors,
    List<JournalEntry> entries,
    List<Map<String, String>> moods,
  ) {
    final moodCounts = <String, int>{};
    for (final m in moods) {
      final mood = m['mood'] ?? 'okay';
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }
    String topMood = 'okay';
    int topCount = 0;
    for (final e in moodCounts.entries) {
      if (e.value > topCount) {
        topCount = e.value;
        topMood = e.key;
      }
    }
    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.wordCount);

    final stats = <_StatData>[
      _StatData('${entries.length}', 'Entries', Icons.edit_note_rounded),
      _StatData(_formatNumber(totalWords), 'Words', Icons.text_fields_rounded),
      _StatData(_moodEmoji(topMood), 'Top Mood', Icons.mood_rounded),
    ];

    if (period != ReflectionPeriod.weekly) {
      final activeDays = entries.map((e) {
        final d = e.entryDate;
        return DateTime(d.year, d.month, d.day);
      }).toSet().length;
      stats.add(
          _StatData('$activeDays', 'Active\nDays', Icons.calendar_today_rounded));
    }

    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _buildStatCardWidget(colors, stats[i])),
        ],
      ],
    );
  }

  Widget _buildStatCardWidget(AppPalette colors, _StatData stat) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            stat.value,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mood visualization ─────────────────────────────────────────────────────

  Widget _buildMoodVisualization(
      AppPalette colors, List<Map<String, String>> moods) {
    if (period == ReflectionPeriod.weekly) {
      return _buildWeeklyMoodChart(colors, moods);
    } else if (period == ReflectionPeriod.monthly) {
      return _buildMonthlyMoodGrid(colors, moods);
    } else {
      return _buildYearlyMoodSummary(colors, moods);
    }
  }

  Widget _buildWeeklyMoodChart(
      AppPalette colors, List<Map<String, String>> moods) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          final dayMoods = moods.where((m) {
            final mDate = DateTime.tryParse(m['date'] ?? '');
            return mDate != null &&
                mDate.year == date.year &&
                mDate.month == date.month &&
                mDate.day == date.day;
          });
          final mood = dayMoods.isNotEmpty ? dayMoods.first['mood'] : null;
          final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return Column(
            children: [
              Text(
                mood != null ? _moodEmoji(mood) : '•',
                style: TextStyle(
                  fontSize: mood != null ? 22 : 14,
                  color: mood != null ? null : colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                days[(date.weekday - 1) % 7],
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMonthlyMoodGrid(
      AppPalette colors, List<Map<String, String>> moods) {
    final now = DateTime.now();
    const daysInRange = 30;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(d,
                            style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(5, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (col) {
                  final dayIndex = row * 7 + col;
                  if (dayIndex >= daysInRange) {
                    return const SizedBox(width: 32, height: 32);
                  }
                  final date = now
                      .subtract(Duration(days: daysInRange - 1 - dayIndex));
                  final dayMood = moods.where((m) {
                    final mDate = DateTime.tryParse(m['date'] ?? '');
                    return mDate != null &&
                        mDate.year == date.year &&
                        mDate.month == date.month &&
                        mDate.day == date.day;
                  });
                  final mood =
                      dayMood.isNotEmpty ? dayMood.first['mood'] : null;
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: mood != null
                          ? _moodColor(mood).withAlpha(60)
                          : colors.highlightFaint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        mood != null ? _moodEmoji(mood) : '${date.day}',
                        style: TextStyle(
                          fontSize: mood != null ? 16 : 9,
                          color: mood != null ? null : colors.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendChip(colors, 'Great', const Color(0xFF10B981)),
              _buildLegendChip(colors, 'Good', const Color(0xFF3B82F6)),
              _buildLegendChip(colors, 'Okay', const Color(0xFFF59E0B)),
              _buildLegendChip(colors, 'Low', const Color(0xFFF97316)),
              _buildLegendChip(colors, 'Tough', const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip(AppPalette colors, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildYearlyMoodSummary(
      AppPalette colors, List<Map<String, String>> moods) {
    final counts = <String, int>{
      'great': 0,
      'good': 0,
      'okay': 0,
      'low': 0,
      'tough': 0,
    };
    for (final m in moods) {
      final mood = m['mood'] ?? 'okay';
      counts[mood] = (counts[mood] ?? 0) + 1;
    }
    final total = moods.isEmpty ? 1 : moods.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: counts.entries.map((e) {
          final pct = (e.value / total * 100).round();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child:
                      Text(_moodEmoji(e.key), style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    _moodLabel(e.key),
                    style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / total,
                      backgroundColor: colors.highlightFaint,
                      valueColor:
                          AlwaysStoppedAnimation(_moodColor(e.key)),
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Monthly breakdown (yearly only) ────────────────────────────────────────

  Widget _buildMonthlyBreakdown(AppPalette colors, List<JournalEntry> entries) {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 11; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: months.map((month) {
          final count = entries
              .where((e) =>
                  e.entryDate.year == month.year &&
                  e.entryDate.month == month.month)
              .length;
          final maxCount =
              entries.isEmpty ? 1 : entries.length / 12 * 2.5;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    DateFormat('MMM').format(month),
                    style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (count / maxCount).clamp(0.0, 1.0),
                      backgroundColor: colors.highlightFaint,
                      valueColor: AlwaysStoppedAnimation(colors.accent),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Year in numbers ────────────────────────────────────────────────────────

  Widget _buildYearInNumbers(
    AppPalette colors,
    List<JournalEntry> entries,
    List<Map<String, String>> moods,
  ) {
    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.wordCount);
    final activeDays = entries.map((e) {
      final d = e.entryDate;
      return DateTime(d.year, d.month, d.day);
    }).toSet().length;

    final sortedDays = entries.map((e) {
      final d = e.entryDate;
      return DateTime(d.year, d.month, d.day);
    }).toSet().toList()
      ..sort();
    int longestStreak = 0;
    int current = 1;
    for (int i = 1; i < sortedDays.length; i++) {
      if (sortedDays[i].difference(sortedDays[i - 1]).inDays == 1) {
        current++;
      } else {
        if (current > longestStreak) longestStreak = current;
        current = 1;
      }
    }
    if (current > longestStreak) longestStreak = current;

    final monthCounts = <int, int>{};
    for (final e in entries) {
      final key = e.entryDate.month;
      monthCounts[key] = (monthCounts[key] ?? 0) + 1;
    }
    String bestMonth = '—';
    if (monthCounts.isNotEmpty) {
      final topMonth =
          monthCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      bestMonth = DateFormat('MMMM').format(DateTime(2026, topMonth));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withAlpha(20),
            colors.accent.withAlpha(8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                'Your Year in Numbers',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildNumberRow(colors, '${entries.length}', 'memories captured'),
          _buildNumberRow(colors, _formatNumber(totalWords), 'words written'),
          _buildNumberRow(colors, '$activeDays', 'active days'),
          _buildNumberRow(colors, '$longestStreak', 'day longest streak'),
          _buildNumberRow(colors, bestMonth, 'most active month'),
        ],
      ),
    );
  }

  Widget _buildNumberRow(AppPalette colors, String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.accent,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                  fontSize: 14, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(AppPalette colors, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, AppPalette colors) {
    final message = switch (period) {
      ReflectionPeriod.weekly => 'No entries this week yet',
      ReflectionPeriod.monthly => 'No entries this month yet',
      ReflectionPeriod.yearly => 'No entries this year yet',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 48, color: colors.textMuted.withAlpha(80)),
          const SizedBox(height: 16),
          Text(message,
              style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary)),
          const SizedBox(height: 8),
          Text('Start journaling to see your reflection',
              style: GoogleFonts.manrope(
                  fontSize: 13, color: colors.textMuted)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/write'),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
                boxShadow: [
                  BoxShadow(
                      color: colors.accent.withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child:
                  const Icon(Icons.add_rounded, size: 28, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _moodEmoji(String? mood) => switch (mood) {
        'great' => '😍',
        'good' => '😊',
        'okay' => '😐',
        'low' => '😔',
        'tough' => '😢',
        _ => '😐',
      };

  String _moodLabel(String mood) => switch (mood) {
        'great' => 'Great',
        'good' => 'Good',
        'okay' => 'Okay',
        'low' => 'Low',
        'tough' => 'Tough',
        _ => mood,
      };

  Color _moodColor(String mood) => switch (mood) {
        'great' => const Color(0xFF10B981),
        'good' => const Color(0xFF3B82F6),
        'okay' => const Color(0xFFF59E0B),
        'low' => const Color(0xFFF97316),
        'tough' => const Color(0xFFEF4444),
        _ => const Color(0xFFF59E0B),
      };

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
// Full-bleed photo (or gradient fallback) with the reflection title overlaid.

class _HeroCard extends ConsumerWidget {
  final JournalEntry entry;
  final ReflectionPeriod period;
  final String dateRange;

  const _HeroCard({
    required this.entry,
    required this.period,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo =
        entry.media.where((m) => m.mediaType == 'photo').firstOrNull;

    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: photo or gradient
          if (photo != null)
            _SignedPhoto(storagePath: photo.storagePath)
          else
            _MoodGradient(mood: entry.mood),

          // Dark overlay for text legibility
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.4, 1.0],
              ),
            ),
          ),

          // Period label + date
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(60)),
                  ),
                  child: Text(
                    switch (period) {
                      ReflectionPeriod.weekly => 'WEEKLY REFLECTION',
                      ReflectionPeriod.monthly => 'MONTHLY REFLECTION',
                      ReflectionPeriod.yearly => 'YEARLY REFLECTION',
                    },
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateRange,
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo highlight card ───────────────────────────────────────────────────────
// Shows a photo strip at the top when the entry has media; gradient fallback
// based on mood color when it doesn't.

class _PhotoHighlightCard extends ConsumerWidget {
  final Highlight highlight;
  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final AppPalette colors;

  const _PhotoHighlightCard({
    required this.highlight,
    required this.entry,
    required this.allEntries,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo =
        entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    final hasPhoto = photo != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () {
          final idx = allEntries.indexOf(entry);
          context.push('/memory',
              extra: MemoryDetailArgs(
                  entry: entry, allEntries: allEntries, initialIndex: idx));
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                  color: colors.textPrimary.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo / gradient top strip ──────────────────────────────
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPhoto)
                      _SignedPhoto(storagePath: photo.storagePath)
                    else
                      _MoodGradient(mood: entry.mood),

                    // Subtle bottom fade to blend into card body
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              colors.cardBg.withAlpha(220),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Highlight type badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(100),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              highlight.type == HighlightType.insight
                                  ? Icons.lightbulb_outline_rounded
                                  : highlight.type == HighlightType.emotion
                                      ? Icons.favorite_border_rounded
                                      : Icons.auto_awesome_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              highlight.type == HighlightType.insight
                                  ? 'INSIGHT'
                                  : highlight.type == HighlightType.emotion
                                      ? 'FEELING'
                                      : 'MOMENT',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Quote + date ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u201C${highlight.text}\u201D',
                      style: GoogleFonts.newsreader(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: colors.textPrimary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12, color: colors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('EEEE, MMM d')
                              .format(highlight.entryDate),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: colors.textMuted,
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
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String summary;
  final AppPalette colors;
  const _SummaryCard({required this.summary, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withAlpha(25)),
      ),
      child: Text(
        summary,
        style: GoogleFonts.newsreader(
          fontSize: 15,
          color: colors.textPrimary,
          height: 1.65,
        ),
      ),
    );
  }
}

// ── Signed photo widget ───────────────────────────────────────────────────────
// Uses getSignedUrl (async) for private-bucket paths, same as MemoryDetailScreen.

class _SignedPhoto extends ConsumerWidget {
  final String storagePath;
  const _SignedPhoto({required this.storagePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Paths that are already absolute URLs (e.g. legacy public-bucket entries)
    // can be used directly without signing.
    if (storagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: storagePath,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        placeholder: (_, __) => const _MoodGradient(mood: null),
        errorWidget: (_, __, ___) => const _MoodGradient(mood: null),
      );
    }

    final mediaService = ref.watch(mediaServiceProvider);
    return FutureBuilder<String>(
      future: mediaService.getSignedUrl(storagePath),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const _MoodGradient(mood: null);
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          placeholder: (_, __) => const ColoredBox(color: Color(0xFF1A1A2E)),
          errorWidget: (_, __, ___) => const _MoodGradient(mood: null),
        );
      },
    );
  }
}

// ── Mood gradient fallback ────────────────────────────────────────────────────

class _MoodGradient extends StatelessWidget {
  final String? mood;
  const _MoodGradient({required this.mood});

  @override
  Widget build(BuildContext context) {
    final (start, end) = switch (mood) {
      'great' => (const Color(0xFF065F46), const Color(0xFF10B981)),
      'good' => (const Color(0xFF1E3A5F), const Color(0xFF3B82F6)),
      'okay' => (const Color(0xFF78350F), const Color(0xFFF59E0B)),
      'low' => (const Color(0xFF7C2D12), const Color(0xFFF97316)),
      'tough' => (const Color(0xFF7F1D1D), const Color(0xFFEF4444)),
      _ => (const Color(0xFF1A1A2E), const Color(0xFF2D3561)),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
    );
  }
}

class _StatData {
  final String value;
  final String label;
  final IconData icon;
  const _StatData(this.value, this.label, this.icon);
}

// ═════════════════════════════════════════════════════════════════════════════
// WEEKLY MEMORY STRIP — horizontal scroll of compact chips
// ═════════════════════════════════════════════════════════════════════════════

class _WeeklyMemoryStrip extends StatelessWidget {
  final List<JournalEntry> entries;
  final AppPalette colors;
  const _WeeklyMemoryStrip({required this.entries, required this.colors});

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            _MemoryChip(entry: sorted[i], allEntries: sorted, colors: colors),
      ),
    );
  }
}

class _MemoryChip extends ConsumerWidget {
  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final AppPalette colors;
  const _MemoryChip(
      {required this.entry,
      required this.allEntries,
      required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo =
        entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    final preview = entry.content.length > 40
        ? '${entry.content.substring(0, 40)}…'
        : entry.content;

    return GestureDetector(
      onTap: () {
        final idx = allEntries.indexOf(entry);
        context.push('/memory',
            extra: MemoryDetailArgs(
                entry: entry, allEntries: allEntries, initialIndex: idx));
      },
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo or gradient top
            SizedBox(
              height: 56,
              child: photo != null
                  ? _SignedPhoto(storagePath: photo.storagePath)
                  : _MoodGradient(mood: entry.mood),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 0),
              child: Text(
                DateFormat('EEE d').format(entry.entryDate),
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 2, 7, 0),
              child: Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 8,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MONTHLY WEEK CARDS — one featured card per week of the month, with swap
// ═════════════════════════════════════════════════════════════════════════════

class _MonthlyWeekCards extends ConsumerWidget {
  final List<JournalEntry> entries;
  final AppPalette colors;
  final int year;
  final int month;
  const _MonthlyWeekCards({
    required this.entries,
    required this.colors,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(reflectionOverrideRepositoryProvider);
    final grouped = FeaturePickerService.groupByWeekOfMonth(entries);
    final weeks = grouped.keys.toList()..sort();

    return Column(
      children: weeks.map((week) {
        final weekEntries = grouped[week]!;
        final overrideKey =
            ReflectionOverrideRepository.monthlyKey(year, month, week);
        final overrideId = overrides.get(overrideKey);
        final featured = overrideId != null
            ? weekEntries.where((e) => e.id == overrideId).firstOrNull ??
                FeaturePickerService().pick(weekEntries)
            : FeaturePickerService().pick(weekEntries);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _FeaturedWeekCard(
            weekLabel: FeaturePickerService.weekLabel(year, month, week),
            entryCount: weekEntries.length,
            featured: featured,
            allInWeek: weekEntries,
            allEntries: entries,
            overrideKey: overrideKey,
            colors: colors,
          ),
        );
      }).toList(),
    );
  }
}

class _FeaturedWeekCard extends ConsumerWidget {
  final String weekLabel;
  final int entryCount;
  final JournalEntry featured;
  final List<JournalEntry> allInWeek;
  final List<JournalEntry> allEntries;
  final String overrideKey;
  final AppPalette colors;

  const _FeaturedWeekCard({
    required this.weekLabel,
    required this.entryCount,
    required this.featured,
    required this.allInWeek,
    required this.allEntries,
    required this.overrideKey,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo =
        featured.media.where((m) => m.mediaType == 'photo').firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week header row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                weekLabel.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        ),
        // Card
        GestureDetector(
          onTap: () {
            final idx = allEntries.indexOf(featured);
            context.push('/memory',
                extra: MemoryDetailArgs(
                    entry: featured,
                    allEntries: allEntries,
                    initialIndex: idx));
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo strip with ⟳ change button
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photo != null
                          ? _SignedPhoto(storagePath: photo.storagePath)
                          : _MoodGradient(mood: featured.mood),
                      // ⟳ Change button — only show if week has >1 entry
                      if (allInWeek.length > 1)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _showSwapSheet(
                                context, ref, allInWeek, overrideKey),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.swap_horiz_rounded,
                                      size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Change',
                                      style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(featured.entryDate),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        featured.content.length > 100
                            ? '${featured.content.substring(0, 100)}…'
                            : featured.content,
                        style: GoogleFonts.newsreader(
                          fontSize: 13,
                          color: colors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSwapSheet(BuildContext context, WidgetRef ref,
      List<JournalEntry> candidates, String key) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SwapBottomSheet(
        candidates: candidates,
        overrideKey: key,
        colors: colors,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// YEARLY PHOTO MOSAIC — 3-column grid of month tiles
// ═════════════════════════════════════════════════════════════════════════════

class _YearlyPhotoMosaic extends ConsumerWidget {
  final List<JournalEntry> entries;
  final AppPalette colors;
  final int year;
  const _YearlyPhotoMosaic(
      {required this.entries, required this.colors, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(reflectionOverrideRepositoryProvider);
    final grouped = FeaturePickerService.groupByMonth(entries);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: 12,
      itemBuilder: (context, i) {
        final month = i + 1;
        final monthEntries = grouped[month] ?? [];
        final overrideKey = ReflectionOverrideRepository.yearlyKey(year, month);
        final overrideId = overrides.get(overrideKey);
        final featured = monthEntries.isEmpty
            ? null
            : overrideId != null
                ? monthEntries
                        .where((e) => e.id == overrideId)
                        .firstOrNull ??
                    FeaturePickerService().pick(monthEntries)
                : FeaturePickerService().pick(monthEntries);

        return _MonthTile(
          month: month,
          year: year,
          entryCount: monthEntries.length,
          featured: featured,
          allInMonth: monthEntries,
          allEntries: entries,
          overrideKey: overrideKey,
          colors: colors,
        );
      },
    );
  }
}

class _MonthTile extends ConsumerWidget {
  final int month;
  final int year;
  final int entryCount;
  final JournalEntry? featured;
  final List<JournalEntry> allInMonth;
  final List<JournalEntry> allEntries;
  final String overrideKey;
  final AppPalette colors;

  const _MonthTile({
    required this.month,
    required this.year,
    required this.entryCount,
    required this.featured,
    required this.allInMonth,
    required this.allEntries,
    required this.overrideKey,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = featured?.media
        .where((m) => m.mediaType == 'photo')
        .firstOrNull;
    final isEmpty = entryCount == 0;

    return GestureDetector(
      onTap: isEmpty
          ? null
          : () {
              final idx = allEntries.indexOf(featured!);
              context.push('/memory',
                  extra: MemoryDetailArgs(
                      entry: featured!,
                      allEntries: allEntries,
                      initialIndex: idx));
            },
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isEmpty ? colors.border : colors.accent.withAlpha(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Photo / gradient / empty top
                Expanded(
                  child: isEmpty
                      ? Container(color: colors.highlightFaint)
                      : photo != null
                          ? _SignedPhoto(storagePath: photo.storagePath)
                          : _MoodGradient(mood: featured?.mood),
                ),
                // Month name + count
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FeaturePickerService.shortMonthLabel(month),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isEmpty
                              ? colors.textMuted
                              : colors.textPrimary,
                        ),
                      ),
                      Text(
                        isEmpty ? 'No entries' : '$entryCount mem.',
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ⟳ Change — only when month has >1 entry
            if (allInMonth.length > 1)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _SwapBottomSheet(
                      candidates: allInMonth,
                      overrideKey: overrideKey,
                      colors: colors,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(110),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        size: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SWAP BOTTOM SHEET — pick a different featured entry
// ═════════════════════════════════════════════════════════════════════════════

class _SwapBottomSheet extends ConsumerWidget {
  final List<JournalEntry> candidates;
  final String overrideKey;
  final AppPalette colors;

  const _SwapBottomSheet({
    required this.candidates,
    required this.overrideKey,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...candidates]
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Choose Featured Memory',
            style: GoogleFonts.newsreader(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          Text(
            'Tap any memory to feature it on your reflection.',
            style: GoogleFonts.manrope(
                fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...sorted.map((entry) {
            final photo = entry.media
                .where((m) => m.mediaType == 'photo')
                .firstOrNull;
            return GestureDetector(
              onTap: () async {
                await ref
                    .read(reflectionOverrideRepositoryProvider)
                    .set(overrideKey, entry.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: photo != null
                            ? _SignedPhoto(storagePath: photo.storagePath)
                            : _MoodGradient(mood: entry.mood),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEE, MMM d').format(entry.entryDate),
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.content.length > 70
                                ? '${entry.content.substring(0, 70)}…'
                                : entry.content,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
