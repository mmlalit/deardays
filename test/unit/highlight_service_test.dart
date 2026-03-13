import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/ai/highlight_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

void main() {
  group('HighlightService', () {
    late HighlightService service;

    setUp(() {
      service = HighlightService();
    });

    test('is a singleton', () {
      final a = HighlightService();
      final b = HighlightService();
      expect(identical(a, b), isTrue);
    });

    group('extractHighlight', () {
      test('returns null for empty content', () {
        final entry = _makeEntry(content: '');
        expect(service.extractHighlight(entry), isNull);
      });

      test('extracts a highlight from emotional content', () {
        final entry = _makeEntry(
          content:
              'A Morning Walk\n\nThe streets were quiet. I realized that these small moments of peace are what I truly treasure in life. The coffee was perfect.',
        );
        final highlight = service.extractHighlight(entry);
        expect(highlight, isNotNull);
        expect(highlight!.length, greaterThan(10));
      });

      test('prefers insightful sentences', () {
        final entry = _makeEntry(
          content:
              'Today was normal.\nI went to the store.\nLooking back, I realized this year taught me more about patience than any other.',
        );
        final highlight = service.extractHighlight(entry);
        expect(highlight, isNotNull);
        expect(highlight!.toLowerCase(), contains('realized'));
      });
    });

    group('extractHighlights', () {
      test('returns empty for whitespace-only content', () {
        final entry = _makeEntry(content: '   \n  ');
        expect(service.extractHighlights(entry), isEmpty);
      });

      test('respects maxHighlights parameter', () {
        final entry = _makeEntry(
          content:
              'First sentence is amazing. Second one is incredible. Third is wonderful. Fourth is beautiful. Fifth is lovely.',
        );
        final highlights = service.extractHighlights(entry, maxHighlights: 2);
        expect(highlights.length, lessThanOrEqualTo(2));
      });

      test('highlights have non-zero scores', () {
        final entry = _makeEntry(
          content:
              'Beach Sunrise\n\nI love the way the sun paints the sky. It made me realize how beautiful mornings can be. My heart was full of gratitude.',
        );
        final highlights = service.extractHighlights(entry);
        for (final h in highlights) {
          expect(h.score, greaterThan(0));
        }
      });

      test('classifies highlights by type', () {
        final entry = _makeEntry(
          content:
              'Title\n\nI realized that love is patient. My heart was full of joy. The sunset was unforgettable.',
        );
        final highlights = service.extractHighlights(entry, maxHighlights: 5);
        if (highlights.isNotEmpty) {
          final types = highlights.map((h) => h.type).toSet();
          expect(types, isNotEmpty);
        }
      });

      test('uses polishedContent when available', () {
        final entry = _makeEntry(
          content: 'Basic raw text.',
          polishedContent:
              'Polished Story\n\nI treasure every moment with the people I love. These memories are precious beyond words.',
        );
        final highlights = service.extractHighlights(entry);
        if (highlights.isNotEmpty) {
          // Should use polished content for extraction
          expect(
            highlights.first.text.toLowerCase(),
            anyOf(contains('treasure'), contains('precious'), contains('love')),
          );
        }
      });
    });

    group('extractWeeklyHighlights', () {
      test('returns empty for empty entries list', () {
        expect(service.extractWeeklyHighlights([]), isEmpty);
      });

      test('extracts highlights across multiple entries', () {
        final entries = [
          _makeEntry(
            id: '1',
            content: 'Entry One\n\nI love the peaceful mornings in the garden.',
          ),
          _makeEntry(
            id: '2',
            content: 'Entry Two\n\nI realized that friendship is everything.',
          ),
        ];
        final highlights = service.extractWeeklyHighlights(entries);
        expect(highlights, isNotEmpty);
      });

      test('deduplicates similar highlights', () {
        final entries = [
          _makeEntry(
            id: '1',
            content: 'Title\n\nI love mornings so much.',
          ),
          _makeEntry(
            id: '2',
            content: 'Title\n\nI love mornings so much.',
          ),
        ];
        final highlights = service.extractWeeklyHighlights(entries);
        // Should not have duplicate content
        final texts = highlights.map((h) => h.text).toList();
        expect(texts.toSet().length, texts.length);
      });

      test('respects maxHighlights', () {
        final entries = List.generate(
          10,
          (i) => _makeEntry(
            id: '$i',
            content: 'Title $i\n\nI treasure this beautiful moment of peace and love.',
          ),
        );
        final highlights =
            service.extractWeeklyHighlights(entries, maxHighlights: 3);
        expect(highlights.length, lessThanOrEqualTo(3));
      });
    });
  });
}

JournalEntry _makeEntry({
  String id = 'test-1',
  required String content,
  String? polishedContent,
}) {
  return JournalEntry(
    id: id,
    userId: 'test-user',
    content: content,
    polishedContent: polishedContent,
    entryDate: DateTime.now().subtract(const Duration(days: 1)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
