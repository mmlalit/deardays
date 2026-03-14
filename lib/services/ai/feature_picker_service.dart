import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/services/ai/highlight_service.dart';

/// Picks the single most "feature-worthy" entry from a list using a
/// composite score that combines emotional quality, visual richness, and
/// user-defined importance signals.
///
/// Used by the monthly week-cards and yearly month-tiles in ReflectionScreen
/// to automatically select the best representative memory for each period.
///
/// Score breakdown:
///   highlight × 2.0  — emotional / literary quality (HighlightService)
///   photo     × 3.0  — visual entries are far more engaging in card format
///   milestone × 2.0  — user explicitly marked this as important
///   polished  × 1.0  — AI identified it worth narrative expansion
///   words     × 0.5  — above-average length adds signal (capped)
///
/// Mood is intentionally excluded: hard days are just as worth featuring
/// as happy ones.
class FeaturePickerService {
  FeaturePickerService._internal();
  static final FeaturePickerService _instance = FeaturePickerService._internal();
  factory FeaturePickerService() => _instance;

  /// Returns the entry with the highest composite score.
  /// Returns `entries.first` if the list has only one element.
  JournalEntry pick(List<JournalEntry> entries) {
    assert(entries.isNotEmpty, 'entries must not be empty');
    if (entries.length == 1) return entries.first;

    JournalEntry best = entries.first;
    double bestScore = _score(entries.first);

    for (int i = 1; i < entries.length; i++) {
      final s = _score(entries[i]);
      if (s > bestScore) {
        bestScore = s;
        best = entries[i];
      }
    }
    return best;
  }

  double _score(JournalEntry entry) {
    // Highlight quality — extract top highlight, use its score.
    final highlights =
        HighlightService().extractHighlights(entry, maxHighlights: 1);
    final hs = highlights.isEmpty ? 0.0 : highlights.first.score;

    final photo =
        entry.media.any((m) => m.mediaType == 'photo') ? 3.0 : 0.0;
    final milestone = entry.isMilestone ? 2.0 : 0.0;
    final polished = entry.polishedContent != null ? 1.0 : 0.0;
    // Word count bonus: above 80 words gets 0.5, above 200 gets 1.0 (capped).
    final words = entry.wordCount >= 200
        ? 1.0
        : entry.wordCount >= 80
            ? 0.5
            : 0.0;

    return hs * 2.0 + photo + milestone + polished + words;
  }

  // ── Group helpers ───────────────────────────────────────────────────────────

  /// Groups entries by ISO-week-of-month (1–5).
  /// Week 1 = days 1–7, Week 2 = days 8–14, etc.
  static Map<int, List<JournalEntry>> groupByWeekOfMonth(
      List<JournalEntry> entries) {
    final map = <int, List<JournalEntry>>{};
    for (final e in entries) {
      final week = ((e.entryDate.day - 1) ~/ 7) + 1; // 1-based
      (map[week] ??= []).add(e);
    }
    return map;
  }

  /// Groups entries by month number (1–12).
  static Map<int, List<JournalEntry>> groupByMonth(
      List<JournalEntry> entries) {
    final map = <int, List<JournalEntry>>{};
    for (final e in entries) {
      (map[e.entryDate.month] ??= []).add(e);
    }
    return map;
  }

  /// Human-readable week label, e.g. "Mar 1–7".
  static String weekLabel(int year, int month, int weekOfMonth) {
    final start = (weekOfMonth - 1) * 7 + 1;
    final end =
        (start + 6).clamp(1, DateTime(year, month + 1, 0).day).toInt();
    final monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${monthNames[month]} $start–$end';
  }

  /// Human-readable month label, e.g. "March".
  static String monthLabel(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }

  /// Short month label, e.g. "Mar".
  static String shortMonthLabel(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month];
  }
}
