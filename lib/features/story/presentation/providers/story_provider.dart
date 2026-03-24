import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/config/feature_flags.dart';
import 'package:deardays/core/providers/app_providers.dart';
// ReflectionPeriod is re-exported from app_providers.dart
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/features/book/presentation/providers/life_book_provider.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/story/data/models/life_story.dart';
import 'package:deardays/features/story/data/models/story_node.dart';
import 'package:deardays/features/story/data/models/story_summary.dart';
import 'package:deardays/features/story/data/repositories/story_node_repository.dart';
import 'package:deardays/features/story/data/services/story_generation_service.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/notification/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class HierarchicalBookState {
  /// Which level tab is selected.
  final StoryLevelType selectedLevel;

  /// Cached nodes per level, keyed by StoryNode.id.
  final Map<String, StoryNode> nodes;

  /// Node currently being generated (its id), or null.
  final String? generatingId;

  /// Non-fatal error message to show inline.
  final String? error;

  const HierarchicalBookState({
    this.selectedLevel = StoryLevelType.weekly,
    this.nodes = const {},
    this.generatingId,
    this.error,
  });

  HierarchicalBookState copyWith({
    StoryLevelType? selectedLevel,
    Map<String, StoryNode>? nodes,
    String? generatingId,
    bool clearGenerating = false,
    String? error,
    bool clearError = false,
  }) {
    return HierarchicalBookState(
      selectedLevel: selectedLevel ?? this.selectedLevel,
      nodes: nodes ?? this.nodes,
      generatingId: clearGenerating ? null : (generatingId ?? this.generatingId),
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<StoryNode> nodesForLevel(StoryLevelType level) => nodes.values
      .where((n) => n.level == level)
      .toList()
    ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

  StoryNode? get lifetimeNode => nodes[StoryNode.lifetimeKey];

  bool get isGenerating => generatingId != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class HierarchicalBookNotifier extends StateNotifier<HierarchicalBookState> {
  HierarchicalBookNotifier(this._ref, {this.language})
      : super(const HierarchicalBookState()) {
    _loadCached();
  }

  final Ref _ref;
  final String? language;

  final _repo = StoryNodeRepository();
  final _svc = StoryGenerationService();

  // ── Initial load ────────────────────────────────────────────────────────

  Future<void> _loadCached() async {
    final all = <String, StoryNode>{};
    for (final level in StoryLevelType.values) {
      final nodes = await _repo.getAll(level);
      for (final n in nodes) {
        all[n.id] = n;
      }
    }
    final lifetime = await _repo.get(StoryNode.lifetimeKey);
    if (lifetime != null) all[lifetime.id] = lifetime;

    if (mounted) state = state.copyWith(nodes: all, clearError: true);
  }

  // ── Level selection ──────────────────────────────────────────────────────

  void selectLevel(StoryLevelType level) {
    state = state.copyWith(selectedLevel: level, clearError: true);
  }

  // ── Weekly generation ────────────────────────────────────────────────────

  Future<void> generateWeekly(DateTime weekDate) async {
    if (!FeatureFlags().isEnabledSync(Feature.hierarchicalStories)) {
      state = state.copyWith(error: 'Hierarchical stories are not enabled.');
      return;
    }
    final key = StoryNode.weekKey(weekDate.year, StoryNode.isoWeekNumber(weekDate));
    if (state.generatingId != null) return;

    state = state.copyWith(generatingId: key, clearError: true);

    try {
      final entries = await _entriesForWeek(weekDate);
      // Also pull check-in texts from LifeBook for that week
      final checkInTexts = _lifeBookTextsForWeek(weekDate);
      final entryTexts = _textsFromEntries(entries);
      final allTexts = [...checkInTexts, ...entryTexts];

      if (allTexts.isEmpty) {
        state = state.copyWith(
          clearGenerating: true,
          error: 'No entries found for this week.',
        );
        return;
      }

      final node = await _svc.generateWeekly(
        weekDate,
        allTexts,
        entries: entries,
        language: language,
      );
      _upsertNode(node);
      NotificationService().showStoryReadyNotification(
        period: 'weekly',
        entryCount: entries.length,
        periodDate: weekDate,
      ).ignore();
    } on AiServiceException catch (e) {
      state = state.copyWith(clearGenerating: true, error: e.message);
    } catch (_) {
      state = state.copyWith(
        clearGenerating: true,
        error: 'Generation failed. Please try again.',
      );
    }
  }

  Future<void> regenerateWeekly(DateTime weekDate) async {
    final key = StoryNode.weekKey(weekDate.year, StoryNode.isoWeekNumber(weekDate));
    await _repo.invalidate(key);
    _removeNode(key);
    await generateWeekly(weekDate);
  }

  // ── Monthly generation ───────────────────────────────────────────────────

  Future<void> generateMonthly(int year, int month) async {
    if (!FeatureFlags().isEnabledSync(Feature.hierarchicalStories)) {
      state = state.copyWith(error: 'Hierarchical stories are not enabled.');
      return;
    }
    final key = StoryNode.monthKey(year, month);
    if (state.generatingId != null) return;

    state = state.copyWith(generatingId: key, clearError: true);

    try {
      final allMonthEntries = await _entriesForMonth(year, month);

      final node = await _svc.generateMonthly(
        year,
        month,
        dailyTextsForWeek: (weekDate) async {
          final entries = await _entriesForWeek(weekDate);
          final checkIn = _lifeBookTextsForWeek(weekDate);
          return [...checkIn, ..._textsFromEntries(entries)];
        },
        entriesForWeek: (weekDate) => _entriesForWeek(weekDate),
        allMonthEntries: allMonthEntries,
        language: language,
      );
      _upsertNode(node);
      await _loadCached(); // refresh newly generated weekly nodes
      NotificationService().showStoryReadyNotification(
        period: 'monthly',
        entryCount: allMonthEntries.length,
        periodDate: DateTime(year, month),
      ).ignore();
    } on AiServiceException catch (e) {
      state = state.copyWith(clearGenerating: true, error: e.message);
    } catch (_) {
      state = state.copyWith(
        clearGenerating: true,
        error: 'Generation failed. Please try again.',
      );
    }
  }

  Future<void> regenerateMonthly(int year, int month) async {
    final key = StoryNode.monthKey(year, month);
    await _repo.invalidate(key);
    _removeNode(key);
    await generateMonthly(year, month);
  }

  // ── Yearly generation ────────────────────────────────────────────────────

  Future<void> generateYearly(int year) async {
    if (!FeatureFlags().isEnabledSync(Feature.hierarchicalStories)) {
      state = state.copyWith(error: 'Hierarchical stories are not enabled.');
      return;
    }
    final key = StoryNode.yearKey(year);
    if (state.generatingId != null) return;

    state = state.copyWith(generatingId: key, clearError: true);

    try {
      final allYearEntries = await _entriesForYear(year);
      final node = await _svc.generateYearly(
        year,
        allYearEntries: allYearEntries,
        language: language,
      );
      _upsertNode(node);
      NotificationService().showStoryReadyNotification(
        period: 'yearly',
        entryCount: allYearEntries.length,
        periodDate: DateTime(year),
      ).ignore();
    } on AiServiceException catch (e) {
      state = state.copyWith(clearGenerating: true, error: e.message);
    } catch (_) {
      state = state.copyWith(
        clearGenerating: true,
        error: 'Generation failed. Please try again.',
      );
    }
  }

  Future<void> regenerateYearly(int year) async {
    final key = StoryNode.yearKey(year);
    await _repo.invalidate(key);
    _removeNode(key);
    await generateYearly(year);
  }

  // ── Lifetime generation ──────────────────────────────────────────────────

  Future<void> generateLifetime() async {
    if (!FeatureFlags().isEnabledSync(Feature.hierarchicalStories)) {
      state = state.copyWith(error: 'Hierarchical stories are not enabled.');
      return;
    }
    const key = StoryNode.lifetimeKey;
    if (state.generatingId != null) return;

    state = state.copyWith(generatingId: key, clearError: true);

    try {
      final allEntries =
          await _ref.read(journalRepositoryProvider).getEntries(limit: 1000);

      final node = await _svc.generateLifetime(
        allEntries: allEntries,
        language: language,
      );
      _upsertNode(node);
    } on AiServiceException catch (e) {
      state = state.copyWith(clearGenerating: true, error: e.message);
    } catch (_) {
      state = state.copyWith(
        clearGenerating: true,
        error: 'Generation failed. Please try again.',
      );
    }
  }

  Future<void> regenerateLifetime() async {
    await _repo.invalidate(StoryNode.lifetimeKey);
    _removeNode(StoryNode.lifetimeKey);
    await generateLifetime();
  }

  // ── Data fetching helpers ────────────────────────────────────────────────

  Future<List<JournalEntry>> _entriesForWeek(DateTime weekDate) =>
      _ref.read(journalRepositoryProvider).getEntries(
            startDate: StoryNode.weekStart(weekDate),
            endDate: StoryNode.weekEnd(weekDate),
            limit: 14,
          );

  Future<List<JournalEntry>> _entriesForMonth(int year, int month) =>
      _ref.read(journalRepositoryProvider).getEntries(
            startDate: DateTime(year, month, 1),
            endDate: DateTime(year, month + 1, 0),
            limit: 60,
          );

  Future<List<JournalEntry>> _entriesForYear(int year) =>
      _ref.read(journalRepositoryProvider).getEntries(
            startDate: DateTime(year, 1, 1),
            endDate: DateTime(year, 12, 31),
            limit: 400,
          );

  List<String> _textsFromEntries(List<JournalEntry> entries) => entries
      .map((e) => e.polishedContent ?? e.content)
      .where((t) => t.trim().isNotEmpty)
      .toList();

  /// Polished check-in texts from LifeBook for the given week.
  List<String> _lifeBookTextsForWeek(DateTime weekDate) {
    final start = StoryNode.weekStart(weekDate);
    final end = StoryNode.weekEnd(weekDate);
    final lifeBookState = _ref.read(lifeBookProvider);
    return [
      for (final ch in lifeBookState.chapters)
        for (final e in ch.entries)
          if (!e.date.isBefore(start) && !e.date.isAfter(end))
            if ((e.polishedText ?? e.rawText).trim().isNotEmpty)
              e.polishedText ?? e.rawText,
    ];
  }

  // ── State helpers ────────────────────────────────────────────────────────

  void _upsertNode(StoryNode node) {
    final updated = Map<String, StoryNode>.from(state.nodes)..[node.id] = node;
    state = state.copyWith(nodes: updated, clearGenerating: true);
  }

  void _removeNode(String key) {
    final updated = Map<String, StoryNode>.from(state.nodes)..remove(key);
    state = state.copyWith(nodes: updated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final hierarchicalBookProvider =
    StateNotifierProvider<HierarchicalBookNotifier, HierarchicalBookState>((ref) {
  final language = ref.watch(localeProvider).languageName;
  return HierarchicalBookNotifier(ref, language: language);
});

// ─────────────────────────────────────────────────────────────────────────────
// Legacy StoryNotifier — used by StoryViewerScreen (weekly recap cards)
// ─────────────────────────────────────────────────────────────────────────────

class StoryNotifier extends StateNotifier<StoryState> {
  StoryNotifier(this._ref, {this.period = ReflectionPeriod.weekly})
      : super(const StoryState()) {
    _checkDataAvailability();
  }

  final Ref _ref;
  final ReflectionPeriod period;

  Future<void> _checkDataAvailability() async {
    try {
      final now = DateTime.now();
      final startDate = switch (period) {
        ReflectionPeriod.weekly  => StoryNode.weekStart(now),
        ReflectionPeriod.monthly => DateTime(now.year, now.month, 1),
        ReflectionPeriod.yearly  => DateTime(now.year, 1, 1),
      };
      // Check entries within the actual period, not lifetime total
      final entries = await _ref
          .read(journalRepositoryProvider)
          .getEntries(startDate: startDate, endDate: now, limit: 5);
      if (entries.length >= 3) {
        state = state.copyWith(status: StoryStatus.ready, entriesNeeded: 0);
      } else {
        state = state.copyWith(
          status: StoryStatus.notEnoughData,
          entriesNeeded: 3 - entries.length,
        );
      }
    } catch (_) {
      state = state.copyWith(status: StoryStatus.notEnoughData);
    }
  }

  /// Fetch a pre-computed [StorySummary] from the `story_summaries` table.
  /// Returns null if not available (Supabase unreachable, or no row yet).
  Future<StorySummary?> _fetchServerSummary(DateTime now) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final periodName = period.name; // 'weekly' | 'monthly' | 'yearly'
      final year = now.year;
      final month = period == ReflectionPeriod.weekly ? now.month : null;
      final response = await client.rpc('get_story_summary', params: {
        'p_user_id': client.auth.currentUser?.id,
        'p_period':  periodName,
        'p_year':    year,
        if (month != null) 'p_month': month,
      });
      final rows = response as List<dynamic>?;
      if (rows == null || rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return StorySummary.fromJson({...row, 'period_type': periodName});
    } catch (_) {
      return null; // gracefully degrade to local generation
    }
  }

  Future<void> generateStory() async {
    state = state.copyWith(status: StoryStatus.generating, progress: 0.1);
    try {
      final now = DateTime.now();
      final (startDate, limit) = switch (period) {
        ReflectionPeriod.weekly  => (StoryNode.weekStart(now), 14),
        ReflectionPeriod.monthly => (DateTime(now.year, now.month, 1), 60),
        ReflectionPeriod.yearly  => (DateTime(now.year, 1, 1), 400),
      };

      // Try server-side summary first (zero AI cost).
      final serverSummary = await _fetchServerSummary(now);

      final entries = await _ref
          .read(journalRepositoryProvider)
          .getEntries(startDate: startDate, endDate: now, limit: limit);

      if (entries.isEmpty) {
        state = state.copyWith(
          status: StoryStatus.notEnoughData,
          entriesNeeded: 3,
        );
        return;
      }

      state = state.copyWith(progress: 0.4);

      // ── Top mood — server value preferred; fall back to local count ───────
      final String topMood;
      if (serverSummary?.topMood != null) {
        topMood = serverSummary!.topMood!;
      } else {
        final moodCounts = <String, int>{};
        for (final e in entries) {
          if (e.mood != null) moodCounts[e.mood!] = (moodCounts[e.mood!] ?? 0) + 1;
        }
        topMood = moodCounts.isEmpty
            ? 'okay'
            : (moodCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first.key;
      }

      // ── Top theme — server value preferred; fall back to local count ──────
      final String topTheme;
      if (serverSummary?.topTheme != null) {
        topTheme = serverSummary!.topTheme!;
      } else {
        final tagCounts = <String, int>{};
        for (final t in entries.expand((e) => e.tags)) {
          tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
        topTheme = tagCounts.isEmpty
            ? 'Everyday Life'
            : (tagCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first.key;
      }

      // ── Most active time — computed from actual entry timestamps ──────────
      final hourCounts = <int, int>{};
      for (final e in entries) {
        final h = e.entryTime?.hour;
        if (h != null) hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      }
      String mostActiveTime = 'Evening';
      if (hourCounts.isNotEmpty) {
        final peakHour = (hourCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first.key;
        mostActiveTime = peakHour < 12
            ? 'Morning'
            : peakHour < 17
                ? 'Afternoon'
                : peakHour < 21
                    ? 'Evening'
                    : 'Night';
      }

      // ── Writing streak — consecutive calendar days ────────────────────────
      final writtenDays = entries
          .map((e) => DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day))
          .toSet()
          .toList()
        ..sort();
      int streak = writtenDays.isEmpty ? 0 : 1;
      int maxStreak = streak;
      for (int i = 1; i < writtenDays.length; i++) {
        final diff = writtenDays[i].difference(writtenDays[i - 1]).inDays;
        if (diff == 1) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
        } else {
          streak = 1;
        }
      }

      // ── Highlight entry ───────────────────────────────────────────────────
      final highlight = entries.reduce((a, b) {
        final sa = (a.sentimentScore?.abs() ?? 0) +
            (a.isMilestone ? 0.5 : 0) +
            (a.wordCount / 1000);
        final sb = (b.sentimentScore?.abs() ?? 0) +
            (b.isMilestone ? 0.5 : 0) +
            (b.wordCount / 1000);
        return sa >= sb ? a : b;
      });

      // Use first line of content as title (up to first newline or 60 chars)
      final highlightRaw = highlight.polishedContent ?? highlight.content;
      final firstLine = highlightRaw.split('\n').first.trim();
      final highlightTitle = firstLine.length > 60
          ? '${firstLine.substring(0, 57)}...'
          : firstLine;

      // ── Narrative — use server summary when available; else local join ────
      final narrative = serverSummary?.summary ??
          entries
              .map((e) => (e.polishedContent ?? e.content).trim())
              .where((t) => t.isNotEmpty)
              .join('\n\n');

      // ── Quote — first sentence of highest-sentiment entry ─────────────────
      final bestEntry = entries.reduce((a, b) =>
          (a.sentimentScore ?? 0) >= (b.sentimentScore ?? 0) ? a : b);
      final bestText = (bestEntry.polishedContent ?? bestEntry.content).trim();
      final sentenceEnd = RegExp(r'[.!?]');
      final match = sentenceEnd.firstMatch(bestText);
      final quoteText = match != null && match.end <= 120
          ? bestText.substring(0, match.end)
          : bestText.length > 100
              ? '${bestText.substring(0, 97)}…'
              : bestText;
      final quote = '"$quoteText"';

      state = state.copyWith(progress: 0.8);

      final story = LifeStory(
        period: period.name,
        startDate: startDate,
        endDate: now,
        totalEntries: entries.length,
        voiceEntries: entries.where((e) => e.hasVoice).length,
        textEntries: entries.where((e) => !e.hasVoice).length,
        narrative: narrative,
        highlightTitle: highlightTitle,
        highlightDate: highlight.entryDate,
        topMood: topMood,
        topTheme: topTheme,
        mostActiveTime: mostActiveTime,
        writingStreak: maxStreak,
        quote: quote,
        entries: entries,
      );

      state = state.copyWith(
        status: StoryStatus.available,
        story: story,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: StoryStatus.error,
        errorMessage: 'Could not generate story. Please try again.',
      );
    }
  }
}

final storyFamilyProvider = StateNotifierProvider.family<StoryNotifier, StoryState, ReflectionPeriod>(
  (ref, period) => StoryNotifier(ref, period: period),
);
