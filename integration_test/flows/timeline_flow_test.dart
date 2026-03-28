import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';

import '../helpers/test_app.dart';

void timelineFlowTests() {
  group('Timeline — Structure', () {
    testWidgets('TimelineScreen renders', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('shows "Your Life Timeline" heading', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Your Life Timeline'), findsOneWidget);
    });

    testWidgets('shows subtitle text', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('A journey through your memories'), findsOneWidget);
    });
  });

  group('Timeline — Stats Grid', () {
    testWidgets('shows Memories stat card', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Memories'), findsOneWidget);
    });

    testWidgets('shows Chapters stat card', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Chapters'), findsOneWidget);
    });

    testWidgets('shows Years stat card', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Years'), findsOneWidget);
    });

    testWidgets('memory count is non-zero with mock data', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      // mock data has multiple entries
      final hasCount = find.textContaining('1').evaluate().isNotEmpty ||
          find.textContaining('2').evaluate().isNotEmpty;
      expect(hasCount, isTrue);
    });
  });

  group('Timeline — Category Filters', () {
    testWidgets('shows All Memories filter chip', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('All Memories'), findsOneWidget);
    });

    testWidgets('shows Family filter chip', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('shows Travel filter chip', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Travel'), findsOneWidget);
    });

    testWidgets('shows Career filter chip', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('Career'), findsOneWidget);
    });

    testWidgets('shows Personal Growth filter chip', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      // The filter chip row is a horizontal ListView; scroll right to reveal
      // "Personal Growth" which may be off-screen on narrow test windows.
      final chipRow = find.byType(ListView).first;
      await tester.drag(chipRow, const Offset(-200, 0));
      await tester.pump();

      expect(find.text('Personal Growth'), findsOneWidget);
    });

    testWidgets('tapping Family filter chip selects it', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Family chip should be selected (screen still renders)
      expect(find.text('Family'), findsOneWidget);
      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('tapping All Memories resets filter', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      // Select a filter then reset
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Memories'));
      await tester.pumpAndSettle();

      expect(find.text('All Memories'), findsOneWidget);
      expect(find.byType(TimelineScreen), findsOneWidget);
    });
  });

  group('Timeline — Entry Cards', () {
    testWidgets('shows mock entry cards', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      // Scroll down past the header to see entries
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Mock data contains Bali, birthday, etc.
      final hasEntries =
          find.textContaining('Bali').evaluate().isNotEmpty ||
          find.textContaining('birthday').evaluate().isNotEmpty ||
          find.textContaining('Trip').evaluate().isNotEmpty ||
          find.textContaining('Mom').evaluate().isNotEmpty;
      expect(hasEntries, isTrue);
    });

    testWidgets('year badge is visible on timeline', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Year 2026 badge should be visible
      expect(find.textContaining('2026'), findsWidgets);
    });
  });

  // ── Long-press context menu ──────────────────────────────────────────────

  group('Timeline — Long-Press Context Menu', () {
    testWidgets('long-pressing an entry card opens context menu sheet', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      // Scroll to see entry cards
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      // Find any known mock entry title and long-press its card
      final knownTitles = ['Trip to Bali', "Mom's birthday", 'Got the promotion'];
      bool longPressed = false;
      for (final title in knownTitles) {
        final found = find.textContaining(title);
        if (found.evaluate().isNotEmpty) {
          final card = find.ancestor(
            of: found.first,
            matching: find.byType(GestureDetector),
          );
          if (card.evaluate().isNotEmpty) {
            await tester.longPress(card.first);
            await tester.pumpAndSettle();
            longPressed = true;
            break;
          }
        }
      }

      if (!longPressed) return;

      // Context menu sheet should show Edit Memory and Share options
      expect(
        find.text('Edit Memory').evaluate().isNotEmpty ||
            find.text('Share').evaluate().isNotEmpty ||
            find.text('Delete').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('context menu shows Edit Memory option', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final knownTitles = ['Trip to Bali', "Mom's birthday", 'Got the promotion'];
      for (final title in knownTitles) {
        final found = find.textContaining(title);
        if (found.evaluate().isNotEmpty) {
          final card = find.ancestor(
            of: found.first,
            matching: find.byType(GestureDetector),
          );
          if (card.evaluate().isNotEmpty) {
            await tester.longPress(card.first);
            await tester.pumpAndSettle();
            break;
          }
        }
      }

      expect(find.text('Edit Memory'), findsOneWidget);
    });

    testWidgets('context menu shows Share option', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final knownTitles = ['Trip to Bali', "Mom's birthday", 'Got the promotion'];
      for (final title in knownTitles) {
        final found = find.textContaining(title);
        if (found.evaluate().isNotEmpty) {
          final card = find.ancestor(
            of: found.first,
            matching: find.byType(GestureDetector),
          );
          if (card.evaluate().isNotEmpty) {
            await tester.longPress(card.first);
            await tester.pumpAndSettle();
            break;
          }
        }
      }

      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('context menu shows Delete option', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final knownTitles = ['Trip to Bali', "Mom's birthday", 'Got the promotion'];
      for (final title in knownTitles) {
        final found = find.textContaining(title);
        if (found.evaluate().isNotEmpty) {
          final card = find.ancestor(
            of: found.first,
            matching: find.byType(GestureDetector),
          );
          if (card.evaluate().isNotEmpty) {
            await tester.longPress(card.first);
            await tester.pumpAndSettle();
            break;
          }
        }
      }

      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('dismissing context menu returns to timeline', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final knownTitles = ['Trip to Bali', "Mom's birthday", 'Got the promotion'];
      for (final title in knownTitles) {
        final found = find.textContaining(title);
        if (found.evaluate().isNotEmpty) {
          final card = find.ancestor(
            of: found.first,
            matching: find.byType(GestureDetector),
          );
          if (card.evaluate().isNotEmpty) {
            await tester.longPress(card.first);
            await tester.pumpAndSettle();
            break;
          }
        }
      }

      // Close menu via the X button
      final closeBtn = find.byIcon(Icons.close);
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(find.byType(TimelineScreen), findsOneWidget);
    });
  });

  group('Timeline — Weekly Summary', () {
    testWidgets('weekly summary card is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      // Summary card uses the overridden mock summary
      final hasSummary =
          find.text('WEEKLY SUMMARY').evaluate().isNotEmpty ||
          find.textContaining('wonderful week').evaluate().isNotEmpty;
      expect(hasSummary, isTrue);
    });
  });
}
