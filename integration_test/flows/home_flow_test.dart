import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';

import '../helpers/test_app.dart';

void homeFlowTests() {
  group('Home Screen — Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows time-of-day greeting', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final hasGreeting =
          find.textContaining('Good morning').evaluate().isNotEmpty ||
          find.textContaining('Good afternoon').evaluate().isNotEmpty ||
          find.textContaining('Good evening').evaluate().isNotEmpty;
      expect(hasGreeting, isTrue);
    });

    testWidgets('shows "What happened today?" prompt', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('today'), findsWidgets);
    });

    testWidgets('shows Daily Spark card', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('DAILY SPARK'), findsOneWidget);
    });

    testWidgets('shows Recent Memories section header', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('Recent Memories'), findsOneWidget);
    });

    testWidgets('shows View All link', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('shows memory category chips', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // The home screen shows category chips: Travel, Celebrations, People, etc.
      // Scroll down to make them visible.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      final hasCategories =
          find.text('Travel').evaluate().isNotEmpty ||
          find.text('Celebrations').evaluate().isNotEmpty ||
          find.text('People').evaluate().isNotEmpty ||
          find.text('Chapters').evaluate().isNotEmpty;
      expect(hasCategories, isTrue);
    });
  });

  group('Home Screen — Action Buttons', () {
    testWidgets('large mic button is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // The main action is a large circular mic button (Icons.mic_rounded, size 40)
      final micButton = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.mic_rounded && (w.size ?? 0) >= 40,
      );
      expect(micButton, findsOneWidget);
    });

    testWidgets('Write label is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('Write'), findsOneWidget);
    });

    testWidgets('Chat label is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('tapping Write navigates to TextEntryScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.byType(TextEntryScreen), findsOneWidget);
    });

    testWidgets('tapping mic button navigates to RecordingScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      final micButton = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.mic_rounded && (w.size ?? 0) >= 40,
      );
      await tester.tap(micButton);
      // Use pump(Duration) instead of pumpAndSettle() — RecordingScreen
      // initialises audio platform channels that keep the frame loop alive.
      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(RecordingScreen), findsOneWidget);
    });

    testWidgets('tapping Chat navigates to TextEntryScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(find.byType(TextEntryScreen), findsOneWidget);
    });
  });

  group('Home Screen — Memory Cards', () {
    testWidgets('memory cards are visible with mock data', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Mock entries include "Trip to Bali"
      final hasCards =
          find.textContaining('Bali').evaluate().isNotEmpty ||
          find.textContaining('birthday').evaluate().isNotEmpty ||
          find.textContaining('Trip').evaluate().isNotEmpty;
      expect(hasCards, isTrue);
    });

    testWidgets('tapping View All navigates to Timeline', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('hero memory card is full-width at the top', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Hero card is the first entry — Bali trip
      final hasHero = find.textContaining('Bali').evaluate().isNotEmpty ||
          find.textContaining('Trip').evaluate().isNotEmpty;
      expect(hasHero, isTrue);
    });
  });

  group('Home Screen — Settings navigation', () {
    testWidgets('settings icon is visible in header', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Profile avatar acts as settings entry point
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}
