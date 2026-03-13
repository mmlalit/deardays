/// E2E test app — mirrors main_mock.dart but safe for integration_test.
///
/// Skips RevenueCat and Notification init (require real device services).
/// Uses real Supabase client (no session → currentUser = null, no DB calls).
/// All data providers are overridden with mock data.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/core/mock/mock_data.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:deardays/services/storage/local_storage_service.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/services/ai/ai_service.dart';

// ── Screens ──────────────────────────────────────────────────────────────────
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/processing_screen.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/book/presentation/screens/my_story_screen.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_detail_screen.dart';
import 'package:deardays/features/book/presentation/screens/my_life_book_screen.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';
import 'package:deardays/features/share/presentation/screens/share_card_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One-time init — call from setUpAll()
// ─────────────────────────────────────────────────────────────────────────────

bool _initialized = false;

Future<void> initE2EApp() async {
  if (_initialized) return;
  _initialized = true;

  WidgetsFlutterBinding.ensureInitialized();

  // Supabase: real client, but no stored session → currentUser = null.
  // No actual DB calls because all providers are overridden below.
  if (SupabaseConfig.supabaseUrl.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized by a previous test run in the same process.
    }
  }

  // Hive: needed by CheckInNotifier local persistence.
  await Hive.initFlutter(Directory.systemTemp.path);
  await LocalStorageService().init();
}

// ─────────────────────────────────────────────────────────────────────────────
// App builder — fresh instance per test
// ─────────────────────────────────────────────────────────────────────────────

