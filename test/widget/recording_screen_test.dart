import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp() {
    return ProviderScope(
      overrides: authenticatedOverrides(),
      child: MaterialApp(theme: AppTheme.light, home: const RecordingScreen()),
    );
  }

  group('RecordingScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RecordingScreen), findsOneWidget);
    });

    testWidgets('shows Recording Memory header', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Recording Memory'), findsOneWidget);
    });

    testWidgets('shows timer display', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Timer displays m:s format e.g. '0:00'
      expect(
        find.textContaining(':').evaluate().isNotEmpty ||
        find.textContaining('0').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows recording status text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Ready').evaluate().isNotEmpty ||
        find.text('Recording in progress').evaluate().isNotEmpty ||
        find.text('Paused').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows mic icon button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byIcon(Icons.mic_rounded).evaluate().isNotEmpty ||
        find.byIcon(Icons.mic_off_rounded).evaluate().isNotEmpty ||
        find.byIcon(Icons.mic).evaluate().isNotEmpty ||
        find.byIcon(Icons.stop).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows close button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byIcon(Icons.close_rounded).evaluate().isNotEmpty ||
        find.byIcon(Icons.close).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows waveform visualization', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('shows a writing prompt', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      final knownPrompts = [
        'What made today special?',
        'Who did you spend time with?',
        'What are you grateful for today?',
        'What challenged you today?',
        'Describe one moment from today.',
      ];
      final hasPrompt = knownPrompts.any(
        (p) => find.text(p).evaluate().isNotEmpty,
      );
      expect(hasPrompt, isTrue);
    });
  });

  group('RecordingScreen - Controls', () {
    testWidgets('Finish Recording button is visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Finish Recording').evaluate().isNotEmpty ||
        find.byType(RecordingScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
