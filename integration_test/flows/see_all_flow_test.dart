import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';

import '../helpers/test_app.dart';

/// E2E tests for the SeeAllTimelineScreen (Explore > "See all" on a section).

void seeAllFlowTests() {
  Future<void> navigateToExplore(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);

    await tester.tap(find.text('EXPLORE'));
    await settle(tester);
  }

  group('See All — Navigation', () {
    testWidgets('"See all" links are visible on Explore', (tester) async {
      await navigateToExplore(tester);

      expect(find.textContaining('See all'), findsWidgets);
    });

    testWidgets('tapping first "See all" navigates to SeeAllTimelineScreen',
        (tester) async {
      await navigateToExplore(tester);

      final seeAll = find.textContaining('See all');
      expect(seeAll, findsWidgets);

      await tester.tap(seeAll.first);
      await settle(tester);

      expect(find.byType(SeeAllTimelineScreen), findsOneWidget);
    });
  });

  group('See All — Screen Structure', () {
    testWidgets('SeeAllTimelineScreen renders with a title',
        (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      // The title should be one of: "Happiest Memories", "Family Journey",
      // "Travel Adventures".
      final hasTitle =
          find.text('Happiest Memories').evaluate().isNotEmpty ||
              find.text('Family Journey').evaluate().isNotEmpty ||
              find.text('Travel Adventures').evaluate().isNotEmpty;
      expect(hasTitle, isTrue);
    });

    testWidgets('SeeAllTimelineScreen shows subtitle text', (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      final hasSubtitle =
          find.text('Reliving your peak moments').evaluate().isNotEmpty ||
              find.text('Our shared history').evaluate().isNotEmpty ||
              find.text('Exploring the world').evaluate().isNotEmpty;
      expect(hasSubtitle, isTrue);
    });

    testWidgets('SeeAllTimelineScreen shows filter chips', (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      // The "All" filter chip is always present.
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('SeeAllTimelineScreen shows additional filter chips',
        (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      // Depending on the section, there will be extra chips like
      // "Great", "Good" for happiest; "Milestones", "Travel" for family, etc.
      final hasExtraFilters =
          find.text('Great').evaluate().isNotEmpty ||
              find.text('Good').evaluate().isNotEmpty ||
              find.text('Milestones').evaluate().isNotEmpty ||
              find.text('Trips').evaluate().isNotEmpty;
      expect(hasExtraFilters, isTrue);
    });

    testWidgets('tapping a filter chip updates the active filter',
        (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      // Tap the second filter chip (not "All").
      // Find all text widgets that match known filter names.
      final knownFilters = ['Great', 'Good', 'Milestones', 'Trips', 'Travel', 'Adventures'];
      String? tappedFilter;
      for (final name in knownFilters) {
        final finder = find.text(name);
        if (finder.evaluate().isNotEmpty) {
          await tester.tap(finder.first);
          await settle(tester);
          tappedFilter = name;
          break;
        }
      }

      // After tapping, the screen should still be SeeAllTimelineScreen.
      expect(find.byType(SeeAllTimelineScreen), findsOneWidget);
      // The tapped filter text should still be visible.
      if (tappedFilter != null) {
        expect(find.text(tappedFilter), findsOneWidget);
      }
    });
  });

  group('See All — Back Navigation', () {
    testWidgets('SeeAllTimelineScreen has a back button', (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('tapping back button returns to ExploreScreen',
        (tester) async {
      await navigateToExplore(tester);

      await tester.tap(find.textContaining('See all').first);
      await settle(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);

      expect(find.byType(ExploreScreen), findsOneWidget);
    });
  });
}
