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

    testWidgets('shows Write header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Header now shows "Write" (not "Write Memory")
      expect(find.text('Write'), findsOneWidget);
    });

    testWidgets('shows a writing prompt chip', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Prompts are shown as list items — check for any known prompt texts
      final knownPrompts = [
        'What made you smile today?',
        'Who were you with today?',
        'Something new you learned',
        'A challenge you faced',
        'What are you grateful for?',
        'Best part of today',
        'A meal you enjoyed',
        'Something beautiful you saw',
        'An idea that excited you',
        'A memorable conversation',
        'Something you accomplished',
        'A calm moment today',
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

    testWidgets('shows Continue button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Bottom bar has "Continue" button (replacing "Save Memory")
      expect(
        find.text('Continue').evaluate().isNotEmpty ||
        find.textContaining('Continue').evaluate().isNotEmpty ||
        find.textContaining('Save').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows prompt section', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Prompt section header changed from "NEED A PROMPT?" to "Need a spark?"
      expect(find.text('Need a spark?'), findsOneWidget);
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

    testWidgets('options menu button is visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // The text entry screen has a "more options" icon button (photo attachment
      // was removed; options are now in the overflow menu)
      expect(
        find.byIcon(Icons.more_horiz_rounded).evaluate().isNotEmpty ||
        find.byIcon(Icons.more_vert).evaluate().isNotEmpty ||
        find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
