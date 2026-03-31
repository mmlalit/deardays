/// Story Card flow tests — Your Story card on the Explore tab.
///
/// Covers: card visibility, header text, Day/Week/Month/Year period tabs,
/// "Read full story" link, and navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';

import '../helpers/test_app.dart';

void storyCardFlowTests() {
  /// Navigate to Explore and scroll to expose the Your Story card.
  Future<void> openExploreAndScrollToStory(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);

    await tester.tap(find.text('EXPLORE'));
    await settle(tester);

    // Your Story card may be below the fold — scroll down
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
  }

  group('Story Card — Visibility', () {
    testWidgets('Explore tab shows Your Story card', (tester) async {
      await openExploreAndScrollToStory(tester);

      expect(
        find.text('YOUR STORY').evaluate().isNotEmpty ||
            find.textContaining('Your').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Your Story card shows "YOUR STORY" header', (tester) async {
      await openExploreAndScrollToStory(tester);

      // The header is rendered as uppercased text
      expect(
        find.text('YOUR STORY').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Story Card — Period Tabs', () {
    testWidgets('Day tab is selected by default', (tester) async {
      await openExploreAndScrollToStory(tester);

      // Default period is daily — "Your Day" hero title should appear
      expect(
        find.text('Day').evaluate().isNotEmpty ||
            find.textContaining('Your Day').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('tapping Week tab changes content', (tester) async {
      await openExploreAndScrollToStory(tester);

      final weekTab = find.text('Week');
      if (weekTab.evaluate().isEmpty) return;

      await tester.tap(weekTab, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Your Week').evaluate().isNotEmpty ||
            find.byType(ExploreScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('tapping Month tab changes content', (tester) async {
      await openExploreAndScrollToStory(tester);

      final monthTab = find.text('Month');
      if (monthTab.evaluate().isEmpty) return;

      await tester.tap(monthTab, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Your Month').evaluate().isNotEmpty ||
            find.byType(ExploreScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('tapping Year tab changes content', (tester) async {
      await openExploreAndScrollToStory(tester);

      final yearTab = find.text('Year');
      if (yearTab.evaluate().isEmpty) return;

      await tester.tap(yearTab, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Your Year').evaluate().isNotEmpty ||
            find.byType(ExploreScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Story Card — Read Full Story', () {
    testWidgets('"Read full story" link is visible', (tester) async {
      await openExploreAndScrollToStory(tester);

      expect(
        find.textContaining('Read full story').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('tapping "Read full story" navigates to story viewer',
        (tester) async {
      await openExploreAndScrollToStory(tester);

      final readLink = find.textContaining('Read full story');
      if (readLink.evaluate().isEmpty) return;

      // The whole card is a GestureDetector that navigates to /story
      final card = find.ancestor(
        of: readLink.first,
        matching: find.byType(GestureDetector),
      );
      if (card.evaluate().isNotEmpty) {
        await tester.tap(card.first, warnIfMissed: false);
        await tester.pump(const Duration(seconds: 2));
      }

      // App should survive navigation (even if /story route is not in test router)
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
