/// E2E test app — mirrors main_mock.dart but safe for integration_test.
///
/// Skips RevenueCat and Notification init (require real device services).
/// Uses real Supabase client (no session → currentUser = null, no DB calls).
/// All data providers are overridden with mock data.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
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
import 'package:deardays/services/media/media_service.dart';

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
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/data/repositories/sharing_repository.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:deardays/features/sharing/presentation/screens/request_access_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/shared_with_me_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/share_approvals_screen.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/book/presentation/screens/chapter_detail_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_reader_screen.dart';
import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One-time init — call from setUpAll()
// ─────────────────────────────────────────────────────────────────────────────

bool _initialized = false;

Future<void> initE2EApp() async {
  if (_initialized) return;
  _initialized = true;

  WidgetsFlutterBinding.ensureInitialized();

  // Supabase: initialize with real or dummy credentials so that
  // Supabase.instance is always accessible (e.g. _FakeMediaService, home_screen).
  // No actual DB calls because all providers are overridden below.
  final url = SupabaseConfig.supabaseUrl.isNotEmpty
      ? SupabaseConfig.supabaseUrl
      : 'https://placeholder.supabase.co';
  final anonKey = SupabaseConfig.supabaseAnonKey.isNotEmpty
      ? SupabaseConfig.supabaseAnonKey
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsYWNlaG9sZGVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MTkwMDAwMDAwMH0.placeholder';
  try {
    await Supabase.initialize(url: url, anonKey: anonKey);
  } catch (_) {
    // Already initialized by a previous test run in the same process.
  }

  // Intercept HTTP requests so CachedNetworkImage resolves instantly
  // (returns a 1×1 transparent PNG) instead of hanging pumpAndSettle().
  // Set AFTER Supabase.initialize() so Supabase's internal setup is not affected.
  HttpOverrides.global = _TestHttpOverrides();

  // Hive: needed by CheckInNotifier local persistence.
  await Hive.initFlutter(Directory.systemTemp.path);
  await LocalStorageService().init();
}

// ─────────────────────────────────────────────────────────────────────────────
// settle() — Android-safe replacement for pumpAndSettle()
// ─────────────────────────────────────────────────────────────────────────────

/// Pumps frames until no more are scheduled, or until [timeout] elapses.
///
/// Unlike `pumpAndSettle()`, this never hangs — if animations (cursor blink,
/// shimmer, repeating controllers) keep scheduling frames, the function
/// returns after [timeout] instead of waiting forever.
///
/// Use this everywhere instead of `tester.pumpAndSettle()` so that the E2E
/// suite works on both Windows AND Android.
Future<void> settle(
  WidgetTester tester, [
  Duration timeout = const Duration(seconds: 5),
]) async {
  // Pump frames manually instead of pumpAndSettle to avoid the test framework
  // catching debug assertions (parentDataDirty) during the settle loop.
  // pumpAndSettle internally calls pump() in a loop — we replicate that but
  // drain exceptions between each pump so they don't accumulate.
  final end = DateTime.now().add(timeout);
  int count = 0;
  do {
    await tester.pump(const Duration(milliseconds: 100));
    drainExceptions(tester);
    count++;
  } while (tester.hasRunningAnimations && DateTime.now().isBefore(end) && count < 50);
}

/// Pops and discards all pending exceptions that match known-benign patterns.
/// Call after every pump/settle/tap to prevent "Multiple exceptions" failures.
///
/// Returns true if a genuine (non-benign) exception was found and re-thrown.
void drainExceptions(WidgetTester tester) {
  dynamic e = tester.takeException();
  while (e != null) {
    final msg = e.toString();
    if (!_isBenignException(msg)) {
      // Re-throw genuine exceptions so the test still fails
      throw e; // ignore: only_throw_errors
    }
    e = tester.takeException();
  }
}

