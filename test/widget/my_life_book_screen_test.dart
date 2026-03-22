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

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MyLifeBookScreen), findsOneWidget);
    });

    testWidgets('shows empty state when no chapters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      // With no chapters, the screen shows the empty state message
      expect(find.text('No chapters yet'), findsOneWidget);
    });

    testWidgets('shows empty state guidance text', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Library tab').evaluate().isNotEmpty ||
            find.textContaining('chapters').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows book icon in empty state', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('renders header area without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      // Header always renders regardless of chapter state
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('shows Scaffold in all states', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows CustomScrollView', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}