Widget buildE2EApp() {
  return ProviderScope(
    overrides: _e2eOverrides(),
    child: const _E2EApp(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider overrides — all data comes from mock_data.dart, no network
// ─────────────────────────────────────────────────────────────────────────────

List<Override> _e2eOverrides() {
  final now = DateTime.now();

  final profile = UserProfile(
    id: 'e2e-user',
    displayName: 'Alex',
    encryptionSalt: 'e2e-salt',
    trialStartedAt: now,
    isSubscribed: true,
    createdAt: now.subtract(const Duration(days: 365)),
    consentGivenAt: now.subtract(const Duration(days: 365)),
  );

  final streak = Streak(
    id: 'e2e-streak',
    userId: 'e2e-user',
    currentStreak: 7,
    longestStreak: 21,
    lastEntryDate: now,
    totalEntries: mockEntries.length,
  );

  return [
    // All data providers → mock data, no DB calls
    profileProvider.overrideWith((_) async => profile),
    streakProvider.overrideWith((_) async => streak),
    timelineEntriesProvider.overrideWith((_) => Stream.value(mockEntries)),
    todayEntryProvider.overrideWith((_) => Stream.value(mockEntries.first)),
    onThisDayProvider.overrideWith((_) async => mockEntries.take(2).toList()),
    moodStatsProvider.overrideWith((_) async => mockMoodStats),
    totalEntriesProvider.overrideWith((_) async => mockEntries.length),
    weeklyMoodsProvider.overrideWith((_) async => mockWeeklyMoods),
    weeklyEntriesProvider.overrideWith((_) async => mockEntries.take(5).toList()),
    weeklySummaryProvider.overrideWith((_) async => 'A wonderful week of memories and moments shared with the people you love.'),
    booksProvider.overrideWith((_) async => [
      Book(
        id: 'e2e-book-id',
        userId: 'e2e-user',
        title: 'My Life Story',
        coverColor: '#6B4EFF',
        writingStyle: 'memoir',
        startDate: DateTime(2025, 1, 1),
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ]),
    // Prevent CheckInNotifier from initialising speech_to_text (hangs on Windows)
    checkInProvider.overrideWith((ref) => _FakeCheckInNotifier()),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Router — same routes as main_mock.dart, fresh instance per build
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _createRouter() => GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
            ),
            GoRoute(
              path: '/book',
              pageBuilder: (_, __) => const NoTransitionPage(child: LibraryScreen()),
            ),
            GoRoute(
              path: '/timeline',
              pageBuilder: (_, __) => const NoTransitionPage(child: TimelineScreen()),
            ),
            GoRoute(
              path: '/explore',
              pageBuilder: (_, __) => const NoTransitionPage(child: ExploreScreen()),
            ),
          ],
        ),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/checkin', builder: (_, __) => const CheckInScreen()),
        GoRoute(path: '/record', builder: (_, __) => const RecordingScreen()),
        GoRoute(path: '/write', builder: (_, __) => const TextEntryScreen()),
        GoRoute(
          path: '/processing',
          builder: (_, s) => ProcessingScreen(data: s.extra as ReviewData),
        ),
        GoRoute(
          path: '/review',
          builder: (_, s) => ReviewSaveScreen(data: s.extra as ReviewData),
        ),
        GoRoute(
          path: '/edit-memory',
          builder: (_, s) => EditMemoryScreen(data: s.extra as ReviewData),
        ),
        GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
        GoRoute(path: '/on-this-day', builder: (_, __) => const OnThisDayScreen()),
        GoRoute(path: '/export', builder: (_, __) => const ExportScreen()),
        GoRoute(
          path: '/explore/see-all/:section',
          builder: (context, state) {
            final sectionStr = state.pathParameters['section']!;
            final section = SeeAllSection.values.firstWhere(
              (s) => s.name == sectionStr,
              orElse: () => SeeAllSection.happiest,
            );
            return SeeAllTimelineScreen(section: section);
          },
        ),
        GoRoute(
          path: '/memory',
          builder: (_, s) {
            final extra = s.extra;
            if (extra is MemoryDetailArgs) {
              return MemoryDetailScreen(
                entry: extra.entry,
                allEntries: extra.allEntries,
                initialIndex: extra.initialIndex,
              );
            }
            return MemoryDetailScreen(entry: extra as JournalEntry);
          },
        ),
        GoRoute(
          path: '/book/:id',
          builder: (_, s) => MyStoryScreen(bookId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/my-life-book',
          builder: (_, __) => const MyLifeBookScreen(),
        ),
        GoRoute(
          path: '/share-card',
          builder: (_, s) => ShareCardScreen(entry: s.extra as JournalEntry),
        ),
        GoRoute(
          path: '/post-save',
          builder: (_, s) {
            final extra = s.extra;
            if (extra is PostSaveData) return PostSaveScreen(data: extra);
            return const PostSaveScreen();
          },
        ),
        GoRoute(
          path: '/book-create',
          builder: (_, __) => const BookCreationScreen(),
        ),
        GoRoute(
          path: '/book-detail',
          builder: (_, s) => BookDetailScreen(book: s.extra as GeneratedBook),
        ),
      ],
    );

// ─────────────────────────────────────────────────────────────────────────────
// App widget
// ─────────────────────────────────────────────────────────────────────────────

class _E2EApp extends ConsumerStatefulWidget {
  const _E2EApp();

  @override
  ConsumerState<_E2EApp> createState() => _E2EAppState();
}

class _E2EAppState extends ConsumerState<_E2EApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final localeState = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'DearDays E2E',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.effectiveThemeMode,
      locale: localeState.locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      routerConfig: _router,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake CheckInNotifier — skips Hive box load and speech_to_text init
// ─────────────────────────────────────────────────────────────────────────────

class _FakeCheckInNotifier extends CheckInNotifier {
  _FakeCheckInNotifier() : super(AiService(), loadData: false);

  /// Skip AI HTTP call — immediately transition to chat state so tests don't
  /// hang waiting for a network response that will never succeed.
  @override
  Future<void> selectMood(String mood) async {
    state = state.copyWith(
      currentMood: mood,
      isLoading: false,
      isFirstCheckInToday: false,
    );
  }
}
