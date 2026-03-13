import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/ai/ai_credit_service.dart';
import 'package:deardays/services/ai/offline_ai_queue.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/location/location_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/data/repositories/book_repository.dart';
import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/services/sync/sync_service.dart';
import 'package:deardays/services/search/search_service.dart';
import 'package:deardays/services/backup/backup_service.dart';
import 'package:deardays/services/analytics/analytics_service.dart';
import 'package:deardays/services/crash_reporting/crash_reporting_service.dart';
import 'package:deardays/services/ai/mood_detection_service.dart';
import 'package:deardays/services/ai/highlight_service.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';

// Re-export SyncStatus so widgets can import from app_providers
export 'package:deardays/services/sync/sync_service.dart' show SyncStatus;

// --- Post-Save Data (survives go_router refreshes) ---

final postSaveDataProvider = StateProvider<PostSaveData?>((ref) => null);

// --- Sync & Connectivity ---

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);
final connectivityProvider = StateProvider<bool>((ref) => true);

// --- Core Services ---

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(client: ref.watch(supabaseClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// --- New Services (Phase 1-3) ---

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final crashReportingProvider = Provider<CrashReportingService>((ref) {
  return CrashReportingService();
});

final moodDetectionProvider = Provider<MoodDetectionService>((ref) {
  return MoodDetectionService();
});

final highlightServiceProvider = Provider<HighlightService>((ref) {
  return HighlightService();
});

final aiCreditServiceProvider = Provider<AiCreditService>((ref) {
  return AiCreditService();
});

final offlineAiQueueProvider = Provider<OfflineAiQueue>((ref) {
  return OfflineAiQueue();
});

// --- Repositories ---

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(client: ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(client: ref.watch(supabaseClientProvider));
});

// --- Auth State ---

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isAuthenticated;
});

// --- Profile & Streak ---

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getProfile();
});

final streakProvider = FutureProvider<Streak?>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getStreak();
});

final chaptersProvider = FutureProvider<List<Chapter>>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getChapters();
});

// --- Books ---

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(client: ref.watch(supabaseClientProvider));
});

final booksProvider = FutureProvider<List<Book>>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(bookRepositoryProvider).getBooks();
});

// --- Journal Entries ---

final entriesProvider =
    FutureProvider.family<List<JournalEntry>, EntriesFilter>((ref, filter) async {
  try {
    return await ref.watch(journalRepositoryProvider).getEntries(
          startDate: filter.startDate,
          endDate: filter.endDate,
          mood: filter.mood,
          limit: filter.limit,
          offset: filter.offset,
        );
  } catch (_) {
    // Offline fallback: return cached entries
    return ref.watch(localStorageProvider).getCachedEntries();
  }
});

final todayEntryProvider = StreamProvider<JournalEntry?>((ref) async* {
  final localStorage = ref.watch(localStorageProvider);
  final today = DateTime.now();

  // Check cache first for instant display
  final cached = await localStorage.getCachedEntries();
  final todayCached = cached.where((e) =>
      e.entryDate.year == today.year &&
      e.entryDate.month == today.month &&
      e.entryDate.day == today.day).toList();
  if (todayCached.isNotEmpty) {
    yield todayCached.first;
  }

  // Then fetch fresh from network
  try {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final entries = await ref.watch(journalRepositoryProvider).getEntries(
          startDate: startOfDay,
          endDate: now,
          limit: 1,
        );
    yield entries.isEmpty ? null : entries.first;
  } catch (_) {
    // If cache was empty, emit null so UI exits loading
    if (todayCached.isEmpty) {
      yield null;
    }
  }
});

final onThisDayProvider = FutureProvider<List<JournalEntry>>((ref) async {
  try {
    return await ref.watch(journalRepositoryProvider).getOnThisDay();
  } catch (_) {
    return [];
  }
});

final moodStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    return await ref.watch(journalRepositoryProvider).getMoodStats();
  } catch (_) {
    return {};
  }
});

final totalEntriesProvider = FutureProvider<int>((ref) async {
  try {
    return await ref.watch(journalRepositoryProvider).getTotalEntries();
  } catch (_) {
    final cached = await ref.watch(localStorageProvider).getCachedEntries();
    return cached.length;
  }
});

/// All entries for the timeline screen (most recent, paginated).
/// Returns cached data first (if available), then refreshes from network.
/// On success, caches entries locally for offline access.
final timelineEntriesProvider =
    StreamProvider<List<JournalEntry>>((ref) async* {
  final localStorage = ref.watch(localStorageProvider);

  // Emit cached data immediately so the UI has something to show
  final cached = await localStorage.getCachedEntries();
  if (cached.isNotEmpty) {
    cached.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    yield cached;
  }

  // Then fetch fresh data from the network
  try {
    final entries = await ref.watch(journalRepositoryProvider).getEntries(limit: 50);
    // Cache entries locally for offline access
    for (final entry in entries) {
      await localStorage.cacheEntry(entry);
    }
    yield entries;
  } catch (_) {
    // If we already emitted cached data, no need to emit again.
    // If cache was empty, emit empty list so the UI exits loading state.
    if (cached.isEmpty) {
      yield <JournalEntry>[];
    }
  }
});

// --- Insights ---

/// Mood values for the last 7 days (for the weekly bar chart).
final weeklyMoodsProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  return ref.watch(journalRepositoryProvider).getMoodsByDateRange(days: 7);
});

