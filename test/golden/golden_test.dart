/// Golden (screenshot regression) tests for DearDays key screens.
///
/// FIRST RUN / after UI changes — regenerate baselines:
///   flutter test test/golden/golden_test.dart --update-goldens
///
/// SUBSEQUENT RUNS — compare against baselines:
///   flutter test test/golden/golden_test.dart
///
/// ⚠️  Goldens must be regenerated after the following redesign changes:
///   • Home screen: mood check-in row, 2×2 capture grid (SPEAK IT/SNAP IT/
///     WRITE/CHAT), Journal Activity card with 7-day tiles
///   • Checklist card: circular % progress ring (replaces linear bar)
///   • AppShell: glass header (DdLogo + wordmark + history/search/avatar)
///     and glass BottomAppBar with notched Snap FAB — note that goldens
///     render screens in isolation (no AppShell), so the glass header is
///     NOT captured in screen goldens.
///
/// Golden files are stored next to this file at test/golden/goldens/*.png
/// and should be committed to version control.
///
/// Notes:
/// • GoogleFonts.config.allowRuntimeFetching = false is set by setUpTestEnv(),
///   so text renders with the fallback system font — layout is stable across
///   machines but font glyphs will differ from production.
/// • CachedNetworkImage widgets show their placeholder/error state (no network
///   in widget tests). The layout grid is still fully exercised.
/// • Goldens are Windows-only snapshots; they will differ on macOS/Linux.

library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';

// New screen imports for expanded golden tests
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import 'package:deardays/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';
import 'package:deardays/features/settings/presentation/screens/subscription_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_detail_screen.dart';
import 'package:deardays/features/book/data/models/generated_book.dart';
import 'package:deardays/features/share/presentation/screens/share_card_screen.dart';
import 'package:deardays/features/journal/presentation/screens/post_save_screen.dart';
import 'package:deardays/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:deardays/core/providers/subscription_providers.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/features/journal/data/models/chapter.dart';

// Group 1 — Simple screens
import 'package:deardays/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:deardays/features/auth/presentation/screens/signup_screen.dart';
import 'package:deardays/features/settings/presentation/screens/cookie_policy_screen.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';

// Group 2 — Flow screens
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import 'package:deardays/features/journal/presentation/screens/reflection_screen.dart';

// Group 3 — Sharing screens
import 'package:deardays/features/sharing/presentation/screens/shared_with_me_screen.dart';
import 'package:deardays/features/sharing/presentation/screens/share_approvals_screen.dart';
import 'package:deardays/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:deardays/features/sharing/data/models/memory_share.dart';

// Group 4 — Book screens
import 'package:deardays/features/book/presentation/screens/book_reader_screen.dart';
import 'package:deardays/features/book/data/models/book_page.dart' show BookMode;
import 'package:deardays/features/book/presentation/screens/chapter_detail_screen.dart';

// Group 5 — Auth security screens
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';

import '../helpers/mock_providers.dart';

final _now = DateTime.now();

// ─── Mock data for new golden tests ─────────────────────────────────────────

final _mockGeneratedBook = GeneratedBook(
  id: 'gen-book-id',
  title: 'My Life Story',
  author: 'Test Author',
  dateRange: 'Jan 2026 - Mar 2026',
  createdAt: DateTime.now(),
  chapters: const [
    BookChapter(title: 'Chapter 1', startPage: 1, pages: [
      BookPage(
        pageNumber: 1,
        type: BookPageType.chapterDivider,
        content: 'Chapter 1',
        chapterTitle: 'Chapter 1',
      ),
      BookPage(
        pageNumber: 2,
        type: BookPageType.entryContent,
        content: 'A wonderful memory.',
        dateLabel: 'January 15, 2026',
      ),
    ]),
  ],
  allPages: const [
    BookPage(pageNumber: 0, type: BookPageType.titlePage, content: 'My Life Story'),
    BookPage(
      pageNumber: 1,
      type: BookPageType.chapterDivider,
      content: 'Chapter 1',
      chapterTitle: 'Chapter 1',
    ),
    BookPage(
      pageNumber: 2,
      type: BookPageType.entryContent,
      content: 'A wonderful memory.',
      dateLabel: 'January 15, 2026',
    ),
  ],
  sourceEntries: const [],
);

