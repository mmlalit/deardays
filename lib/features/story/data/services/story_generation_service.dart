import 'package:flutter/foundation.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/story/data/models/story_node.dart';
import 'package:deardays/features/story/data/repositories/story_node_repository.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/ai/ai_credit_service.dart';

/// Orchestrates hierarchical story generation:
///   Daily entries → Weekly → Monthly → Yearly → Lifetime
///
/// Each level builds on cached summaries from the level below — never
/// re-processes raw entries at higher levels, keeping AI costs minimal.
class StoryGenerationService {
  StoryGenerationService._();
  static final StoryGenerationService _instance = StoryGenerationService._();
  factory StoryGenerationService() => _instance;

  final _repo = StoryNodeRepository();
  final _ai = AiService();
  final _credits = AiCreditService();

  // ── C-14: Simple in-memory rate limit: 1 generation per 10 minutes ────────
  static DateTime? _lastGenerationTime;
  static const _generationCooldown = Duration(minutes: 10);

  Future<void> _checkRateLimit() async {
    if (_lastGenerationTime != null) {
      final elapsed = DateTime.now().difference(_lastGenerationTime!);
      if (elapsed < _generationCooldown) {
        final remaining = _generationCooldown - elapsed;
        final mins = remaining.inMinutes + 1;
        throw Exception(
            'Please wait $mins minute${mins == 1 ? '' : 's'} before generating another story.');
      }
    }
    _lastGenerationTime = DateTime.now();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Significance scoring
  // ─────────────────────────────────────────────────────────────────────────

  /// Scores how significant an entry is (0.0 – 1.0).
  /// Entries with score >= 0.5 are "key moments" that bubble up to the
  /// Lifetime story alongside yearly summaries.
  double significanceScore(JournalEntry entry) {
    double score = 0.0;
    if (entry.isMilestone) score += 0.3;
    if ((entry.sentimentScore ?? 0).abs() > 0.7) score += 0.2;
    if (entry.wordCount > 300) score += 0.2;
    if (entry.tags.length > 3) score += 0.15;
    if (entry.mood == 'great' || entry.mood == 'tough') score += 0.15;
    return score.clamp(0.0, 1.0);
  }

  /// Returns entries with significanceScore >= 0.5.
  List<JournalEntry> extractKeyMoments(List<JournalEntry> entries) =>
      entries.where((e) => significanceScore(e) >= 0.5).toList();

  // ─────────────────────────────────────────────────────────────────────────
  // Staleness check
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true when [entries] contain entries added after [node.generatedAt].
  bool needsRegeneration(StoryNode node, List<JournalEntry> entries) {
    if (!node.isGenerated || node.generatedAt == null) return true;
    return entries.any((e) => e.createdAt.isAfter(node.generatedAt!));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Weekly generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates (or returns cached) weekly story for the ISO week containing [weekDate].
  ///
  /// [dailyTexts] — polished or raw text for each entry in the week, in date order.
  /// [entries] — the source JournalEntry objects for metadata extraction.
  Future<StoryNode> generateWeekly(
    DateTime weekDate,
    List<String> dailyTexts, {
    List<JournalEntry> entries = const [],
    String? language,
  }) async {
    final key = StoryNode.weekKey(
      weekDate.year,
      StoryNode.isoWeekNumber(weekDate),
    );

    await _checkRateLimit();

    final cached = await _repo.get(key);
    if (cached != null && cached.isGenerated) {
      if (!needsRegeneration(cached, entries)) return cached;
    }

    if (dailyTexts.isEmpty) {
      return _emptyNode(key, StoryLevelType.weekly,
          StoryNode.weekStart(weekDate), StoryNode.weekEnd(weekDate));
    }

    if (!_credits.canUse(AiOperation.summary)) {
      throw AiServiceException('No summary credits remaining');
    }
    _credits.consume(AiOperation.summary);

    final tags = entries.expand((e) => e.tags).toSet().toList();
    final people = entries.expand((e) => e.people).toSet().toList();
    final moods = entries.map((e) => e.mood).whereType<String>().toSet().toList();

    final result = await _ai.generateWeeklyStory(
      dailyTexts,
      tags: tags,
      people: people,
      moods: moods,
      language: language,
    );

    // Analyse story in one call: theme + highlight (replaces two separate calls).
    String? theme;
    try {
      if (_credits.canUse(AiOperation.themes)) {
        final analysis = await _ai.analyzeStory(result.story);
        theme = analysis['theme'];
        _credits.consume(AiOperation.themes);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[StoryGenerationService] story analysis failed: $e');
    }

    final keyMomentIds = extractKeyMoments(entries).map((e) => e.id).toList();

    final node = StoryNode(
      id: key,
      level: StoryLevelType.weekly,
      periodStart: StoryNode.weekStart(weekDate),
      periodEnd: StoryNode.weekEnd(weekDate),
      generatedStory: result.story,
      summary: result.summary,
      theme: theme,
      keyMomentIds: keyMomentIds,
      generatedAt: DateTime.now(),
    );

    await _repo.save(node);
    return node;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Monthly generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates (or returns cached) monthly story for [year]/[month].
  ///
  /// Fetches cached weekly nodes for that month; if any are missing, generates
  /// them first using [entriesForWeek] callback.
  Future<StoryNode> generateMonthly(
    int year,
    int month, {
    required Future<List<String>> Function(DateTime weekDate) dailyTextsForWeek,
    required Future<List<JournalEntry>> Function(DateTime weekDate) entriesForWeek,
    List<JournalEntry> allMonthEntries = const [],
    String? language,
  }) async {
    await _checkRateLimit();

    final key = StoryNode.monthKey(year, month);

    final cached = await _repo.get(key);
    if (cached != null && cached.isGenerated) {
      if (!needsRegeneration(cached, allMonthEntries)) return cached;
    }

    // Find all ISO weeks that overlap this month
    final weeksInMonth = _isoWeeksInMonth(year, month);
    final weeklyStories = <String>[];

    for (final weekDate in weeksInMonth) {
      final weekKey = StoryNode.weekKey(weekDate.year, StoryNode.isoWeekNumber(weekDate));
      var weekNode = await _repo.get(weekKey);
      if (weekNode == null || !weekNode.isGenerated) {
        final texts = await dailyTextsForWeek(weekDate);
        final entries = await entriesForWeek(weekDate);
        weekNode = await generateWeekly(weekDate, texts,
            entries: entries, language: language);
      }
      // Use short summary as input if available — avoids sending full story text
      if (weekNode.isGenerated) {
        weeklyStories.add(weekNode.summary ?? weekNode.generatedStory!);
      }
    }

    if (weeklyStories.isEmpty) {
      return _emptyNode(key, StoryLevelType.monthly,
          DateTime(year, month, 1), DateTime(year, month + 1, 0));
    }

    if (!_credits.canUse(AiOperation.summary)) {
      throw AiServiceException('No summary credits remaining');
    }
    _credits.consume(AiOperation.summary);

    final tags = allMonthEntries.expand((e) => e.tags).toSet().toList();
    final people = allMonthEntries.expand((e) => e.people).toSet().toList();
    final moods = allMonthEntries.map((e) => e.mood).whereType<String>().toSet().toList();

    final result = await _ai.generateMonthlyStory(
      weeklyStories,
      tags: tags,
      people: people,
      moods: moods,
      language: language,
    );

    String? theme;
    try {
      if (_credits.canUse(AiOperation.themes)) {
        final analysis = await _ai.analyzeStory(result.story);
        theme = analysis['theme'];
        _credits.consume(AiOperation.themes);
      }
    } catch (_) {}

    final keyMomentIds = extractKeyMoments(allMonthEntries).map((e) => e.id).toList();

    final node = StoryNode(
      id: key,
      level: StoryLevelType.monthly,
      periodStart: DateTime(year, month, 1),
      periodEnd: DateTime(year, month + 1, 0),
      generatedStory: result.story,
      summary: result.summary,
      theme: theme,
      keyMomentIds: keyMomentIds,
      generatedAt: DateTime.now(),
    );

    await _repo.save(node);
    return node;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Yearly generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates (or returns cached) yearly story for [year].
  /// Fetches cached monthly nodes (does NOT auto-generate missing months —
  /// uses only what's available so the user controls the trigger).
  Future<StoryNode> generateYearly(
    int year, {
    List<JournalEntry> allYearEntries = const [],
    String? language,
  }) async {
    await _checkRateLimit();

    final key = StoryNode.yearKey(year);

    final cached = await _repo.get(key);
    if (cached != null && cached.isGenerated) {
      if (!needsRegeneration(cached, allYearEntries)) return cached;
    }

    // Collect all generated monthly nodes for this year
    final monthlyNodes = await _repo.getAll(StoryLevelType.monthly);
    final yearMonthly = monthlyNodes
        .where((n) => n.periodStart.year == year && n.isGenerated)
        .toList();

    if (yearMonthly.isEmpty) {
      throw AiServiceException(
          'Generate monthly stories first before creating the yearly story.');
    }

    if (!_credits.canUse(AiOperation.summary)) {
      throw AiServiceException('No summary credits remaining');
    }
    _credits.consume(AiOperation.summary);

    // Use short summary as input if available — avoids sending full monthly stories
    final monthlySummaries = yearMonthly
        .map((n) => n.summary ?? n.generatedStory!)
        .toList();
    final tags = allYearEntries.expand((e) => e.tags).toSet().toList();
    final people = allYearEntries.expand((e) => e.people).toSet().toList();
    final moods = allYearEntries.map((e) => e.mood).whereType<String>().toSet().toList();

    final result = await _ai.generateYearlyStory(
      monthlySummaries,
      tags: tags,
      people: people,
      moods: moods,
      language: language,
    );

    String? theme;
    try {
      if (_credits.canUse(AiOperation.themes)) {
        final analysis = await _ai.analyzeStory(result.story);
        theme = analysis['theme'];
        _credits.consume(AiOperation.themes);
      }
    } catch (_) {}

    final keyMomentIds = extractKeyMoments(allYearEntries).map((e) => e.id).toList();

    final node = StoryNode(
      id: key,
      level: StoryLevelType.yearly,
      periodStart: DateTime(year, 1, 1),
      periodEnd: DateTime(year, 12, 31),
      generatedStory: result.story,
      summary: result.summary,
      theme: theme,
      keyMomentIds: keyMomentIds,
      generatedAt: DateTime.now(),
    );

    await _repo.save(node);
    return node;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifetime generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates the lifetime story from all available yearly nodes + key moments.
  /// Always re-generates (manually triggered, expensive).
  Future<StoryNode> generateLifetime({
    List<JournalEntry> allEntries = const [],
    String? language,
  }) async {
    final yearlyNodes = await _repo.getAll(StoryLevelType.yearly);
    final generated = yearlyNodes.where((n) => n.isGenerated).toList();

    if (generated.isEmpty) {
      throw AiServiceException(
          'Generate yearly stories first before creating your Lifetime Book.');
    }

    if (!_credits.canUse(AiOperation.summary)) {
      throw AiServiceException('No summary credits remaining');
    }

    final yearlyTexts = generated.map((n) => n.generatedStory!).toList();
    final keyMoments = extractKeyMoments(allEntries);
    final keyMomentTexts = keyMoments
        .map((e) => e.polishedContent ?? e.content)
        .take(10)
        .toList();

    final story = await _ai.generateLifetimeStory(
      yearlyTexts,
      keyMomentTexts: keyMomentTexts,
      language: language,
    );
    _credits.consume(AiOperation.summary);

    final node = StoryNode(
      id: StoryNode.lifetimeKey,
      level: StoryLevelType.lifetime,
      periodStart: generated.first.periodStart,
      periodEnd: generated.last.periodEnd,
      generatedStory: story,
      keyMomentIds: keyMoments.map((e) => e.id).toList(),
      generatedAt: DateTime.now(),
    );

    await _repo.save(node);
    return node;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  StoryNode _emptyNode(
    String key,
    StoryLevelType level,
    DateTime start,
    DateTime end,
  ) =>
      StoryNode(id: key, level: level, periodStart: start, periodEnd: end);

  /// Returns a DateTime for each distinct ISO week that has at least one day
  /// falling within [year]/[month]. The date is the Monday of that week.
  List<DateTime> _isoWeeksInMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final weeks = <String, DateTime>{};

    for (var d = firstDay;
        !d.isAfter(lastDay);
        d = d.add(const Duration(days: 1))) {
      final weekNum = StoryNode.isoWeekNumber(d);
      final weekStart = StoryNode.weekStart(d);
      final wKey = '${weekStart.year}_$weekNum';
      weeks.putIfAbsent(wKey, () => weekStart);
    }
    return weeks.values.toList()..sort();
  }
}
