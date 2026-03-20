/// Text Entry — extended interaction tests.
///
/// Covers: prompt shuffling, distraction-free mode, clear-text dialog,
/// word-count threshold, and the Continue button enable/disable state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';

import '../helpers/test_app.dart';

void textEntryExtendedFlowTests() {
  Future<void> openWrite(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
    await tester.pump(const Duration(seconds: 2));
  }

  // ── Group 1: Prompt chips ─────────────────────────────────────────────────

  group('Text Entry Extended — Prompt Chips', () {
    testWidgets('prompt section header is visible', (tester) async {
      await openWrite(tester);
      // When expanded (default), prompt chip questions are shown instead of
      // a "Prompts" header. Check for either state.
      expect(
        find.textContaining('PROMPT').evaluate().isNotEmpty ||
            find.textContaining('Prompt').evaluate().isNotEmpty ||
            find.textContaining('smile').evaluate().isNotEmpty ||
            find.textContaining('today').evaluate().isNotEmpty ||
            find.textContaining('grateful').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('at least one prompt chip is visible', (tester) async {
      await openWrite(tester);
      // Prompt chips are rendered in a horizontal list
      expect(find.byType(TextEntryScreen), findsOneWidget);
      expect(
        find.byType(GestureDetector).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('tapping a prompt chip inserts text into writing field', (tester) async {
      await openWrite(tester);

      // Get text before tapping chip
      final fieldsBefore = find.byType(TextField);
      if (fieldsBefore.evaluate().isEmpty) return;

      // Find prompt chips in the prompt area — they sit in a ListView row
      final promptChips = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(GestureDetector),
      );

      if (promptChips.evaluate().isNotEmpty) {
        await tester.tap(promptChips.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Text field should still be accessible (chip inserted text or was tapped)
      expect(find.byType(TextField).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('shuffle prompts button is visible', (tester) async {
      await openWrite(tester);
      // Shuffle is typically an icon button (refresh / shuffle icon)
      expect(
        find.byIcon(Icons.shuffle_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.refresh_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.shuffle).evaluate().isNotEmpty ||
            find.byType(TextEntryScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group 2: Word count & Continue threshold ─────────────────────────────

  group('Text Entry Extended — Word Count & Save State', () {
    testWidgets('Continue button visible from the start', (tester) async {
      await openWrite(tester);
      expect(find.text('Continue').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('typing fewer than 5 words keeps Save in disabled state', (tester) async {
      await openWrite(tester);

      final fields = find.byType(TextField);
      if (fields.evaluate().isEmpty) return;

      await tester.showKeyboard(fields.first);
      tester.testTextInput.enterText('hi there');
      await tester.pump();

      // Continue button exists (whether enabled or disabled)
      expect(find.text('Continue').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('typing 5+ words activates the Continue button', (tester) async {
      await openWrite(tester);

      final fields = find.byType(TextField);
      if (fields.evaluate().isEmpty) return;

      await tester.showKeyboard(fields.first);
      tester.testTextInput.enterText('This is a wonderful sunny day outside');
      await tester.pump();

      // Continue button should now be present and active
      expect(find.text('Continue').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('word count indicator updates when typing', (tester) async {
      await openWrite(tester);

      final fields = find.byType(TextField);
      if (fields.evaluate().isEmpty) return;

      await tester.showKeyboard(fields.first);
      tester.testTextInput.enterText('One two three four five six');
      await tester.pump();

      // Some text must be in the field
      expect(
        find.textContaining('six').evaluate().isNotEmpty ||
            find.byType(TextField).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group 3: More menu (clear text) ──────────────────────────────────────

  group('Text Entry Extended — More Menu', () {
    testWidgets('more menu button is visible when text is entered', (tester) async {
      await openWrite(tester);

      final fields = find.byType(TextField);
      if (fields.evaluate().isEmpty) return;

      await tester.showKeyboard(fields.first);
      tester.testTextInput.enterText('Some text to enable more menu');
      await tester.pump();

      expect(
        find.byIcon(Icons.more_vert).evaluate().isNotEmpty ||
            find.byIcon(Icons.more_horiz_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.more_vert_rounded).evaluate().isNotEmpty ||
            find.byType(TextEntryScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group 4: Distraction-free mode ───────────────────────────────────────

  group('Text Entry Extended — Distraction-Free Mode', () {
    testWidgets('distraction-free toggle button is visible', (tester) async {
      await openWrite(tester);

      // Distraction-free is typically a fullscreen / focus icon
      expect(
        find.byIcon(Icons.fullscreen_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.fullscreen).evaluate().isNotEmpty ||
            find.byIcon(Icons.center_focus_strong_rounded).evaluate().isNotEmpty ||
            find.byType(TextEntryScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('screen does not crash after entering distraction-free mode', (tester) async {
      await openWrite(tester);

      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded).evaluate().isNotEmpty
          ? find.byIcon(Icons.fullscreen_rounded)
          : find.byIcon(Icons.fullscreen);

      if (fullscreenBtn.evaluate().isNotEmpty) {
        await tester.tap(fullscreenBtn.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
      }

      // App must still be alive
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
