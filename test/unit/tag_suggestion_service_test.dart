import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/ai/tag_suggestion_service.dart';

void main() {
  group('TagSuggestionService', () {
    group('suggest — travel keywords', () {
      test('suggests Travel tag for content with travel keywords', () {
        final tags = TagSuggestionService.suggest(
          'We took an amazing trip to Paris and the flight was smooth.',
        );
        expect(tags, contains('Travel'));
      });

      test('suggests Travel for vacation content', () {
        final tags = TagSuggestionService.suggest(
          'Booked a hotel for our vacation at the beach destination.',
        );
        expect(tags, contains('Travel'));
      });
    });

    group('suggest — family keywords', () {
      test('suggests Family tag for content about family members', () {
        final tags = TagSuggestionService.suggest(
          'Spent the weekend with mom and dad at the family house.',
        );
        expect(tags, contains('Family'));
      });

      test('suggests Family for content mentioning children', () {
        final tags = TagSuggestionService.suggest(
          'My daughter and son had a great time with grandma today.',
        );
        expect(tags, contains('Family'));
      });
    });

    group('suggest — work/career keywords', () {
      test('suggests Work tag for work-related content', () {
        final tags = TagSuggestionService.suggest(
          'Had a big meeting at the office with my boss about the project deadline.',
        );
        expect(tags, contains('Work'));
      });

      test('suggests Work for career-related content', () {
        final tags = TagSuggestionService.suggest(
          'Got a promotion at work after the presentation to the client.',
        );
        expect(tags, contains('Work'));
      });
    });

    group('suggest — default for generic content', () {
      test('returns Reflection for content with no keyword matches', () {
        final tags = TagSuggestionService.suggest(
          'Today was uneventful.',
        );
        expect(tags, equals(['Reflection']));
      });
    });

    group('suggest — max tags limit', () {
      test('returns at most 5 tags by default', () {
        // Content with keywords spanning many categories
        final tags = TagSuggestionService.suggest(
          'I took a trip with my family to the beach hotel. '
          'We had dinner at a restaurant and went for a hike in the mountain forest. '
          'I felt grateful and blessed for this adventure. '
          'My friend joined for coffee and we had a creative music session. '
          'At work the boss gave a presentation about the project. '
          'I love my partner and we had a romantic date night.',
        );
        expect(tags.length, lessThanOrEqualTo(5));
      });

      test('respects custom maxTags parameter', () {
        final tags = TagSuggestionService.suggest(
          'We took a trip with family to the beach hotel for vacation. '
          'Had dinner at a restaurant. Went hiking in the mountain forest. '
          'Felt grateful and blessed. My friend joined for coffee.',
          maxTags: 3,
        );
        expect(tags.length, lessThanOrEqualTo(3));
      });
    });

    group('suggest — empty content', () {
      test('handles empty string gracefully', () {
        final tags = TagSuggestionService.suggest('');
        // Empty content has no keyword matches → returns default
        expect(tags, equals(['Reflection']));
      });
    });

    group('suggest — case-insensitive matching', () {
      test('matches uppercase keywords', () {
        final tags = TagSuggestionService.suggest(
          'TRAVEL TRIP FLIGHT VACATION',
        );
        expect(tags, contains('Travel'));
      });

      test('matches mixed-case keywords', () {
        final tags = TagSuggestionService.suggest(
          'My Family went on a Trip to the Beach',
        );
        expect(tags, contains('Family'));
        expect(tags, contains('Travel'));
      });
    });

    group('suggest — sorting by hit count', () {
      test('returns tags sorted by number of keyword hits (descending)', () {
        // Many travel keywords, few family keywords
        final tags = TagSuggestionService.suggest(
          'We took a trip on a flight to the airport for a vacation at a hotel '
          'to explore the destination. My mom came along.',
        );
        expect(tags.first, 'Travel');
      });
    });

    group('allTags', () {
      test('contains expected tag names', () {
        expect(TagSuggestionService.allTags, contains('Travel'));
        expect(TagSuggestionService.allTags, contains('Family'));
        expect(TagSuggestionService.allTags, contains('Work'));
        expect(TagSuggestionService.allTags, contains('Reflection'));
        expect(TagSuggestionService.allTags, contains('Gratitude'));
        expect(TagSuggestionService.allTags, contains('Love'));
      });

      test('has 15 tags', () {
        expect(TagSuggestionService.allTags.length, 15);
      });
    });
  });
}
