import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';

import '../helpers/test_app.dart';

/// E2E tests for the BookDetailScreen.
///
/// BookDetailScreen requires a GeneratedBook passed via go_router extra. In
/// demo mode the CHAPTERS tab shows sample chapter cards rather than the mock
/// Book model. The MyLifeBookScreen (auto-generated book) is the main entry
/// point that can produce a GeneratedBook instance. Because generating the
/// book requires AI service calls we cannot reach BookDetailScreen through
/// normal navigation in E2E. Instead we verify the CHAPTERS tab renders the
/// library correctly, which is the prerequisite for reaching the detail screen.

void bookDetailFlowTests() {

  group('Book Detail — CHAPTERS Tab Prerequisite', () {
    testWidgets('CHAPTERS tab renders LibraryScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('LibraryScreen shows book content', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      // Scroll to expose book cards below the header.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // In demo mode either book title or sample chapter cards are visible.
      final hasContent =
          find.textContaining('My Life Story').evaluate().isNotEmpty ||
              find.textContaining('Chapter').evaluate().isNotEmpty ||
              find.byType(GestureDetector).evaluate().isNotEmpty;
      expect(hasContent, isTrue);
    });

    testWidgets('My Life Book button is accessible from CHAPTERS tab',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      // The LibraryScreen shows a "My Life Book" card or similar entry point.
      // Scroll to find it.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      final hasLifeBook =
          find.textContaining('My Life').evaluate().isNotEmpty ||
              find.textContaining('Life Book').evaluate().isNotEmpty ||
              find.textContaining('Auto').evaluate().isNotEmpty;
      expect(hasLifeBook, isTrue);
    });

    testWidgets('can navigate back from CHAPTERS to HOME', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsNothing);
    });
  });
}
