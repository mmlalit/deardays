import 'package:deardays/features/journal/data/models/journal_entry.dart';

/// Represents an AI-generated life story summary for a period.
class LifeStory {
  final String period; // 'weekly' or 'monthly'
  final DateTime startDate;
  final DateTime endDate;
  final int totalEntries;
  final int voiceEntries;
  final int textEntries;
  final int checkInEntries;

  // AI-generated content
  final String narrative;
  final String highlightTitle;
  final String? highlightEntryId;
  final DateTime? highlightDate;
  final String topMood;
  final String topTheme;
  final String mostActiveTime; // 'Morning', 'Afternoon', 'Evening'
  final int writingStreak;
  final String quote;

  // Source entries for reference
  final List<JournalEntry> entries;

  const LifeStory({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalEntries,
    this.voiceEntries = 0,
    this.textEntries = 0,
    this.checkInEntries = 0,
    required this.narrative,
    required this.highlightTitle,
    this.highlightEntryId,
    this.highlightDate,
    required this.topMood,
    required this.topTheme,
    required this.mostActiveTime,
    this.writingStreak = 0,
    required this.quote,
    this.entries = const [],
  });
}

/// Status of story generation.
enum StoryStatus {
  /// Not enough entries to generate a story.
  notEnoughData,

  /// Ready to generate (enough data, not yet generated).
  ready,

  /// Currently generating.
  generating,

  /// Story is available to view.
  available,

  /// Generation failed.
  error,
}

/// Wraps story state for the provider.
class StoryState {
  final StoryStatus status;
  final LifeStory? story;
  final double progress;
  final String? errorMessage;
  final int entriesNeeded; // how many more entries needed

  const StoryState({
    this.status = StoryStatus.notEnoughData,
    this.story,
    this.progress = 0.0,
    this.errorMessage,
    this.entriesNeeded = 5,
  });

  StoryState copyWith({
    StoryStatus? status,
    LifeStory? story,
    double? progress,
    String? errorMessage,
    int? entriesNeeded,
  }) {
    return StoryState(
      status: status ?? this.status,
      story: story ?? this.story,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      entriesNeeded: entriesNeeded ?? this.entriesNeeded,
    );
  }
}
