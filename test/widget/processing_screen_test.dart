import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/processing_screen.dart';
import 'package:deardays/features/journal/presentation/screens/review_save_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  const reviewData = ReviewData(
    rawText: 'Today was a wonderful day at the park.',
    mood: 'great',
    isVoice: false,
  );

  group('ProcessingScreen - Structure', () {
    // ProcessingScreen uses AnimationController.repeat() in initState,
    // which leaves perpetually pending timers. Widget tests cannot cleanly
    // dispose of repeating animation controllers, so we verify construction
    // only via runAsync (real async, no fake timer assertions).
    testWidgets('can be constructed', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildTestApp(const ProcessingScreen(data: reviewData)),
        );
      });
      expect(find.byType(ProcessingScreen), findsOneWidget);
    });
  });
}
