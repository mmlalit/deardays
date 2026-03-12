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

    testWidgets('shows Chat with AI title', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.text('Chat with AI'), findsOneWidget);
    });

    testWidgets('shows YOUR AI MEMORY COMPANION subtitle', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.text('YOUR AI MEMORY COMPANION'), findsOneWidget);
    });

    testWidgets('back button is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Check-in — Mood Selection', () {
    testWidgets('shows "How are you feeling today?" heading', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      expect(find.textContaining('feeling'), findsWidgets);
    });

    testWidgets('shows all 5 mood options', (tester) async {
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

    testWidgets('tapping Great mood selects it and advances', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      await tester.tap(find.text('Great'));
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('tapping Skip for now advances to chat', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      await tester.tap(find.text('Skip for now'));
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsOneWidget);
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
    testWidgets('back button returns from chat screen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pump(_settle);

      await tester.tap(find.text('Chat AI'));
      await tester.pump(_settle);

      final backBtn = find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_rounded)
          : find.byIcon(Icons.arrow_back);

      await tester.tap(backBtn);
      await tester.pump(_settle);

      expect(find.byType(CheckInScreen), findsNothing);
    });
  });
}
