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
import 'package:deardays/features/journal/data/repositories/reflection_cache_repository.dart';
import 'package:deardays/features/journal/data/repositories/reflection_override_repository.dart';
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

final reflectionCacheRepositoryProvider =
    Provider<ReflectionCacheRepository>((ref) {
  return ReflectionCacheRepository(ref.watch(supabaseClientProvider));
});

final reflectionOverrideRepositoryProvider =
    Provider<ReflectionOverrideRepository>((ref) {
  return ReflectionOverrideRepository();
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
  final repo = ref.watch(profileRepositoryProvider);
  // Seed 4 defaults on first load if user has no chapters
  return repo.seedDefaultChapters();
});

/// Entries for a specific chapter, ordered chronologically (oldest first).
final chapterEntriesProvider =
    FutureProvider.family<List<JournalEntry>, String>((ref, chapterId) async {
  return ref.watch(journalRepositoryProvider).getEntriesByChapter(chapterId);
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
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'entriesProvider');
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
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'todayEntryProvider');
    if (todayCached.isEmpty) {
      yield null;
    }
  }
});

final onThisDayProvider = FutureProvider<List<JournalEntry>>((ref) async {
  try {
    return await ref.watch(journalRepositoryProvider).getOnThisDay();
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'onThisDayProvider');
    return [];
  }
});

final moodStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    return await ref.watch(journalRepositoryProvider).getMoodStats();
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'moodStatsProvider');
    return {};
  }
});

final totalEntriesProvider = FutureProvider<int>((ref) async {
  try {
    return await ref.watch(journalRepositoryProvider).getTotalEntries();
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'totalEntriesProvider');
    final cached = await ref.watch(localStorageProvider).getCachedEntries();
    return cached.length;
  }
});

/// Paginated timeline entries with cursor-based loading.
///
/// Loads 20 entries at a time. Call `ref.read(timelineControllerProvider.notifier).loadMore()`
/// to fetch the next page. Uses cache-first strategy for instant display.
final timelineControllerProvider =
    StateNotifierProvider<TimelineController, TimelineState>((ref) {
  return TimelineController(ref);
});

