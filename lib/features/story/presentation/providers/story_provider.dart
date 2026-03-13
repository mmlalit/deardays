import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/story/data/models/life_story.dart';
import 'package:deardays/services/ai/ai_service.dart';

const _minEntries = 5;

final storyProvider = StateNotifierProvider<StoryNotifier, StoryState>((ref) {
  return StoryNotifier(ref);
});

class StoryNotifier extends StateNotifier<StoryState> {
  StoryNotifier(this._ref) : super(const StoryState());

  final Ref _ref;
  final _aiService = AiService();

  /// Check if a story can be generated from current entries.
  void checkAvailability() {
    final entriesAsync = _ref.read(timelineEntriesProvider);
    final entries = entriesAsync.valueOrNull ?? [];

    // Get entries from the last 7 days
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekEntries = entries.where((e) => e.entryDate.isAfter(weekAgo)).toList();

    if (weekEntries.length >= _minEntries) {
      if (state.status != StoryStatus.available) {
        state = state.copyWith(
          status: StoryStatus.ready,
          entriesNeeded: 0,
        );
      }
    } else {
      state = state.copyWith(
        status: StoryStatus.notEnoughData,
        entriesNeeded: _minEntries - weekEntries.length,
      );
    }
  }

  /// Generate the weekly life story.
  Future<void> generateStory() async {
    final entriesAsync = _ref.read(timelineEntriesProvider);
    final allEntries = entriesAsync.valueOrNull ?? [];

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekEntries = allEntries
        .where((e) => e.entryDate.isAfter(weekAgo))
        .toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    if (weekEntries.length < _minEntries) {
      state = state.copyWith(
        status: StoryStatus.notEnoughData,
        entriesNeeded: _minEntries - weekEntries.length,
      );
      return;
    }

    state = state.copyWith(status: StoryStatus.generating, progress: 0.0);

    try {
      // Step 1: Compute stats (instant — no AI needed)
      final voiceCount = weekEntries.where((e) => e.hasVoice).length;
      final textCount = weekEntries.where((e) => !e.hasVoice).length;
      final entryTexts = weekEntries.map((e) => e.content).toList();

      // Mood analysis (local)
      final moodCounts = <String, int>{};
      for (final e in weekEntries) {
        if (e.mood != null) {
          moodCounts[e.mood!] = (moodCounts[e.mood!] ?? 0) + 1;
        }
      }
      final topMood = moodCounts.isNotEmpty
          ? (moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key
          : 'Reflective';

      // Time analysis (local)
      final hourCounts = <String, int>{'Morning': 0, 'Afternoon': 0, 'Evening': 0};
      for (final e in weekEntries) {
        final hour = e.entryTime?.hour ?? e.entryDate.hour;
        if (hour < 12) {
          hourCounts['Morning'] = hourCounts['Morning']! + 1;
        } else if (hour < 17) {
          hourCounts['Afternoon'] = hourCounts['Afternoon']! + 1;
        } else {
          hourCounts['Evening'] = hourCounts['Evening']! + 1;
        }
      }
      final mostActive = (hourCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

      // Streak calculation
      final dates = weekEntries.map((e) =>
          DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day)).toSet().toList()
        ..sort();
      int streak = 1;
      int maxStreak = 1;
      for (int i = 1; i < dates.length; i++) {
        if (dates[i].difference(dates[i - 1]).inDays == 1) {
          streak++;
          if (streak > maxStreak) maxStreak = streak;
        } else {
          streak = 1;
        }
      }

      state = state.copyWith(progress: 0.2);

      // Step 2–4: AI — merged analysis (themes + summary + highlight in one call)
      String topTheme = _fallbackTheme(topMood);
      String narrative = _fallbackNarrative(weekEntries.length, topMood, topTheme);
      String highlightTitle = 'A meaningful moment';
      DateTime? highlightDate;
      String? highlightEntryId;
      String quote = _fallbackQuote(topMood);

      try {
        if (_aiService.isConfigured) {
          final analysis = await _aiService.analyzeEntries(entryTexts);

          // Themes
          final themes = analysis['themes'] as List<String>? ?? [];
          if (themes.isNotEmpty) topTheme = themes.first;

          // Summary
          final summary = analysis['summary'] as String? ?? '';
          if (summary.isNotEmpty) narrative = summary;

          // Highlight + quote
          final highlight = analysis['highlight'] as Map<String, dynamic>? ?? {};
          final hTitle = highlight['title'] as String? ?? '';
          final hQuote = highlight['quote'] as String? ?? '';
          if (hTitle.isNotEmpty) highlightTitle = hTitle;
          if (hQuote.isNotEmpty) quote = hQuote;
        }
      } catch (_) {
        // Fallbacks already set above
      }

      state = state.copyWith(progress: 0.8);

      // Find the happiest entry as highlight
      final happyOrder = ['great', 'good', 'okay', 'low', 'tough'];
      final sorted = List<JournalEntry>.from(weekEntries)
        ..sort((a, b) {
          final ai = happyOrder.indexOf(a.mood?.toLowerCase() ?? 'okay');
          final bi = happyOrder.indexOf(b.mood?.toLowerCase() ?? 'okay');
          return ai.compareTo(bi);
        });
      if (sorted.isNotEmpty) {
        highlightDate = sorted.first.entryDate;
        highlightEntryId = sorted.first.id;
      }

      state = state.copyWith(progress: 0.9);

      // Build the final story
      final story = LifeStory(
        period: 'weekly',
        startDate: weekAgo,
        endDate: now,
        totalEntries: weekEntries.length,
        voiceEntries: voiceCount,
        textEntries: textCount,
        checkInEntries: 0,
        narrative: narrative,
        highlightTitle: highlightTitle,
        highlightEntryId: highlightEntryId,
        highlightDate: highlightDate,
        topMood: _capitalize(topMood),
        topTheme: _capitalize(topTheme),
        mostActiveTime: mostActive,
        writingStreak: maxStreak,
        quote: quote,
        entries: weekEntries,
      );

      state = StoryState(
        status: StoryStatus.available,
        story: story,
        progress: 1.0,
      );
    } catch (e) {
      state = const StoryState(
        status: StoryStatus.error,
        errorMessage: 'Failed to generate story. Try again.',
      );
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _fallbackTheme(String mood) {
    switch (mood.toLowerCase()) {
      case 'great': return 'Joy';
      case 'good': return 'Gratitude';
      case 'okay': return 'Reflection';
      case 'low': return 'Growth';
      case 'tough': return 'Resilience';
      default: return 'Reflection';
    }
  }

  String _fallbackNarrative(int count, String mood, String theme) {
    return 'You wrote $count times this week. '
        'Mostly ${mood.toLowerCase()} days, with a theme of ${theme.toLowerCase()} running through them. '
        'Not a bad week overall.';
  }

  String _fallbackQuote(String mood) {
    switch (mood.toLowerCase()) {
      case 'great': return 'Every day brought something worth remembering.';
      case 'good': return 'Small moments created the biggest memories.';
      case 'okay': return 'Even quiet days have stories worth telling.';
      case 'low': return 'Growth often comes from the hardest days.';
      case 'tough': return 'Strength is found in showing up every day.';
      default: return 'Life is made of the moments we choose to remember.';
    }
  }
}
