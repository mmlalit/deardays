import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/edit_memory_screen.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  const reviewData = ReviewData(
    rawText: 'A Beautiful Morning\nWalking through the park, I noticed the cherry blossoms blooming.',
    mood: 'great',
  );

  Widget buildApp() {
    return buildTestApp(EditMemoryScreen(data: reviewData));
  }

  group('EditMemoryScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EditMemoryScreen), findsOneWidget);
    });

    testWidgets('shows title text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // The title controller should be pre-filled with first line
      expect(find.text('A Beautiful Morning'), findsOneWidget);
    });

    testWidgets('shows story text field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('cherry blossoms'),
        findsOneWidget,
      );
    });

    testWidgets('renders text fields for editing', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsWidgets);
    });
  });
}