class TimelineState {
  final List<JournalEntry> entries;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const TimelineState({
    this.entries = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  TimelineState copyWith({
    List<JournalEntry>? entries,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return TimelineState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class TimelineController extends StateNotifier<TimelineState> {
  final Ref _ref;
  static const _pageSize = 20;

  TimelineController(this._ref) : super(const TimelineState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true);
    final localStorage = _ref.read(localStorageProvider);

    // Show cached entries instantly
    final cached = await localStorage.getCachedEntries();
    if (cached.isNotEmpty) {
      cached.sort((a, b) => b.entryDate.compareTo(a.entryDate));
      state = state.copyWith(entries: cached, isLoading: false);
    }

    // Then fetch first page from network
    try {
      final entries = await _ref.read(journalRepositoryProvider).getEntries(
            limit: _pageSize,
            offset: 0,
          );
      for (final entry in entries) {
        await localStorage.cacheEntry(entry);
      }
      state = state.copyWith(
        entries: entries,
        isLoading: false,
        hasMore: entries.length >= _pageSize,
        error: null,
      );
    } catch (e) {
      if (cached.isEmpty) {
        state = state.copyWith(
          entries: [],
          isLoading: false,
          error: e.toString(),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Load the next page of entries. No-op if already loading or no more data.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      final entries = await _ref.read(journalRepositoryProvider).getEntries(
            limit: _pageSize,
            offset: state.entries.length,
          );
      state = state.copyWith(
        entries: [...state.entries, ...entries],
        isLoading: false,
        hasMore: entries.length >= _pageSize,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh from the beginning (pull-to-refresh).
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final entries = await _ref.read(journalRepositoryProvider).getEntries(
            limit: _pageSize,
            offset: 0,
          );
      final localStorage = _ref.read(localStorageProvider);
      for (final entry in entries) {
        await localStorage.cacheEntry(entry);
      }
      state = TimelineState(
        entries: entries,
        hasMore: entries.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Legacy provider — kept for backward compatibility with screens that use StreamProvider.
/// Delegates to the paginated controller's current state.
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
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'timelineEntriesProvider');
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

/// Truncate and sample entry texts to stay within AI token budget.
/// Server limit is 40K chars (~10K tokens). We cap at 35K to leave margin.
List<String> _sampleTexts(List<String> texts, {int maxTotalChars = 35000}) {
  // Truncate each entry to 2K chars, then take as many as fit in budget.
  final truncated = texts.map((t) => t.length > 2000 ? t.substring(0, 2000) : t);
  final result = <String>[];
  var totalLen = 0;
  for (final t in truncated) {
    if (totalLen + t.length > maxTotalChars) break;
    result.add(t);
    totalLen += t.length;
  }
  return result;
}

// --- Period-aware reflection providers ---

enum ReflectionPeriod { weekly, monthly, yearly }

/// Entries for a given reflection period (raw DB entries, used for mood charts
/// and highlight extraction — not fed directly to AI for monthly/yearly).
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

/// Cached AI summary for a given reflection period.
///
/// Hierarchy:
///   weekly  → summarises raw entry texts for the current ISO week
///   monthly → summarises the weekly summaries cached for this month
///   yearly  → summarises the monthly summaries cached for this year
///
/// AI is called at most ONCE per period window per user. Every subsequent
/// open of the same week/month/year is served from reflection_cache.
final reflectionSummaryProvider =
    FutureProvider.family<String?, ReflectionPeriod>((ref, period) async {
  final now = DateTime.now();
  final cache = ref.watch(reflectionCacheRepositoryProvider);

  final periodKey = switch (period) {
    ReflectionPeriod.weekly  => ReflectionCacheRepository.weeklyKey(now),
    ReflectionPeriod.monthly => ReflectionCacheRepository.monthlyKey(now),
    ReflectionPeriod.yearly  => ReflectionCacheRepository.yearlyKey(now),
  };

  // Serve from cache if available.
  final cached = await cache.get(period: period.name, periodKey: periodKey);
  if (cached?.summary != null) return cached!.summary;

  final language = ref.watch(localeProvider).languageName;
  final ai = ref.watch(aiServiceProvider);

  try {
    final String? summary;

    switch (period) {
      case ReflectionPeriod.weekly:
        final entries = await ref.watch(reflectionEntriesProvider(period).future);
        if (entries.isEmpty) return null;
        final texts = _sampleTexts(entries.map((e) => e.content).toList());
        summary = await ai.generateSummary(texts, period: 'weekly', language: language);

      case ReflectionPeriod.monthly:
        // Summarise the weekly summaries already cached for this month.
        final weeklies = await cache.getWeeklySummariesForMonth(now.year, now.month);
        if (weeklies.isEmpty) {
          // Fallback: summarise raw entries if no weekly cache exists yet.
          final entries = await ref.watch(reflectionEntriesProvider(period).future);
          if (entries.isEmpty) return null;
          final texts = _sampleTexts(entries.map((e) => e.content).toList());
          summary = await ai.generateSummary(texts, period: 'monthly', language: language);
        } else {
          summary = await ai.generateSummary(weeklies, period: 'monthly', language: language);
        }

      case ReflectionPeriod.yearly:
        // Summarise the monthly summaries already cached for this year.
        final monthlies = await cache.getMonthlySummariesForYear(now.year);
        if (monthlies.isEmpty) {
          // Fallback: sample raw entries if no monthly cache exists yet.
          final entries = await ref.watch(reflectionEntriesProvider(period).future);
          if (entries.isEmpty) return null;
          final raw = entries.map((e) => e.content).toList();
          final sampled = (raw.toList()..shuffle()).take(30).toList();
          final texts = _sampleTexts(sampled);
          summary = await ai.generateSummary(texts, period: 'yearly', language: language);
        } else {
          summary = await ai.generateSummary(monthlies, period: 'yearly', language: language);
        }
    }

    await cache.save(period: period.name, periodKey: periodKey, summary: summary);
    return summary;
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'reflectionSummaryProvider');
    return null;
  }
});

/// Cached AI themes for a given reflection period.
final reflectionThemesProvider =
    FutureProvider.family<List<String>, ReflectionPeriod>((ref, period) async {
  final now = DateTime.now();
  final cache = ref.watch(reflectionCacheRepositoryProvider);

  final periodKey = switch (period) {
    ReflectionPeriod.weekly  => ReflectionCacheRepository.weeklyKey(now),
    ReflectionPeriod.monthly => ReflectionCacheRepository.monthlyKey(now),
    ReflectionPeriod.yearly  => ReflectionCacheRepository.yearlyKey(now),
  };

  // Serve themes from cache if available.
  final cached = await cache.get(period: period.name, periodKey: periodKey);
  if (cached != null && cached.themes.isNotEmpty) return cached.themes;

  final entries = await ref.watch(reflectionEntriesProvider(period).future);
  if (entries.isEmpty) return [];

  final raw = entries.map((e) => e.content).toList();
  final presampled = period == ReflectionPeriod.yearly && raw.length > 30
      ? (raw.toList()..shuffle()).take(30).toList()
      : raw;
  final sampled = _sampleTexts(presampled);
  try {
    final themes = await ref.watch(aiServiceProvider).detectThemes(sampled);
    // Merge themes into whatever cache row already exists for this key.
    await cache.save(period: period.name, periodKey: periodKey, themes: themes);
    return themes;
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'reflectionThemesProvider');
    return [];
  }
});

// Legacy aliases — WeeklyReportScreen reads these; they now delegate to the
// unified cached providers so no AI duplication occurs.
final weeklySummaryProvider = FutureProvider<String?>((ref) =>
    ref.watch(reflectionSummaryProvider(ReflectionPeriod.weekly).future));
final weeklyThemesProvider = FutureProvider<List<String>>((ref) =>
    ref.watch(reflectionThemesProvider(ReflectionPeriod.weekly).future));

/// AI-generated writing prompt (refreshes each call; UI should cache per day).
final writingPromptProvider = FutureProvider<String?>((ref) async {
  final ai = ref.watch(aiServiceProvider);
  if (!ai.isConfigured) return null;
  try {
    return await ai.getWritingPrompt();
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'writingPromptProvider');
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
  } catch (e, st) {
    CrashReportingService().recordError(e, st, reason: 'bookCoverQueryProvider');
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
