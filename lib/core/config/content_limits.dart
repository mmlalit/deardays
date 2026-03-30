/// Hard limits to prevent abuse and control AI costs.
///
/// These apply to all users (free and paid). They protect against
/// accidental or intentional misuse (30-minute voice recordings,
/// pasting entire books, etc.).
class ContentLimits {
  ContentLimits._();

  // ── Recording ───────────────────────────────────────────────────────────
  /// Maximum recording duration in minutes.
  static const int maxRecordingMinutes = 5;

  /// Maximum recording duration as Duration.
  static const Duration maxRecordingDuration = Duration(minutes: maxRecordingMinutes);

  /// Maximum audio file size in bytes (10 MB).
  static const int maxAudioFileBytes = 10 * 1024 * 1024;

  // ── Text ────────────────────────────────────────────────────────────────
  /// Maximum words per memory entry.
  static const int maxWordsPerEntry = 2000;

  /// Maximum characters per memory entry.
  static const int maxCharsPerEntry = 12000;

  /// Warning threshold — show "getting long" hint.
  static const int wordWarningThreshold = 1500;

  // ── Photos ──────────────────────────────────────────────────────────────
  /// Maximum photo file size in bytes (10 MB).
  static const int maxPhotoFileBytes = 10 * 1024 * 1024;

  /// Maximum photos per entry.
  static const int maxPhotosPerEntry = 5;

  // ── Entry spam prevention ──────────────────────────────────────────────
  /// Maximum entries per day (hard cap, even for paid users).
  static const int maxEntriesPerDayHard = 30;

  /// Maximum entries per day for free users.
  static const int maxEntriesPerDayFree = 10;

  /// Minimum seconds between saves (prevents rapid-fire bot saves).
  static const int minSecondsBetweenSaves = 10;

  // ── Edit debounce ──────────────────────────────────────────────────────
  /// Minimum minutes between needs_refresh triggers for the same entry.
  /// Prevents cascading AI cost when user edits the same entry repeatedly.
  static const int needsRefreshDebounceMinutes = 5;

  // ── AI search ──────────────────────────────────────────────────────────
  /// Maximum AI-powered searches per hour.
  static const int maxAiSearchesPerHour = 20;

  // ── Chapters ───────────────────────────────────────────────────────────
  /// Maximum chapters per user.
  static const int maxChaptersPerUser = 50;

  // ── Shares ─────────────────────────────────────────────────────────────
  /// Maximum active share links per entry.
  static const int maxSharesPerEntry = 10;

  // ── Exports ────────────────────────────────────────────────────────────
  /// Maximum PDF exports per day.
  static const int maxExportsPerDay = 3;

  // ── Storage ────────────────────────────────────────────────────────────
  /// Storage quota for free users in bytes (500 MB).
  static const int storageQuotaFreeBytes = 500 * 1024 * 1024;

  /// Storage quota for paid users in bytes (5 GB).
  static const int storageQuotaPaidBytes = 5 * 1024 * 1024 * 1024;

  // ── Daily story ────────────────────────────────────────────────────────
  /// Maximum entries fed into daily story generation.
  static const int maxEntriesPerDailyStory = 10;

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Truncate text to [maxWordsPerEntry], preserving paragraph boundaries.
  static String truncateForAi(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= maxWordsPerEntry) return text;
    return '${words.take(maxWordsPerEntry).join(' ')}...';
  }

  /// Returns true if text exceeds the word limit.
  static bool isOverWordLimit(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length > maxWordsPerEntry;
  }

  /// Word count for display.
  static int wordCount(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Tracks last save timestamp for rate limiting.
  static DateTime? _lastSaveTime;

  /// Returns true if save is allowed (respects minSecondsBetweenSaves).
  /// Updates the timestamp if allowed.
  static bool canSaveNow() {
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!).inSeconds < minSecondsBetweenSaves) {
      return false;
    }
    _lastSaveTime = now;
    return true;
  }

  /// Seconds remaining until next save is allowed.
  static int secondsUntilNextSave() {
    if (_lastSaveTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastSaveTime!).inSeconds;
    final remaining = minSecondsBetweenSaves - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Tracks AI search count for rate limiting.
  static final List<DateTime> _aiSearchTimestamps = [];

  /// Returns true if AI search is allowed (respects maxAiSearchesPerHour).
  static bool canAiSearchNow() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    _aiSearchTimestamps.removeWhere((t) => t.isBefore(oneHourAgo));
    if (_aiSearchTimestamps.length >= maxAiSearchesPerHour) return false;
    _aiSearchTimestamps.add(now);
    return true;
  }

  /// AI searches remaining this hour.
  static int aiSearchesRemaining() {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    _aiSearchTimestamps.removeWhere((t) => t.isBefore(oneHourAgo));
    return maxAiSearchesPerHour - _aiSearchTimestamps.length;
  }
}
