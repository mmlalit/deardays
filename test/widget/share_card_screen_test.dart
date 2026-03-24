import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/share/presentation/screens/share_card_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
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
    return buildTestApp(
      ShareCardScreen(entry: testEntry),
      overrides: authenticatedOverrides(),
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
    testWidgets('shows Instagram Story, WhatsApp Status, and Memory Card tabs', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Tabs use multi-line labels: 'Instagram\nStory', 'WhatsApp\nStatus', 'Memory\nCard'
      expect(find.textContaining('Instagram'), findsWidgets);
      expect(find.textContaining('WhatsApp'), findsWidgets);
      expect(find.textContaining('Memory'), findsWidgets);
    });
  });

  group('ShareCardScreen - Action buttons', () {
    testWidgets('shows a share or save button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // Primary button label includes platform name or shows sharing state
      final hasShareButton =
          find.textContaining('Share').evaluate().isNotEmpty ||
          find.textContaining('Sharing').evaluate().isNotEmpty;
      expect(hasShareButton, isTrue);
    });

    testWidgets('shows Save Image button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Save Image'), findsOneWidget);
    });
  });
}
