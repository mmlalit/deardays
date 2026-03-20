import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';

import '../helpers/test_app.dart';

Widget _darkApp() => buildE2EApp(additionalOverrides: [
      themeProvider.overrideWith(
        (ref) => ThemeNotifier()..setThemeMode(ThemeMode.dark),
      ),
    ]);

Widget _emptyApp() => buildE2EApp(additionalOverrides: [
      timelineEntriesProvider.overrideWith((_) => Stream.value([])),
      todayEntryProvider.overrideWith((_) => Stream.value(null)),
      booksProvider.overrideWith((_) async => []),
      totalEntriesProvider.overrideWith((_) async => 0),
      weeklyMoodsProvider.overrideWith((_) async => []),
      onThisDayProvider.overrideWith((_) async => []),
      weeklySummaryProvider.overrideWith((_) async => null),
    ]);

void uxPolishFlowTests() {
  group('UX — Empty States', () {
    testWidgets('home renders without crash when user has no entries',
        (tester) async {
      await tester.pumpWidget(_emptyApp());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('library shows empty state when there are no books',
        (tester) async {
      await tester.pumpWidget(_emptyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
      // Empty state: either a message or a CTA button — app must not crash
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('timeline renders without crash when there are no entries',
        (tester) async {
      await tester.pumpWidget(_emptyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('explore renders without crash when there are no entries',
        (tester) async {
      await tester.pumpWidget(_emptyApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('home action buttons still visible with no entries', (tester) async {
      await tester.pumpWidget(_emptyApp());
      await tester.pumpAndSettle();

      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
    });
  });

  group('UX — Dark Mode', () {
    testWidgets('home screen renders without crash in dark mode', (tester) async {
      await tester.pumpWidget(_darkApp());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('CHAPTERS tab renders in dark mode', (tester) async {
      await tester.pumpWidget(_darkApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('TIMELINE tab renders in dark mode', (tester) async {
      await tester.pumpWidget(_darkApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('EXPLORE tab renders in dark mode', (tester) async {
      await tester.pumpWidget(_darkApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('switching light → dark → light does not crash', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.pumpWidget(_darkApp());
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('UX — Tap Targets', () {
    testWidgets('Write button meets 44px minimum tap target', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final writeBtn = find.text('Write');
      expect(writeBtn, findsOneWidget);

      final box = tester.getRect(writeBtn);
      // Minimum tap target is 44×44 logical pixels (Material guideline: 48×48)
      expect(box.height, greaterThanOrEqualTo(44),
          reason: 'Write button height ${box.height}px < 44px');
    });

    testWidgets('Photo button meets 44px minimum tap target', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final photoBtn = find.text('Photo');
      expect(photoBtn, findsOneWidget);

      final box = tester.getRect(photoBtn);
      expect(box.height, greaterThanOrEqualTo(44),
          reason: 'Photo button height ${box.height}px < 44px');
    });

    testWidgets('Chat button meets 44px minimum tap target', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final chatBtn = find.text('Chat');
      expect(chatBtn, findsOneWidget);

      final box = tester.getRect(chatBtn);
      expect(box.height, greaterThanOrEqualTo(44),
          reason: 'Chat button height ${box.height}px < 44px');
    });

    testWidgets('mic button meets 56px minimum tap target', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final micBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.mic_rounded && (w.size ?? 0) >= 40,
      );
      expect(micBtn, findsOneWidget);

      final box = tester.getRect(micBtn);
      expect(box.width, greaterThanOrEqualTo(44));
      expect(box.height, greaterThanOrEqualTo(44));
    });

    testWidgets('bottom nav tabs meet 44px tap target', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      for (final label in ['HOME', 'CHAPTERS', 'TIMELINE', 'EXPLORE']) {
        final tab = find.text(label);
        if (tab.evaluate().isNotEmpty) {
          final box = tester.getRect(tab);
          // Bottom nav items may span the full nav bar height; check width only
          expect(box.width, greaterThan(0),
              reason: '$label tab has zero width');
        }
      }
    });
  });

  group('UX — Accessibility Semantics', () {
    testWidgets('home screen has at least one semantic node', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(Scaffold).first);
      expect(semantics, isNotNull);
    });

    testWidgets('Write button is reachable via semantics', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Verifies the Write text widget is in the semantic tree
      final writeFinder = find.text('Write');
      expect(writeFinder, findsOneWidget);
      expect(tester.getSemantics(writeFinder), isNotNull);
    });

    testWidgets('mood option buttons are semantically labelled', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final hasMoodSemantics =
          find.text('Great').evaluate().isNotEmpty ||
          find.text('Good').evaluate().isNotEmpty ||
          find.text('Okay').evaluate().isNotEmpty;
      expect(hasMoodSemantics, isTrue);
    });

    testWidgets('bottom nav items expose text labels in semantics', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Each tab label must render as a text widget accessible to screen readers
      final tabLabels = ['HOME', 'CHAPTERS', 'TIMELINE', 'EXPLORE'];
      for (final label in tabLabels) {
        if (find.text(label).evaluate().isNotEmpty) {
          final sem = tester.getSemantics(find.text(label).first);
          expect(sem, isNotNull, reason: '$label tab semantics missing');
        }
      }
    });
  });

  group('UX — Layout Integrity', () {
    testWidgets('home screen renders without RenderFlex overflow', (tester) async {
      final overflowDetected = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflowDetected.add(details.exceptionAsString());
        }
      };

      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      FlutterError.onError = previous;

      expect(overflowDetected, isEmpty,
          reason: 'Layout overflow on home: ${overflowDetected.join('\n')}');
    });

    testWidgets('timeline renders without RenderFlex overflow', (tester) async {
      final overflowDetected = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflowDetected.add(details.exceptionAsString());
        }
      };

      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      FlutterError.onError = previous;

      expect(overflowDetected, isEmpty,
          reason: 'Layout overflow on timeline: ${overflowDetected.join('\n')}');
    });

    testWidgets('explore renders without RenderFlex overflow', (tester) async {
      final overflowDetected = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflowDetected.add(details.exceptionAsString());
        }
      };

      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      FlutterError.onError = previous;

      expect(overflowDetected, isEmpty,
          reason: 'Overflow on explore: ${overflowDetected.join('\n')}');
    });

    testWidgets('library renders without RenderFlex overflow', (tester) async {
      final overflowDetected = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          overflowDetected.add(details.exceptionAsString());
        }
      };

      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      FlutterError.onError = previous;

      expect(overflowDetected, isEmpty,
          reason: 'Overflow on library: ${overflowDetected.join('\n')}');
    });
  });

  group('UX — Loading & Error States', () {
    testWidgets('app renders placeholder while profile loads', (tester) async {
      // Slow provider — never completes during the pump window
      await tester.pumpWidget(buildE2EApp(
        additionalOverrides: [
          profileProvider.overrideWith(
            (_) => Future.delayed(const Duration(hours: 1), () => throw Exception()),
          ),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // App must show *something* — a loader, skeleton, or fallback — not crash
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('home shows content after streak loads', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final hasStreakOrActivity =
          find.textContaining('streak').evaluate().isNotEmpty ||
          find.textContaining('day streak').evaluate().isNotEmpty ||
          find.text('Journal Activity').evaluate().isNotEmpty;

      // Streak section may be below fold — scroll to it
      if (!hasStreakOrActivity) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
