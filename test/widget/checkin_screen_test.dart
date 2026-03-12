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

    testWidgets('shows mood selection prompt', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('feeling today'), findsOneWidget);
    });

    testWidgets('shows mood options', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Great'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Tough'), findsOneWidget);
    });

    testWidgets('shows Aura header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Aura'), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
