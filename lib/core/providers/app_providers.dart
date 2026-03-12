import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/location/location_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/core/demo/demo_data.dart';
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

// Re-export SyncStatus so widgets can import from app_providers
export 'package:deardays/services/sync/sync_service.dart' show SyncStatus;

// --- Sync & Connectivity ---

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);
final connectivityProvider = StateProvider<bool>((ref) => true);

// --- Demo Mode ---

/// When true, all data providers return static demo data instead of
/// making real network/database calls.
/// Defaults to true so the app always looks great with sample content.
final demoModeProvider = StateProvider<bool>((ref) => true);

// --- Core Services ---

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
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

// --- Repositories ---

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(
    client: ref.watch(supabaseClientProvider),
    encryption: ref.watch(encryptionServiceProvider),
  );
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
  if (ref.watch(demoModeProvider)) return DemoData.profile;
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getProfile();
});

final streakProvider = FutureProvider<Streak?>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.streak;
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
  if (ref.watch(demoModeProvider)) return DemoData.books;
  ref.watch(authStateProvider);
  return ref.watch(bookRepositoryProvider).getBooks();
});

// --- Journal Entries ---

final entriesProvider =
    FutureProvider.family<List<JournalEntry>, EntriesFilter>((ref, filter) async {
  return ref.watch(journalRepositoryProvider).getEntries(
        startDate: filter.startDate,
        endDate: filter.endDate,
        mood: filter.mood,
        limit: filter.limit,
        offset: filter.offset,
      );
});

final todayEntryProvider = FutureProvider<JournalEntry?>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.entries.first;
  final now = DateTime.now().toUtc();
  final startOfDay = DateTime.utc(now.year, now.month, now.day);
  final entries = await ref.watch(journalRepositoryProvider).getEntries(
        startDate: startOfDay,
        endDate: now,
        limit: 1,
      );
  return entries.isEmpty ? null : entries.first;
});

final onThisDayProvider = FutureProvider<List<JournalEntry>>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.entries.take(2).toList();
  return ref.watch(journalRepositoryProvider).getOnThisDay();
});

final moodStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.moodStats;
  return ref.watch(journalRepositoryProvider).getMoodStats();
});

final totalEntriesProvider = FutureProvider<int>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.streak.totalEntries;
  return ref.watch(journalRepositoryProvider).getTotalEntries();
});

/// All entries for the timeline screen (most recent, paginated).
final timelineEntriesProvider =
    FutureProvider<List<JournalEntry>>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.entries;
  return ref.watch(journalRepositoryProvider).getEntries(limit: 50);
});

// --- Insights ---

/// Mood values for the last 7 days (for the weekly bar chart).
final weeklyMoodsProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.weeklyMoods;
  return ref.watch(journalRepositoryProvider).getMoodsByDateRange(days: 7);
});

/// Mood breakdown for the last 30 days.
final monthlyMoodStatsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.moodStats;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 1, now.day);
  return ref
      .watch(journalRepositoryProvider)
      .getMoodStatsByRange(start: start, end: now);
});

/// Weekly entries for AI summary generation.
final weeklyEntriesProvider =
    FutureProvider<List<JournalEntry>>((ref) async {
  if (ref.watch(demoModeProvider)) return DemoData.entries;
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
