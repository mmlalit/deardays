import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  const reviewData = ReviewData(
    rawText: 'Today was a wonderful day at the park with my family.',
    mood: 'great',
  );

  Widget buildApp() {
    return buildTestApp(
      ReviewSaveScreen(data: reviewData),
      overrides: authenticatedOverrides(),
    );
  }

  group('ReviewSaveScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReviewSaveScreen), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows the entry text content', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('wonderful day'), findsWidgets);
    });
  });
}
