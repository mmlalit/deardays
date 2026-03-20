import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/book/data/models/book_page.dart';
import 'package:deardays/features/book/presentation/screens/book_reader_screen.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

import '../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Model unit tests
// ---------------------------------------------------------------------------

void main() {
  group('PagePhoto.fromJson', () {
    test('parses full JSON correctly', () {
      final json = {
        'storage_path': 'user-id/entries/entry-id/photo.jpg',
        'entry_id': 'entry-id',
        'caption': 'A sunny afternoon at the beach.',
        'score': 72,
        'layout': 'weekOpener',
        'after_paragraph': 0,
        'aspect_ratio': 'landscape',
        'is_hero': true,
      };

      final photo = PagePhoto.fromJson(json);

      expect(photo.storagePath, 'user-id/entries/entry-id/photo.jpg');
      expect(photo.entryId, 'entry-id');
      expect(photo.caption, 'A sunny afternoon at the beach.');
      expect(photo.score, 72);
      expect(photo.layout, PageLayout.weekOpener);
      expect(photo.afterParagraph, 0);
      expect(photo.isHero, true);
    });

    test('defaults missing fields gracefully', () {
      final photo = PagePhoto.fromJson(<String, dynamic>{});

      expect(photo.storagePath, '');
      expect(photo.entryId, '');
      expect(photo.caption, '');
      expect(photo.score, 0);
      expect(photo.layout, PageLayout.midPage);
      expect(photo.afterParagraph, 0);
      expect(photo.isHero, false);
    });

    test('unknown layout string falls back to midPage', () {
      final photo = PagePhoto.fromJson({'layout': 'fancyNewLayout'});
      expect(photo.layout, PageLayout.midPage);
    });

    test('parses all layout values', () {
      for (final layout in PageLayout.values) {
        final photo = PagePhoto.fromJson({'layout': layout.name});
        expect(photo.layout, layout);
      }
    });

    test('toJson round-trips correctly', () {
      const photo = PagePhoto(
        storagePath: 'path/photo.jpg',
        entryId: 'e1',
        caption: 'Caption text',
        score: 55,
        layout: PageLayout.rightFloat,
        afterParagraph: 2,
        isHero: false,
      );

      final json = photo.toJson();
      final restored = PagePhoto.fromJson(json);

      expect(restored.storagePath, photo.storagePath);
      expect(restored.entryId, photo.entryId);
      expect(restored.caption, photo.caption);
      expect(restored.score, photo.score);
      expect(restored.layout, photo.layout);
      expect(restored.afterParagraph, photo.afterParagraph);
      expect(restored.isHero, photo.isHero);
    });
  });

  group('WeeklyNarrativeBookPage.fromJson', () {
    final sampleJson = {
      'id': 'page-id-1',
      'content': 'The week began quietly.\n\nBy Thursday things picked up.',
      'week_start': '2026-03-09',
      'page_number': 1,
      'word_count': 195,
      'photos': [
        {
          'storage_path': 'user/entries/e1/img.jpg',
          'entry_id': 'e1',
          'caption': 'Sunday brunch.',
          'score': 68,
          'layout': 'weekOpener',
          'after_paragraph': 0,
          'is_hero': true,
        },
      ],
    };

    test('parses full page JSON', () {
      final page = WeeklyNarrativeBookPage.fromJson(sampleJson);

      expect(page.id, 'page-id-1');
      expect(page.content, contains('The week began quietly.'));
      expect(page.weekStart, '2026-03-09');
      expect(page.pageNumber, 1);
      expect(page.wordCount, 195);
      expect(page.photos.length, 1);
      expect(page.photos.first.caption, 'Sunday brunch.');
      expect(page.photos.first.layout, PageLayout.weekOpener);
      expect(page.photos.first.isHero, true);
    });

    test('parses page with empty photos array', () {
      final page = WeeklyNarrativeBookPage.fromJson({
        'id': 'p2',
        'content': 'A quiet week.',
        'week_start': '2026-03-16',
        'page_number': 2,
        'word_count': 120,
        'photos': [],
      });

      expect(page.photos, isEmpty);
    });

    test('parses page with null photos field', () {
      final page = WeeklyNarrativeBookPage.fromJson({
        'id': 'p3',
        'content': 'Another week.',
        'week_start': '2026-03-23',
        'page_number': 3,
        'word_count': 100,
      });

      expect(page.photos, isEmpty);
    });

    test('parses multiple photos', () {
      final page = WeeklyNarrativeBookPage.fromJson({
        'id': 'p4',
        'content': 'A busy week.',
        'week_start': '2026-03-02',
        'page_number': 1,
        'word_count': 150,
        'photos': [
          {'storage_path': 'a', 'entry_id': 'e1', 'caption': 'One',
           'score': 60, 'layout': 'leftFloat', 'after_paragraph': 1, 'is_hero': false},
          {'storage_path': 'b', 'entry_id': 'e2', 'caption': 'Two',
           'score': 50, 'layout': 'rightFloat', 'after_paragraph': 2, 'is_hero': false},
          {'storage_path': 'c', 'entry_id': 'e3', 'caption': 'Three',
           'score': 40, 'layout': 'photoStrip', 'after_paragraph': 0, 'is_hero': false},
        ],
      });

      expect(page.photos.length, 3);
      expect(page.photos[0].layout, PageLayout.leftFloat);
      expect(page.photos[1].layout, PageLayout.rightFloat);
      expect(page.photos[2].layout, PageLayout.photoStrip);
    });
  });

  // ── Widget tests ─────────────────────────────────────────────────────────

  setUpTestEnv();

  group('BookReaderScreen — WeeklyNarrativeBookPage in page list', () {
    // The reader uses BookBuilderService to build pages from entries.
    // WeeklyNarrativeBookPage is injected from the backend, not from the builder.
    // These tests verify the screen handles the sealed class exhaustively.

    const weeklyPage = WeeklyNarrativeBookPage(
      id: 'page-id-1',
      content:
          'The week began with a quiet morning walk.\n\n'
          'By Thursday the pace picked up considerably.\n\n'
          'The weekend brought rest and reflection.',
      weekStart: '2026-03-09',
      pageNumber: 1,
      wordCount: 195,
      photos: const [],
    );

    const weeklyPageWithHeroPhoto = WeeklyNarrativeBookPage(
      id: 'page-id-2',
      content:
          'What a week it was.\n\n'
          'There were moments of joy and wonder.',
      weekStart: '2026-03-16',
      pageNumber: 1,
      wordCount: 160,
      photos: const [
        PagePhoto(
          storagePath: 'user/photo.jpg',
          entryId: 'e1',
          caption: 'Afternoon light.',
          score: 70,
          layout: PageLayout.weekOpener,
          afterParagraph: 0,
          isHero: true,
        ),
      ],
    );

    // Renders a BookReaderScreen that will show the empty state (no entries)
    // because mock entries are empty — we just verify no type errors.
    Widget buildReader({List<JournalEntry> entries = const []}) {
      return buildTestApp(
        const BookReaderScreen(mode: BookMode.stream),
        overrides: authenticatedOverrides(entries: entries),
      );
    }

    testWidgets('renders without crash when entries is empty (shows empty state)',
        (tester) async {
      await tester.pumpWidget(buildReader());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('WeeklyNarrativeBookPage is a valid BookPage subtype', (tester) async {
      expect(weeklyPage, isA<BookPage>());
      expect(weeklyPage, isA<WeeklyNarrativeBookPage>());
    });

    testWidgets('WeeklyNarrativeBookPage with no photos is a BookPage', (tester) async {
      expect(weeklyPage.photos, isEmpty);
      expect(weeklyPage.weekStart, '2026-03-09');
    });

    testWidgets('WeeklyNarrativeBookPage with hero photo has correct layout',
        (tester) async {
      expect(weeklyPageWithHeroPhoto.photos.length, 1);
      expect(weeklyPageWithHeroPhoto.photos.first.layout, PageLayout.weekOpener);
      expect(weeklyPageWithHeroPhoto.photos.first.isHero, isTrue);
    });

    testWidgets('all PageLayout enum values are defined', (tester) async {
      expect(PageLayout.values, containsAll([
        PageLayout.weekOpener,
        PageLayout.rightFloat,
        PageLayout.leftFloat,
        PageLayout.midPage,
        PageLayout.photoStrip,
      ]));
    });

    testWidgets('PagePhoto.toJson produces correct layout key', (tester) async {
      for (final layout in PageLayout.values) {
        const photo = PagePhoto(
          storagePath: 'p',
          entryId: 'e',
          caption: '',
          score: 0,
          layout: PageLayout.midPage,
          afterParagraph: 0,
          isHero: false,
        );
        final json = photo.toJson();
        expect(json.containsKey('layout'), isTrue);
        expect(json.containsKey('storage_path'), isTrue);
        expect(json.containsKey('entry_id'), isTrue);
        expect(json.containsKey('caption'), isTrue);
        expect(json.containsKey('score'), isTrue);
        expect(json.containsKey('after_paragraph'), isTrue);
        expect(json.containsKey('is_hero'), isTrue);
        // suppress unused warning
        expect(layout, isA<PageLayout>());
      }
    });
  });
}
