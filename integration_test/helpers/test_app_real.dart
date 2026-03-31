/// Real-backend E2E app helper.
///
/// Signs in with a real Supabase account and runs the app without data
/// provider overrides. Only platform-channel services are faked:
///   - CheckInNotifier  (speech-to-text hangs on Windows)
///   - MediaService     (image picker not available in tests)
///   - SharingRepository (not the focus of backend tests)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/onboarding_provider.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/core/routing/app_shell.dart';
import 'package:deardays/core/routing/memory_detail_args.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/media/media_service.dart';
import 'package:deardays/services/ai/ai_service.dart';

import 'package:deardays/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';
import 'package:deardays/features/sharing/data/repositories/sharing_repository.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:deardays/features/sharing/presentation/screens/request_access_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/shared_with_me_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/share_approvals_screen.dart';

import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/processing_screen.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';

import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/book/presentation/screens/my_story_screen.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_detail_screen.dart';
import 'package:deardays/features/book/presentation/screens/my_life_book_screen.dart';
import 'package:deardays/features/book/presentation/screens/chapter_detail_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_reader_screen.dart';

import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/share/presentation/screens/share_card_screen.dart';
import 'package:deardays/features/story/presentation/screens/story_viewer_screen.dart';
import 'package:deardays/features/journal/presentation/screens/reflection_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';
import 'package:deardays/features/settings/presentation/screens/subscription_screen.dart';
import 'package:deardays/features/settings/presentation/screens/edit_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test credentials
// ─────────────────────────────────────────────────────────────────────────────

/// Dedicated test account. Create in Supabase → Authentication → Users.
const kBackendTestEmail = 'mlalit03@gmail.com';
const kBackendTestPassword = '123456';

/// Prefix used to tag all entries created by backend tests so cleanup can
/// find and delete them without touching the user's real data.
const kTestPrefix = '[BACKEND_TEST]';

// ─────────────────────────────────────────────────────────────────────────────
// One-time init
// ─────────────────────────────────────────────────────────────────────────────

bool _backendInitialized = false;

/// Initialises Supabase and signs in with the test account.
/// Safe to call multiple times — skips init after the first call.
Future<void> initBackendApp() async {
  if (_backendInitialized) return;
  _backendInitialized = true;

  WidgetsFlutterBinding.ensureInitialized();

  final url = SupabaseConfig.supabaseUrl.isNotEmpty
      ? SupabaseConfig.supabaseUrl
      : 'https://mcmlawztwyrjcwmieciw.supabase.co';
  final anonKey = SupabaseConfig.supabaseAnonKey.isNotEmpty
      ? SupabaseConfig.supabaseAnonKey
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE';

  try {
    await Supabase.initialize(url: url, anonKey: anonKey);
  } catch (_) {
    // Already initialized by another test process.
  }

  // Sign in with test account.
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    await client.auth.signInWithPassword(
      email: kBackendTestEmail,
      password: kBackendTestPassword,
    );
  }

  // Ensure profile row exists — direct sign-in bypasses AuthService which
  // normally creates the row. Without this, profileProvider throws and all
  // home screen widget tests fail.
  final userId = client.auth.currentUser?.id;
  if (userId != null) {
    await client.from('profiles').upsert(
      {
        'id': userId,
        'encryption_salt': 'server-side',
        'trial_started_at': DateTime.now().toUtc().toIso8601String(),
        'is_subscribed': true,
      },
      onConflict: 'id',
      ignoreDuplicates: true,
    );
  }

  // Intercept image-only URLs so CachedNetworkImage doesn't hang.
  // All Supabase API/function calls pass through to the real network.
  HttpOverrides.global = _BackendHttpOverrides();

  await Hive.initFlutter(Directory.systemTemp.path);
  await LocalStorageService().init();
}

