import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/share/presentation/screens/share_card_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime.now();
  final testEntry = JournalEntry(
    id: 'share-entry-id',
    userId: 'test-user-id',
    content: 'Today was a wonderful day at the park with friends.',
    rawContent: 'Today was a wonderful day at the park with friends.',
    mood: 'great',
    entryDate: now,
    wordCount: 10,
    createdAt: now,
    updatedAt: now,
  );

  Widget buildApp() {
    return MaterialApp(
      theme: AppTheme.light,
      home: ShareCardScreen(entry: testEntry),
    );
  }

  group('ShareCardScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ShareCardScreen), findsOneWidget);
    });

    testWidgets('shows Share Memory title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Share Memory'), findsOneWidget);
    });
  });

  group('ShareCardScreen - Platform tabs', () {
    testWidgets('shows Instagram, WhatsApp, and X tabs', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
    });
  });

  group('ShareCardScreen - Style options', () {
    testWidgets('shows Style section with style names', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Minimal'), findsOneWidget);
      expect(find.text('Vibrant'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Nature'), findsOneWidget);
    });
  });

  group('ShareCardScreen - Action buttons', () {
    testWidgets('shows Share/Save button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // On Windows the label is "Save & Copy Path"; on mobile it's "Share"
      final hasSaveOrShare =
          find.text('Save & Copy Path').evaluate().isNotEmpty ||
          find.text('Share').evaluate().isNotEmpty;
      expect(hasSaveOrShare, isTrue);
    });

    testWidgets('shows Save Image button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Save Image'), findsOneWidget);
    });
  });
}
