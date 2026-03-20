import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';
import 'package:deardays/features/auth/presentation/screens/set_passphrase_screen.dart';
import 'package:deardays/features/auth/presentation/screens/e2e_passphrase_gate_screen.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
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
import 'package:deardays/features/book/presentation/screens/chapter_detail_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_reader_screen.dart';
import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/journal/presentation/screens/weekly_report_screen.dart';
import 'package:deardays/features/journal/presentation/screens/reflection_screen.dart';
import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/settings/presentation/screens/backup_restore_screen.dart';
import 'package:deardays/features/story/presentation/screens/story_viewer_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/request_access_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/shared_with_me_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/share_approvals_screen.dart';
import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    if (SupabaseConfig.supabaseUrl.isNotEmpty) {
      Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        notifyListeners();
      });
    }
  }
}

class AppRouter {
  AppRouter._();

  static const _publicPaths = {'/onboarding', '/login', '/set-passphrase', '/e2e-gate'};
  static bool _isPublicPath(String path) =>
      _publicPaths.contains(path) || path.startsWith('/share/');
  static final _authNotifier = _AuthChangeNotifier();

  static final router = GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      if (SupabaseConfig.supabaseUrl.isEmpty) return null;
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final currentPath = state.matchedLocation;

      if (!isLoggedIn && !_isPublicPath(currentPath)) {
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
          onLogin: () => context.go('/e2e-gate'),
        ),
      ),
      GoRoute(
        path: '/e2e-gate',
        builder: (context, state) => _E2EGateWidget(
          onDone: () => context.go('/home'),
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
        path: '/photo-entry',
        builder: (context, state) {
          final photoPath = state.extra;
          if (photoPath is! String) return const HomeScreen();
          return PhotoEntryScreen(photoPath: photoPath);
        },
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
          final extra = state.extra;
          if (extra is JournalEntry) {
            return EditMemoryScreen(entry: extra);
          }
          return const HomeScreen();
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
        path: '/explore/mood/:mood',
        builder: (context, state) {
          final mood = state.pathParameters['mood']!;
          return SeeAllTimelineScreen(
            section: SeeAllSection.mood,
            initialMoodFilter: mood,
          );
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
      GoRoute(
        path: '/chapter/:id',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Chapter) {
            return const HomeScreen();
          }
          return ChapterDetailScreen(chapter: extra);
        },
      ),
      GoRoute(
        path: '/book-reader',
        builder: (context, state) {
          final mode = state.extra;
          return BookReaderScreen(
            mode: mode is BookMode ? mode : BookMode.stream,
          );
        },
      ),

      // ── Sharing ──────────────────────────────────────────────────────────
      // Public: deep link from WhatsApp — no auth required
      GoRoute(
        path: '/share/:token',
        builder: (context, state) => RequestAccessScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      // Mum's inbox: memories shared with her
      GoRoute(
        path: '/shared-with-me',
        builder: (context, state) => const SharedWithMeScreen(),
      ),
      // Sarah's pending approval requests (all memories)
      GoRoute(
        path: '/share-approvals',
        builder: (context, state) => const ShareApprovalsScreen(),
      ),
    ],
  );
}

/// Checks whether E2E is enabled for the current user. If so, shows the
/// passphrase gate; otherwise passes straight through to [onDone].
/// This runs once at login time before the main shell is mounted.
class _E2EGateWidget extends StatefulWidget {
  final VoidCallback onDone;
  const _E2EGateWidget({required this.onDone});

  @override
  State<_E2EGateWidget> createState() => _E2EGateWidgetState();
}

class _E2EGateWidgetState extends State<_E2EGateWidget> {
  bool _checked = false;
  bool _needsGate = false;
  String? _salt;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // If the key is already loaded (e.g. passphrase changed mid-session),
    // skip the gate.
    if (EncryptionService().currentKey != null) {
      widget.onDone();
      return;
    }

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        widget.onDone();
        return;
      }

      final profile = await client
          .from('profiles')
          .select('e2e_enabled, e2e_salt')
          .eq('id', userId)
          .maybeSingle();

      final e2eEnabled = (profile?['e2e_enabled'] as bool?) ?? false;
      final salt = profile?['e2e_salt'] as String?;

      if (!e2eEnabled || salt == null) {
        if (mounted) widget.onDone();
        return;
      }

      if (mounted) {
        setState(() {
          _checked = true;
          _needsGate = true;
          _salt = salt;
        });
      }
    } catch (_) {
      // On any error (network, etc.) let the user through without E2E.
      if (mounted) widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      // Brief loading state while we fetch the profile.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsGate && _salt != null) {
      return E2EPassphraseGateScreen(
        e2eSalt: _salt!,
        onUnlocked: widget.onDone,
        onForgot: () async {
          // Disable E2E and delete encrypted entries, then proceed.
          final client = Supabase.instance.client;
          final userId = client.auth.currentUser?.id;
          if (userId != null) {
            await client.from('journal_entries')
                .delete()
                .eq('user_id', userId)
                .eq('is_client_encrypted', true);
            await client.from('profiles').update({
              'e2e_enabled': false,
              'e2e_salt': null,
              'e2e_enabled_at': null,
            }).eq('id', userId);
          }
          if (mounted) widget.onDone();
        },
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
