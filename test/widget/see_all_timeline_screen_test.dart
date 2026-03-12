import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/explore/presentation/screens/see_all_timeline_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({SeeAllSection section = SeeAllSection.happiest}) {
    return buildTestApp(
      SeeAllTimelineScreen(section: section),
      overrides: authenticatedOverrides(),
    );
  }

  group('SeeAllTimelineScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SeeAllTimelineScreen), findsOneWidget);
    });

    testWidgets('shows Happiest Memories title', (tester) async {
      await tester.pumpWidget(buildApp(section: SeeAllSection.happiest));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Happiest Memories'), findsOneWidget);
    });

    testWidgets('shows Family Journey title', (tester) async {
      await tester.pumpWidget(buildApp(section: SeeAllSection.family));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Family Journey'), findsOneWidget);
    });

    testWidgets('shows Travel Adventures title', (tester) async {
      await tester.pumpWidget(buildApp(section: SeeAllSection.travel));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Travel Adventures'), findsOneWidget);
    });

    testWidgets('shows filter chips for happiest section', (tester) async {
      await tester.pumpWidget(buildApp(section: SeeAllSection.happiest));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Great'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