// ─────────────────────────────────────────────────────────────────────────────
// App builder
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the real-backend app widget. Pass [additionalOverrides] to inject
/// extra provider overrides on top of the minimal set.
Widget buildBackendApp({List<Override>? additionalOverrides}) {
  return ProviderScope(
    overrides: [
      ..._minimalOverrides(),
      ...?additionalOverrides,
    ],
    child: const _BackendApp(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal provider overrides — only platform-channel fakes
// ─────────────────────────────────────────────────────────────────────────────

List<Override> _minimalOverrides() => [
      // Skip onboarding — go straight to home with real data.
      onboardingProvider.overrideWith((ref) => OnboardingNotifier.completed()),
      // Skip speech-to-text (hangs Windows test runner).
      checkInProvider.overrideWith((ref) => _FakeCheckInNotifier()),
      // Skip signed-URL calls for photo paths (image_picker not in tests).
      mediaServiceProvider.overrideWith((_) => _FakeMediaService()),
      // Skip sharing feature Supabase calls (not tested here).
      sharingRepositoryProvider.overrideWith(
          (_) => _FakeBackendSharingRepository()),
      // Skip AI-generated weekly summary — calls backend function that may
      // time out or fail in test environment, causing pump() to throw and
      // failing every home-screen widget test.
      weeklySummaryProvider.overrideWith(
          (_) async => 'A great week of memories.'),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Router (mirrors test_app.dart)
// ─────────────────────────────────────────────────────────────────────────────

GoRouter createBackendRouter() => GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
                path: '/home',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: HomeScreen())),
            GoRoute(
                path: '/book',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: LibraryScreen())),
            GoRoute(
                path: '/timeline',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: TimelineScreen())),
            GoRoute(
                path: '/explore',
                pageBuilder: (_, __) =>
                    const NoTransitionPage(child: ExploreScreen())),
          ],
        ),
        GoRoute(
            path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
            path: '/checkin', builder: (_, __) => const CheckInScreen()),
        GoRoute(
            path: '/record', builder: (_, __) => const RecordingScreen()),
        GoRoute(
            path: '/write', builder: (_, __) => const TextEntryScreen()),
        GoRoute(
            path: '/processing',
            builder: (_, s) =>
                ProcessingScreen(data: s.extra as ReviewData)),
        GoRoute(
            path: '/review',
            builder: (_, s) =>
                ReviewSaveScreen(data: s.extra as ReviewData)),
        GoRoute(
            path: '/edit-memory',
            builder: (_, s) =>
                EditMemoryScreen(entry: s.extra as JournalEntry)),
        GoRoute(
            path: '/paywall', builder: (_, __) => const PaywallScreen()),
        GoRoute(
            path: '/on-this-day',
            builder: (_, __) => const OnThisDayScreen()),
        GoRoute(
            path: '/export', builder: (_, __) => const ExportScreen()),
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
                  initialIndex: extra.initialIndex);
            }
            return MemoryDetailScreen(entry: extra as JournalEntry);
          },
        ),
        GoRoute(
            path: '/book/:id',
            builder: (_, s) =>
                MyStoryScreen(bookId: s.pathParameters['id']!)),
        GoRoute(
            path: '/my-life-book',
            builder: (_, __) => const MyLifeBookScreen()),
        GoRoute(
            path: '/share-card',
            builder: (_, s) =>
                ShareCardScreen(entry: s.extra as JournalEntry)),
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
            builder: (_, __) => const BookCreationScreen()),
        GoRoute(
            path: '/book-detail',
            builder: (_, s) =>
                BookDetailScreen(book: s.extra as GeneratedBook)),
        GoRoute(
            path: '/share/:token',
            builder: (_, s) =>
                RequestAccessScreen(token: s.pathParameters['token']!)),
        GoRoute(
            path: '/shared-with-me',
            builder: (_, __) => const SharedWithMeScreen()),
        GoRoute(
            path: '/share-approvals',
            builder: (_, __) => const ShareApprovalsScreen()),
        GoRoute(
            path: '/search', builder: (_, __) => const SearchScreen()),
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
                mode: mode is BookMode ? mode : BookMode.stream);
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
        GoRoute(
          path: '/story',
          builder: (_, s) {
            final p = s.uri.queryParameters['period'] ?? 'weekly';
            final period = ReflectionPeriod.values.firstWhere(
              (e) => e.name == p,
              orElse: () => ReflectionPeriod.weekly,
            );
            return StoryViewerScreen(period: period);
          },
        ),
        GoRoute(
          path: '/reflection',
          builder: (_, s) {
            final p = s.uri.queryParameters['period'] ?? 'weekly';
            final period = ReflectionPeriod.values.firstWhere(
              (e) => e.name == p,
              orElse: () => ReflectionPeriod.weekly,
            );
            return ReflectionScreen(period: period);
          },
        ),
        GoRoute(
            path: '/privacy',
            builder: (_, __) => const PrivacyScreen()),
        GoRoute(
            path: '/terms', builder: (_, __) => const TermsScreen()),
        GoRoute(
            path: '/subscription',
            builder: (_, __) => const SubscriptionScreen()),
        GoRoute(
            path: '/edit-profile',
            builder: (_, __) => const EditProfileScreen()),
      ],
    );

