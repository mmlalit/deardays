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
  @override
  void initState() {
    super.initState();
    final s = ref.read(storyFamilyProvider(widget.period));
    if (s.status == StoryStatus.ready || s.status == StoryStatus.error) {
      Future.microtask(
          () => ref.read(storyFamilyProvider(widget.period).notifier).generateStory());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyFamilyProvider(widget.period));
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
                    'Crafting your story…',
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reading your memories',
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
                        .read(storyFamilyProvider(widget.period).notifier)
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
                      if (widget.period == ReflectionPeriod.monthly) ...[
                        const SizedBox(height: 28),
                        _buildWeekBars(story, colors),
                      ],
                      if (widget.period == ReflectionPeriod.yearly) ...[
                        const SizedBox(height: 28),
                        _buildMonthChart(story, colors),
                      ],
                      if (story.entries.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildMemoryFilmstrip(story, colors),
                      ],
                      const SizedBox(height: 36),
                      _buildQuote(story, colors),
                      const SizedBox(height: 28),
                      _buildShareButton(colors),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: colors.textPrimary),
          ),
          const Spacer(),
          if (story != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share coming soon!')),
                );
              },
              child: Icon(Icons.ios_share_rounded,
                  size: 20, color: colors.textSecondary),
            ),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────────

  Widget _buildHero(LifeStory story, AppPalette colors) {
    final dateRange =
        '${DateFormat('MMM d').format(story.startDate)} – ${DateFormat('MMM d, yyyy').format(story.endDate)}';
    final title = switch (widget.period) {
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
    final chips = _filmstripEntries(story);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('MEMORIES', colors),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _MemoryChip(
              entry: chips[i],
              allEntries: story.entries,
              period: widget.period,
              colors: colors,
            ),
          ),
        ),
      ],
    );
  }

  List<JournalEntry> _filmstripEntries(LifeStory story) {
    final entries = story.entries;
    return switch (widget.period) {
      ReflectionPeriod.weekly  => entries,
      ReflectionPeriod.monthly => (List.of(entries)
            ..sort((a, b) =>
                (b.sentimentScore ?? 0).compareTo(a.sentimentScore ?? 0)))
          .take(8)
          .toList(),
      ReflectionPeriod.yearly => _bestPerMonth(entries),
    };
  }

  List<JournalEntry> _bestPerMonth(List<JournalEntry> entries) {
    final byMonth = <int, JournalEntry>{};
    for (final e in entries) {
      final m = e.entryDate.month;
      final existing = byMonth[m];
      if (existing == null ||
          (e.sentimentScore ?? 0) > (existing.sentimentScore ?? 0)) {
        byMonth[m] = e;
      }
    }
    return (byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => e.value)
        .toList();
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

  // ── Share button ──────────────────────────────────────────────────────────────

  Widget _buildShareButton(AppPalette colors) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Share coming soon!')),
          );
        },
        icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
        label: Text(
          'Share Your Story',
          style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

// ── Memory chip ───────────────────────────────────────────────────────────────

class _MemoryChip extends ConsumerWidget {
  final JournalEntry entry;
  final List<JournalEntry> allEntries;
  final ReflectionPeriod period;
  final AppPalette colors;

  const _MemoryChip({
    required this.entry,
    required this.allEntries,
    required this.period,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = entry.media.where((m) => m.mediaType == 'photo').firstOrNull;
    final label = period == ReflectionPeriod.yearly
        ? DateFormat('MMM').format(entry.entryDate)
        : DateFormat('EEE d').format(entry.entryDate);

    return GestureDetector(
      onTap: () {
        final idx = allEntries.indexOf(entry);
        context.push('/memory',
            extra: MemoryDetailArgs(
                entry: entry, allEntries: allEntries, initialIndex: idx));
      },
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: photo != null
                  ? _StorySignedPhoto(storagePath: photo.storagePath)
                  : _StoryMoodGradient(mood: entry.mood),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  Text(
                    _moodEmoji(entry.mood),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moodEmoji(String? mood) => switch (mood?.toLowerCase()) {
        'great' => '😍',
        'good'  => '😊',
        'okay'  => '😐',
        'low'   => '😔',
        'tough' => '😢',
        _       => '·',
      };
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
