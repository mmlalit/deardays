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
              _buildHeader(ref),
              const SizedBox(height: 24),
              _buildMoodCurve(ref),
              const SizedBox(height: 20),
              _buildStreakAndStats(ref),
              const SizedBox(height: 20),
              _buildWeeklySummary(ref),
              const SizedBox(height: 20),
              _buildMoodHeatmap(ref),
              const SizedBox(height: 20),
              _buildMoodBreakdown(ref),
              const SizedBox(height: 20),
              _buildOnThisDay(ref),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // -- Header -----------------------------------------------------------

  Widget _buildHeader(WidgetRef ref) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range =
        '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Week in Review',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          range,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // -- Mood Curve (smooth line chart) ------------------------------------

  Widget _buildMoodCurve(WidgetRef ref) {
    final weeklyMoods = ref.watch(weeklyMoodsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(20)),
      ),
      child: weeklyMoods.when(
        data: (moods) => _buildMoodCurveContent(moods),
        loading: () => _buildLoadingPlaceholder(height: 160),
        error: (_, __) => _buildErrorPlaceholder('Could not load mood data'),
      ),
    );
  }

  Widget _buildMoodCurveContent(List<Map<String, String>> moods) {
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
    String dominantLabel = 'No data yet';
    Color dominantColor = AppColors.textMuted;
    if (moods.isNotEmpty) {
      final moodCounts = <String, int>{};
      for (final m in moods) {
        final mood = m['mood']!.toLowerCase();
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
      final top = moodCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      dominantLabel = 'Mostly ${top.key}';
      dominantColor = _moodColors[_moodToValue[top.key] ?? 2];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mood Trend',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: dominantColor.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dominantLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dominantColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (moods.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.show_chart, size: 36, color: AppColors.textMuted.withAlpha(76)),
                  const SizedBox(height: 8),
                  Text(
                    'Start journaling to see your mood trends',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: const Size(double.infinity, 130),
              painter: _MoodCurvePainter(
                weekMoods: weekMoods,
                todayWeekday: now.weekday,
                moodColors: _moodColors,
              ),
            ),
          ),
        if (moods.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final isToday = weekday == now.weekday;
              return SizedBox(
                width: 36,
                child: Text(
                  days[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  // -- Streak + Stats Row ------------------------------------------------

  Widget _buildStreakAndStats(WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final totalAsync = ref.watch(totalEntriesProvider);

    return Row(
      children: [
        // Streak card
        Expanded(
          child: streakAsync.when(
            data: (streak) => _buildStatCard(
              icon: Icons.local_fire_department,
              iconColor: (streak?.currentStreak ?? 0) > 0
                  ? AppColors.moodOkay
                  : AppColors.textMuted,
              value: '${streak?.currentStreak ?? 0}',
              label: 'Day Streak',
              subtitle: 'Best: ${streak?.longestStreak ?? 0}',
            ),
            loading: () => _buildLoadingPlaceholder(height: 100),
            error: (_, __) => _buildStatCard(
              icon: Icons.local_fire_department,
              iconColor: AppColors.textMuted,
              value: '0',
              label: 'Day Streak',
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Total entries card
        Expanded(
          child: totalAsync.when(
            data: (total) => _buildStatCard(
              icon: Icons.auto_stories,
              iconColor: AppColors.primary,
              value: '$total',
              label: 'Total Entries',
            ),
            loading: () => _buildLoadingPlaceholder(height: 100),
            error: (_, __) => _buildStatCard(
              icon: Icons.auto_stories,
              iconColor: AppColors.textMuted,
              value: '0',
              label: 'Total Entries',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: iconColor),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -- Weekly Summary ----------------------------------------------------

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

  // -- Mood Heatmap (GitHub-style contribution graph) --------------------

  Widget _buildMoodHeatmap(WidgetRef ref) {
    final monthlyMoods = ref.watch(monthlyMoodStatsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(20)),
      ),
      child: monthlyMoods.when(
        data: (_) => _buildHeatmapContent(ref),
        loading: () => _buildLoadingPlaceholder(height: 140),
        error: (_, __) => _buildErrorPlaceholder('Could not load heatmap'),
      ),
    );
  }

  Widget _buildHeatmapContent(WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build 30 days of cells
    final cells = <Widget>[];
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      cells.add(_buildHeatmapCell(date, i == 0));
    }

    // Month labels
    final months = <String>{};
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      months.add(DateFormat('MMM').format(date));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Activity',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              'Last 30 days',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: cells,
        ),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            ...[
              AppColors.primary.withAlpha(20),
              AppColors.primary.withAlpha(64),
              AppColors.primary.withAlpha(128),
              AppColors.primary,
            ].map((c) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
            Text(
              'More',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatmapCell(DateTime date, bool isToday) {
    // Simple visual — just show whether a day has activity
    // Since we don't have per-day data easily available here,
    // use a deterministic pattern based on the date for now.
    // In production, this would use actual entry data.
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(3),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
    );
  }

  // -- Mood Breakdown (horizontal bars) ----------------------------------

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
        loading: () => _buildLoadingPlaceholder(height: 180),
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
    final moodIcons = {
      'great': Icons.sentiment_very_satisfied,
      'good': Icons.sentiment_satisfied,
      'okay': Icons.sentiment_neutral,
      'low': Icons.sentiment_dissatisfied,
      'tough': Icons.sentiment_very_dissatisfied,
    };

    final total = stats.values.fold<int>(0, (sum, v) => sum + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mood Breakdown',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (total > 0)
              Text(
                '$total entries',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (total == 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No mood data in the last 30 days.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          ...moodOrder.map((m) {
            final count = stats[m] ?? 0;
            final pct = total > 0 ? (count / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(moodIcons[m], size: 18, color: moodColorMap[m]),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      moodLabels[m]!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            color: AppColors.primary.withAlpha(15),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: moodColorMap[m],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${(pct * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // -- On This Day -------------------------------------------------------

  Widget _buildOnThisDay(WidgetRef ref) {
    final onThisDayAsync = ref.watch(onThisDayProvider);

    return onThisDayAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return _buildOnThisDayContent(entries);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOnThisDayContent(List<JournalEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(13),
            AppColors.primary.withAlpha(8),
          ],
        ),
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
              const Spacer(),
              Text(
                DateFormat('MMM d').format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final yearsAgo = DateTime.now().year - entry.entryDate.year;
            final preview = entry.content.length > 120
                ? '${entry.content.substring(0, 120)}...'
                : entry.content;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$yearsAgo yr${yearsAgo != 1 ? 's' : ''} ago',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
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
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -- Shared widgets ----------------------------------------------------

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

// -- Mood Curve Painter --------------------------------------------------

class _MoodCurvePainter extends CustomPainter {
  final Map<int, int> weekMoods;
  final int todayWeekday;
  final List<Color> moodColors;

  _MoodCurvePainter({
    required this.weekMoods,
    required this.todayWeekday,
    required this.moodColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weekMoods.isEmpty) return;

    final points = <Offset>[];
    final colors = <Color>[];
    final padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - 20;

    // Collect points with data
    for (int day = 1; day <= 7; day++) {
      if (weekMoods.containsKey(day)) {
        final x = padding + ((day - 1) / 6) * chartWidth;
        final y = 10 + (1 - weekMoods[day]! / 4) * chartHeight;
        points.add(Offset(x, y));
        colors.add(moodColors[weekMoods[day]!]);
      }
    }

    if (points.length < 2) {
      // Single point — draw a dot
      if (points.isNotEmpty) {
        final dotPaint = Paint()
          ..color = colors.first
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points.first, 6, dotPaint);
        final ringPaint = Paint()
          ..color = colors.first.withAlpha(51)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points.first, 12, ringPaint);
      }
      return;
    }

    // Draw gradient fill under the curve
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    // Smooth curve through points using cubic bezier
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cpx = (p0.dx + p1.dx) / 2;
      fillPath.cubicTo(cpx, p0.dy, cpx, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withAlpha(38),
          AppColors.primary.withAlpha(5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw the curve line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cpx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cpx, p0.dy, cpx, p1.dy, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw dots
    for (int i = 0; i < points.length; i++) {
      // Outer glow
      final glowPaint = Paint()
        ..color = colors[i].withAlpha(38)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], 8, glowPaint);

      // White ring
      final ringPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], 5, ringPaint);

      // Colored dot
      final dotPaint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodCurvePainter oldDelegate) =>
      weekMoods != oldDelegate.weekMoods ||
      todayWeekday != oldDelegate.todayWeekday;
}
