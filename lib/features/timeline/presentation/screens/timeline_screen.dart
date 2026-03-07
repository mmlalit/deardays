import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/streak.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  static const _moodToValue = {
    'great': 4,
    'good': 3,
    'okay': 2,
    'low': 1,
    'tough': 0,
  };

  static const _moodColors = [
    AppColors.moodTough,
    AppColors.moodLow,
    AppColors.moodOkay,
    AppColors.moodGood,
    AppColors.moodGreat,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildMoodTrend(ref),
              const SizedBox(height: 24),
              _buildStreakCard(ref),
              const SizedBox(height: 24),
              _buildWeeklySummary(ref),
              const SizedBox(height: 24),
              _buildOnThisDay(ref),
              const SizedBox(height: 24),
              _buildMoodBreakdown(ref),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSIGHTS',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your journaling patterns',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Mood Trend (7-day) ─────────────────────────────────────────────

  Widget _buildMoodTrend(WidgetRef ref) {
    final weeklyMoods = ref.watch(weeklyMoodsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(20)),
      ),
      child: weeklyMoods.when(
        data: (moods) => _buildMoodTrendContent(moods),
        loading: () => _buildLoadingPlaceholder(height: 140),
        error: (_, __) => _buildErrorPlaceholder('Could not load mood data'),
      ),
    );
  }

  Widget _buildMoodTrendContent(List<Map<String, String>> moods) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();

    // Build a map of weekday -> mood value for this week
    final weekMoods = <int, int>{};
    for (final entry in moods) {
      final date = DateTime.parse(entry['date']!);
      final mood = entry['mood']!.toLowerCase();
      weekMoods[date.weekday] = _moodToValue[mood] ?? 2;
    }

    // Determine dominant mood label
    String dominantLabel = 'No data';
    if (moods.isNotEmpty) {
      final moodCounts = <String, int>{};
      for (final m in moods) {
        final mood = m['mood']!;
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
      final top = moodCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      dominantLabel = 'Mostly ${top.key}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mood This Week',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (moods.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.moodGood.withAlpha(31),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dominantLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.moodGood,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (moods.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Start journaling to see your mood trends',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final weekday = i + 1; // Monday=1 ... Sunday=7
                final value = weekMoods[weekday];
                final hasData = value != null;
                final barHeight =
                    hasData ? 20.0 + (value / 4) * 80.0 : 8.0;
                final isToday = weekday == now.weekday;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: hasData
                                ? (isToday
                                    ? _moodColors[value]
                                    : _moodColors[value].withAlpha(128))
                                : AppColors.textMuted.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                            border: isToday && hasData
                                ? Border.all(
                                    color: _moodColors[value], width: 2)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[i],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isToday
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ── Streak Card ────────────────────────────────────────────────────

  Widget _buildStreakCard(WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);

    return streakAsync.when(
      data: (streak) => _buildStreakContent(streak),
      loading: () => _buildLoadingPlaceholder(height: 84),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStreakContent(Streak? streak) {
    final current = streak?.currentStreak ?? 0;
    final longest = streak?.longestStreak ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2A3A), Color(0xFF2A3A4A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(51),
              border: Border.all(
                color: AppColors.primary.withAlpha(128),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$current',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day Streak',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your longest streak: $longest days',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withAlpha(153),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_fire_department,
            color: current > 0 ? AppColors.moodOkay : Colors.white24,
            size: 28,
          ),
        ],
      ),
    );
  }

  // ── Weekly Summary ─────────────────────────────────────────────────

  Widget _buildWeeklySummary(WidgetRef ref) {
    final summaryAsync = ref.watch(weeklySummaryProvider);
    final themesAsync = ref.watch(weeklyThemesProvider);
    final weeklyEntries = ref.watch(weeklyEntriesProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'WEEKLY REFLECTION',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              weeklyEntries.when(
                data: (entries) => Text(
                  '${entries.length} entries',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          summaryAsync.when(
            data: (summary) {
              if (summary == null) {
                return Text(
                  'Journal a few more days this week to unlock your weekly reflection.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                );
              }
              return Text(
                summary,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              );
            },
            loading: () => _buildLoadingPlaceholder(height: 60),
            error: (_, __) => Text(
              'Could not generate summary right now.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          themesAsync.when(
            data: (themes) {
              if (themes.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: themes
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── On This Day ────────────────────────────────────────────────────

  Widget _buildOnThisDay(WidgetRef ref) {
    final onThisDayAsync = ref.watch(onThisDayProvider);

    return onThisDayAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return _buildOnThisDayContent(entries);
      },
      loading: () => _buildLoadingPlaceholder(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOnThisDayContent(List<JournalEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'ON THIS DAY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final year = entry.entryDate.year.toString();
            final moodLabel = entry.mood ?? '';
            final preview = entry.content.length > 120
                ? '${entry.content.substring(0, 120)}...'
                : entry.content;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      year,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                        if (moodLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Feeling $moodLabel',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Mood Breakdown ─────────────────────────────────────────────────

  Widget _buildMoodBreakdown(WidgetRef ref) {
    final statsAsync = ref.watch(monthlyMoodStatsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(20)),
      ),
      child: statsAsync.when(
        data: (stats) => _buildMoodBreakdownContent(stats),
        loading: () => _buildLoadingPlaceholder(height: 120),
        error: (_, __) =>
            _buildErrorPlaceholder('Could not load mood breakdown'),
      ),
    );
  }

  Widget _buildMoodBreakdownContent(Map<String, int> stats) {
    final moodOrder = ['great', 'good', 'okay', 'low', 'tough'];
    final moodLabels = {
      'great': 'Great',
      'good': 'Good',
      'okay': 'Okay',
      'low': 'Low',
      'tough': 'Tough',
    };
    final moodColorMap = {
      'great': AppColors.moodGreat,
      'good': AppColors.moodGood,
      'okay': AppColors.moodOkay,
      'low': AppColors.moodLow,
      'tough': AppColors.moodTough,
    };

    final total = stats.values.fold<int>(0, (sum, v) => sum + v);

    if (total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mood Breakdown',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No mood data in the last 30 days.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood Breakdown',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Last 30 days \u2022 $total entries',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: moodOrder.where((m) => (stats[m] ?? 0) > 0).map((m) {
                final count = stats[m] ?? 0;
                return Expanded(
                  flex: count,
                  child: Container(color: moodColorMap[m]),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        ...moodOrder.map((m) {
          final count = stats[m] ?? 0;
          final pct = total > 0 ? ((count / total) * 100).round() : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: moodColorMap[m],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  moodLabels[m]!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count ($pct%)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────

  Widget _buildLoadingPlaceholder({required double height}) {
    return SizedBox(
      height: height,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primary.withAlpha(128),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
