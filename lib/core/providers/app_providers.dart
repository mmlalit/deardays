import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/auth/auth_service.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/location/location_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/features/journal/data/repositories/journal_repository.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';

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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// --- Repositories ---

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(encryptionServiceProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
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
  final entries = await ref.watch(journalRepositoryProvider).getEntries(
        startDate: DateTime.now().copyWith(hour: 0, minute: 0, second: 0),
        endDate: DateTime.now(),
        limit: 1,
      );
  return entries.isEmpty ? null : entries.first;
});

final onThisDayProvider = FutureProvider<List<JournalEntry>>((ref) async {
  return ref.watch(journalRepositoryProvider).getOnThisDay();
});

final moodStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(journalRepositoryProvider).getMoodStats();
});

final totalEntriesProvider = FutureProvider<int>((ref) async {
  return ref.watch(journalRepositoryProvider).getTotalEntries();
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
