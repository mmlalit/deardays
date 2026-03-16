import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/checkin/presentation/screens/checkin_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return buildTestApp(
      const CheckInScreen(),
      overrides: authenticatedOverrides(),
    );
  }

  group('CheckInScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CheckInScreen), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows Chat header title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('shows empty state prompt text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining("What's on your mind"), findsOneWidget);
    });

    testWidgets('shows prompt cards in empty state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // Prompt cards are shown; at least one should be visible
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('does not show mood picker options', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // Mood options were removed in redesign
      expect(find.text('Great'), findsNothing);
      expect(find.text('Tough'), findsNothing);
    });
  });
}
