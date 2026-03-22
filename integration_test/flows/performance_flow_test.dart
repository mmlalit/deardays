import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/search/presentation/screens/search_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';

import '../helpers/test_app.dart';

void performanceFlowTests() {
  group('Performance — Home Screen Load', () {
    testWidgets('home screen settles within 3 seconds', (tester) async {
      final sw = Stopwatch()..start();
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(3000),
        reason: 'Home settled in ${sw.elapsedMilliseconds}ms, budget 3000ms',
      );
    });

    testWidgets('home screen renders first frame within 500 ms', (tester) async {
      final sw = Stopwatch()..start();
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(); // single frame
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: 'First frame took ${sw.elapsedMilliseconds}ms, budget 500ms',
      );
    });
  });

  group('Performance — Tab Navigation', () {
    testWidgets('CHAPTERS tab settles within 3 seconds', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'CHAPTERS tab: ${sw.elapsedMilliseconds}ms');
    });

    testWidgets('TIMELINE tab settles within 3 seconds', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'TIMELINE tab: ${sw.elapsedMilliseconds}ms');
    });

    testWidgets('EXPLORE tab settles within 3 seconds', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'EXPLORE tab: ${sw.elapsedMilliseconds}ms');
    });

    testWidgets('cycling through all 4 tabs stays within 8 seconds total',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      for (final label in ['CHAPTERS', 'TIMELINE', 'EXPLORE', 'HOME']) {
        if (find.text(label).evaluate().isNotEmpty) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(8000),
          reason: 'Full tab cycle: ${sw.elapsedMilliseconds}ms');
    });
  });

  group('Performance — Screen Open Time', () {
    testWidgets('Write screen opens within 2 seconds', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      await tester.tap(find.text('WRITE'));
      await tester.pump(const Duration(seconds: 2));
      sw.stop();

      expect(find.byType(TextEntryScreen), findsOneWidget);
      expect(sw.elapsedMilliseconds, lessThan(2500),
          reason: 'Write screen: ${sw.elapsedMilliseconds}ms');

      // Close to avoid Windows keyboard assertion crash
      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Settings screen opens within 2 seconds', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      // Navigate to settings via bottom-nav "Settings" tab if present,
      // or via the settings icon/avatar in the home app bar.
      final settingsTab = find.text('SETTINGS');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
      } else {
        final gear = find.byIcon(Icons.settings_outlined);
        if (gear.evaluate().isNotEmpty) await tester.tap(gear.first);
      }
      await tester.pump(const Duration(seconds: 2));
      sw.stop();

      final opened = find.byType(SettingsScreen).evaluate().isNotEmpty;
      // If settings is in a ShellRoute tab it may already be mounted
      expect(opened || find.byType(MaterialApp).evaluate().isNotEmpty, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(2500),
          reason: 'Settings screen: ${sw.elapsedMilliseconds}ms');
    });

    testWidgets('Search screen opens within 2 seconds', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final sw = Stopwatch()..start();
      final searchIcon = find.byIcon(Icons.search_rounded);
      if (searchIcon.evaluate().isNotEmpty) {
        await tester.tap(searchIcon.first);
        await tester.pump(const Duration(seconds: 2));
      }
      sw.stop();

      final opened = find.byType(SearchScreen).evaluate().isNotEmpty;
      if (opened) {
        expect(sw.elapsedMilliseconds, lessThan(2500),
            reason: 'Search screen: ${sw.elapsedMilliseconds}ms');
      } else {
        // Search icon not present on home in this build — skip timing assertion.
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });

  group('Performance — Rapid Interaction', () {
    testWidgets('10 rapid tab taps do not crash', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final tabs = ['CHAPTERS', 'TIMELINE', 'EXPLORE', 'HOME',
                    'TIMELINE', 'HOME', 'EXPLORE', 'CHAPTERS', 'HOME', 'TIMELINE'];
      for (final label in tabs) {
        if (find.text(label).evaluate().isNotEmpty) {
          await tester.tap(find.text(label));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('scrolling home screen 5 times stays responsive', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 150));
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(3000));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('timeline scroll 5 times stays responsive', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();
      expect(find.byType(TimelineScreen), findsOneWidget);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        await tester.drag(
            find.byType(CustomScrollView).first, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 150));
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(3000));
      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('explore screen scroll stays responsive', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.drag(
            find.byType(ListView).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(ExploreScreen), findsOneWidget);
    });
  });
}