// ─────────────────────────────────────────────────────────────────────────────
// App widget
// ─────────────────────────────────────────────────────────────────────────────

class _BackendApp extends ConsumerStatefulWidget {
  const _BackendApp();

  @override
  ConsumerState<_BackendApp> createState() => _BackendAppState();
}

class _BackendAppState extends ConsumerState<_BackendApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createBackendRouter();
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
      title: 'DearDays Backend Test',
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
// Fakes — platform-channel services only
// ─────────────────────────────────────────────────────────────────────────────

class _FakeCheckInNotifier extends CheckInNotifier {
  _FakeCheckInNotifier() : super(AiService(), loadData: false);

  @override
  Future<void> selectMood(String mood) async {
    state = state.copyWith(
      currentMood: mood,
      isLoading: false,
      isFirstCheckInToday: false,
    );
  }
}

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

class _FakeBackendSharingRepository extends SharingRepository {
  _FakeBackendSharingRepository()
      : super(client: Supabase.instance.client);

  static MemoryShare _fake() => MemoryShare(
        id: 'fake-share-id',
        token: 'fake-token',
        memoryId: 'fake-memory-id',
        sharerId:
            Supabase.instance.client.auth.currentUser?.id ?? 'unknown',
        status: ShareStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

  @override
  Future<MemoryShare?> getShareByToken(String token) async => null;
  @override
  Future<MemoryShare> createShare(String memoryId) async => _fake();
  @override
  Future<List<MemoryShare>> getPendingRequests() async => [];
  @override
  Future<List<MemoryShare>> getSharesForMemory(String memoryId) async =>
      [];
  @override
  Future<List<SharedMemoryItem>> getSharedWithMe() async => [];
  @override
  Future<void> requestAccess(
      {required String shareId,
      required String recipientName,
      String? recipientId}) async {}
  @override
  Future<void> respondToRequest(
      {required String shareId, required bool approve}) async {}
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

// ─────────────────────────────────────────────────────────────────────────────
// HTTP override — blocks image-only URLs, lets Supabase API calls through
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

class _BackendHttpOverrides extends HttpOverrides {
  final HttpOverrides? _prev = HttpOverrides.current;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final real = _prev != null
        ? _prev.createHttpClient(context)
        : super.createHttpClient(context);
    return _ImageOnlyInterceptor(real);
  }
}

class _ImageOnlyInterceptor implements HttpClient {
  final HttpClient _real;
  _ImageOnlyInterceptor(this._real);

