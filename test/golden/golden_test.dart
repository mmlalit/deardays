/// Golden (screenshot regression) tests for DearDays key screens.
///
/// FIRST RUN — generate baselines:
///   flutter test test/golden/golden_test.dart --update-goldens
///
/// SUBSEQUENT RUNS — compare against baselines:
///   flutter test test/golden/golden_test.dart
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
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

import '../helpers/mock_providers.dart';

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
      await _settle(tester);

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
      await _settle(tester);

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
    });
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
      await tester.pumpWidget(_app(const RecordingScreen()));
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
          writingPromptProvider.overrideWith((ref) async => 'What made today special?'),
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
}
