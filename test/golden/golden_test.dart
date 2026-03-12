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

import '../helpers/mock_providers.dart';

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
}