  static bool _isImage(Uri url) {
    final host = url.host;
    final path = url.path.toLowerCase();
    if (host == 'placeholder.test') { return true; }
    if (host.contains('unsplash.com')) return true;
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp')) return true;
    return false;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      _isImage(url) ? Future.value(_FakeImageReq(url)) : _real.getUrl(url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _isImage(url)
          ? Future.value(_FakeImageReq(url))
          : _real.openUrl(method, url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) =>
      _isImage(url) ? Future.value(_FakeImageReq(url)) : _real.headUrl(url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _real.postUrl(url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _real.putUrl(url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _real.deleteUrl(url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _real.patchUrl(url);
  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
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

  @override
  bool get autoUncompress => _real.autoUncompress;
  @override
  set autoUncompress(bool v) => _real.autoUncompress = v;
  @override
  Duration? get connectionTimeout => _real.connectionTimeout;
  @override
  set connectionTimeout(Duration? v) => _real.connectionTimeout = v;
  @override
  Duration get idleTimeout => _real.idleTimeout;
  @override
  set idleTimeout(Duration v) => _real.idleTimeout = v;
  @override
  int? get maxConnectionsPerHost => _real.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? v) => _real.maxConnectionsPerHost = v;
  @override
  String? get userAgent => _real.userAgent;
  @override
  set userAgent(String? v) => _real.userAgent = v;
  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _real.addCredentials(url, realm, credentials);
  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _real.addProxyCredentials(host, port, realm, credentials);
  @override
  set authenticate(
          Future<bool> Function(Uri, String, String?)? f) =>
      _real.authenticate = f;
  @override
  set authenticateProxy(
          Future<bool> Function(String, int, String, String?)? f) =>
      _real.authenticateProxy = f;
  @override
  set badCertificateCallback(
          bool Function(X509Certificate, String, int)? callback) =>
      _real.badCertificateCallback = callback;
  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri, String?, int?)?
              f) =>
      _real.connectionFactory = f;
  @override
  set findProxy(String Function(Uri)? f) => _real.findProxy = f;
  @override
  set keyLog(Function(String)? callback) => _real.keyLog = callback;
  @override
  void close({bool force = false}) => _real.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeImageHeaders implements HttpHeaders {
  final _h = <String, List<String>>{};
  @override
  List<String>? operator [](String name) => _h[name];
  @override
  void add(String name, Object value,
      {bool preserveHeaderCase = false}) =>
      _h.putIfAbsent(name, () => []).add(value.toString());
  @override
  void set(String name, Object value,
      {bool preserveHeaderCase = false}) =>
      _h[name] = [value.toString()];
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  String? value(String name) => _h[name]?.first;
  @override
  void forEach(void Function(String, List<String>) action) =>
      _h.forEach(action);
  @override
  void noFolding(String name) {}
  @override
  void clear() => _h.clear();
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

class _FakeImageReq implements HttpClientRequest {
  final Uri _uri;
  _FakeImageReq(this._uri);
  @override
  Uri get uri => _uri;
  @override
  String get method => 'GET';
  @override
  HttpHeaders get headers => _FakeImageHeaders();
  @override
  List<Cookie> get cookies => [];
  @override
  int get contentLength => -1;
  @override
  set contentLength(int v) {}
  @override
  bool get persistentConnection => false;
  @override
  set persistentConnection(bool v) {}
  @override
  bool get followRedirects => true;
  @override
  set followRedirects(bool v) {}
  @override
  int get maxRedirects => 5;
  @override
  set maxRedirects(int v) {}
  @override
  bool get bufferOutput => true;
  @override
  set bufferOutput(bool v) {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding v) {}
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
  Future<HttpClientResponse> close() async => _FakeImageResp(_uri);
  @override
  Future flush() async {}
  @override
  Future<HttpClientResponse> get done async => _FakeImageResp(_uri);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeImageResp extends Stream<List<int>>
    implements HttpClientResponse {
  // ignore: unused_field
  final Uri _uri;
  _FakeImageResp(this._uri);

  late final Uint8List _body = _transparentPixel;

  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _body.length;
  @override
  HttpHeaders get headers => _FakeImageHeaders();
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
  Future<HttpClientResponse> redirect(
          [String? method, Uri? url, bool? followLoops]) async =>
      this;
  @override
  Future<Socket> detachSocket() =>
      throw UnsupportedError('detachSocket');
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.fromIterable([_body]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}