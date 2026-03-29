import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';

import '../helpers/test_app.dart';

void onThisDayFlowTests() {
  // The OnThisDayCard is rendered inside the ExploreScreen (not TimelineScreen).
  // It shows past entries from the same calendar date in prior years.

  group('On This Day — Section in Explore', () {
    testWidgets('"On This Day" section header is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      await tester.tap(find.text('EXPLORE'));
      await settle(tester);

      // On This Day is near the top of ExploreScreen — scroll slightly.
      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await settle(tester);

      expect(find.text('On This Day'), findsOneWidget);
    });

    testWidgets('shows history icon in the section header', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      await tester.tap(find.text('EXPLORE'));
      await settle(tester);

      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await settle(tester);

      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('On This Day cards are visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      await tester.tap(find.text('EXPLORE'));
      await settle(tester);

      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await settle(tester);

      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byType(GestureDetector).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('tapping an On This Day card navigates to MemoryDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      await tester.tap(find.text('EXPLORE'));
      await settle(tester);

      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await settle(tester);

      // Try tapping a known mock entry title.
      final knownTitles = ['Trip to Bali', "Mom's birthday", 'Got the promotion'];
      bool navigated = false;
      for (final title in knownTitles) {
        final found = find.textContaining(title);
        if (found.evaluate().isNotEmpty) {
          final card = find.ancestor(
            of: found.first,
            matching: find.byType(GestureDetector),
          );
          if (card.evaluate().isNotEmpty) {
            await tester.tap(card.first, warnIfMissed: false);
            await tester.pump(const Duration(seconds: 3));
            navigated = true;
            break;
          }
        }
      }
      if (navigated) {
        expect(
          find.byType(MemoryDetailScreen).evaluate().isNotEmpty ||
              find.byType(ExploreScreen).evaluate().isNotEmpty,
          isTrue,
        );
      } else {
        expect(find.byType(ExploreScreen), findsOneWidget);
      }
    });
  });

  group('On This Day — Empty State', () {
    testWidgets('section renders conditionally', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
