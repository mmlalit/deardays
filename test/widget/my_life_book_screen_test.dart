import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/features/book/presentation/screens/my_life_book_screen.dart';

import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildScreen() {
    return buildTestApp(
      const MyLifeBookScreen(),
      overrides: authenticatedOverrides(),
    );
  }

  group('MyLifeBookScreen', () {
    testWidgets('renders header with title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('My Life Book'), findsOneWidget);
    });

    testWidgets('renders cover card with volume label', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('VOLUME I'), findsOneWidget);
      expect(find.text('The Digital Autobiography'), findsOneWidget);
    });

    testWidgets('renders reading progress', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('READING PROGRESS'), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
    });

    testWidgets('renders Contents section with chapters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Contents'), findsOneWidget);
      // Chapter titles
      expect(find.textContaining('New Year Beginnings'), findsWidgets);
      expect(find.textContaining('Love & Connection'), findsOneWidget);
      expect(find.textContaining('Family Life'), findsOneWidget);
    });

    testWidgets('shows first chapter content by default', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Chapter 1: New Year Beginnings'),
          findsOneWidget);
      expect(find.text('FRESH STARTS'), findsOneWidget);
    });

    testWidgets('shows floating nav with SAVE and SHARE', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SAVE'), findsOneWidget);
      expect(find.text('SHARE'), findsOneWidget);
    });

    testWidgets('shows continue hint to next chapter', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continued in Chapter 2'), findsOneWidget);
    });

    testWidgets('shows chapter mood metadata', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('MOOD: HOPEFUL'), findsOneWidget);
    });
  });
}
