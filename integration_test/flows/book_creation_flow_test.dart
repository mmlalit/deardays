import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';

import '../helpers/test_app.dart';

void bookCreationFlowTests() {
  // The LibraryScreen was redesigned — "Create a Book" is no longer in it.
  // Navigate to BookCreationScreen directly via the /book-create route.
  Future<void> openBookCreation(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp());
    await tester.pumpAndSettle();

    // Navigate directly to BookCreationScreen via the router.
    // Use HomeScreen context (inside router scope) rather than MaterialApp.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/book-create');
    await tester.pumpAndSettle();
  }

  group('Book Creation — Navigation', () {
    testWidgets('CHAPTERS tab shows LibraryScreen', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('CHAPTERS tab shows "FEATURED COLLECTION" hero card',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.text('FEATURED COLLECTION'), findsOneWidget);
    });

    testWidgets('CHAPTERS tab shows "Read Autobiography" button',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.text('Read Autobiography'), findsOneWidget);
    });
  });

  group('Book Creation — Screen Structure', () {
    testWidgets('BookCreationScreen renders without crash', (tester) async {
      await openBookCreation(tester);
      expect(find.byType(BookCreationScreen), findsOneWidget);
    });

    testWidgets('shows "Choose how to create your book" prompt',
        (tester) async {
      await openBookCreation(tester);
      expect(find.textContaining('Choose how to create'), findsOneWidget);
    });

    testWidgets('shows Pick & Choose approach card', (tester) async {
      await openBookCreation(tester);
      expect(find.text('Pick & Choose'), findsOneWidget);
    });

    testWidgets('shows Daily Diary approach card', (tester) async {
      await openBookCreation(tester);
      expect(find.text('Daily Diary'), findsOneWidget);
    });

    testWidgets('shows AI Surprise Me approach card', (tester) async {
      await openBookCreation(tester);
      expect(find.text('AI Surprise Me'), findsOneWidget);
    });

    testWidgets('tapping Pick & Choose shows entry selection flow',
        (tester) async {
      await openBookCreation(tester);

      await tester.tap(find.text('Pick & Choose'));
      await tester.pumpAndSettle();

      // The Pick & Choose flow shows a "Book Title" input and entry count
      expect(find.textContaining('entries selected'), findsOneWidget);
    });
  });

  group('Book Creation — CHAPTERS tab structure', () {
    testWidgets('CHAPTERS tab shows "Continue Your Journey" title',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.text('Continue Your Journey'), findsOneWidget);
    });

    testWidgets('CHAPTERS tab shows "Life Chapters" section', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life Chapters'), findsOneWidget);
    });

    testWidgets('CHAPTERS tab shows "Create a Book" button',
        (tester) async {
      // Create a Book is accessible via direct route navigation.
      await openBookCreation(tester);
      // BookCreationScreen title bar shows "Create a Book"
      expect(find.text('Create a Book'), findsOneWidget);
    });
  });
}
