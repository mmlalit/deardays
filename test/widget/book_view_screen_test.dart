import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/book/presentation/screens/book_view_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';

void main() {
  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.light,
      home: const BookViewScreen(),
    );
  }

  group('BookViewScreen - Layout', () {
    testWidgets('renders DEARDAYS header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('DEARDAYS'), findsOneWidget);
    });

    testWidgets('renders Memoir style badge', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Memoir'), findsOneWidget);
    });

    testWidgets('renders book title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('The Story of Sarah'), findsOneWidget);
    });

    testWidgets('renders date range', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('2026 \u2014 Present'), findsOneWidget);
    });

    testWidgets('renders Contents section', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Contents'), findsOneWidget);
    });

    testWidgets('renders 3 chapters', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('CHAPTER 1'), findsOneWidget);
      expect(find.textContaining('CHAPTER 2'), findsOneWidget);
      expect(find.textContaining('CHAPTER 3'), findsOneWidget);
    });

    testWidgets('renders entry date and mood', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('March 7, 2026'), findsOneWidget);
      expect(find.textContaining('Grateful'), findsOneWidget);
    });

    testWidgets('renders drop cap T', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('renders Download as PDF button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll down to find button
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('Download as PDF'), findsOneWidget);
    });
  });
}