/// Mood breakdown for the last 30 days.
final monthlyMoodStatsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 1, now.day);
  return ref
      .watch(journalRepositoryProvider)
      .getMoodStatsByRange(start: start, end: now);
});

/// Weekly entries for AI summary generation.
final weeklyEntriesProvider =
    FutureProvider<List<JournalEntry>>((ref) async {
  final now = DateTime.now();
  final weekStart = now.subtract(const Duration(days: 6));
  return ref.watch(journalRepositoryProvider).getEntries(
        startDate: DateTime(weekStart.year, weekStart.month, weekStart.day),
        endDate: now,
        limit: 50,
      );
});

/// AI-generated weekly summary text.
final weeklySummaryProvider = FutureProvider<String?>((ref) async {
  final entries = await ref.watch(weeklyEntriesProvider.future);
  if (entries.isEmpty) return null;

  final language = ref.watch(localeProvider).languageName;
  final texts = entries.map((e) => e.content).toList();
  try {
    return await ref.watch(aiServiceProvider).generateSummary(
          texts,
          period: 'weekly',
          language: language,
        );
  } catch (_) {
    return null;
  }
});

/// AI-detected themes from this week's entries.
final weeklyThemesProvider = FutureProvider<List<String>>((ref) async {
  final entries = await ref.watch(weeklyEntriesProvider.future);
  if (entries.isEmpty) return [];

  final texts = entries.map((e) => e.content).toList();
  try {
    return await ref.watch(aiServiceProvider).detectThemes(texts);
  } catch (_) {
    return [];
  }
});

// --- Period-aware reflection providers (monthly / yearly) ---

enum ReflectionPeriod { weekly, monthly, yearly }

/// Entries for a given reflection period.
final reflectionEntriesProvider =
    FutureProvider.family<List<JournalEntry>, ReflectionPeriod>((ref, period) async {
  final now = DateTime.now();
  final DateTime start;
  switch (period) {
    case ReflectionPeriod.weekly:
      start = now.subtract(const Duration(days: 6));
    case ReflectionPeriod.monthly:
      start = DateTime(now.year, now.month - 1, now.day);
    case ReflectionPeriod.yearly:
      start = DateTime(now.year - 1, now.month, now.day);
  }
  return ref.watch(journalRepositoryProvider).getEntries(
        startDate: DateTime(start.year, start.month, start.day),
        endDate: now,
        limit: period == ReflectionPeriod.yearly ? 500 : 100,
      );
});

/// Moods for a given reflection period.
final reflectionMoodsProvider =
    FutureProvider.family<List<Map<String, String>>, ReflectionPeriod>((ref, period) async {
  final days = switch (period) {
    ReflectionPeriod.weekly => 7,
    ReflectionPeriod.monthly => 30,
    ReflectionPeriod.yearly => 365,
  };
  return ref.watch(journalRepositoryProvider).getMoodsByDateRange(days: days);
});

/// AI summary for a given reflection period.
final reflectionSummaryProvider =
    FutureProvider.family<String?, ReflectionPeriod>((ref, period) async {
  final entries = await ref.watch(reflectionEntriesProvider(period).future);
  if (entries.isEmpty) return null;

  final language = ref.watch(localeProvider).languageName;
  final texts = entries.map((e) => e.content).toList();
  // For yearly, sample at most 30 entries to stay within token limits
  final sampled = period == ReflectionPeriod.yearly && texts.length > 30
      ? (texts.toList()..shuffle()).take(30).toList()
      : texts;
  try {
    return await ref.watch(aiServiceProvider).generateSummary(
          sampled,
          period: period.name,
          language: language,
        );
  } catch (_) {
    return null;
  }
});

/// AI themes for a given reflection period.
final reflectionThemesProvider =
    FutureProvider.family<List<String>, ReflectionPeriod>((ref, period) async {
  final entries = await ref.watch(reflectionEntriesProvider(period).future);
  if (entries.isEmpty) return [];

  final texts = entries.map((e) => e.content).toList();
  final sampled = period == ReflectionPeriod.yearly && texts.length > 30
      ? (texts.toList()..shuffle()).take(30).toList()
      : texts;
  try {
    return await ref.watch(aiServiceProvider).detectThemes(sampled);
  } catch (_) {
    return [];
  }
});

/// AI-generated writing prompt (refreshes each call; UI should cache per day).
final writingPromptProvider = FutureProvider<String?>((ref) async {
  final ai = ref.watch(aiServiceProvider);
  if (!ai.isConfigured) return null;
  try {
    return await ai.getWritingPrompt();
  } catch (_) {
    return null;
  }
});

/// AI-generated cover search query for a given book title.
final bookCoverQueryProvider =
    FutureProvider.family<String?, String>((ref, bookTitle) async {
  final ai = ref.watch(aiServiceProvider);
  if (!ai.isConfigured) return null;
  try {
    return await ai.generateCoverQuery(bookTitle);
  } catch (_) {
    return null;
  }
});

// --- Filter Model ---

class EntriesFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? mood;
  final int limit;
  final int offset;

  const EntriesFilter({
    this.startDate,
    this.endDate,
    this.mood,
    this.limit = 50,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntriesFilter &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          mood == other.mood &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(startDate, endDate, mood, limit, offset);
}
