/// Mock entry point — bypasses auth and injects fake journal entries.
///
/// Run with:
///   flutter run -t lib/main_mock.dart
///
/// The app starts directly on the Home screen with pre-populated mock data
/// so you can review all UI screens without a real account or network.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/core/mock/mock_data.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';
import 'package:deardays/features/journal/data/models/streak.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';

// ── Screens ──────────────────────────────────────────────────────────────────
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/processing_screen.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_reader_screen.dart';
import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/book/presentation/screens/my_story_screen.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (needed so the client singleton exists — providers
  // are overridden so no real network calls are made for data).
  if (SupabaseConfig.supabaseUrl.isNotEmpty) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  await LocalStorageService().init();

  await RevenueCatService().init();
  await NotificationService().init();

  runApp(
    ProviderScope(
      overrides: _mockOverrides(),
      child: const _MockApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider overrides — inject mock data without touching real DB
// ─────────────────────────────────────────────────────────────────────────────

List<Override> _mockOverrides() {
  final now = DateTime.now();
  final mockProfile = UserProfile(
    id: 'mock-user',
    displayName: 'Alex',
    encryptionSalt: 'mock-salt',
    trialStartedAt: now,
    isSubscribed: true,
    createdAt: now.subtract(const Duration(days: 365)),
    consentGivenAt: now.subtract(const Duration(days: 365)),
  );
  final mockStreak = Streak(
    id: 'mock-streak',
    userId: 'mock-user',
    currentStreak: 7,
    longestStreak: 21,
    lastEntryDate: now,
    totalEntries: mockEntries.length,
  );

  return [
    // Journal entries (timeline, explore)
    timelineEntriesProvider.overrideWith((_) => Stream.value(mockEntries)),

    // Home screen stats
    moodStatsProvider.overrideWith((_) async => mockMoodStats),
    totalEntriesProvider.overrideWith((_) async => mockEntries.length),
    weeklyMoodsProvider.overrideWith((_) async => mockWeeklyMoods),

    // Today's entry — use the most recent mock
    todayEntryProvider.overrideWith((_) => Stream.value(mockEntries.first)),

    // On this day — pick 2 older entries (safe access in case mock list is short)
    onThisDayProvider.overrideWith((_) async =>
        mockEntries.length > 13 ? [mockEntries[12], mockEntries[13]] : mockEntries.take(2).toList()),

    // Weekly entries (for AI summary — returns empty to skip real AI call)
    weeklyEntriesProvider.overrideWith((_) async => mockEntries.take(5).toList()),

    // Profile & streak
    profileProvider.overrideWith((_) async => mockProfile),
    streakProvider.overrideWith((_) async => mockStreak),

    // Chapters — static mock list
    chaptersProvider.overrideWith((_) async {
      final now = DateTime(2024, 1, 1);
      return [
        Chapter(id: 'mock-ch-1', userId: 'mock-user', title: 'Family',          chapterNumber: 1, startDate: now, createdAt: now),
        Chapter(id: 'mock-ch-2', userId: 'mock-user', title: 'Career',          chapterNumber: 2, startDate: now, createdAt: now),
        Chapter(id: 'mock-ch-3', userId: 'mock-user', title: 'Travel',          chapterNumber: 3, startDate: now, createdAt: now),
        Chapter(id: 'mock-ch-4', userId: 'mock-user', title: 'Personal Growth', chapterNumber: 4, startDate: now, createdAt: now),
      ];
    }),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock router — same routes as AppRouter but starts at /home, no auth redirect
// ─────────────────────────────────────────────────────────────────────────────

final _mockRouter = GoRouter(
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
    GoRoute(path: '/book/:id', builder: (_, s) => MyStoryScreen(bookId: s.pathParameters['id']!)),
    GoRoute(path: '/checkin', builder: (_, __) => const CheckInScreen()),
    GoRoute(path: '/record', builder: (_, __) => const RecordingScreen()),
    GoRoute(path: '/processing', builder: (_, s) => ProcessingScreen(data: s.extra as ReviewData)),
    GoRoute(path: '/write', builder: (_, __) => const TextEntryScreen()),
    GoRoute(path: '/review', builder: (_, s) => ReviewSaveScreen(data: s.extra as ReviewData)),
    GoRoute(path: '/edit-memory', builder: (_, s) => EditMemoryScreen(entry: s.extra as JournalEntry)),
    GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
    GoRoute(path: '/on-this-day', builder: (_, __) => const OnThisDayScreen()),
    GoRoute(path: '/export', builder: (_, __) => const ExportScreen()),
    GoRoute(path: '/book-reader', builder: (_, s) {
      final mode = s.extra;
      return BookReaderScreen(mode: mode is BookMode ? mode : BookMode.stream);
    }),
    GoRoute(path: '/memory', builder: (_, s) {
      final extra = s.extra;
      if (extra is MemoryDetailArgs) {
        return MemoryDetailScreen(entry: extra.entry, allEntries: extra.allEntries, initialIndex: extra.initialIndex);
      }
      return MemoryDetailScreen(entry: extra as JournalEntry);
    }),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// App widget
// ─────────────────────────────────────────────────────────────────────────────

class _MockApp extends ConsumerWidget {
  const _MockApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final localeState = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'DearDays (Mock)',
      debugShowCheckedModeBanner: true,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.effectiveThemeMode,
      locale: localeState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _mockRouter,
    );
  }
}
