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

/// Weekly reflection report screen showing mood trends, highlights,
/// and key moments from the past week.
class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final entriesAsync = ref.watch(weeklyEntriesProvider);
    final summaryAsync = ref.watch(weeklySummaryProvider);
    final themesAsync = ref.watch(weeklyThemesProvider);
    final moodsAsync = ref.watch(weeklyMoodsProvider);

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

  Widget _buildHeader(BuildContext context, AppPalette colors) {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));
    final dateRange =
        '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(now)}';

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
                  'Your Week in Review',
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  dateRange,
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

  Widget _buildContent(
    BuildContext context,
    AppPalette colors,
    List<JournalEntry> entries,
    String? summary,
    List<String> themes,
    List<Map<String, String>> moods,
  ) {
    if (entries.isEmpty) {
      return _buildEmptyState(context, colors);
    }

    final highlights =
        HighlightService().extractWeeklyHighlights(entries, maxHighlights: 3);

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
            _buildSectionHeader(colors, 'Weekly Summary',
                Icons.auto_awesome_rounded),
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

          // Mood chart
          _buildSectionHeader(
              colors, 'Mood This Week', Icons.favorite_rounded),
          const SizedBox(height: 12),
          _buildMoodChart(colors, moods),
          const SizedBox(height: 24),

          // Highlights
          if (highlights.isNotEmpty) ...[
            _buildSectionHeader(
                colors, 'Key Moments', Icons.format_quote_rounded),
            const SizedBox(height: 12),
            ...highlights.map((h) => _buildHighlightCard(context, colors, h, entries)),
            const SizedBox(height: 24),
          ],

          // Themes
          if (themes.isNotEmpty) ...[
            _buildSectionHeader(
                colors, 'This Week\'s Themes', Icons.tag_rounded),
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
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    AppPalette colors,
    List<JournalEntry> entries,
    List<Map<String, String>> moods,
  ) {
    // Calculate dominant mood
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

    final totalWords =
        entries.fold<int>(0, (sum, e) => sum + e.wordCount);

    return Row(
      children: [
        _buildStatCard(colors, '${entries.length}', 'Entries',
            Icons.edit_note_rounded),
        const SizedBox(width: 10),
        _buildStatCard(
            colors, '$totalWords', 'Words', Icons.text_fields_rounded),
        const SizedBox(width: 10),
        _buildStatCard(
            colors, _moodEmoji(topMood), 'Top Mood', Icons.mood_rounded),
      ],
    );
  }

  Widget _buildStatCard(
      AppPalette colors, String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
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

  Widget _buildMoodChart(
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
          final mood =
              dayMoods.isNotEmpty ? dayMoods.first['mood'] : null;

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

  Widget _buildSectionHeader(
      AppPalette colors, String title, IconData icon) {
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 48, color: colors.textMuted.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'No entries this week yet',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start journaling to see your weekly reflection',
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

  String _moodEmoji(String? mood) {
    switch (mood) {
      case 'great':
        return '\u{1F60D}';
      case 'good':
        return '\u{1F60A}';
      case 'okay':
        return '\u{1F610}';
      case 'low':
        return '\u{1F614}';
      case 'tough':
        return '\u{1F622}';
      default:
        return '\u{1F610}';
    }
  }
}
