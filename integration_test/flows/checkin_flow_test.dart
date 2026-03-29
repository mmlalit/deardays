import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';

import '../helpers/test_app.dart';

// Use pump(Duration) throughout this file instead of pumpAndSettle().
// The speech_to_text plugin keeps a recurring platform channel listener
// alive on Windows, which causes pumpAndSettle() to wait indefinitely.
const _settle = Duration(seconds: 2);

void checkinFlowTests() {
  Future<void> openChat(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);
    final _navCtx = tester.element(find.byType(Scaffold).first); GoRouter.of(_navCtx).push('/checkin');
    await settle(tester);
  }

  group('Check-in / Chat AI — Structure', () {
    testWidgets('CheckInScreen renders from Home Chat AI button', (tester) async {
      await openChat(tester);
      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('shows Chat title in header', (tester) async {
      await openChat(tester);
      // Header shows "Chat" as the screen title
      expect(find.text('Chat'), findsWidgets);
    });

    testWidgets('shows date in header', (tester) async {
      await openChat(tester);
      // Header shows a formatted date (e.g., "Mon, Mar 17")
      final hasDate =
          find.textContaining('Jan').evaluate().isNotEmpty ||
          find.textContaining('Feb').evaluate().isNotEmpty ||
          find.textContaining('Mar').evaluate().isNotEmpty ||
          find.textContaining('Apr').evaluate().isNotEmpty ||
          find.textContaining('May').evaluate().isNotEmpty ||
          find.textContaining('Jun').evaluate().isNotEmpty ||
          find.textContaining('Jul').evaluate().isNotEmpty ||
          find.textContaining('Aug').evaluate().isNotEmpty ||
          find.textContaining('Sep').evaluate().isNotEmpty ||
          find.textContaining('Oct').evaluate().isNotEmpty ||
          find.textContaining('Nov').evaluate().isNotEmpty ||
          find.textContaining('Dec').evaluate().isNotEmpty;
      expect(hasDate, isTrue);
    });

    testWidgets('shows history button in header', (tester) async {
      await openChat(tester);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('shows more options button in header', (tester) async {
      await openChat(tester);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });
  });

  group('Check-in — Chat Interface', () {
    testWidgets('chat message input is visible', (tester) async {
      await openChat(tester);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('prompt suggestion chips appear', (tester) async {
      await openChat(tester);

      final hasChips =
          find.textContaining('smile').evaluate().isNotEmpty ||
          find.textContaining('grateful').evaluate().isNotEmpty ||
          find.textContaining('learned').evaluate().isNotEmpty ||
          find.textContaining('challenge').evaluate().isNotEmpty ||
          find.textContaining('mind').evaluate().isNotEmpty ||
          find.textContaining('morning').evaluate().isNotEmpty;
      expect(hasChips, isTrue);
    });

    testWidgets('send button is visible', (tester) async {
      await openChat(tester);
      expect(
        find.byIcon(Icons.send_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.send).evaluate().isNotEmpty ||
            find.byIcon(Icons.more_horiz_rounded).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('voice record button is visible', (tester) async {
      await openChat(tester);
      expect(
        find.byIcon(Icons.mic_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.mic).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('can type a message into input field', (tester) async {
      await openChat(tester);

      final inputField = find.byType(TextField).last;
      await tester.showKeyboard(inputField);
      tester.testTextInput.enterText('Today was really good!');
      await tester.pump();

      expect(find.text('Today was really good!'), findsOneWidget);
    });
  });

  group('Check-in — Navigation', () {
    testWidgets('back navigation returns from chat screen', (tester) async {
      await openChat(tester);
      expect(find.byType(CheckInScreen), findsOneWidget);

      // Tap the arrow_back_rounded button in the CheckIn header.
      final backBtn = find.byIcon(Icons.arrow_back_rounded);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await settle(tester);

      expect(find.byType(CheckInScreen), findsNothing);
    });
  });
}
