import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_creation_screen.dart';

import '../helpers/test_app.dart';

void bookCreationFlowTests() {
  group('Book Creation — Navigation', () {
    testWidgets('CHAPTERS tab shows "Create a Book" button', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Navigate to CHAPTERS tab
      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);

      // Scroll down to reveal the "Create a Book" button
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create a Book'), findsOneWidget);
    });

    testWidgets('tapping "Create a Book" navigates to BookCreationScreen',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      // Navigate to CHAPTERS tab
      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      // Scroll down to reveal the "Create a Book" button
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create a Book'));
      await tester.pumpAndSettle();

      expect(find.byType(BookCreationScreen), findsOneWidget);
    });
  });

  group('Book Creation — Screen Structure', () {
    Future<void> openBookCreation(WidgetTester tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create a Book'));
      await tester.pumpAndSettle();
    }

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
    testWidgets('CHAPTERS tab shows "My Life Book" card', (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.text('My Life Book'), findsOneWidget);
    });

    testWidgets('CHAPTERS tab shows "Your Life Stories" section',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      expect(find.text('Your Life Stories'), findsOneWidget);
    });

    testWidgets('CHAPTERS tab shows "Create Custom Chapter" button',
        (tester) async {
      await tester.pumpWidget(buildE2EApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHAPTERS'));
      await tester.pumpAndSettle();

      // Scroll down to see the create chapter button
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Custom Chapter'), findsOneWidget);
    });
  });
}