const _mockPostSaveData = PostSaveData(
  entryId: 'entry-id',
  title: 'A Great Day',
  content: 'Today was a great day full of sunshine and laughter.',
);

/// Fake SubscriptionNotifier that does not call RevenueCat.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier() : super(RevenueCatService());

  @override
  Future<void> refresh() async {
    // no-op — avoid real RevenueCat calls in tests
  }
}

/// Provider overrides that include subscriptionProvider for screens needing it.
List<Override> _subsOverrides() {
  return [
    ...authenticatedOverrides(),
    subscriptionProvider.overrideWith((_) => _FakeSubscriptionNotifier()),
  ];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// A phone-sized viewport (logical px, dpr 1.0) that gives consistent goldens
/// across different host monitor resolutions.
const _goldenSize = Size(390, 844);

/// Wraps [screen] with the full provider + theme stack (light theme).
Widget _app(Widget screen, {List<Override>? overrides}) {
  return buildTestApp(screen, overrides: overrides ?? authenticatedOverrides());
}

/// Wraps [screen] with a specific [ThemeData].
Widget _themedApp(Widget screen, ThemeData theme, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? authenticatedOverrides(),
    child: MaterialApp(theme: theme, home: screen),
  );
}

/// Pump the widget, let async providers settle, then wait for any animations
/// that fire on first build (shimmer, flutter_animate, etc.).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  await tester.pump();
}

