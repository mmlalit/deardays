import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';

import '../helpers/test_app.dart';

/// Builds the app with one provider throwing so we can verify graceful degradation.
Widget _appWithError(Override errorOverride) =>
    buildE2EApp(additionalOverrides: [errorOverride]);

void backendResilienceFlowTests() {
  group('Backend Resilience — Provider Errors', () {
    testWidgets('books provider error does not crash library screen',
        (tester) async {
      await tester.pumpWidget(_appWithError(
        booksProvider.overrideWith((_) async => throw Exception('DB timeout')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      // Screen must render — error state or empty state, not a crash
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('timeline entries error does not crash timeline screen',
        (tester) async {
      await tester.pumpWidget(_appWithError(
        timelineEntriesProvider.overrideWith(
          (_) => Stream.error(Exception('Network unavailable')),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('explore provider error does not crash explore screen',
        (tester) async {
      await tester.pumpWidget(_appWithError(
        moodStatsProvider.overrideWith((_) async => throw Exception('503')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('streak provider error does not crash home screen',
        (tester) async {
      await tester.pumpWidget(_appWithError(
        streakProvider.overrideWith((_) async => throw Exception('offline')),
      ));
      await tester.pumpAndSettle();

      // Home must still render greeting and action buttons
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Write'), findsOneWidget);
    });

    testWidgets('weekly summary error does not crash home screen',
        (tester) async {
      await tester.pumpWidget(_appWithError(
        weeklySummaryProvider.overrideWith(
            (_) async => throw Exception('AI unavailable')),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('onThisDay error does not crash home screen', (tester) async {
      await tester.pumpWidget(_appWithError(
        onThisDayProvider.overrideWith(
            (_) async => throw Exception('query timeout')),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('multiple providers erroring simultaneously does not crash',
        (tester) async {
      await tester.pumpWidget(buildE2EApp(
        additionalOverrides: [
          booksProvider.overrideWith((_) async => throw Exception('503')),
          streakProvider.overrideWith((_) async => throw Exception('503')),
          weeklySummaryProvider.overrideWith((_) async => throw Exception('503')),
          onThisDayProvider.overrideWith((_) async => throw Exception('503')),
        ],
      ));
      await tester.pumpAndSettle();

      // App shell and home must survive partial failures
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Backend Resilience — Slow Providers', () {
    testWidgets('app renders while streak is still loading', (tester) async {
      await tester.pumpWidget(buildE2EApp(
        additionalOverrides: [
          streakProvider.overrideWith(
            (_) => Future.delayed(const Duration(minutes: 1), () => throw Exception()),
          ),
        ],
      ));
      // Only pump one frame — provider hasn't resolved yet
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('library renders while books are still loading', (tester) async {
      await tester.pumpWidget(buildE2EApp(
        additionalOverrides: [
          booksProvider.overrideWith(
            (_) => Future.delayed(const Duration(minutes: 1), () => []),
          ),
        ],
      ));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('CHAPTERS'));
      await tester.pump(const Duration(seconds: 2));

      // Loading state must not crash
      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });

  group('Backend Resilience — Navigation After Error', () {
    testWidgets('can navigate between tabs after a provider error', (tester) async {
      await tester.pumpWidget(_appWithError(
        booksProvider.overrideWith((_) async => throw Exception('error')),
      ));
      await tester.pumpAndSettle();

      // Navigate through tabs — must not get stuck
      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('write entry still works after a provider error', (tester) async {
      await tester.pumpWidget(_appWithError(
        booksProvider.overrideWith((_) async => throw Exception('timeout')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MaterialApp), findsOneWidget);

      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('Backend Resilience — Feature Flags', () {
    testWidgets('app does not crash when feature flags are unavailable',
        (tester) async {
      // Feature flags use hardcoded defaults when remote config is unavailable.
      // The E2E environment has no network — flags fall back to defaults.
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // All main screens must render with default flags
      for (final label in ['CHAPTERS', 'TIMELINE', 'EXPLORE', 'HOME']) {
        if (find.text(label).evaluate().isNotEmpty) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('voice recording feature renders mic button by default',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // voiceRecording flag defaults true → mic button visible
      final micBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.mic_rounded && (w.size ?? 0) >= 40,
      );
      expect(micBtn, findsOneWidget);
    });

    testWidgets('book generation feature shows CHAPTERS tab by default',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // bookGeneration flag defaults true → CHAPTERS tab is present
      expect(find.text('CHAPTERS'), findsOneWidget);
    });
  });

  group('Backend Resilience — Offline Queue', () {
    testWidgets('app starts without crashing even if offline AI queue is empty',
        (tester) async {
      // OfflineAiQueue is initialized lazily — no crash expected on cold start
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
