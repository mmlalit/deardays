import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/timeline/presentation/screens/memory_detail_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return buildTestApp(
      MemoryDetailScreen(entry: mockEntry),
      overrides: authenticatedOverrides(),
    );
  }

  group('MemoryDetailScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MemoryDetailScreen), findsOneWidget);
    });

    testWidgets('shows entry content', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Today was a great day'), findsWidgets);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows back navigation', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.arrow_back_rounded),
        findsWidgets,
      );
    });
  });
}
