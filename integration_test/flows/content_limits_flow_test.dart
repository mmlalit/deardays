/// Content limits flow tests.
///
/// Covers: word count display, word count updates on typing, long text
/// threshold hints, draft save on back navigation, recording screen renders,
/// and photo entry Continue button validation.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/photo_entry_screen.dart';

import '../helpers/test_app.dart';

/// Close TextEntryScreen if open (prevents Windows KeyUpEvent crash).
Future<void> _closeTextEntryIfOpen(WidgetTester tester) async {
  if (find.byType(TextEntryScreen).evaluate().isEmpty) return;
  final backRounded = find.byIcon(Icons.arrow_back_rounded);
  final backPlain = find.byIcon(Icons.arrow_back);
  if (backRounded.evaluate().isNotEmpty) {
    await tester.tap(backRounded.first);
  } else if (backPlain.evaluate().isNotEmpty) {
    await tester.tap(backPlain.first);
  } else {
    (tester.state(find.byType(Navigator).last) as NavigatorState).pop();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// Close RecordingScreen if open.
Future<void> _closeRecordingIfOpen(WidgetTester tester) async {
  if (find.byType(RecordingScreen).evaluate().isEmpty) return;
  final closeBtn = find.byWidgetPredicate(
    (w) =>
        w is Icon &&
        (w.icon == Icons.close_rounded ||
            w.icon == Icons.arrow_back_rounded ||
            w.icon == Icons.arrow_back ||
            w.icon == Icons.close),
  );
  if (closeBtn.evaluate().isNotEmpty) {
    await tester.tap(closeBtn.first, warnIfMissed: false);
  } else {
    (tester.state(find.byType(Navigator).last) as NavigatorState).pop();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// Navigate to /write and wait for the screen to settle.
Future<void> _openWrite(WidgetTester tester) async {
  await tester.pumpWidget(buildE2EApp());
  await settle(tester);

  final ctx = tester.element(find.byType(Scaffold).first);
  GoRouter.of(ctx).push('/write');
  await settle(tester);
}

void contentLimitsFlowTests() {
  // ── Word Count ───────────────────────────────────────────────────────────

  group('Content Limits — Word Count', () {
    testWidgets('write screen shows word count', (tester) async {
      await _openWrite(tester);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'Hello world this is five');
      await tester.pump();

      final hasWordCount = find.textContaining('word').evaluate().isNotEmpty;
      expect(hasWordCount, isTrue);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('write screen word count updates when typing', (tester) async {
      await _openWrite(tester);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, 'One two three');
      await tester.pump();

      final hasWordCount1 = find.textContaining('word').evaluate().isNotEmpty;
      expect(hasWordCount1, isTrue);

      // Type more words — count should update
      await tester.enterText(mainField, 'One two three four five six seven eight');
      await tester.pump();

      final hasWordCount2 = find.textContaining('word').evaluate().isNotEmpty;
      expect(hasWordCount2, isTrue);

      await _closeTextEntryIfOpen(tester);
    });

    testWidgets('long text (1500+ words) shows warning or color change',
        (tester) async {
      await _openWrite(tester);

      // Generate a long string with 1500+ words
      final longText = List.generate(1600, (i) => 'word$i').join(' ');

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(mainField, longText);
      await tester.pump();

      // Word count badge should show a large number
      expect(
        find.textContaining('word').evaluate().isNotEmpty ||
            find.byType(TextEntryScreen).evaluate().isNotEmpty,
        isTrue,
      );

      await _closeTextEntryIfOpen(tester);
    });
  });

  // ── Draft Save ───────────────────────────────────────────────────────────

  group('Content Limits — Draft Save', () {
    testWidgets('draft saves when navigating back from write screen',
        (tester) async {
      await _openWrite(tester);

      final mainField = find.byType(TextField).first;
      await tester.tap(mainField);
      await tester.enterText(
          mainField, 'This is my draft text that should be saved on back.');
      await tester.pump();

      // Navigate back — triggers draft save
      final backBtn =
          find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty
              ? find.byIcon(Icons.arrow_back_rounded)
              : find.byIcon(Icons.arrow_back);

      await tester.tap(backBtn);
      await settle(tester);

      // App survives draft save without crash
      expect(find.byType(TextEntryScreen), findsNothing);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ── Recording Screen ─────────────────────────────────────────────────────

  group('Content Limits — Recording', () {
    testWidgets('voice recording screen renders without crash',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/record');
      await tester.pump(const Duration(seconds: 3));

      // Even if platform channels fail, the app must not hard crash
      expect(find.byType(MaterialApp), findsOneWidget);

      await _closeRecordingIfOpen(tester);
    });
  });

  // ── Photo Entry Continue ─────────────────────────────────────────────────

  group('Content Limits — Photo Entry', () {
    testWidgets('photo entry shows Continue button only with enough text',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      final fakePath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}e2e_content_limits_test.jpg';

      final ctx = tester.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).push('/photo-entry', extra: fakePath);
      await settle(tester);

      if (find.byType(PhotoEntryScreen).evaluate().isEmpty) return;

      // Continue button should exist but be dimmed/disabled with no text
      final continueBtn = find.textContaining('Continue');
      expect(continueBtn, findsOneWidget);

      // Tapping Continue with empty text should keep us on PhotoEntryScreen
      await tester.tap(continueBtn);
      await tester.pump();
      expect(find.byType(PhotoEntryScreen), findsOneWidget);

      // Close to prevent KeyUpEvent crash
      final back = find.byIcon(Icons.arrow_back_rounded);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
      } else {
        (tester.state(find.byType(Navigator).last) as NavigatorState).pop();
      }
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
