import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/onboarding/presentation/screens/onboarding_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  bool completed = false;

  Widget buildApp() {
    completed = false;
    return buildTestApp(
      OnboardingScreen(onComplete: () => completed = true),
    );
  }

  group('OnboardingScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('shows first page title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Speak your day'), findsOneWidget);
    });

    testWidgets('shows Skip button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('shows Next button on first page', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // Next button now uses an arrow icon (GestureDetector + AnimatedContainer)
      // instead of "Next" text — check for the forward arrow icon
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('page dots are visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // 3 dot indicators rendered as AnimatedContainer
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('Skip calls onComplete', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(completed, isTrue);
    });
  });
}
