import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/services/ai/ai_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/book/data/models/book.dart';

// ---------------------------------------------------------------------------
// In-memory PKCE storage — avoids SharedPreferences platform channel in tests.
// ---------------------------------------------------------------------------

class _InMemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final _map = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _map[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _map[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _map.remove(key);
}

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

/// Initializes Hive + Supabase (fake) so screens that call
/// Supabase.instance or open Hive boxes don't throw.
void setUpTestEnv() {
  setUpAll(() async {
    // Prevent google_fonts from making HTTP requests during tests.
    // Font files in assets/fonts/ satisfy the asset-bundle lookup so no
    // exceptions are thrown; the fallback glyph shapes differ from production
    // but layout geometry is stable.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Mock path_provider channels so flutter_cache_manager (used by
    // CachedNetworkImage) doesn't throw MissingPluginException in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => Directory.systemTemp.path,
    );

    Hive.init(Directory.systemTemp.path);

    // Initialize Supabase with placeholder credentials so screens that call
    // Supabase.instance.client don't fail the _isInitialized assertion.
    // Supabase.initialize is idempotent — a second call is silently ignored.
    // EmptyLocalStorage + _InMemoryGotrueAsyncStorage avoid SharedPreferences.
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-anon-key',
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _InMemoryGotrueAsyncStorage(),
      ),
    );
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
// App builder with correct AppPalette theme extension
// ---------------------------------------------------------------------------

/// Wraps [child] in ProviderScope + MaterialApp using AppTheme.light so that
/// AppColors.of(context) can resolve the AppPalette ThemeExtension.
Widget buildTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

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
    demoModeProvider.overrideWith((ref) => false),
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