/// Configure the test viewport to [size] at 1× density and restore on teardown.
void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpTestEnv();

  // ── Login Screen ───────────────────────────────────────────────────────────

  group('Golden — LoginScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(onLogin: () {}),
        ),
      );
      // AuthShell has a repeating orb animation — pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_light.png'),
      );
    });

    testWidgets('dark theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(onLogin: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_dark.png'),
      );
    });
  });

  // ── Home Screen ────────────────────────────────────────────────────────────

  group('Golden — HomeScreen', () {
    testWidgets('light theme — empty state', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const HomeScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_light_empty.png'),
      );
    });

    testWidgets('light theme — with mock entry', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const HomeScreen(),
        overrides: authenticatedOverrides(
          entries: [mockEntry],
          todayEntry: mockEntry,
          profile: mockProfile,
          streak: mockStreak,
        ),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_light_with_entry.png'),
      );
    });

    testWidgets('dark theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        _themedApp(
          const HomeScreen(),
          AppTheme.dark,
          overrides: authenticatedOverrides(profile: mockProfile),
        ),
      );
      await _settle(tester);

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_dark.png'),
      );
    });
  });

  // ── Timeline Screen ────────────────────────────────────────────────────────

  group('Golden — TimelineScreen', () {
    testWidgets('light theme — empty state', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const TimelineScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(TimelineScreen),
        matchesGoldenFile('goldens/timeline_screen_light_empty.png'),
      );
    });

    testWidgets('light theme — with mock entry', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const TimelineScreen(),
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(TimelineScreen),
        matchesGoldenFile('goldens/timeline_screen_light_with_entry.png'),
      );
    }, skip: true); // Non-deterministic font rendering — golden updated when stable
  });

  // ── Library (Chapters) Screen ──────────────────────────────────────────────

  group('Golden — LibraryScreen', () {
    testWidgets('light theme — empty state', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const LibraryScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(LibraryScreen),
        matchesGoldenFile('goldens/library_screen_light_empty.png'),
      );
    });

    testWidgets('light theme — with mock book', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const LibraryScreen(),
        overrides: authenticatedOverrides(books: [mockBook]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(LibraryScreen),
        matchesGoldenFile('goldens/library_screen_light_with_book.png'),
      );
    });
  });

  // ── Explore Screen ──────────────────────────────────────────────────────────

  group('Golden — ExploreScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const ExploreScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(ExploreScreen),
        matchesGoldenFile('goldens/explore_screen_light.png'),
      );
    });
  });

  // ── Settings Screen ─────────────────────────────────────────────────────────

  group('Golden — SettingsScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const SettingsScreen(),
        overrides: _subsOverrides(),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_screen_light.png'),
      );
    });
  });

  // ── Recording Screen ────────────────────────────────────────────────────────

  group('Golden — RecordingScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const RecordingScreen(),
        overrides: [
          ...authenticatedOverrides(),
          writingPromptProvider.overrideWith((ref) => 'What made today special?'),
        ],
      ));
      // Platform channel screen — use pump() not pumpAndSettle()
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump();

      await expectLater(
        find.byType(RecordingScreen),
        matchesGoldenFile('goldens/recording_screen_light.png'),
      );
    });
  });

  // ── Text Entry Screen ───────────────────────────────────────────────────────

  group('Golden — TextEntryScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const TextEntryScreen(),
        overrides: [
          ...authenticatedOverrides(),
          writingPromptProvider.overrideWith((ref) => 'What made today special?'),
        ],
      ));
      await _settle(tester);

      await expectLater(
        find.byType(TextEntryScreen),
        matchesGoldenFile('goldens/text_entry_screen_light.png'),
      );
    });
  });

  // ── Book Creation Screen ────────────────────────────────────────────────────

  group('Golden — BookCreationScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const BookCreationScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(BookCreationScreen),
        matchesGoldenFile('goldens/book_creation_screen_light.png'),
      );
    });
  });

  // ── Check-In Screen ─────────────────────────────────────────────────────────

  group('Golden — CheckInScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const CheckInScreen()));
      // Platform channels possible — use pump()
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump();

      await expectLater(
        find.byType(CheckInScreen),
        matchesGoldenFile('goldens/checkin_screen_light.png'),
      );
    });
  });

  // ── Export Screen ───────────────────────────────────────────────────────────

  group('Golden — ExportScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const ExportScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(ExportScreen),
        matchesGoldenFile('goldens/export_screen_light.png'),
      );
    });
  });

  // ── Paywall Screen ──────────────────────────────────────────────────────────

  group('Golden — PaywallScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const PaywallScreen(),
        overrides: _subsOverrides(),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(PaywallScreen),
        matchesGoldenFile('goldens/paywall_screen_light.png'),
      );
    });
  });

  // ── On This Day Screen ──────────────────────────────────────────────────────

  group('Golden — OnThisDayScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const OnThisDayScreen(),
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(OnThisDayScreen),
        matchesGoldenFile('goldens/on_this_day_screen_light.png'),
      );
    });
  });

  // ── Edit Profile Screen ─────────────────────────────────────────────────────

  group('Golden — EditProfileScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const EditProfileScreen(),
        overrides: authenticatedOverrides(profile: mockProfile),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(EditProfileScreen),
        matchesGoldenFile('goldens/edit_profile_screen_light.png'),
      );
    });
  });

  // ── Privacy Screen ──────────────────────────────────────────────────────────

  group('Golden — PrivacyScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const PrivacyScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(PrivacyScreen),
        matchesGoldenFile('goldens/privacy_screen_light.png'),
      );
    });
  });

  // ── Terms Screen ────────────────────────────────────────────────────────────

  group('Golden — TermsScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const TermsScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(TermsScreen),
        matchesGoldenFile('goldens/terms_screen_light.png'),
      );
    });
  });

  // ── Subscription Screen ─────────────────────────────────────────────────────

  group('Golden — SubscriptionScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const SubscriptionScreen(),
        overrides: _subsOverrides(),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(SubscriptionScreen),
        matchesGoldenFile('goldens/subscription_screen_light.png'),
      );
    });
  });

  // ── Book Detail Screen ──────────────────────────────────────────────────────

  group('Golden — BookDetailScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(BookDetailScreen(book: _mockGeneratedBook)));
      await _settle(tester);

      await expectLater(
        find.byType(BookDetailScreen),
        matchesGoldenFile('goldens/book_detail_screen_light.png'),
      );
    });
  });

  // ── Share Card Screen ───────────────────────────────────────────────────────

  group('Golden — ShareCardScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(ShareCardScreen(entry: mockEntry)));
      await _settle(tester);

      await expectLater(
        find.byType(ShareCardScreen),
        matchesGoldenFile('goldens/share_card_screen_light.png'),
      );
    });
  });

  // ── Post Save Screen ───────────────────────────────────────────────────────

  group('Golden — PostSaveScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const PostSaveScreen(data: _mockPostSaveData),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(PostSaveScreen),
        matchesGoldenFile('goldens/post_save_screen_light.png'),
      );
    });
  });

  // ── Onboarding Screen ──────────────────────────────────────────────────────

  group('Golden — OnboardingScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(onComplete: () {}),
        ),
      );
      await _settle(tester);

      await expectLater(
        find.byType(OnboardingScreen),
        matchesGoldenFile('goldens/onboarding_screen_light.png'),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Bug-fix regression goldens — photo display, time display, post-save flow
  // ════════════════════════════════════════════════════════════════════════════

  // ── Timeline with entryTime (time display bug regression) ─────────────────

  group('Golden — TimelineScreen with entryTime', () {
    testWidgets('shows correct time, not 00:00', (tester) async {
      _setView(tester, _goldenSize);

      final entryWithTime = mockEntry.copyWith(
        entryTime: const TimeOfDay(hour: 19, minute: 49),
        content: 'Evening walk in the park\n\nThe sunset was beautiful.',
        mood: 'great',
      );

      await tester.pumpWidget(_app(
        const TimelineScreen(),
        overrides: authenticatedOverrides(entries: [entryWithTime]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(TimelineScreen),
        matchesGoldenFile('goldens/timeline_screen_with_time.png'),
      );
    });

    testWidgets('multiple entries with different times', (tester) async {
      _setView(tester, _goldenSize);

      final morningEntry = mockEntry.copyWith(
        id: 'entry-morning',
        entryTime: const TimeOfDay(hour: 7, minute: 30),
        content: 'Morning coffee and journaling\n\nA peaceful start.',
        mood: 'good',
        entryDate: DateTime(2026, 3, 14),
      );
      final eveningEntry = mockEntry.copyWith(
        id: 'entry-evening',
        entryTime: const TimeOfDay(hour: 21, minute: 15),
        content: 'Evening reflection\n\nGrateful for today.',
        mood: 'great',
        entryDate: DateTime(2026, 3, 14),
      );

      await tester.pumpWidget(_app(
        const TimelineScreen(),
        overrides: authenticatedOverrides(entries: [morningEntry, eveningEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(TimelineScreen),
        matchesGoldenFile('goldens/timeline_screen_multiple_times.png'),
      );
    });
  });

  // ── Timeline with photo media (signed URL / FutureBuilder regression) ─────

  group('Golden — TimelineScreen with photo media', () {
    testWidgets('entry with storage-path photo shows FutureBuilder state', (tester) async {
      _setView(tester, _goldenSize);

      final photoEntry = mockEntry.copyWith(
        hasPhoto: true,
        entryTime: const TimeOfDay(hour: 14, minute: 0),
        content: 'Trip to Bali\n\nAmazing scenery and food.',
        media: [
          EntryMedia(
            id: 'media-1',
            entryId: 'entry-id',
            userId: 'test-user-id',
            mediaType: 'photo',
            storagePath: 'test-user-id/entry-id/photo.jpg',
            createdAt: _now,
          ),
        ],
      );

      await tester.pumpWidget(_app(
        const TimelineScreen(),
        overrides: authenticatedOverrides(entries: [photoEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(TimelineScreen),
        matchesGoldenFile('goldens/timeline_screen_with_photo.png'),
      );
    });

    testWidgets('entry with HTTP URL photo', (tester) async {
      _setView(tester, _goldenSize);

      final httpPhotoEntry = mockEntry.copyWith(
        hasPhoto: true,
        entryTime: const TimeOfDay(hour: 10, minute: 30),
        content: 'Beach day\n\nSun and sand.',
        media: [
          EntryMedia(
            id: 'media-2',
            entryId: 'entry-id',
            userId: 'test-user-id',
            mediaType: 'photo',
            storagePath: 'https://example.com/photo.jpg',
            createdAt: _now,
          ),
        ],
      );

      await tester.pumpWidget(_app(
        const TimelineScreen(),
        overrides: authenticatedOverrides(entries: [httpPhotoEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(TimelineScreen),
        matchesGoldenFile('goldens/timeline_screen_with_http_photo.png'),
      );
    });
  });

  // ── Home Screen with photo entries (signed URL regression) ────────────────

  group('Golden — HomeScreen with photo entries', () {
    testWidgets('entry with storage-path photo', (tester) async {
      _setView(tester, _goldenSize);

      final photoEntry = mockEntry.copyWith(
        hasPhoto: true,
        entryTime: const TimeOfDay(hour: 16, minute: 45),
        content: 'Garden photos\n\nThe roses are blooming.',
        media: [
          EntryMedia(
            id: 'media-home-1',
            entryId: 'entry-id',
            userId: 'test-user-id',
            mediaType: 'photo',
            storagePath: 'test-user-id/entry-id/garden.jpg',
            createdAt: _now,
          ),
        ],
      );

      await tester.pumpWidget(_app(
        const HomeScreen(),
        overrides: authenticatedOverrides(
          entries: [photoEntry],
          todayEntry: photoEntry,
          profile: mockProfile,
          streak: mockStreak,
        ),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_with_photo.png'),
      );
    });

    testWidgets('multiple entries with mixed media', (tester) async {
      _setView(tester, _goldenSize);

      final photoEntry = mockEntry.copyWith(
        id: 'entry-photo',
        hasPhoto: true,
        entryTime: const TimeOfDay(hour: 9, minute: 0),
        content: 'Morning hike\n\nGreat views from the summit.',
        media: [
          EntryMedia(
            id: 'media-mix-1',
            entryId: 'entry-photo',
            userId: 'test-user-id',
            mediaType: 'photo',
            storagePath: 'test-user-id/entry-photo/hike.jpg',
            createdAt: _now,
          ),
        ],
      );
      final textEntry = mockEntry.copyWith(
        id: 'entry-text',
        entryTime: const TimeOfDay(hour: 20, minute: 0),
        content: 'Quiet evening reading\n\nFinished a good book.',
        mood: 'good',
      );

      await tester.pumpWidget(_app(
        const HomeScreen(),
        overrides: authenticatedOverrides(
          entries: [photoEntry, textEntry],
          todayEntry: photoEntry,
          profile: mockProfile,
          streak: mockStreak,
        ),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_mixed_media.png'),
      );
    });
  });

  // ── Post Save Screen with chapters (post-save flow regression) ────────────

  group('Golden — PostSaveScreen with chapters', () {
    testWidgets('chapter selection step with chapters', (tester) async {
      _setView(tester, _goldenSize);

      final chapters = [
        Chapter(
          id: 'ch-1',
          userId: 'test-user-id',
          title: 'My Story 2026',
          chapterNumber: 1,
          startDate: DateTime(2026, 1, 1),
          createdAt: _now,
        ),
        Chapter(
          id: 'ch-2',
          userId: 'test-user-id',
          title: 'Travel Memories',
          chapterNumber: 2,
          startDate: DateTime(2025, 6, 1),
          createdAt: _now,
        ),
      ];

      await tester.pumpWidget(_app(
        const PostSaveScreen(data: _mockPostSaveData),
        overrides: [
          ...authenticatedOverrides(),
          chaptersProvider.overrideWith((ref) async => chapters),
        ],
      ));
      await _settle(tester);

      await expectLater(
        find.byType(PostSaveScreen),
        matchesGoldenFile('goldens/post_save_screen_with_chapters.png'),
      );
    });
  });

  // ── Photo Entry Screen ──────────────────────────────────────────────────────

  group('Golden — PhotoEntryScreen', () {
    testWidgets('light theme — default text mode', (tester) async {
      _setView(tester, _goldenSize);
      // Non-existent path → broken-image fallback renders (no network needed)
      final fakePath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}golden_test_photo.jpg';
      await tester.pumpWidget(_app(PhotoEntryScreen(photoPath: fakePath)));
      // autofocused TextField — use pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await expectLater(
        find.byType(PhotoEntryScreen),
        matchesGoldenFile('goldens/photo_entry_screen_light.png'),
      );
    });
  });

  // ── Explore Screen with photo entries (signed URL regression) ─────────────

  group('Golden — ExploreScreen with entries', () {
    testWidgets('entries with photos and times', (tester) async {
      _setView(tester, _goldenSize);

      final entries = [
        mockEntry.copyWith(
          id: 'explore-1',
          hasPhoto: true,
          entryTime: const TimeOfDay(hour: 8, minute: 30),
          content: 'Trip to Bali\n\nIncredible temples and beaches.',
          mood: 'great',
          media: [
            EntryMedia(
              id: 'media-explore-1',
              entryId: 'explore-1',
              userId: 'test-user-id',
              mediaType: 'photo',
              storagePath: 'test-user-id/explore-1/bali.jpg',
              createdAt: _now,
            ),
          ],
        ),
        mockEntry.copyWith(
          id: 'explore-2',
          entryTime: const TimeOfDay(hour: 19, minute: 0),
          content: 'Birthday celebration\n\nSurprise party was amazing!',
          mood: 'great',
          isMilestone: true,
          milestoneType: 'birthday',
        ),
      ];

      await tester.pumpWidget(_app(
        const ExploreScreen(),
        overrides: authenticatedOverrides(entries: entries),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(ExploreScreen),
        matchesGoldenFile('goldens/explore_screen_with_photos.png'),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Group 1 — Simple screens
  // ════════════════════════════════════════════════════════════════════════════

  // ── Forgot Password Screen ─────────────────────────────────────────────────

  group('Golden — ForgotPasswordScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ForgotPasswordScreen(),
        ),
      );
      // AuthShell has a repeating orb animation — pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await expectLater(
        find.byType(ForgotPasswordScreen),
        matchesGoldenFile('goldens/forgot_password_screen_light.png'),
      );
    });
  });

  // ── Signup Screen ──────────────────────────────────────────────────────────

  group('Golden — SignupScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SignupScreen(onLogin: () {}),
        ),
      );
      // AuthShell has a repeating orb animation — pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await expectLater(
        find.byType(SignupScreen),
        matchesGoldenFile('goldens/signup_screen_light.png'),
      );
    });
  });

  // ── Cookie Policy Screen ───────────────────────────────────────────────────

  group('Golden — CookiePolicyScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const CookiePolicyScreen()));
      await _settle(tester);

      await expectLater(
        find.byType(CookiePolicyScreen),
        matchesGoldenFile('goldens/cookie_policy_screen_light.png'),
      );
    });
  });

  // ── Search Screen ──────────────────────────────────────────────────────────

  group('Golden — SearchScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(const SearchScreen()));
      // autofocused TextField — use pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await expectLater(
        find.byType(SearchScreen),
        matchesGoldenFile('goldens/search_screen_light.png'),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Group 2 — Flow screens (need mock data)
  // ════════════════════════════════════════════════════════════════════════════

  // ── Review Save Screen ─────────────────────────────────────────────────────

  group('Golden — ReviewSaveScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const ReviewSaveScreen(
          data: ReviewData(
            rawText: 'A wonderful morning at the park with friends and family.',
            isVoice: false,
          ),
        ),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(ReviewSaveScreen),
        matchesGoldenFile('goldens/review_save_screen_light.png'),
      );
    });
  });

  // ── See All Timeline Screen ────────────────────────────────────────────────

  group('Golden — SeeAllTimelineScreen', () {
    testWidgets('light theme — happiest section', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const SeeAllTimelineScreen(section: SeeAllSection.happiest),
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(SeeAllTimelineScreen),
        matchesGoldenFile('goldens/see_all_timeline_screen_light.png'),
      );
    });
  });

  // ── Memory Detail Screen ───────────────────────────────────────────────────

  group('Golden — MemoryDetailScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(MemoryDetailScreen(entry: mockEntry)));
      // Platform channels (audio player) — use pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await expectLater(
        find.byType(MemoryDetailScreen),
        matchesGoldenFile('goldens/memory_detail_screen_light.png'),
      );
    });
  });

  // ── Reflection Screen ──────────────────────────────────────────────────────

  group('Golden — ReflectionScreen', () {
    testWidgets('light theme — weekly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const ReflectionScreen(period: ReflectionPeriod.weekly),
        overrides: authenticatedOverrides(entries: [mockEntry]),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(ReflectionScreen),
        matchesGoldenFile('goldens/reflection_screen_light.png'),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Group 3 — Sharing screens
  // ════════════════════════════════════════════════════════════════════════════

  // ── Shared With Me Screen ──────────────────────────────────────────────────

  group('Golden — SharedWithMeScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const SharedWithMeScreen(),
        overrides: [
          ...authenticatedOverrides(),
          sharedWithMeProvider.overrideWith((ref) async => <SharedMemoryItem>[]),
        ],
      ));
      await _settle(tester);

      await expectLater(
        find.byType(SharedWithMeScreen),
        matchesGoldenFile('goldens/shared_with_me_screen_light.png'),
      );
    });
  });

  // ── Share Approvals Screen ─────────────────────────────────────────────────

  group('Golden — ShareApprovalsScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const ShareApprovalsScreen(),
        overrides: [
          ...authenticatedOverrides(),
          pendingShareRequestsProvider.overrideWith((ref) async => <MemoryShare>[]),
        ],
      ));
      await _settle(tester);

      await expectLater(
        find.byType(ShareApprovalsScreen),
        matchesGoldenFile('goldens/share_approvals_screen_light.png'),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Group 4 — Book screens
  // ════════════════════════════════════════════════════════════════════════════

  // ── Book Reader Screen ─────────────────────────────────────────────────────

  group('Golden — BookReaderScreen', () {
    testWidgets('light theme — stream mode', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        const BookReaderScreen(mode: BookMode.stream),
        overrides: authenticatedOverrides(
          entries: [mockEntry],
          books: [mockBook],
        ),
      ));
      // Page controller animation — use pump() not pumpAndSettle()
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await expectLater(
        find.byType(BookReaderScreen),
        matchesGoldenFile('goldens/book_reader_screen_light.png'),
      );
    });
  });

  // ── Chapter Detail Screen ──────────────────────────────────────────────────

  group('Golden — ChapterDetailScreen', () {
    testWidgets('light theme renders correctly', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(_app(
        ChapterDetailScreen(
          chapter: Chapter(
            id: 'ch-1',
            userId: 'test-user-id',
            title: 'Summer 2025',
            chapterNumber: 1,
            startDate: DateTime(2025, 6, 1),
            entryCount: 5,
            createdAt: _now,
          ),
        ),
      ));
      await _settle(tester);

      await expectLater(
        find.byType(ChapterDetailScreen),
        matchesGoldenFile('goldens/chapter_detail_screen_light.png'),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Group 5 — Auth security screens
  // ════════════════════════════════════════════════════════════════════════════

  // ── Pin Screen ─────────────────────────────────────────────────────────────

  group('Golden — PinScreen', () {
    testWidgets('light theme — setup mode', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PinScreen(mode: PinMode.setup, onSuccess: () {}),
        ),
      );
      await _settle(tester);

      await expectLater(
        find.byType(PinScreen),
        matchesGoldenFile('goldens/pin_screen_light.png'),
      );
    });
  });

  // ── Pattern Screen ─────────────────────────────────────────────────────────

  group('Golden — PatternScreen', () {
    testWidgets('light theme — setup mode', (tester) async {
      _setView(tester, _goldenSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PatternScreen(mode: PatternMode.setup, onSuccess: () {}),
        ),
      );
      await _settle(tester);

      await expectLater(
        find.byType(PatternScreen),
        matchesGoldenFile('goldens/pattern_screen_light.png'),
      );
    });
  });
}
