import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/story/data/models/life_story.dart';
import 'package:deardays/features/story/presentation/providers/story_provider.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final ReflectionPeriod period;
  const StoryViewerScreen({super.key, this.period = ReflectionPeriod.weekly});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late ReflectionPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = widget.period;
    _triggerIfNeeded(_period);
  }

  void _triggerIfNeeded(ReflectionPeriod p) {
    final s = ref.read(storyFamilyProvider(p));
    if (s.status == StoryStatus.ready) {
      Future.microtask(() async {
        try {
          await ref.read(storyFamilyProvider(p).notifier).generateStory();
        } catch (e, st) {
          debugPrint('[StoryViewer] Failed to load story: $e\n$st');
        }
      });
    }
  }

  void _selectPeriod(ReflectionPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    _triggerIfNeeded(p);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyFamilyProvider(_period));
    final colors = AppColors.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: switch (state.status) {
            StoryStatus.generating => _buildLoading(state, colors),
            StoryStatus.available when state.story != null =>
              _buildPage(state.story!, colors),
            StoryStatus.notEnoughData => _buildNotEnoughData(state, colors),
            _ => _buildError(state, colors),
          },
        ),
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────────

  Widget _buildLoading(StoryState state, AppPalette colors) {
    return Column(
      children: [
        _topBar(colors),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Preparing your story…',
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gathering your memories',
                    style: GoogleFonts.manrope(
                        fontSize: 13, color: colors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: state.progress,
                      backgroundColor: colors.border,
                      color: colors.accent,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────

  Widget _buildError(StoryState state, AppPalette colors) {
    return Column(
      children: [
        _topBar(colors),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 40, color: colors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'Something went wrong',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => ref
                        .read(storyFamilyProvider(_period).notifier)
                        .generateStory(),
                    child: Text(
                      'Try again',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Not enough data ──────────────────────────────────────────────────────────

  Widget _buildNotEnoughData(StoryState state, AppPalette colors) {
    final needed = state.entriesNeeded;
    return Column(
      children: [
        _topBar(colors),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 40, color: colors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Write $needed more ${needed == 1 ? 'entry' : 'entries'}\nto unlock your story',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => context.push('/write'),
                    child: Text(
                      'Start writing →',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Main page ────────────────────────────────────────────────────────────────

  Widget _buildPage(LifeStory story, AppPalette colors) {
    return Column(
      children: [
        _topBar(colors, story: story),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(story, colors),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNarrative(story, colors),
                      const SizedBox(height: 28),
                      _buildHighlight(story, colors),
                      const SizedBox(height: 28),
                      _buildInsights(story, colors),
                      if (_period == ReflectionPeriod.monthly) ...[
                        const SizedBox(height: 28),
                        _buildWeekBars(story, colors),
                      ],
                      if (_period == ReflectionPeriod.yearly) ...[
                        const SizedBox(height: 28),
                        _buildMonthChart(story, colors),
                      ],
                      if (story.entries.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildMemoryFilmstrip(story, colors),
                      ],
                      const SizedBox(height: 36),
                      _buildQuote(story, colors),
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

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _topBar(AppPalette colors, {LifeStory? story}) {
    final dateRange = story != null
        ? '${DateFormat('MMM d').format(story.startDate)} – ${DateFormat('MMM d, yyyy').format(story.endDate)}'
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: colors.textPrimary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your Highlights',
                      style: GoogleFonts.newsreader(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (dateRange != null)
                      Text(
                        dateRange,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Period switcher tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              _periodTab('Day',   ReflectionPeriod.daily,   colors),
              const SizedBox(width: 8),
              _periodTab('Week',  ReflectionPeriod.weekly,  colors),
              const SizedBox(width: 8),
              _periodTab('Month', ReflectionPeriod.monthly, colors),
              const SizedBox(width: 8),
              _periodTab('Year',  ReflectionPeriod.yearly,  colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodTab(String label, ReflectionPeriod p, AppPalette colors) {
    final selected = _period == p;
    return GestureDetector(
      onTap: () => _selectPeriod(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────────

  Widget _buildHero(LifeStory story, AppPalette colors) {
    final dateRange =
        '${DateFormat('MMM d').format(story.startDate)} – ${DateFormat('MMM d, yyyy').format(story.endDate)}';
    final title = switch (_period) {
      ReflectionPeriod.daily   => 'Your Day',
      ReflectionPeriod.weekly  => 'Your Week',
      ReflectionPeriod.monthly => 'Your Month',
      ReflectionPeriod.yearly  => 'Your Year',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [colors.accent.withAlpha(22), colors.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 22, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.newsreader(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: colors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateRange,
            style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          // Inline stat row
          Row(
            children: [
              _statPill('${story.totalEntries}',
                  story.totalEntries == 1 ? 'memory' : 'memories', colors),
              _statDot(colors),
              _statPill('${story.voiceEntries}', 'voice', colors),
              _statDot(colors),
              _statPill('${story.textEntries}', 'written', colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label, AppPalette colors) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: value,
          style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.accent),
        ),
        TextSpan(
          text: ' $label',
          style: GoogleFonts.manrope(fontSize: 13, color: colors.textMuted),
        ),
      ]),
    );
  }

  Widget _statDot(AppPalette colors) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.textMuted.withAlpha(80),
          ),
        ),
      );

  // ── Narrative ────────────────────────────────────────────────────────────────

  Widget _buildNarrative(LifeStory story, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('STORY', colors),
        const SizedBox(height: 10),
        Text(
          story.narrative,
          style: GoogleFonts.newsreader(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: colors.textPrimary,
            height: 1.75,
          ),
        ),
      ],
    );
  }

  // ── Highlight ────────────────────────────────────────────────────────────────

  Widget _buildHighlight(LifeStory story, AppPalette colors) {
    final dateStr = story.highlightDate != null
        ? DateFormat('EEEE, MMM d').format(story.highlightDate!)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('HIGHLIGHT', colors),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.accent, colors.accent.withAlpha(190)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Colors.white.withAlpha(180)),
              const SizedBox(height: 12),
              Text(
                story.highlightTitle,
                style: GoogleFonts.newsreader(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: GoogleFonts.manrope(
                      fontSize: 12, color: Colors.white.withAlpha(180)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Insights ─────────────────────────────────────────────────────────────────

  Widget _buildInsights(LifeStory story, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('INSIGHTS', colors),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _insightTile(
                Icons.sentiment_satisfied_rounded,
                'Mood',
                _moodEmoji(story.topMood),
                _moodColor(story.topMood),
                colors,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _insightTile(
                Icons.tag_rounded,
                'Theme',
                story.topTheme,
                colors.accent,
                colors,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _insightTile(
                Icons.schedule_rounded,
                'Peak Time',
                story.mostActiveTime,
                AppColors.moodLow,
                colors,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _insightTile(
                Icons.local_fire_department_rounded,
                'Streak',
                '${story.writingStreak} ${story.writingStreak == 1 ? 'day' : 'days'}',
                AppColors.moodTough,
                colors,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _insightTile(
      IconData icon, String label, String value, Color color, AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ── Week bars (monthly only) ──────────────────────────────────────────────────

  Widget _buildWeekBars(LifeStory story, AppPalette colors) {
    final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
    for (final e in story.entries) {
      final week = ((e.entryDate.day - 1) ~/ 7 + 1).clamp(1, 4);
      counts[week] = (counts[week] ?? 0) + 1;
    }
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
    if (maxCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('WEEK BY WEEK', colors),
        const SizedBox(height: 12),
        ...counts.entries.map((e) {
          final frac = e.value / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    'Week ${e.key}',
                    style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      backgroundColor: colors.cardBg,
                      color: colors.accent.withAlpha(160),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  child: Text(
                    '${e.value}',
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
        }),
      ],
    );
  }

  // ── Month chart (yearly only) ─────────────────────────────────────────────────

  Widget _buildMonthChart(LifeStory story, AppPalette colors) {
    final counts = <int, int>{};
    for (final e in story.entries) {
      final m = e.entryDate.month;
      counts[m] = (counts[m] ?? 0) + 1;
    }
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
    if (maxCount == 0) return const SizedBox.shrink();

    const labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('MONTH BY MONTH', colors),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (i) {
              final m = i + 1;
              final count = counts[m] ?? 0;
              final frac = count / maxCount;
              final isActive = count > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 4 + (40 * frac),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.accent.withAlpha(180)
                              : colors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          color: isActive ? colors.accent : colors.textMuted,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
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

  // ── Memory filmstrip ──────────────────────────────────────────────────────────

  Widget _buildMemoryFilmstrip(LifeStory story, AppPalette colors) {
    if (story.entries.isEmpty) return const SizedBox.shrink();
    return switch (_period) {
      ReflectionPeriod.daily   => _buildWeeklyFilmstrip(story, colors),
      ReflectionPeriod.weekly  => _buildWeeklyFilmstrip(story, colors),
      ReflectionPeriod.monthly => _buildMonthlyFilmstrip(story, colors),
      ReflectionPeriod.yearly  => _buildYearlyFilmstrip(story, colors),
    };
  }

  // Weekly: horizontal scrollable chips, one per entry, improved size
  Widget _buildWeeklyFilmstrip(LifeStory story, AppPalette colors) {
    final entries = story.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('MEMORIES', colors),
        const SizedBox(height: 10),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) => _MemoryChip(
              entry: entries[i],
              allEntries: entries,
              dateLabel: DateFormat('EEE d').format(entries[i].entryDate),
              colors: colors,
            ),
          ),
        ),
      ],
    );
  }

  // Monthly: 4 week columns, best entry per week
  Widget _buildMonthlyFilmstrip(LifeStory story, AppPalette colors) {
    final entries = story.entries;
    // Group entries by week-of-month (1–4)
    final byWeek = <int, List<JournalEntry>>{1: [], 2: [], 3: [], 4: []};
    for (final e in entries) {
      final week = ((e.entryDate.day - 1) ~/ 7 + 1).clamp(1, 4);
      byWeek[week]!.add(e);
    }
    // Pick best (highest sentiment) per week
    JournalEntry? bestInWeek(List<JournalEntry> list) {
      if (list.isEmpty) return null;
      return list.reduce((a, b) =>
          (a.sentimentScore ?? 0) >= (b.sentimentScore ?? 0) ? a : b);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('MEMORIES', colors),
        const SizedBox(height: 10),
        Row(
          children: List.generate(4, (i) {
            final week = i + 1;
            final best = bestInWeek(byWeek[week]!);
            final count = byWeek[week]!.length;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 8.0 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'W$week',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (best != null)
                      GestureDetector(
                        onTap: () => context.push('/memory',
                            extra: MemoryDetailArgs(
                                entry: best,
                                allEntries: entries,
                                initialIndex: entries.indexOf(best))),
                        child: _MonthWeekCell(
                          entry: best,
                          count: count,
                          colors: colors,
                        ),
                      )
                    else
                      _MonthWeekEmpty(colors: colors),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // Yearly: 2 rows × 6 columns, best entry per month, no scroll needed
  Widget _buildYearlyFilmstrip(LifeStory story, AppPalette colors) {
    final entries = story.entries;
    // Best entry per month
    final byMonth = <int, JournalEntry>{};
    for (final e in entries) {
      final m = e.entryDate.month;
      final existing = byMonth[m];
      if (existing == null ||
          (e.sentimentScore ?? 0) > (existing.sentimentScore ?? 0)) {
        byMonth[m] = e;
      }
    }

    const labels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    Widget monthCell(int month) {
      final entry = byMonth[month];
      return GestureDetector(
        onTap: entry == null
            ? null
            : () => context.push('/memory',
                extra: MemoryDetailArgs(
                    entry: entry,
                    allEntries: entries,
                    initialIndex: entries.indexOf(entry))),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: entry != null
                    ? (() {
                        final photo = entry.media
                            .where((m) => m.mediaType == 'photo')
                            .firstOrNull;
                        return photo != null
                            ? _StorySignedPhoto(storagePath: photo.storagePath)
                            : _StoryMoodGradient(mood: entry.mood);
                      })()
                    : Container(
                        decoration: BoxDecoration(
                          color: colors.border.withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[month - 1],
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: entry != null ? FontWeight.w700 : FontWeight.w400,
                color: entry != null ? colors.accent : colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('MEMORIES', colors),
        const SizedBox(height: 10),
        // Row 1: Jan–Jun
        Row(
          children: List.generate(6, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 5 ? 6.0 : 0),
              child: monthCell(i + 1),
            ),
          )),
        ),
        const SizedBox(height: 8),
        // Row 2: Jul–Dec
        Row(
          children: List.generate(6, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 5 ? 6.0 : 0),
              child: monthCell(i + 7),
            ),
          )),
        ),
      ],
    );
  }

  // ── Quote ────────────────────────────────────────────────────────────────────

  Widget _buildQuote(LifeStory story, AppPalette colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(width: 32, height: 1, color: colors.border),
            const SizedBox(height: 24),
            Text(
              story.quote,
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _eyebrow(String label, AppPalette colors) => Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.textMuted,
          letterSpacing: 1.5,
        ),
      );

  String _moodEmoji(String mood) => switch (mood.toLowerCase()) {
        'great' => '😍',
        'good'  => '😊',
        'okay'  => '😐',
        'low'   => '😔',
        'tough' => '😢',
        _       => '😐',
      };

  Color _moodColor(String mood) => switch (mood.toLowerCase()) {
        'great' => AppColors.moodGreat,
        'good'  => AppColors.moodGood,
        'okay'  => AppColors.moodOkay,
        'low'   => AppColors.moodLow,
        'tough' => AppColors.moodTough,
        _       => AppColors.moodOkay,
      };
}

// ── Memory chip (weekly) ──────────────────────────────────────────────────────

class _MemoryChip extends ConsumerWidget {
  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final String dateLabel;
  final AppPalette colors;

  const _MemoryChip({
    required this.entry,
    required this.allEntries,
    required this.dateLabel,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    // Extract a short title/excerpt for the label row
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final excerpt = lines.isNotEmpty ? lines.first.trim() : '';

    return GestureDetector(
      onTap: () {
        final idx = allEntries.indexOf(entry);
        context.push('/memory',
            extra: MemoryDetailArgs(
                entry: entry, allEntries: allEntries, initialIndex: idx));
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed 4:3 photo area — predictable, no aggressive crop
            AspectRatio(
              aspectRatio: 4 / 3,
              child: photo != null
                  ? _StorySignedPhoto(storagePath: photo.storagePath)
                  : _StoryMoodGradient(mood: entry.mood),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                  if (excerpt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      excerpt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: colors.textSecondary,
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
}

// ── Month week cell ───────────────────────────────────────────────────────────

class _MonthWeekCell extends ConsumerWidget {
  final JournalEntry entry;
  final int count;
  final AppPalette colors;

  const _MonthWeekCell({
    required this.entry,
    required this.count,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    final lines = entry.content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final excerpt = lines.isNotEmpty ? lines.first.trim() : '';

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo != null
                    ? _StorySignedPhoto(storagePath: photo.storagePath)
                    : _StoryMoodGradient(mood: entry.mood),
                if (count > 1)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
            child: Text(
              excerpt.isNotEmpty ? excerpt : DateFormat('MMM d').format(entry.entryDate),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month week empty cell ─────────────────────────────────────────────────────

class _MonthWeekEmpty extends StatelessWidget {
  final AppPalette colors;
  const _MonthWeekEmpty({required this.colors});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: colors.border.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withAlpha(60)),
        ),
        child: Center(
          child: Icon(Icons.edit_note_rounded, size: 20, color: colors.textMuted.withAlpha(100)),
        ),
      ),
    );
  }
}

// ── Signed photo ──────────────────────────────────────────────────────────────

class _StorySignedPhoto extends ConsumerWidget {
  final String storagePath;
  const _StorySignedPhoto({required this.storagePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (storagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: storagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => const _StoryMoodGradient(mood: null),
        errorWidget: (_, __, ___) => const _StoryMoodGradient(mood: null),
      );
    }
    if (storagePath.startsWith('/') || storagePath.contains(':\\')) {
      return Image.file(File(storagePath),
          fit: BoxFit.cover, width: double.infinity);
    }
    final mediaService = ref.watch(mediaServiceProvider);
    return FutureBuilder<String>(
      future: mediaService.getSignedUrl(storagePath),
      builder: (context, snap) {
        if (!snap.hasData) return const _StoryMoodGradient(mood: null);
        return CachedNetworkImage(
          imageUrl: snap.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, __) => const _StoryMoodGradient(mood: null),
          errorWidget: (_, __, ___) => const _StoryMoodGradient(mood: null),
        );
      },
    );
  }
}

// ── Mood gradient ─────────────────────────────────────────────────────────────

class _StoryMoodGradient extends StatelessWidget {
  final String? mood;
  const _StoryMoodGradient({required this.mood});

  @override
  Widget build(BuildContext context) {
    final (a, b) = switch (mood?.toLowerCase()) {
      'great' => (const Color(0xFF065F46), const Color(0xFF10B981)),
      'good'  => (const Color(0xFF1E3A5F), const Color(0xFF3B82F6)),
      'okay'  => (const Color(0xFF78350F), const Color(0xFFF59E0B)),
      'low'   => (const Color(0xFF7C2D12), const Color(0xFFF97316)),
      'tough' => (const Color(0xFF7F1D1D), const Color(0xFFEF4444)),
      _       => (const Color(0xFF1A1A2E), const Color(0xFF2D3561)),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
    );
  }
}
