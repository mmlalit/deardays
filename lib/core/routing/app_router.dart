import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';
import 'package:deardays/features/auth/presentation/screens/set_passphrase_screen.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/processing_screen.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/book/presentation/screens/my_story_screen.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';
import 'package:deardays/features/book/presentation/screens/my_life_book_screen.dart';
import 'package:deardays/features/share/presentation/screens/share_card_screen.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_detail_screen.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/journal/presentation/screens/weekly_report_screen.dart';
import 'package:deardays/features/journal/presentation/screens/reflection_screen.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/settings/presentation/screens/backup_restore_screen.dart';
import 'package:deardays/features/story/presentation/screens/story_viewer_screen.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

class AppRouter {
  AppRouter._();

  static const _publicPaths = {'/onboarding', '/login', '/set-passphrase'};
  static final _authNotifier = _AuthChangeNotifier();

  static final router = GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final currentPath = state.matchedLocation;

      if (!isLoggedIn && !_publicPaths.contains(currentPath)) {
        return '/login';
      }

      if (isLoggedIn && (currentPath == '/onboarding' || currentPath == '/login')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onComplete: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLogin: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/set-passphrase',
        builder: (context, state) => SetPassphraseScreen(
          onComplete: () => context.go('/home'),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/book',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: '/timeline',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TimelineScreen(),
            ),
          ),
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExploreScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) => MyStoryScreen(
          bookId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/checkin',
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const RecordingScreen(),
      ),
      GoRoute(
        path: '/processing',
        builder: (context, state) {
          final data = state.extra;
          if (data is! ReviewData) {
            return const HomeScreen();
          }
          return ProcessingScreen(data: data);
        },
      ),
      GoRoute(
        path: '/write',
        builder: (context, state) => const TextEntryScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) {
          final data = state.extra;
          if (data is! ReviewData) {
            return const HomeScreen();
          }
          return ReviewSaveScreen(data: data);
        },
      ),
      GoRoute(
        path: '/edit-memory',
        builder: (context, state) {
          final data = state.extra;
          if (data is! ReviewData) {
            return const HomeScreen();
          }
          return EditMemoryScreen(data: data);
        },
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/on-this-day',
        builder: (context, state) => const OnThisDayScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
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
        builder: (context, state) {
          final extra = state.extra;
          if (extra is MemoryDetailArgs) {
            return MemoryDetailScreen(
              entry: extra.entry,
              allEntries: extra.allEntries,
              initialIndex: extra.initialIndex,
            );
          }
          // Backward-compatible: bare JournalEntry
          final entry = extra as JournalEntry;
          return MemoryDetailScreen(entry: entry);
        },
      ),
      GoRoute(
        path: '/my-life-book',
        builder: (context, state) => const MyLifeBookScreen(),
      ),
      GoRoute(
        path: '/share-card',
        builder: (context, state) {
          final entry = state.extra;
          if (entry is! JournalEntry) {
            return const HomeScreen();
          }
          return ShareCardScreen(entry: entry);
        },
      ),
      GoRoute(
        path: '/post-save',
        builder: (context, state) {
          // Accept data from route extra OR from provider (provider
          // survives go_router refreshes caused by auth state changes).
          final extra = state.extra;
          if (extra is PostSaveData) {
            return PostSaveScreen(data: extra);
          }
          // Fallback: screen reads from postSaveDataProvider
          return const PostSaveScreen();
        },
      ),
      GoRoute(
        path: '/book-create',
        builder: (context, state) => const BookCreationScreen(),
      ),
      GoRoute(
        path: '/book-detail',
        builder: (context, state) {
          final book = state.extra;
          if (book is! GeneratedBook) {
            return const HomeScreen();
          }
          return BookDetailScreen(book: book);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/weekly-report',
        builder: (context, state) => const WeeklyReportScreen(),
      ),
      GoRoute(
        path: '/reflection',
        builder: (context, state) {
          final periodStr = state.uri.queryParameters['period'] ?? 'weekly';
          final period = ReflectionPeriod.values.firstWhere(
            (p) => p.name == periodStr,
            orElse: () => ReflectionPeriod.weekly,
          );
          return ReflectionScreen(period: period);
        },
      ),
      GoRoute(
        path: '/backup-restore',
        builder: (context, state) => const BackupRestoreScreen(),
      ),
      GoRoute(
        path: '/story',
        builder: (context, state) => const StoryViewerScreen(),
      ),
    ],
  );
}
