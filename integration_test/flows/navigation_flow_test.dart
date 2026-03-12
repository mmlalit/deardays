import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';

import '../helpers/test_app.dart';

void navigationFlowTests() {
  group('Navigation — Bottom Nav Bar', () {
    testWidgets('app starts on Home tab', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HOME label is visible in nav bar', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('all 4 nav labels are visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('CHAPTERS'), findsOneWidget);
      expect(find.text('TIMELINE'), findsOneWidget);
      expect(find.text('EXPLORE'), findsOneWidget);
    });

    testWidgets('tapping CHAPTERS navigates to LibraryScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('tapping TIMELINE navigates to TimelineScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('tapping EXPLORE navigates to ExploreScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();

      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('tapping HOME returns from CHAPTERS', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('tapping HOME returns from TIMELINE', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIMELINE'));
      await tester.pumpAndSettle();
      expect(find.byType(TimelineScreen), findsOneWidget);

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('tapping HOME returns from EXPLORE', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXPLORE'));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('can cycle through all tabs', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      for (final tab in ['CHAPTERS', 'TIMELINE', 'EXPLORE', 'HOME']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('FAB is hidden on Home tab', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Home has its own action row — no shell FAB
      expect(find.byType(HomeScreen), findsOneWidget);
      final fabs = find.byType(FloatingActionButton);
      expect(fabs, findsNothing);
    });

    testWidgets('nav bar stays visible across all tabs', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      for (final tab in ['CHAPTERS', 'TIMELINE', 'EXPLORE', 'HOME']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        // All 4 labels always visible
        expect(find.text('HOME'), findsOneWidget);
        expect(find.text('CHAPTERS'), findsOneWidget);
        expect(find.text('TIMELINE'), findsOneWidget);
        expect(find.text('EXPLORE'), findsOneWidget);
      }
    });
  });
}
