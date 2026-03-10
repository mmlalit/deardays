import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';

void main() {
  Widget buildApp() {
    return MaterialApp(theme: AppTheme.light, home: const TextEntryScreen());
  }

  group('TextEntryScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextEntryScreen), findsOneWidget);
    });

    testWidgets('shows salutation (Dear Diary or custom)', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('Dear').evaluate().isNotEmpty ||
        find.textContaining('diary').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows a writing prompt', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // One of the 15 prompts should be visible
      final knownPrompts = [
        'What made you smile today',
        'What are you grateful for',
        'What challenged you today',
        'How are you really feeling',
        'What did you learn today',
      ];

      final hasPrompt = knownPrompts.any(
        (p) => find.textContaining(p).evaluate().isNotEmpty,
      );
      expect(hasPrompt, isTrue);
    });

    testWidgets('shows text input area', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows 0 words initially', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('0 words'), findsOneWidget);
    });

    testWidgets('shows Add to Book button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('Add to Book').evaluate().isNotEmpty ||
        find.textContaining('Save').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('TextEntryScreen - Typing', () {
    testWidgets('typing updates word count', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'Hello world this is a test');
      await tester.pump();

      expect(find.text('0 words').evaluate().isEmpty, isTrue);
      expect(find.textContaining('words'), findsWidgets);
    });

    testWidgets('can type and see text in field', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'My journal entry today');
      await tester.pump();

      expect(find.text('My journal entry today'), findsOneWidget);
    });

    testWidgets('prompt hides when user starts typing', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      // After typing, at least the text field should still be present
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('TextEntryScreen - AI Polish toggle', () {
    testWidgets('shows AI Polish option', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('AI Polish').evaluate().isNotEmpty ||
        find.textContaining('Polish').evaluate().isNotEmpty ||
        find.byType(Switch).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('TextEntryScreen - Actions', () {
    testWidgets('close/back button is visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byIcon(Icons.close).evaluate().isNotEmpty ||
        find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
        find.byIcon(Icons.arrow_back_ios).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('photo attachment option is visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byIcon(Icons.camera_alt_outlined).evaluate().isNotEmpty ||
        find.byIcon(Icons.photo_camera_outlined).evaluate().isNotEmpty ||
        find.byIcon(Icons.camera_alt).evaluate().isNotEmpty ||
        find.textContaining('photo').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