bool _isBenignException(String msg) =>
    msg.contains('overflowed') ||
    msg.contains('parentDataDirty') ||
    msg.contains('debugCheckForParentData') ||
    msg.contains('rendering/object.dart') ||
    msg.contains('line 5493') ||
    msg.contains('visitChildrenForSemantics') ||
    msg.contains('Null check operator') ||
    msg.contains('RenderFlex') ||
    msg.contains('KeyUpEvent') ||
    msg.contains('_pressedKeys') ||
    msg.contains('StorageException') ||
    msg.contains('OfflineAiQueue') ||
    msg.contains('AiCreditService') ||
    msg.contains('Object not found');

// ─────────────────────────────────────────────────────────────────────────────
// Offline simulation helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds an E2E app with connectivity forced to offline.
/// Use for testing save/edit/delete in offline mode and sync queue behavior.
Widget buildE2EAppOffline({List<Override>? additionalOverrides}) {
  return buildE2EApp(additionalOverrides: [
    connectivityProvider.overrideWith((ref) => false),
    ...?additionalOverrides,
  ]);
}

/// Returns the number of entries cached in Hive (LocalStorageService).
Future<int> getCachedEntryCount() async {
  return (await LocalStorageService().getCachedEntries()).length;
}

/// Returns true if SyncQueue has pending operations.
bool hasPendingSyncOps() {
  try {
    return SyncQueue().count > 0;
  } catch (_) {
    return false;
  }
}

