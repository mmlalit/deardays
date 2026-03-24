import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return buildTestApp(
      const ExploreScreen(),
      overrides: authenticatedOverrides(),
    );
  }

  group('ExploreScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('shows Explore header text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Explore'), findsOneWidget);
    });

    testWidgets('shows search icon button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('contains a search icon (not a TextField)', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // Search navigates to /search via a GestureDetector + Icon, not a TextField
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });

  group('ExploreScreen - Photo display', () {
    testWidgets('does not show CircularProgressIndicator while photos load', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 50));
      // Photo shimmer replaced the spinner — no spinners should appear during load
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
