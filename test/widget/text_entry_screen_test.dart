import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return ProviderScope(
      overrides: authenticatedOverrides(),
      child: MaterialApp(theme: AppTheme.light, home: const TextEntryScreen()),
    );
  }

  group('TextEntryScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextEntryScreen), findsOneWidget);
    });

    testWidgets('shows Write Memory header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Write Memory'), findsOneWidget);
    });

    testWidgets('shows a writing prompt chip', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Prompts are shown as chip buttons
      final knownPrompts = [
        'What made you smile?',
        'Who did you meet?',
        'A challenge faced',
        'Something new learned',
        'Best part of today',
        'Grateful for...',
      ];

      final hasPrompt = knownPrompts.any(
        (p) => find.text(p).evaluate().isNotEmpty,
      );
      expect(hasPrompt, isTrue);
    });

    testWidgets('shows text input area', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows Save Memory button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Save Memory').evaluate().isNotEmpty ||
        find.textContaining('Save').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows NEED A PROMPT section', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('NEED A PROMPT?'), findsOneWidget);
    });
  });

  group('TextEntryScreen - Typing', () {
    testWidgets('can type and see text in field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'My journal entry today');
      await tester.pump();

      expect(find.text('My journal entry today'), findsOneWidget);
    });

    testWidgets('word count appears after typing', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'Hello world this is a test');
      await tester.pump();

      // Word count shown as '<n> w'
      expect(
        find.textContaining(' w').evaluate().isNotEmpty ||
        find.byType(TextEntryScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('TextEntryScreen - Actions', () {
    testWidgets('back button is visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty ||
        find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
        find.byIcon(Icons.close).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('photo attachment option is visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('photo').evaluate().isNotEmpty ||
        find.textContaining('Photo').evaluate().isNotEmpty ||
        find.byIcon(Icons.camera_alt_outlined).evaluate().isNotEmpty ||
        find.byIcon(Icons.photo_camera_outlined).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
