import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';

import '../helpers/test_app.dart';

// Use pump(Duration) throughout this file instead of pumpAndSettle().
// The speech_to_text plugin keeps a recurring platform channel listener
// alive on Windows, which causes pumpAndSettle() to wait indefinitely.
const _settle = Duration(seconds: 2);

void checkinFlowTests() {
  group('Check-in / Chat AI — Structure', () {
    testWidgets('CheckInScreen renders from Home Chat AI button', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('shows greeting in header', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      // Greeting contains time-of-day words
      final hasGreeting =
          find.textContaining('morning').evaluate().isNotEmpty ||
          find.textContaining('Morning').evaluate().isNotEmpty ||
          find.textContaining('afternoon').evaluate().isNotEmpty ||
          find.textContaining('Afternoon').evaluate().isNotEmpty ||
          find.textContaining('evening').evaluate().isNotEmpty ||
          find.textContaining('Evening').evaluate().isNotEmpty;
      expect(hasGreeting, isTrue);
    });

    testWidgets('close button is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('Check-in — Mood Selection', () {
    testWidgets('shows all 5 mood options inline', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.text('Great'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Tough'), findsOneWidget);
    });

    testWidgets('"Skip for now" link is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('tapping Great mood selects it and stays on screen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      await tester.tap(find.text('Great'));
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('tapping Skip for now keeps chat screen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      await tester.tap(find.text('Skip for now'));
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('input bar is visible even before mood selection', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      // Input bar should be visible from the start
      expect(find.byType(TextField), findsWidgets);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });
  });

  group('Check-in — Chat Interface', () {
    Future<void> advanceToChat(WidgetTester tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);
      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);
      await tester.tap(find.text('Good'));
      await tester.pump(_settle);
    }

    testWidgets('chat message input is visible after mood selection', (tester) async {
      await advanceToChat(tester);

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('prompt suggestion chips appear', (tester) async {
      await advanceToChat(tester);

      final hasChips =
          find.textContaining('smile').evaluate().isNotEmpty ||
          find.textContaining('grateful').evaluate().isNotEmpty ||
          find.textContaining('learned').evaluate().isNotEmpty ||
          find.textContaining('challenge').evaluate().isNotEmpty;
      expect(hasChips, isTrue);
    });

    testWidgets('send button is visible', (tester) async {
      await advanceToChat(tester);

      expect(
        find.byIcon(Icons.send_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.send).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('voice record button is visible', (tester) async {
      await advanceToChat(tester);

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('can type a message into input field', (tester) async {
      await advanceToChat(tester);

      final inputField = find.byType(TextField).last;
      await tester.tap(inputField);
      await tester.enterText(inputField, 'Today was really good!');
      await tester.pump();

      expect(find.text('Today was really good!'), findsOneWidget);
    });
  });

  group('Check-in — Navigation', () {
    testWidgets('close button returns from chat screen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsNothing);
    });
  });
}
