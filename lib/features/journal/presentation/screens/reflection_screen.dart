import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
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
                  colors,
                  entries,
                  summaryAsync.valueOrNull,
                  themesAsync.valueOrNull ?? [],
                  moodsAsync.valueOrNull ?? [],
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildContent(
                  context,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  String get _title => switch (period) {
        ReflectionPeriod.weekly => 'Your Week in Review',
        ReflectionPeriod.monthly => 'Your Month in Review',
        ReflectionPeriod.yearly => 'Your Year in Review',
      };

  String get _dateRange {
    final now = DateTime.now();
    return switch (period) {
      ReflectionPeriod.weekly => '${DateFormat('MMM d').format(now.subtract(const Duration(days: 6)))} – ${DateFormat('MMM d').format(now)}',
      ReflectionPeriod.monthly => DateFormat('MMMM yyyy').format(now),
      ReflectionPeriod.yearly => '${DateFormat('MMM yyyy').format(DateTime(now.year - 1, now.month, now.day))} – ${DateFormat('MMM yyyy').format(now)}',
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

  // ─────────────────────────────────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────────────────────────────────

  int get _maxHighlights => switch (period) {
        ReflectionPeriod.weekly => 3,
        ReflectionPeriod.monthly => 5,
        ReflectionPeriod.yearly => 10,
      };

  Widget _buildContent(
    BuildContext context,
    AppPalette colors,
    List<JournalEntry> entries,
    String? summary,
    List<String> themes,
    List<Map<String, String>> moods,
  ) {
    if (entries.isEmpty) return _buildEmptyState(context, colors);

    final highlights = HighlightService()
        .extractWeeklyHighlights(entries, maxHighlights: _maxHighlights);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _buildStatsRow(colors, entries, moods),
          const SizedBox(height: 24),

          // AI Summary
          if (summary != null && summary.isNotEmpty) ...[
            _buildSectionTitle(colors, _summaryLabel, Icons.auto_awesome_rounded),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.accent.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.accent.withAlpha(25)),
              ),
              child: Text(
                summary,
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  color: colors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Mood visualization
          _buildSectionTitle(colors, 'Mood Overview', Icons.favorite_rounded),
          const SizedBox(height: 12),
          _buildMoodVisualization(colors, moods),
          const SizedBox(height: 24),

          // Yearly-only: monthly breakdown
          if (period == ReflectionPeriod.yearly) ...[
            _buildSectionTitle(colors, 'Month by Month', Icons.calendar_month_rounded),
            const SizedBox(height: 12),
            _buildMonthlyBreakdown(colors, entries),
            const SizedBox(height: 24),
          ],

          // Highlights
          if (highlights.isNotEmpty) ...[
            _buildSectionTitle(colors, _highlightsLabel, Icons.format_quote_rounded),
            const SizedBox(height: 12),
            ...highlights.map((h) => _buildHighlightCard(context, colors, h, entries)),
            const SizedBox(height: 24),
          ],

          // Themes
          if (themes.isNotEmpty) ...[
            _buildSectionTitle(colors, _themesLabel, Icons.tag_rounded),
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
                        side: BorderSide(color: colors.accent.withAlpha(30)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Yearly: "Your year in numbers" summary card
          if (period == ReflectionPeriod.yearly) ...[
            _buildYearInNumbers(colors, entries, moods),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Labels per period
  // ─────────────────────────────────────────────────────────────────────────

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
        ReflectionPeriod.weekly => 'This Week\'s Themes',
        ReflectionPeriod.monthly => 'This Month\'s Themes',
        ReflectionPeriod.yearly => 'Themes of Your Year',
      };

  // ─────────────────────────────────────────────────────────────────────────
  // Stats row
  // ─────────────────────────────────────────────────────────────────────────

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
      stats.add(_StatData('$activeDays', 'Active\nDays', Icons.calendar_today_rounded));
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

  // ─────────────────────────────────────────────────────────────────────────
  // Mood visualization — adapts to period
  // ─────────────────────────────────────────────────────────────────────────

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

  /// Weekly: 7-day emoji row
  Widget _buildWeeklyMoodChart(
      AppPalette colors, List<Map<String, String>> moods) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

          return Column(
            children: [
              Text(
                mood != null ? _moodEmoji(mood) : '\u{2022}',
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

  /// Monthly: 30-day mood heatmap grid (5 rows x 7 cols ≈ 35 cells)
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
          // Day labels
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
          // Grid
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
                  final date = now.subtract(Duration(days: daysInRange - 1 - dayIndex));
                  final dayMood = moods.where((m) {
                    final mDate = DateTime.tryParse(m['date'] ?? '');
                    return mDate != null &&
                        mDate.year == date.year &&
                        mDate.month == date.month &&
                        mDate.day == date.day;
                  });
                  final mood = dayMood.isNotEmpty ? dayMood.first['mood'] : null;

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
          // Legend
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
                  fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// Yearly: mood distribution bar chart
  Widget _buildYearlyMoodSummary(
      AppPalette colors, List<Map<String, String>> moods) {
    final counts = <String, int>{
      'great': 0, 'good': 0, 'okay': 0, 'low': 0, 'tough': 0,
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
                  child: Text(_moodEmoji(e.key), style: const TextStyle(fontSize: 18)),
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
                      valueColor: AlwaysStoppedAnimation(_moodColor(e.key)),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Yearly: monthly breakdown
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMonthlyBreakdown(AppPalette colors, List<JournalEntry> entries) {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 11; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      months.add(m);
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
          final count = entries.where((e) =>
              e.entryDate.year == month.year &&
              e.entryDate.month == month.month).length;
          final maxCount = entries.isEmpty ? 1 : entries.length / 12 * 2.5;

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

  // ─────────────────────────────────────────────────────────────────────────
  // Yearly: "Your year in numbers" summary card
  // ─────────────────────────────────────────────────────────────────────────

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

    // Find longest streak in the year
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

    // Most journaled month
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
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Highlight card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHighlightCard(BuildContext context, AppPalette colors,
      Highlight highlight, List<JournalEntry> allEntries) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          final entry =
              allEntries.where((e) => e.id == highlight.entryId).firstOrNull;
          if (entry != null) {
            final idx = allEntries.indexOf(entry);
            context.push('/memory',
                extra: MemoryDetailArgs(
                    entry: entry, allEntries: allEntries, initialIndex: idx));
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    highlight.type == HighlightType.insight
                        ? Icons.lightbulb_outline_rounded
                        : highlight.type == HighlightType.emotion
                            ? Icons.favorite_border_rounded
                            : Icons.auto_awesome_rounded,
                    size: 16,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    highlight.type == HighlightType.insight
                        ? 'Insight'
                        : highlight.type == HighlightType.emotion
                            ? 'Feeling'
                            : 'Moment',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '\u201C${highlight.text}\u201D',
                style: GoogleFonts.newsreader(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: colors.textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMM d').format(highlight.entryDate),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────────────────

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
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start journaling to see your reflection',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _moodEmoji(String? mood) => switch (mood) {
        'great' => '\u{1F60D}',
        'good' => '\u{1F60A}',
        'okay' => '\u{1F610}',
        'low' => '\u{1F614}',
        'tough' => '\u{1F622}',
        _ => '\u{1F610}',
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

class _StatData {
  final String value;
  final String label;
  final IconData icon;
  const _StatData(this.value, this.label, this.icon);
}
