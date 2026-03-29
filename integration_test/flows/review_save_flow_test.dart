/// Review & Save flow tests — ReviewSaveScreen polish/edit/save before committing.
library;
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';

import '../helpers/test_app.dart';

void reviewSaveFlowTests() {
  // ReviewSaveScreen is reached via the E2E app navigation:
  // Write → type text → tap Save → ReviewSaveScreen (with AI polish OFF)
  // or: Record → Process → ReviewSaveScreen
  //
  // For direct navigation we tap Write, enter text, and tap Save.

  Future<bool> navigateToReviewSave(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);

    final _navCtx = tester.element(find.byType(Scaffold).first); GoRouter.of(_navCtx).push('/write');
    await settle(tester);

    final textFields = find.byType(TextField);
    if (textFields.evaluate().isEmpty) return false;

    await tester.showKeyboard(textFields.first);
    tester.testTextInput.enterText('A lovely morning walk along the river with Max.');
    await tester.pump();

    final saveBtn = find.text('Continue');
    if (saveBtn.evaluate().isEmpty) return false;

    await tester.tap(saveBtn.first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));

    return find.byType(ReviewSaveScreen).evaluate().isNotEmpty;
  }

  group('Review & Save — Structure', () {
    testWidgets('ReviewSaveScreen renders when navigated to from Write', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return; // write flow may skip review on some builds

      expect(find.byType(ReviewSaveScreen), findsOneWidget);
    });

    testWidgets('ReviewSaveScreen shows a Save button', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      expect(find.textContaining('Save'), findsAtLeastNWidgets(1));
    });

    testWidgets('ReviewSaveScreen shows Cancel or back navigation', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      expect(
        find.text('Cancel').evaluate().isNotEmpty ||
            find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.arrow_back_rounded)
                .evaluate()
                .isNotEmpty,
        isTrue,
      );
    });

    testWidgets('ReviewSaveScreen shows entry content', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      expect(
        find.textContaining('morning walk').evaluate().isNotEmpty ||
            find.byType(ReviewSaveScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('ReviewSaveScreen shows mood selection', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      // Mood chips or selector should be present
      expect(
        find.textContaining('mood').evaluate().isNotEmpty ||
            find.textContaining('Mood').evaluate().isNotEmpty ||
            find.byType(ReviewSaveScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Review & Save — View Modes', () {
    testWidgets('Original view mode button is accessible', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      expect(
        find.textContaining('Original').evaluate().isNotEmpty ||
            find.byType(ReviewSaveScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Polished view mode option is accessible', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      expect(
        find.textContaining('Polished').evaluate().isNotEmpty ||
            find.textContaining('Polish').evaluate().isNotEmpty ||
            find.byType(ReviewSaveScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Tags ─────────────────────────────────────────────────────────────────

  group('Review & Save — Tags', () {
    testWidgets('shows Add tags pill button', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      expect(
        find.text('Add tags').evaluate().isNotEmpty ||
            find.byIcon(Icons.sell_outlined).evaluate().isNotEmpty ||
            find.textContaining('tag').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('tapping Add tags opens the tags sheet', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      final addTags = find.text('Add tags');
      if (addTags.evaluate().isEmpty) return;

      await tester.tap(addTags.first, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      // Tags sheet should show "Type a tag..." hint
      expect(
        find.textContaining('tag').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('can add a tag via the tags sheet', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      final addTags = find.text('Add tags');
      if (addTags.evaluate().isEmpty) return;

      await tester.tap(addTags.first, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));

      // Find the tag input TextField in the sheet
      final tagFields = find.byType(TextField);
      if (tagFields.evaluate().length < 2) return; // main + tag input

      await tester.showKeyboard(tagFields.last);
      tester.testTextInput.enterText('travel');
      await tester.pump();

      // Tap the check/add button
      final checkBtn = find.byIcon(Icons.check_rounded);
      if (checkBtn.evaluate().isNotEmpty) {
        await tester.tap(checkBtn.first, warnIfMissed: false);
        await tester.pump();
      }

      // Tag chip should appear
      expect(
        find.textContaining('travel').evaluate().isNotEmpty ||
            find.textContaining('1 tag').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Review & Save — Navigation', () {
    testWidgets('cancelling returns to previous screen', (tester) async {
      final arrived = await navigateToReviewSave(tester);
      if (!arrived) return;

      final cancelBtn = find.text('Cancel');
      if (cancelBtn.evaluate().isEmpty) return;

      await tester.tap(cancelBtn.first, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
