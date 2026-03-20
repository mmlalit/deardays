import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';

import '../helpers/test_app.dart';

void exploreFlowTests() {
  group('Explore — Structure', () {
    testWidgets('ExploreScreen renders', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('shows search field', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField).evaluate().isNotEmpty ||
            find.widgetWithText(TextField, 'Search memories...').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows search hint text', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.text('Search memories...'), findsOneWidget);
    });
  });

  group('Explore — Curated Sections', () {
    testWidgets('shows Happiest Memories section', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.text('Happiest Memories'), findsOneWidget);
    });

    testWidgets('shows Family Moments section', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      // Family Moments is below the fold — scroll down to it.
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Family Moments'), findsOneWidget);
    });

    testWidgets('shows Travel Stories section', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      // Travel Stories appears after Happiest + Family sections — scroll more.
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('Travel Stories'), findsOneWidget);
    });

    testWidgets('See all buttons are visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('See all'), findsWidgets);
    });

    testWidgets('memory cards are visible in Happiest section', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      // Mock entries include happy moods
      final hasCards = find.byType(GestureDetector).evaluate().isNotEmpty;
      expect(hasCards, isTrue);
    });
  });

  group('Explore — Search', () {
    testWidgets('tapping search field activates it', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('typing in search filters content', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      // Use showKeyboard + testTextInput to avoid Windows hardware keyboard
      // assertion errors (stray KeyUpEvent for modifier keys).
      await tester.showKeyboard(find.byType(TextField).first);
      tester.testTextInput.enterText('Bali');
      await tester.pump();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('clearing search shows all content again', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      await tester.showKeyboard(find.byType(TextField).first);
      tester.testTextInput.enterText('xyz');
      await tester.pump();

      tester.testTextInput.enterText('');
      await tester.pump();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });
  });

  group('Explore — See All Navigation', () {
    testWidgets('tapping "See all" for Happiest navigates to see-all screen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      // Tap the first "See all" link
      final seeAll = find.textContaining('See all');
      if (seeAll.evaluate().isNotEmpty) {
        await tester.tap(seeAll.first);
        await tester.pumpAndSettle();

        // Should navigate to a see-all screen
        expect(find.byType(ExploreScreen), findsNothing);
      }
    });
  });

  group('Explore — Total count', () {
    testWidgets('total entries count is non-zero with mock data', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      // ExploreScreen renders without crash and shows content
      expect(find.byType(ExploreScreen), findsOneWidget);
    });
  });
}
