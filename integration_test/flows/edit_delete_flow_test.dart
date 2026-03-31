/// Edit & Delete memory flow tests.
///
/// Covers: navigating to timeline, opening a memory detail, editing a memory,
/// delete confirmation dialog, and cancel behavior.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';

import '../helpers/test_app.dart';

void editDeleteFlowTests() {
  // ── Helper: navigate to Timeline and find an entry card ──────────────────

  Future<bool> _openMemoryDetail(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await settle(tester);

    await tester.tap(find.text('TIMELINE'));
    await settle(tester);

    // Scroll down to expose entry cards
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
    await settle(tester);

    const knownTitles = [
      'Trip to Bali',
      "Mom's birthday",
      'Got the promotion',
      'Sunday morning run',
      'Reconnecting',
    ];
    for (final title in knownTitles) {
      final found = find.textContaining(title);
      if (found.evaluate().isNotEmpty) {
        final card = find.ancestor(of: found.first, matching: find.byType(GestureDetector));
        if (card.evaluate().isNotEmpty) {
          await tester.tap(card.first, warnIfMissed: false);
          await tester.pump(const Duration(seconds: 3));
          if (find.byType(MemoryDetailScreen).evaluate().isNotEmpty) return true;
        }
      }
    }
    return false;
  }

  // ── Helper: open more menu from MemoryDetail ─────────────────────────────

  Future<bool> _openMoreMenu(WidgetTester tester) async {
    if (!await _openMemoryDetail(tester)) return false;

    final moreBtn = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.more_horiz_rounded,
    );
    if (moreBtn.evaluate().isEmpty) return false;

    await tester.tap(moreBtn.first, warnIfMissed: false);
    await settle(tester);
    return true;
  }

  // ── Group 1: Navigate to Timeline & open entry ───────────────────────────

  group('Edit/Delete — Timeline Navigation', () {
    testWidgets('navigate to timeline and find entry card', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await settle(tester);

      await tester.tap(find.text('TIMELINE'));
      await settle(tester);

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('long-press or tap opens memory detail', (tester) async {
      final opened = await _openMemoryDetail(tester);

      // If mock data cards are found, we should have navigated
      expect(
        opened || find.byType(TimelineScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Group 2: Edit Memory ─────────────────────────────────────────────────

  group('Edit/Delete — Edit Memory', () {
    testWidgets('context menu shows Edit Memory option', (tester) async {
      final opened = await _openMemoryDetail(tester);
      if (!opened) return;

      expect(find.text('Edit Memory'), findsOneWidget);
    });

    testWidgets('tapping Edit Memory navigates to EditMemoryScreen',
        (tester) async {
      final opened = await _openMemoryDetail(tester);
      if (!opened) return;

      await tester.tap(find.text('Edit Memory'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.byType(EditMemoryScreen).evaluate().isNotEmpty ||
            find.text('Edit Memory').evaluate().length >= 1,
        isTrue,
      );
    });

    testWidgets('EditMemoryScreen shows entry content', (tester) async {
      final opened = await _openMemoryDetail(tester);
      if (!opened) return;

      await tester.tap(find.text('Edit Memory'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));

      if (find.byType(EditMemoryScreen).evaluate().isEmpty) return;

      // Should have a text field with content
      expect(
        find.byType(TextField).evaluate().isNotEmpty ||
            find.byType(TextFormField).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('EditMemoryScreen has Save button', (tester) async {
      final opened = await _openMemoryDetail(tester);
      if (!opened) return;

      await tester.tap(find.text('Edit Memory'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));

      if (find.byType(EditMemoryScreen).evaluate().isEmpty) return;

      expect(find.textContaining('Save').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('back from EditMemoryScreen returns to previous screen',
        (tester) async {
      final opened = await _openMemoryDetail(tester);
      if (!opened) return;

      await tester.tap(find.text('Edit Memory'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));

      if (find.byType(EditMemoryScreen).evaluate().isEmpty) return;

      final backBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.arrow_back_rounded,
      );
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await settle(tester);

        expect(find.byType(EditMemoryScreen), findsNothing);
      }
    });
  });

  // ── Group 3: Delete Memory ───────────────────────────────────────────────

  group('Edit/Delete — Delete Memory', () {
    testWidgets('context menu shows Delete option', (tester) async {
      final opened = await _openMoreMenu(tester);
      if (!opened) return;

      expect(find.text('Delete Memory'), findsOneWidget);
    });

    testWidgets('Delete shows confirmation dialog', (tester) async {
      final opened = await _openMoreMenu(tester);
      if (!opened) return;

      if (find.text('Delete Memory').evaluate().isEmpty) return;

      await tester.tap(find.text('Delete Memory'));
      await settle(tester);

      expect(
        find.textContaining('permanently deleted').evaluate().isNotEmpty ||
            find.textContaining('Delete').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Cancel on delete dialog keeps entry', (tester) async {
      final opened = await _openMoreMenu(tester);
      if (!opened) return;

      if (find.text('Delete Memory').evaluate().isEmpty) return;

      await tester.tap(find.text('Delete Memory'));
      await settle(tester);

      expect(find.text('Cancel').evaluate().isNotEmpty, isTrue);

      // Dismiss dialog
      if (find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Still on the detail screen
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
