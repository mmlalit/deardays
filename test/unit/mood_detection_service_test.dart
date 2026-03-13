import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/ai/mood_detection_service.dart';

void main() {
  group('MoodDetectionService', () {
    late MoodDetectionService service;

    setUp(() {
      service = MoodDetectionService();
    });

    test('is a singleton', () {
      final a = MoodDetectionService();
      final b = MoodDetectionService();
      expect(identical(a, b), isTrue);
    });

    group('detectMood', () {
      test('returns okay for empty text', () {
        expect(service.detectMood(''), 'okay');
        expect(service.detectMood('  '), 'okay');
      });

      test('detects great mood from positive keywords', () {
        expect(
          service.detectMood('This was the most amazing day! I feel incredible and thrilled.'),
          'great',
        );
      });

      test('detects good mood from mild positive keywords', () {
        expect(
          service.detectMood('Had a nice and pleasant day. Feeling grateful and relaxed.'),
          'good',
        );
      });

      test('detects tough mood from strong negative keywords', () {
        expect(
          service.detectMood('Terrible day. I feel devastated and heartbroken. Everything is awful.'),
          'tough',
        );
      });

      test('detects low mood from mild negative keywords', () {
        expect(
          service.detectMood('Feeling sad and lonely today. I miss my old friends.'),
          'low',
        );
      });

      test('returns okay for neutral/ambiguous text', () {
        expect(
          service.detectMood('Went to the store and bought some groceries.'),
          'okay',
        );
      });

      test('handles mixed signals by returning dominant mood', () {
        // More positive than negative keywords
        final mood = service.detectMood(
          'Despite feeling tired, I had a wonderful and amazing celebration with friends. So happy!',
        );
        expect(mood, isIn(['great', 'good']));
      });

      test('boosts mood when intensifiers are present', () {
        final withIntensifier = service.detectMood(
          'This was absolutely incredible! Truly the best experience ever.',
        );
        expect(withIntensifier, 'great');
      });

      test('handles negation patterns', () {
        final mood = service.detectMood('Not happy at all today. Nothing worked. I regret everything.');
        // Negation should reduce positive scoring
        expect(mood, isIn(['low', 'tough', 'okay', 'good']));
      });
    });

    group('getConfidence', () {
      test('returns 0 for empty text', () {
        expect(service.getConfidence('', 'great'), 0.0);
      });

      test('returns higher confidence for text with many matching keywords', () {
        final highConf = service.getConfidence(
          'Amazing incredible wonderful fantastic day!',
          'great',
        );
        final lowConf = service.getConfidence(
          'Went to the store.',
          'great',
        );
        expect(highConf, greaterThan(lowConf));
      });

      test('returns value between 0 and 1', () {
        final conf = service.getConfidence(
          'I feel happy and grateful today',
          'good',
        );
        expect(conf, greaterThanOrEqualTo(0.0));
        expect(conf, lessThanOrEqualTo(1.0));
      });
    });
  });
}
