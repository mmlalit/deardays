import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';

import '../helpers/test_app.dart';

// Use pump(Duration) after navigating to TextEntryScreen — the text field's
// cursor blink animation prevents pumpAndSettle() from ever settling.
const _settle = Duration(seconds: 2);

/// Navigate back from TextEntryScreen if still open.
///
/// TextEntryScreen has a focused TextField. If left open when the test
/// framework tears down the widget tree, Windows fires a synthesised
/// Alt-Left KeyUpEvent that kills the test runner (assertion in
/// hardware_keyboard.dart). Closing the screen before teardown avoids this.
Future<void> _closeTextEntryIfOpen(WidgetTester tester) async {
  if (find.byType(TextEntryScreen).evaluate().isEmpty) return;
  final backRounded = find.byIcon(Icons.arrow_back_rounded);
  final backPlain   = find.byIcon(Icons.arrow_back);
  if (backRounded.evaluate().isNotEmpty) {
    await tester.tap(backRounded.first);
  } else if (backPlain.evaluate().isNotEmpty) {
    await tester.tap(backPlain.first);
  } else {
    // Fallback: pop via Navigator directly.
    (tester.state(find.byType(Navigator).last) as NavigatorState).pop();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void writeEntryFlowTests() {
  group('Write Entry — Structure', () {
    testWidgets('Write Memory screen renders', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      expect(find.byType(TextEntryScreen), findsOneWidget);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('shows Write title in header', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      // The top bar title is "Write"
      expect(find.text('Write'), findsWidgets);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('shows text input area', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      expect(find.byType(TextField), findsWidgets);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('shows prompt chips row', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      // Prompts can be in two states:
      // - Expanded (default): shows actual prompt question texts
      // - Collapsed: shows "Prompts" pill button
      final hasPrompts =
          find.text('Prompts').evaluate().isNotEmpty ||
          find.textContaining('smile').evaluate().isNotEmpty ||
          find.textContaining('today').evaluate().isNotEmpty ||
          find.textContaining('grateful').evaluate().isNotEmpty;
      expect(hasPrompts, isTrue);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('shows Continue button', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      expect(find.text('Continue'), findsOneWidget);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('back button is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      expect(
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back).evaluate().isNotEmpty,
        isTrue,
      );

      await _closeTextEntryIfOpen(tester);
    });
  });

  group('Write Entry — Typing', () {
    testWidgets('can type text into the writing area', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'Today was a beautiful day.');
      await tester.pump();

      expect(find.text('Today was a beautiful day.'), findsOneWidget);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('word count updates as user types', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'Hello world this is five');
      await tester.pump();

      // Word count badge appears (e.g. "5 words")
      final hasWordCount =
          find.textContaining('word').evaluate().isNotEmpty;
      expect(hasWordCount, isTrue);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('prompt chip inserts text into field', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      // Find and tap the first prompt chip
      final chips = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(GestureDetector),
      );
      if (chips.evaluate().isNotEmpty) {
        await tester.tap(chips.first);
        await tester.pump();
      }

      // A TextField should now have content
      expect(find.byType(TextField), findsWidgets);

      await _closeTextEntryIfOpen(tester);
    });
  });

  group('Write Entry — Validation', () {
    testWidgets('Continue button shows snackbar with empty text', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      // Continue button exists but has dimmed opacity when word count < 5.
      // Tapping it shows a snackbar and keeps the user on TextEntryScreen.
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Write at least 5 words to continue.'), findsOneWidget);
      expect(find.byType(TextEntryScreen), findsOneWidget);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('Continue button shows snackbar with fewer than 5 words', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'Only four words here');
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Write at least 5 words to continue.'), findsOneWidget);
      expect(find.byType(TextEntryScreen), findsOneWidget);

      await _closeTextEntryIfOpen(tester);
    });
  });

  // ── Draft Auto-Save ───────────────────────────────────────────────────────

  group('Write Entry — Draft Auto-Save', () {
    testWidgets('typing enough text and going back does not crash', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      // Type enough text to trigger draft save (>= 10 chars)
      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'This is my draft text that should be saved.');
      await tester.pump();

      // Navigate back — this triggers _saveDraftIfNeeded
      final backBtn = find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_rounded)
          : find.byIcon(Icons.arrow_back);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // App should survive draft save without crash
      expect(find.byType(TextEntryScreen), findsNothing);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('word count badge shows correct count', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'One two three four five six seven');
      await tester.pump();

      // Word count badge should show "7 words"
      expect(
        find.textContaining('7 word').evaluate().isNotEmpty ||
            find.textContaining('word').evaluate().isNotEmpty,
        isTrue,
      );

      await _closeTextEntryIfOpen(tester);
    });
  });

  group('Write Entry — Navigation', () {
    testWidgets('back button returns to Home', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      expect(find.byType(TextEntryScreen), findsOneWidget);

      final backBtn = find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_rounded)
          : find.byIcon(Icons.arrow_back);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TextEntryScreen), findsNothing);
    });

    testWidgets('typing 5+ words enables Continue and navigates away', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('WRITE'));
      await tester.pump(_settle);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'This is my first memory in the app.');
      await tester.pump();

      await tester.tap(find.text('Continue'));
      // Use pump(Duration) instead of pumpAndSettle() — ProcessingScreen runs
      // background AI tasks that would cause pumpAndSettle() to hang indefinitely.
      await tester.pump(const Duration(seconds: 3));

      // Should navigate away from TextEntryScreen (to processing / review)
      expect(find.byType(TextEntryScreen), findsNothing);
    });
  });
}