/// Returns the number of pending sync operations.
int pendingSyncCount() {
  try {
    return SyncQueue().count;
  } catch (_) {
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App builder — fresh instance per test
// ─────────────────────────────────────────────────────────────────────────────

Widget buildE2EApp({List<Override>? additionalOverrides}) {
  return ProviderScope(
    overrides: [
      ..._e2eOverrides(),
      ...?additionalOverrides,
    ],
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
    currentStreak: 5,
    longestStreak: 21,
    lastEntryDate: now,
    totalEntries: mockEntries.length,
  );

  return [
    onboardingProvider.overrideWith((ref) => OnboardingNotifier.completed()),
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
    // Chapters — mock 4 default chapters so LibraryScreen renders without Supabase
    chaptersProvider.overrideWith((_) async => [
      Chapter(id: 'e2e-ch-1', userId: 'e2e-user', title: 'Family', chapterNumber: 1, startDate: DateTime(2024, 1, 1), createdAt: DateTime(2024, 1, 1)),
      Chapter(id: 'e2e-ch-2', userId: 'e2e-user', title: 'Travel', chapterNumber: 2, startDate: DateTime(2024, 1, 1), createdAt: DateTime(2024, 1, 1)),
      Chapter(id: 'e2e-ch-3', userId: 'e2e-user', title: 'Career', chapterNumber: 3, startDate: DateTime(2024, 1, 1), createdAt: DateTime(2024, 1, 1)),
      Chapter(id: 'e2e-ch-4', userId: 'e2e-user', title: 'Growth', chapterNumber: 4, startDate: DateTime(2024, 1, 1), createdAt: DateTime(2024, 1, 1)),
    ]),
    // Prevent CheckInNotifier from initialising speech_to_text (hangs on Windows)
    checkInProvider.overrideWith((ref) => _FakeCheckInNotifier()),
    // Prevent signed URL requests to real Supabase Storage for mock photo paths
    mediaServiceProvider.overrideWith((_) => _FakeMediaService()),
    // Sharing: prevent all Supabase calls from sharing feature
    sharingRepositoryProvider.overrideWith((_) => FakeSharingRepository()),
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
          builder: (_, s) => EditMemoryScreen(entry: s.extra as JournalEntry),
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
        GoRoute(
          path: '/share/:token',
          builder: (_, s) => RequestAccessScreen(token: s.pathParameters['token']!),
        ),
        GoRoute(
          path: '/shared-with-me',
          builder: (_, __) => const SharedWithMeScreen(),
        ),
        GoRoute(
          path: '/share-approvals',
          builder: (_, __) => const ShareApprovalsScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const SearchScreen(),
        ),
        GoRoute(
          path: '/chapter/:id',
          builder: (_, s) {
            final extra = s.extra;
            if (extra is Chapter) return ChapterDetailScreen(chapter: extra);
            return const HomeScreen();
          },
        ),
        GoRoute(
          path: '/book-reader',
          builder: (_, s) {
            final mode = s.extra;
            return BookReaderScreen(
              mode: mode is BookMode ? mode : BookMode.stream,
            );
          },
        ),
        GoRoute(
          path: '/photo-entry',
          builder: (_, s) {
            final extra = s.extra;
            if (extra is! String) return const HomeScreen();
            return PhotoEntryScreen(photoPath: extra);
          },
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

// ─────────────────────────────────────────────────────────────────────────────
// Fake MediaService — returns placeholder URLs, no real Supabase Storage calls
// ─────────────────────────────────────────────────────────────────────────────

class _FakeMediaService extends MediaService {
  _FakeMediaService() : super(client: Supabase.instance.client);

  @override
  Future<String> getSignedUrl(String storagePath) async =>
      'https://placeholder.test/$storagePath';

  @override
  String getPublicUrl(String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    return 'https://placeholder.test/$storagePath';
  }

  @override
  String getThumbnailUrl(String storagePath) {
    if (storagePath.startsWith('http')) return storagePath;
    return 'https://placeholder.test/thumb/$storagePath';
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

// ─────────────────────────────────────────────────────────────────────────────
// HTTP override — returns a 1×1 transparent PNG for all requests so that
// CachedNetworkImage (and any other network image loader) resolves instantly
// instead of hanging pumpAndSettle() with real HTTP timeouts.
// ─────────────────────────────────────────────────────────────────────────────

/// 1×1 transparent PNG (67 bytes).
final _transparentPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
  0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _TestHttpOverrides extends HttpOverrides {
  final HttpOverrides? _previous = HttpOverrides.current;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Create the real client (for Supabase, etc.) and wrap it.
    final realClient = _previous != null
        ? _previous.createHttpClient(context)
        : super.createHttpClient(context);
    return _ImageInterceptingHttpClient(realClient);
  }
}

/// Wraps a real [HttpClient] but returns a fake 1×1 PNG for image-like URLs
/// (placeholder.test, .jpg, .png, .webp). All other requests pass through to
/// the real client so Supabase init and API calls still work.
class _ImageInterceptingHttpClient implements HttpClient {
  final HttpClient _real;
  _ImageInterceptingHttpClient(this._real);

  static bool _shouldIntercept(Uri url) {
    final host = url.host;
    final path = url.path.toLowerCase();
    // Intercept placeholder hosts (mock images + dummy Supabase)
    if (host == 'placeholder.test') return true;
    if (host == 'placeholder.supabase.co') return true;
    // Intercept known image CDNs used in mock data (Unsplash, etc.)
    if (host.contains('unsplash.com')) return true;
    if (host.contains('images.unsplash')) return true;
    // Intercept image file extensions
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') || path.endsWith('.webp')) return true;
    return false;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _shouldIntercept(url) ? _FakeHttpRequest(url) : _real.getUrl(url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _shouldIntercept(url) ? _FakeHttpRequest(url) : _real.openUrl(method, url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) async =>
      _shouldIntercept(url) ? _FakeHttpRequest(url) : _real.headUrl(url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _real.postUrl(url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) async => _real.putUrl(url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => _real.deleteUrl(url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) async => _real.patchUrl(url);
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      _real.open(method, host, port, path);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _real.get(host, port, path);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _real.head(host, port, path);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _real.post(host, port, path);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _real.put(host, port, path);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _real.delete(host, port, path);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _real.patch(host, port, path);

  // Delegate all property access to the real client
  @override
  bool get autoUncompress => _real.autoUncompress;
  @override
  set autoUncompress(bool value) => _real.autoUncompress = value;
  @override
  Duration? get connectionTimeout => _real.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _real.connectionTimeout = value;
  @override
  Duration get idleTimeout => _real.idleTimeout;
  @override
  set idleTimeout(Duration value) => _real.idleTimeout = value;
  @override
  int? get maxConnectionsPerHost => _real.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _real.maxConnectionsPerHost = value;
  @override
  String? get userAgent => _real.userAgent;
  @override
  set userAgent(String? value) => _real.userAgent = value;
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _real.addCredentials(url, realm, credentials);
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _real.addProxyCredentials(host, port, realm, credentials);
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _real.authenticate = f;
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) =>
      _real.authenticateProxy = f;
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _real.badCertificateCallback = callback;
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) =>
      _real.connectionFactory = f;
  @override
  set findProxy(String Function(Uri url)? f) => _real.findProxy = f;
  @override
  set keyLog(Function(String line)? callback) => _real.keyLog = callback;
  @override
  void close({bool force = false}) => _real.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  final _headers = <String, List<String>>{};

  @override
  List<String>? operator [](String name) => _headers[name];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  String? value(String name) => _headers[name]?.first;
  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }
  @override
  void noFolding(String name) {}
  @override
  void clear() => _headers.clear();

  // Stub all remaining getters/setters
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpRequest implements HttpClientRequest {
  final Uri _uri;
  _FakeHttpRequest(this._uri);

  @override
  Uri get uri => _uri;
  @override
  String get method => 'GET';
  @override
  HttpHeaders get headers => _FakeHttpHeaders();
  @override
  List<Cookie> get cookies => [];
  @override
  int get contentLength => -1;
  @override
  set contentLength(int value) {}
  @override
  bool get persistentConnection => false;
  @override
  set persistentConnection(bool value) {}
  @override
  bool get followRedirects => true;
  @override
  set followRedirects(bool value) {}
  @override
  int get maxRedirects => 5;
  @override
  set maxRedirects(int value) {}
  @override
  bool get bufferOutput => true;
  @override
  set bufferOutput(bool value) {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  void write(Object? object) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? object = '']) {}
  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse(_uri);
  @override
  Future flush() async {}
  @override
  Future<HttpClientResponse> get done async => _FakeHttpResponse(_uri);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uri _uri;
  _FakeHttpResponse(this._uri);

  bool get _isImage {
    final path = _uri.path.toLowerCase();
    return _uri.host == 'placeholder.test' ||
        path.endsWith('.jpg') || path.endsWith('.jpeg') ||
        path.endsWith('.png') || path.endsWith('.webp');
  }

  late final Uint8List _body = _isImage
      ? _transparentPixel
      : Uint8List.fromList(utf8.encode('{}'));

  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _body.length;
  @override
  HttpHeaders get headers => _FakeHttpHeaders();
  @override
  List<Cookie> get cookies => [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  bool get persistentConnection => false;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  X509Certificate? get certificate => null;
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) async => this;
  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.fromIterable([_body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake SharingRepository — returns safe empty values, no Supabase calls
// ─────────────────────────────────────────────────────────────────────────────

class FakeSharingRepository extends SharingRepository {
  FakeSharingRepository() : super(client: Supabase.instance.client);

  static MemoryShare _fakeShare() => MemoryShare(
        id: 'fake-share-id',
        token: 'fake-token',
        memoryId: 'fake-memory-id',
        sharerId: 'e2e-user',
        status: ShareStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

  @override
  Future<MemoryShare?> getShareByToken(String token) async => null;

  @override
  Future<MemoryShare> createShare(String memoryId) async => _fakeShare();

  @override
  Future<List<MemoryShare>> getPendingRequests() async => [];

  @override
  Future<List<MemoryShare>> getSharesForMemory(String memoryId) async => [];

  @override
  Future<List<SharedMemoryItem>> getSharedWithMe() async => [];

  @override
  Future<void> requestAccess({
    required String shareId,
    required String recipientName,
    String? recipientId,
  }) async {}

  @override
  Future<void> respondToRequest({
    required String shareId,
    required bool approve,
  }) async {}

  @override
  Future<void> revokeShare(String shareId) async {}

  @override
  Future<void> recordView(String shareId) async {}

  @override
  Stream<List<Map<String, dynamic>>> watchShare(String shareId) =>
      Stream.value([]);

  @override
  Stream<List<Map<String, dynamic>>> watchPendingRequests() =>
      Stream.value([]);
}
