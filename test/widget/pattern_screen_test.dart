import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/auth/presentation/screens/pattern_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({PatternMode mode = PatternMode.setup}) {
    return buildTestApp(PatternScreen(mode: mode));
  }

  group('PatternScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PatternScreen), findsOneWidget);
    });

    testWidgets('shows Create Pattern title in setup mode', (tester) async {
      await tester.pumpWidget(buildApp(mode: PatternMode.setup));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create Pattern'), findsOneWidget);
    });

    testWidgets('shows Draw Pattern title in verify mode', (tester) async {
      await tester.pumpWidget(buildApp(mode: PatternMode.verify));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Draw Pattern'), findsOneWidget);
    });

    testWidgets('shows subtitle text in setup mode', (tester) async {
      await tester.pumpWidget(buildApp(mode: PatternMode.setup));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Connect at least 4 dots'), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
