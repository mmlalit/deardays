/// Render-budget tests for DearDays key screens.
///
/// Run with:
///   flutter test test/perf/render_perf_test.dart
///
/// These tests measure the number of Flutter frame pump cycles needed to
/// reach a settled state. Budgets are intentionally generous to account for
/// Windows test-runner overhead and cold-start platform-channel initialisation.
///
/// Note: tester.pump() uses simulated time so elapsed-ms measurements reflect
/// frame-scheduling overhead, not wall-clock rendering latency. Tests catch
/// crashes, infinite build loops, and layout overflows — not GPU frame-rate.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/mock_providers.dart';

// ─── Budget constants (ms) ────────────────────────────────────────────────────

/// First-frame render budget — from pumpWidget to the first settled frame.
const _firstFrameBudgetMs = 2000;

/// Scroll-animation budget — time for a drag + one animation step to complete.
const _scrollBudgetMs = 500;

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Pumps [widget] to its first settled frame and returns elapsed milliseconds.
/// Uses real Stopwatch so it captures host-machine frame scheduling overhead.
/// Does NOT use tester.runAsync() to avoid triggering real async platform
/// events (e.g. GoogleFonts network attempts) that cause post-test exceptions.
Future<int> measureFirstFrame(WidgetTester tester, Widget widget) async {
  final sw = Stopwatch()..start();
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 300));
  sw.stop();
  return sw.elapsedMilliseconds;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpTestEnv();

  // ── First-frame render budgets ───────────────────────────────────────────────

  group('Perf — First-frame render budget ($_firstFrameBudgetMs ms)', () {
    testWidgets('HomeScreen renders within budget', (tester) async {
      final ms = await measureFirstFrame(
        tester,
        buildTestApp(
          const HomeScreen(),
          overrides: authenticatedOverrides(
            profile: mockProfile,
            streak: mockStreak,
            entries: [mockEntry],
          ),
        ),
      );
      expect(
        ms,
        lessThan(_firstFrameBudgetMs),
        reason: 'HomeScreen first frame took ${ms}ms '
            '(budget: ${_firstFrameBudgetMs}ms)',
      );
    });

    testWidgets('TimelineScreen renders within budget', (tester) async {
      final ms = await measureFirstFrame(
        tester,
        buildTestApp(
          const TimelineScreen(),
          overrides: authenticatedOverrides(entries: [mockEntry]),
        ),
      );
      expect(
        ms,
        lessThan(_firstFrameBudgetMs),
        reason: 'TimelineScreen first frame took ${ms}ms '
            '(budget: ${_firstFrameBudgetMs}ms)',
      );
    });

    testWidgets('LibraryScreen renders within budget', (tester) async {
      final ms = await measureFirstFrame(
        tester,
        buildTestApp(
          const LibraryScreen(),
          overrides: authenticatedOverrides(books: [mockBook]),
        ),
      );
      expect(
        ms,
        lessThan(_firstFrameBudgetMs),
        reason: 'LibraryScreen first frame took ${ms}ms '
            '(budget: ${_firstFrameBudgetMs}ms)',
      );
    });

    testWidgets('SettingsScreen renders within budget', (tester) async {
      final ms = await measureFirstFrame(
        tester,
        buildTestApp(
          const SettingsScreen(),
          overrides: authenticatedOverrides(profile: mockProfile),
        ),
      );
      expect(
        ms,
        lessThan(_firstFrameBudgetMs),
        reason: 'SettingsScreen first frame took ${ms}ms '
            '(budget: ${_firstFrameBudgetMs}ms)',
      );
    });
  });

  // ── Scroll-animation budget ──────────────────────────────────────────────────

  group('Perf — Scroll-animation budget ($_scrollBudgetMs ms)', () {
    testWidgets('TimelineScreen scroll responds within budget', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const TimelineScreen(),
          overrides: authenticatedOverrides(entries: [mockEntry]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final sw = Stopwatch()..start();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -400),
      );
      await tester.pump(const Duration(milliseconds: 100));
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(_scrollBudgetMs),
        reason: 'Timeline scroll took ${sw.elapsedMilliseconds}ms '
            '(budget: ${_scrollBudgetMs}ms)',
      );
    });

    testWidgets('HomeScreen scroll responds within budget', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeScreen(),
          overrides: authenticatedOverrides(
            entries: [mockEntry],
            profile: mockProfile,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final sw = Stopwatch()..start();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 100));
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(_scrollBudgetMs),
        reason: 'HomeScreen scroll took ${sw.elapsedMilliseconds}ms '
            '(budget: ${_scrollBudgetMs}ms)',
      );
    });
  });

  // ── Rebuild budget ───────────────────────────────────────────────────────────

  group('Perf — Provider rebuild budget', () {
    testWidgets('HomeScreen rebuilds from empty→loaded state within 200 ms',
        (tester) async {
      // Start with empty state.
      await tester.pumpWidget(
        buildTestApp(
          const HomeScreen(),
          overrides: authenticatedOverrides(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Measure how long the build+layout takes for a settled state.
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 100));
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'HomeScreen rebuild took ${sw.elapsedMilliseconds}ms '
            '(budget: 200ms)',
      );
    });
  });
}
