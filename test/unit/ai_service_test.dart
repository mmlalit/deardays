import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/ai/ai_service.dart';

void main() {
  group('AiService', () {
    late AiService service;

    setUp(() {
      service = AiService();
    });

    test('is a singleton', () {
      final a = AiService();
      final b = AiService();
      expect(identical(a, b), isTrue);
    });

    test('instance accessor returns same instance', () {
      expect(identical(AiService.instance, AiService()), isTrue);
    });

    test('isConfigured returns false when AI_API_URL is empty', () {
      // Default value is empty string when no --dart-define is provided
      expect(service.isConfigured, isFalse);
    });

    group('when not configured', () {
      test('lightPolish throws AiServiceException', () {
        expect(
          () => service.lightPolish('test'),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('polishNarrative throws AiServiceException', () {
        expect(
          () => service.polishNarrative('test'),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('transcribeAudio throws AiServiceException', () {
        expect(
          () => service.transcribeAudio('/fake/path.m4a'),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('generateSummary throws AiServiceException', () {
        expect(
          () => service.generateSummary(['entry1', 'entry2']),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('getWritingPrompt throws AiServiceException', () {
        expect(
          () => service.getWritingPrompt(),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('chat throws AiServiceException', () {
        expect(
          () => service.chat(messages: [
            {'role': 'user', 'content': 'hi'}
          ]),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('generateCoverQuery throws AiServiceException', () {
        expect(
          () => service.generateCoverQuery('My Story'),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('generateShareSummary throws AiServiceException', () {
        expect(
          () => service.generateShareSummary('Some journal entry text'),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('detectThemes throws AiServiceException', () {
        expect(
          () => service.detectThemes(['entry text']),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('analyzeEntries throws AiServiceException', () {
        expect(
          () => service.analyzeEntries(['entry text']),
          throwsA(isA<AiServiceException>()),
        );
      });

      test('memorySearch throws AiServiceException', () {
        expect(
          () => service.memorySearch(
            question: 'When was I happy?',
            entrySummaries: ['[0] 2026-01-01 | great | Beach day'],
          ),
          throwsA(isA<AiServiceException>()),
        );
      });
    });

    group('AiServiceException', () {
      test('stores message', () {
        final ex = AiServiceException('test error');
        expect(ex.message, 'test error');
      });

      test('toString includes class name', () {
        final ex = AiServiceException('test error');
        expect(ex.toString(), 'AiServiceException: test error');
      });

      test('is an Exception', () {
        final ex = AiServiceException('test');
        expect(ex, isA<Exception>());
      });
    });
  });
}
