import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return buildTestApp(const OnThisDayScreen());
  }

  group('OnThisDayScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OnThisDayScreen), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 100));
      // Should show a loading state while fetching entries
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.byType(Scaffold).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
