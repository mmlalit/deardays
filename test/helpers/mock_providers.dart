import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/book/data/models/book.dart';

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

/// Minimal CheckInNotifier for tests.
/// Extends CheckInNotifier so overrideWith type check passes.
/// Hive must be initialized before tests create this (call setUpTestEnv()).
class FakeCheckInNotifier extends CheckInNotifier {
  FakeCheckInNotifier() : super(AiService());
}

// ---------------------------------------------------------------------------
// Test environment setup — call in setUpAll() / tearDownAll()
// ---------------------------------------------------------------------------

/// Initializes Hive so CheckInNotifier._loadTodayData() doesn't throw.
void setUpTestEnv() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.path);
  });

  tearDownAll(() async {
    await Hive.close();
  });
}

// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

final _now = DateTime.now();

final mockProfile = UserProfile(
  id: 'test-user-id',
  displayName: 'Test User',
  encryptionSalt: 'mock-salt',
  writingStyle: 'memoir',
  bookOrganization: 'yearly',
  isSubscribed: false,
  biometricEnabled: false,
  trialStartedAt: _now,
  createdAt: _now,
);

final mockStreak = Streak(
  id: 'streak-id',
  userId: 'test-user-id',
  currentStreak: 3,
  longestStreak: 7,
  lastEntryDate: _now,
  totalEntries: 10,
);

final mockEntry = JournalEntry(
  id: 'entry-id',
  userId: 'test-user-id',
  content: 'Today was a great day.',
  rawContent: 'Today was a great day.',
  mood: 'great',
  entryDate: _now,
  wordCount: 6,
  createdAt: _now,
  updatedAt: _now,
);

final mockBook = Book(
  id: 'book-id',
  userId: 'test-user-id',
  title: 'My Story 2026',
  coverColor: '#6B4EFF',
  writingStyle: 'memoir',
  startDate: DateTime(2026, 1, 1),
  sortOrder: 0,
  createdAt: _now,
  updatedAt: _now,
);

// ---------------------------------------------------------------------------
// Provider overrides for authenticated screens
// ---------------------------------------------------------------------------

List<Override> authenticatedOverrides({
  List<JournalEntry> entries = const [],
  List<Book> books = const [],
  UserProfile? profile,
  Streak? streak,
  JournalEntry? todayEntry,
}) {
  final p = profile ?? mockProfile;
  final s = streak ?? mockStreak;
  return [
    checkInProvider.overrideWith((ref) => FakeCheckInNotifier()),
    profileProvider.overrideWith((ref) async => p),
    streakProvider.overrideWith((ref) async => s),
    todayEntryProvider.overrideWith((ref) async => todayEntry),
    onThisDayProvider.overrideWith((ref) async => entries),
    timelineEntriesProvider.overrideWith((ref) async => entries),
    booksProvider.overrideWith((ref) async => books),
    moodStatsProvider.overrideWith((ref) async => <String, int>{}),
    totalEntriesProvider.overrideWith((ref) async => entries.length),
    weeklyMoodsProvider
        .overrideWith((ref) async => <Map<String, String>>[]),
  ];
}
