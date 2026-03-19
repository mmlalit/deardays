import 'dart:convert';

/// The hierarchical level of a generated story.
enum StoryLevelType { weekly, monthly, yearly, lifetime }

/// A single generated story at any level of the hierarchy.
///
/// Persisted as JSON in Hive box `'story_nodes'`.
/// Key format:
///   weekly  → `'week_2024_12'`   (year + ISO week number)
///   monthly → `'month_2024_03'`
///   yearly  → `'year_2024'`
///   lifetime → `'lifetime'`
class StoryNode {
  final String id;
  final StoryLevelType level;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// AI-generated narrative text. Null means not yet generated.
  final String? generatedStory;

  /// Short summary of the period (≤60 words weekly, ≤100 monthly, ≤200 yearly).
  /// Generated in the same AI call as [generatedStory] — no extra cost.
  /// Used by [reflectionSummaryProvider] to avoid a second AI call.
  final String? summary;

  /// 1–3 word theme extracted by AI (e.g. "New Beginnings").
  final String? theme;

  /// IDs of high-significance entries that bubbled up to this level.
  final List<String> keyMomentIds;

  /// When this story was last generated (for staleness checks).
  final DateTime? generatedAt;

  const StoryNode({
    required this.id,
    required this.level,
    required this.periodStart,
    required this.periodEnd,
    this.generatedStory,
    this.summary,
    this.theme,
    this.keyMomentIds = const [],
    this.generatedAt,
  });

  bool get isGenerated => generatedStory != null;

  StoryNode copyWith({
    String? generatedStory,
    String? summary,
    String? theme,
    List<String>? keyMomentIds,
    DateTime? generatedAt,
  }) {
    return StoryNode(
      id: id,
      level: level,
      periodStart: periodStart,
      periodEnd: periodEnd,
      generatedStory: generatedStory ?? this.generatedStory,
      summary: summary ?? this.summary,
      theme: theme ?? this.theme,
      keyMomentIds: keyMomentIds ?? this.keyMomentIds,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  StoryNode cleared() {
    return StoryNode(
      id: id,
      level: level,
      periodStart: periodStart,
      periodEnd: periodEnd,
      keyMomentIds: keyMomentIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level.name,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        if (generatedStory != null) 'generated_story': generatedStory,
        if (summary != null) 'summary': summary,
        if (theme != null) 'theme': theme,
        'key_moment_ids': keyMomentIds,
        if (generatedAt != null) 'generated_at': generatedAt!.toIso8601String(),
      };

  factory StoryNode.fromJson(Map<String, dynamic> json) {
    return StoryNode(
      id: json['id'] as String,
      level: StoryLevelType.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => StoryLevelType.weekly,
      ),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      generatedStory: json['generated_story'] as String?,
      summary: json['summary'] as String?,
      theme: json['theme'] as String?,
      keyMomentIds: List<String>.from(json['key_moment_ids'] as List? ?? []),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : null,
    );
  }

  String toHive() => jsonEncode(toJson());

  factory StoryNode.fromHive(String raw) =>
      StoryNode.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  // ─────────────────────────────────────────────
  // Key builders
  // ─────────────────────────────────────────────

  static String weekKey(int year, int week) =>
      'week_${year}_${week.toString().padLeft(2, '0')}';

  static String monthKey(int year, int month) =>
      'month_${year}_${month.toString().padLeft(2, '0')}';

  static String yearKey(int year) => 'year_$year';

  static const String lifetimeKey = 'lifetime';

  /// Returns the ISO week number (1–53) for [date].
  static int isoWeekNumber(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
    final wday = d.weekday; // 1 = Monday
    return ((dayOfYear - wday + 10) / 7).floor();
  }

  /// Returns the Monday of the ISO week containing [date].
  static DateTime weekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  /// Returns the Sunday of the ISO week containing [date].
  static DateTime weekEnd(DateTime date) {
    final start = weekStart(date);
    return start.add(const Duration(days: 6));
  }
}
