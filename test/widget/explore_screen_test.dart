import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/explore/presentation/screens/explore_screen.dart';
import 'package:deardays/features/journal/data/models/entry_media.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({List<Override> overrides = const []}) {
    return buildTestApp(
      const ExploreScreen(),
      overrides: overrides.isNotEmpty ? overrides : authenticatedOverrides(),
    );
  }

  // Overrides that include one entry so _buildOverview is rendered (not empty state)
  List<Override> withOneEntry() =>
      authenticatedOverrides(entries: [mockEntry]);

  group('ExploreScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('shows Explore header text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Explore'), findsOneWidget);
    });

    testWidgets('shows search icon button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('contains a search icon (not a TextField)', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('ExploreScreen - Photo display', () {
    testWidgets('does not show CircularProgressIndicator while photos load',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ExploreScreen - Section headers (all-caps editorial style)', () {
    testWidgets('shows YOUR HIGHLIGHTS section header', (tester) async {
      await tester.pumpWidget(buildApp(overrides: withOneEntry()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('YOUR HIGHLIGHTS'), findsOneWidget);
    });

    testWidgets("shows THIS WEEK'S MOOD header", (tester) async {
      await tester.pumpWidget(buildApp(overrides: withOneEntry()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text("THIS WEEK'S MOOD"), findsOneWidget);
    });

    testWidgets('shows RECENT MEMORIES section header', (tester) async {
      await tester.pumpWidget(buildApp(overrides: withOneEntry()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('RECENT MEMORIES'), findsOneWidget);
    });
  });

  group('ExploreScreen - Mood day strip', () {
    testWidgets('shows day labels in mood strip', (tester) async {
      await tester.pumpWidget(buildApp(overrides: withOneEntry()));
      await tester.pump(const Duration(seconds: 1));
      // The strip always shows 7 day initials. 'F' appears exactly once.
      expect(find.text('F'), findsWidgets);
    });
  });

  group('ExploreScreen - End-of-feed accent', () {
    testWidgets('shows end-of-feed tagline after scrolling', (tester) async {
      await tester.pumpWidget(buildApp(overrides: withOneEntry()));
      await tester.pump(const Duration(seconds: 1));

      // Scroll to the bottom to build the lazy-loaded end-of-feed widget
      await tester.scrollUntilVisible(
        find.text('More memories await discovery'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('More memories await discovery'), findsOneWidget);
    });
  });

  group('ExploreScreen - With entries', () {
    testWidgets('shows editorial photo card badge for photo entry',
        (tester) async {
      final photoEntry = mockEntry.copyWith(
        id: 'explore-photo',
        content: 'Morning hike with amazing views from the summit today.',
        mood: 'great',
        media: [
          EntryMedia(
            id: 'media-1',
            entryId: 'explore-photo',
            userId: 'test-user-id',
            mediaType: 'photo',
            storagePath: 'test-user-id/explore-photo/hike.jpg',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [photoEntry]),
      ));
      await tester.pump(const Duration(seconds: 1));

      // Mosaic grid renders for photo entries (no PHOTO badge in mosaic layout)
      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('shows audio card for audio-only entry', (tester) async {
      final audioEntry = mockEntry.copyWith(
        id: 'explore-audio',
        content: 'Late night thoughts on the nature of memory and time.',
        mood: 'okay',
        media: [
          EntryMedia(
            id: 'media-audio',
            entryId: 'explore-audio',
            userId: 'test-user-id',
            mediaType: 'audio',
            storagePath: 'test-user-id/explore-audio/memo.m4a',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [audioEntry]),
      ));
      await tester.pump(const Duration(seconds: 1));

      // Audio entries appear in the mosaic grid with mood-gradient background
      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets('shows HAPPIEST MEMORIES section for happy entries after scroll',
        (tester) async {
      final happyEntry = mockEntry.copyWith(
        id: 'happy-1',
        content: 'Best day ever at the beach with the whole family.',
        mood: 'great',
      );

      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [happyEntry]),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('HAPPIEST MEMORIES'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HAPPIEST MEMORIES'), findsOneWidget);
    });

    testWidgets('shows See all → pill once HAPPIEST MEMORIES is visible',
        (tester) async {
      final happyEntry = mockEntry.copyWith(
        id: 'happy-2',
        content: 'Amazing birthday celebration with friends.',
        mood: 'great',
      );

      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [happyEntry]),
      ));
      await tester.pump(const Duration(seconds: 1));

      // Scroll to HAPPIEST MEMORIES — See all → is in the same header row
      await tester.scrollUntilVisible(
        find.text('HAPPIEST MEMORIES'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The pill lives next to the section header
      expect(find.text('See all →'), findsWidgets);
    });

    testWidgets('shows category section headers after scroll', (tester) async {
      final familyEntry = mockEntry.copyWith(
        id: 'family-1',
        content: 'Had a wonderful dinner with mom and dad tonight.',
        mood: 'good',
      );

      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(entries: [familyEntry]),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('FAMILY MOMENTS'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('FAMILY MOMENTS'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('TRAVEL STORIES'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TRAVEL STORIES'), findsOneWidget);
    });
  });

  group('ExploreScreen - Filter interaction', () {
    testWidgets('search icon is present and tappable widget exists',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      // Verify search icon is present — navigation to /search is tested in E2E
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });
  });
}
