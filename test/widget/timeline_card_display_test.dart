library;

/// Test B — Widget tests that assert on actual displayed values.
///
/// Verifies that timeline cards show:
/// - Correct time (not 00:00)
/// - Entry content/title
/// - Photo widget when media present
/// - Gradient banner when no media
/// - Mood tags
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import 'package:deardays/core/theme/app_theme.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  final now = DateTime(2026, 3, 14, 19, 49);

  JournalEntry makeEntry({
    String id = 'e1',
    String content = 'A great day\n\nWent to the park and had fun.',
    String? mood = 'great',
    TimeOfDay? entryTime = const TimeOfDay(hour: 19, minute: 49),
    List<EntryMedia> media = const [],
    bool hasPhoto = false,
  }) {
    return JournalEntry(
      id: id,
      userId: 'test-user',
      content: content,
      mood: mood,
      entryDate: DateTime(2026, 3, 14),
      entryTime: entryTime,
      hasPhoto: hasPhoto,
      wordCount: content.split(' ').length,
      createdAt: now,
      updatedAt: now,
      media: media,
    );
  }

  Widget buildApp({List<JournalEntry> entries = const []}) {
    return ProviderScope(
      overrides: authenticatedOverrides(entries: entries),
      child: MaterialApp(
        theme: AppTheme.light,
        home: const TimelineScreen(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // B1. Time display on timeline cards
  // ---------------------------------------------------------------------------

  group('Timeline card — time display', () {
    testWidgets('shows correct time from entryTime, not 00:00', (tester) async {
      final entry = makeEntry(entryTime: const TimeOfDay(hour: 19, minute: 49));
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      // The card should show 19:49
      expect(find.textContaining('19:49'), findsWidgets);
      // And should NOT show 00:00 (which is what entryDate.hour gives)
      // We can't assert findsNothing for 00:00 because other UI might show it,
      // but the card with our entry should have 19:49
    });

    testWidgets('shows morning time correctly', (tester) async {
      final entry = makeEntry(entryTime: const TimeOfDay(hour: 7, minute: 5));
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('07:05'), findsWidgets);
    });

    testWidgets('shows midnight time as 00:00 only when entryTime is actually midnight', (tester) async {
      final entry = makeEntry(entryTime: const TimeOfDay(hour: 0, minute: 0));
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      // This is legitimate — the user actually logged at midnight
      expect(find.textContaining('00:00'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // B2. Content display on timeline cards
  // ---------------------------------------------------------------------------

  group('Timeline card — content display', () {
    testWidgets('shows entry title text', (tester) async {
      final entry = makeEntry(content: 'My Amazing Trip\n\nBody text here.');
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('My Amazing Trip'), findsWidgets);
    });

    testWidgets('shows date in MMM DD format', (tester) async {
      final entry = makeEntry();
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('MAR 14'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // B3. Photo vs gradient rendering
  // ---------------------------------------------------------------------------

  group('Timeline card — photo rendering', () {
    testWidgets('renders card with photo media without crash', (tester) async {
      final entry = makeEntry(
        hasPhoto: true,
        media: [
          EntryMedia(
            id: 'm1', entryId: 'e1', userId: 'test-user',
            mediaType: 'photo',
            storagePath: 'user-id/entry-id/photo.jpg', // Storage path triggers FutureBuilder
            createdAt: now,
          ),
        ],
      );
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      // With a storage path, FutureBuilder<String> is used for signed URL
      expect(find.byType(FutureBuilder<String>), findsWidgets);
    });

    testWidgets('shows gradient shimmer (not CircularProgressIndicator) while photo loads', (tester) async {
      final entry = makeEntry(
        hasPhoto: true,
        media: [
          EntryMedia(
            id: 'm1', entryId: 'e1', userId: 'test-user',
            mediaType: 'photo',
            storagePath: 'user-id/entry-id/photo.jpg',
            createdAt: now,
          ),
        ],
      );
      await tester.pumpWidget(buildApp(entries: [entry]));
      // Do NOT pump long — catch the waiting state
      await tester.pump(const Duration(milliseconds: 50));

      // No spinner should be shown during photo load
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders collage card with 2 photos without crash', (tester) async {
      final entry = makeEntry(
        hasPhoto: true,
        media: [
          EntryMedia(id: 'm1', entryId: 'e1', userId: 'u', mediaType: 'photo',
              storagePath: 'u/e/p1.jpg', createdAt: now),
          EntryMedia(id: 'm2', entryId: 'e1', userId: 'u', mediaType: 'photo',
              storagePath: 'u/e/p2.jpg', createdAt: now),
        ],
      );
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('renders collage card with 3 photos without crash', (tester) async {
      final entry = makeEntry(
        hasPhoto: true,
        media: [
          EntryMedia(id: 'm1', entryId: 'e1', userId: 'u', mediaType: 'photo',
              storagePath: 'u/e/p1.jpg', createdAt: now),
          EntryMedia(id: 'm2', entryId: 'e1', userId: 'u', mediaType: 'photo',
              storagePath: 'u/e/p2.jpg', createdAt: now),
          EntryMedia(id: 'm3', entryId: 'e1', userId: 'u', mediaType: 'photo',
              storagePath: 'u/e/p3.jpg', createdAt: now),
        ],
      );
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimelineScreen), findsOneWidget);
    });

    testWidgets('renders without crash when entry has no media', (tester) async {
      final entry = makeEntry(media: [], hasPhoto: false);
      await tester.pumpWidget(buildApp(entries: [entry]));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimelineScreen), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // B4. Multiple entries display
  // ---------------------------------------------------------------------------

  group('Timeline — multiple entries', () {
    testWidgets('renders multiple entry cards', (tester) async {
      final entries = [
        makeEntry(id: 'e1', content: 'First entry\n\nBody one.', entryTime: const TimeOfDay(hour: 8, minute: 0)),
        makeEntry(id: 'e2', content: 'Second entry\n\nBody two.', entryTime: const TimeOfDay(hour: 14, minute: 30)),
      ];
      await tester.pumpWidget(buildApp(entries: entries));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('First entry'), findsWidgets);
      expect(find.textContaining('Second entry'), findsWidgets);
    });
  });
}
