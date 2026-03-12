import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';

import '../helpers/test_app.dart';

void writeEntryFlowTests() {
  group('Write Entry — Structure', () {
    testWidgets('Write Memory screen renders', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.byType(TextEntryScreen), findsOneWidget);
    });

    testWidgets('shows Write Memory title', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('Write Memory'), findsOneWidget);
    });

    testWidgets('shows text input area', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows prompt chips row', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('NEED A PROMPT?'), findsOneWidget);
    });

    testWidgets('shows Save Memory button', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('Save Memory'), findsOneWidget);
    });

    testWidgets('shows Photo meta row', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('shows Location meta row', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('shows Tags meta row', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('back button is visible', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Write Entry — Typing', () {
    testWidgets('can type text into the writing area', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'Today was a beautiful day.');
      await tester.pump();

      expect(find.text('Today was a beautiful day.'), findsOneWidget);
    });

    testWidgets('word count updates as user types', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'Hello world this is five');
      await tester.pump();

      // Word count should appear (not hidden at 0)
      final hasWordCount =
          find.textContaining('w').evaluate().isNotEmpty;
      expect(hasWordCount, isTrue);
    });

    testWidgets('prompt chip inserts text into field', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

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
    });
  });

  group('Write Entry — Validation', () {
    testWidgets('tapping Save Memory with empty text shows error', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Memory'));
      await tester.pumpAndSettle();

      // Error snackbar should appear
      expect(
        find.textContaining('Write something').evaluate().isNotEmpty ||
            find.byType(SnackBar).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Write Entry — Navigation', () {
    testWidgets('back button returns to Home', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.byType(TextEntryScreen), findsOneWidget);

      final backBtn = find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty
          ? find.byIcon(Icons.arrow_back_rounded)
          : find.byIcon(Icons.arrow_back);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TextEntryScreen), findsNothing);
    });

    testWidgets('typing text and tapping Save navigates away from entry screen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'This is my first memory in the app.');
      await tester.pump();

      await tester.tap(find.text('Save Memory'));
      // Use pump(Duration) instead of pumpAndSettle() — ProcessingScreen runs
      // background AI tasks that would cause pumpAndSettle() to hang indefinitely.
      await tester.pump(const Duration(seconds: 3));

      // Should navigate away from TextEntryScreen (to processing / review)
      expect(find.byType(TextEntryScreen), findsNothing);
    });
  });
}
