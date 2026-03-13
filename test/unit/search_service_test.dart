import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/search/search_service.dart';
import 'package:deardays/features/journal/data/models/journal_entry.dart';

void main() {
  group('SearchService', () {
    late SearchService service;
    late List<JournalEntry> entries;

    setUp(() {
      service = SearchService();
      service.clearRecentSearches();
      entries = [
        _makeEntry(
          id: '1',
          content: 'Beach Sunrise with Family\n\nWoke up at 5am and drove to the coast.',
          mood: 'great',
          location: 'Malibu Beach, California',
        ),
        _makeEntry(
          id: '2',
          content: 'Completed First Marathon\n\n42 kilometres of pure willpower.',
          mood: 'great',
        ),
        _makeEntry(
          id: '3',
          content: 'Tough Day at Work\n\nThe client call did not go how I hoped.',
          mood: 'tough',
        ),
        _makeEntry(
          id: '4',
          content: 'Paris at Dusk\n\nThe city of lights never fails to enchant.',
          mood: 'good',
          location: 'Paris, France',
        ),
      ];
    });

    group('search', () {
      test('returns empty for blank query', () {
        final results = service.search('', entries);
        expect(results, isEmpty);
      });

      test('finds entries by title keyword', () {
        final results = service.search('Beach', entries);
        expect(results, isNotEmpty);
        expect(results.first.entry.id, '1');
      });

      test('finds entries by content keyword', () {
        final results = service.search('marathon', entries);
        expect(results, isNotEmpty);
        expect(results.first.entry.id, '2');
      });

      test('finds entries by mood', () {
        final results = service.search('tough', entries);
        expect(results.any((r) => r.entry.id == '3'), isTrue);
      });

      test('finds entries by location', () {
        final results = service.search('Paris', entries);
        expect(results, isNotEmpty);
        expect(results.first.entry.id, '4');
      });

      test('returns results sorted by relevance', () {
        final results = service.search('Beach', entries);
        // Entry with 'Beach' in title should score higher
        if (results.length > 1) {
          expect(
            results.first.relevanceScore,
            greaterThanOrEqualTo(results.last.relevanceScore),
          );
        }
      });

      test('sets matchedField correctly', () {
        final results = service.search('Malibu', entries);
        expect(results, isNotEmpty);
        expect(results.first.matchedField, 'location');
      });

      test('returns excerpt containing the search term', () {
        final results = service.search('marathon', entries);
        expect(results, isNotEmpty);
        expect(
          results.first.excerpt.toLowerCase(),
          contains('marathon'),
        );
      });

      test('handles case-insensitive search', () {
        final results = service.search('beach', entries);
        expect(results, isNotEmpty);
        expect(results.first.entry.id, '1');
      });

      test('handles multi-word queries', () {
        final results = service.search('city lights', entries);
        expect(results, isNotEmpty);
        expect(results.first.entry.id, '4');
      });
    });

    group('recentSearches', () {
      test('tracks recent searches', () {
        service.search('beach', entries);
        service.search('marathon', entries);

        expect(service.recentSearches, ['marathon', 'beach']);
      });

      test('deduplicates recent searches', () {
        service.search('beach', entries);
        service.search('marathon', entries);
        service.search('beach', entries);

        expect(service.recentSearches, ['beach', 'marathon']);
      });

      test('limits to 10 recent searches', () {
        for (int i = 0; i < 15; i++) {
          service.search('query$i', entries);
        }

        expect(service.recentSearches, hasLength(10));
      });

      test('clearRecentSearches empties the list', () {
        service.search('beach', entries);
        service.clearRecentSearches();

        expect(service.recentSearches, isEmpty);
      });
    });

    group('getSuggestions', () {
      test('suggests from locations', () {
        final suggestions = service.getSuggestions('mal', entries);
        expect(suggestions, contains('Malibu Beach, California'));
      });

      test('suggests from moods', () {
        final suggestions = service.getSuggestions('gre', entries);
        expect(suggestions, contains('great'));
      });

      test('returns empty for blank input', () {
        final suggestions = service.getSuggestions('', entries);
        expect(suggestions, isEmpty);
      });
    });
  });
}

JournalEntry _makeEntry({
  required String id,
  required String content,
  String? mood,
  String? location,
}) {
  return JournalEntry(
    id: id,
    userId: 'test-user',
    content: content,
    mood: mood,
    locationName: location,
    entryDate: DateTime.now().subtract(const Duration(days: 1)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
