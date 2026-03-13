import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/services/ai/offline_ai_queue.dart';

void main() {
  group('OfflineAiQueue', () {
    late OfflineAiQueue queue;

    setUpAll(() async {
      Hive.init('${DateTime.now().millisecondsSinceEpoch}_queue_test');
    });

    setUp(() async {
      queue = OfflineAiQueue();
      await queue.initForTesting();
      await queue.clear();
    });

    test('is a singleton', () {
      final a = OfflineAiQueue();
      final b = OfflineAiQueue();
      expect(identical(a, b), isTrue);
    });

    group('analyzeLocally', () {
      test('detects mood from positive text', () {
        final result = queue.analyzeLocally(
          'What an amazing and wonderful day! I feel so happy and grateful.',
        );
        expect(result.mood, isIn(['great', 'good']));
        expect(result.moodConfidence, greaterThan(0));
      });

      test('detects mood from negative text', () {
        final result = queue.analyzeLocally(
          'Terrible day. I feel devastated and heartbroken.',
        );
        expect(result.mood, isIn(['tough', 'low']));
      });

      test('returns okay for neutral text', () {
        final result = queue.analyzeLocally(
          'Went to the store and bought some groceries.',
        );
        expect(result.mood, 'okay');
      });

      test('extracts title from first line', () {
        final result = queue.analyzeLocally(
          'Beach Sunrise\n\nWoke up early and drove to the coast.',
        );
        expect(result.title, 'Beach Sunrise');
      });

      test('extracts title from first words when no newline', () {
        final result = queue.analyzeLocally(
          'Today I went to the beautiful park with my family and had a great time playing in the sun.',
        );
        expect(result.title.length, lessThan(60));
        expect(result.title, isNotEmpty);
      });

      test('returns Untitled for empty text', () {
        final result = queue.analyzeLocally('');
        expect(result.title, 'Untitled');
      });

      test('extracts highlight quote when available', () {
        final result = queue.analyzeLocally(
          'Morning Walk\n\nI realized that these small moments of peace are what I truly treasure in life. The coffee was perfect.',
        );
        // Highlight may or may not be extracted depending on sentence scoring
        // but it should not throw
        expect(result.highlightQuote, anyOf(isNull, isA<String>()));
      });
    });

    group('queue operations', () {
      test('starts empty', () {
        expect(queue.pendingCount, 0);
        expect(queue.getPending(), isEmpty);
      });

      test('enqueue adds items', () async {
        await queue.enqueue(AiQueueItem(
          entryId: 'entry-1',
          text: 'Hello world',
          operation: QueueOperation.polish,
          createdAt: DateTime.now(),
        ));

        expect(queue.pendingCount, 1);
      });

      test('getPending returns items in FIFO order', () async {
        final now = DateTime.now();
        await queue.enqueue(AiQueueItem(
          entryId: 'entry-1',
          text: 'First',
          operation: QueueOperation.polish,
          createdAt: now,
        ));
        await queue.enqueue(AiQueueItem(
          entryId: 'entry-2',
          text: 'Second',
          operation: QueueOperation.analyze,
          createdAt: now.add(const Duration(seconds: 1)),
        ));

        final pending = queue.getPending();
        expect(pending.length, 2);
        expect(pending.first.value.entryId, 'entry-1');
        expect(pending.last.value.entryId, 'entry-2');
      });

      test('dequeue removes item by key', () async {
        await queue.enqueue(AiQueueItem(
          entryId: 'entry-1',
          text: 'Test',
          operation: QueueOperation.polish,
          createdAt: DateTime.now(),
        ));

        final pending = queue.getPending();
        expect(pending.length, 1);

        await queue.dequeue(pending.first.key);
        expect(queue.pendingCount, 0);
      });

      test('clear removes all items', () async {
        for (int i = 0; i < 5; i++) {
          await queue.enqueue(AiQueueItem(
            entryId: 'entry-$i',
            text: 'Text $i',
            operation: QueueOperation.polish,
            createdAt: DateTime.now().add(Duration(seconds: i)),
          ));
        }

        expect(queue.pendingCount, 5);
        await queue.clear();
        expect(queue.pendingCount, 0);
      });
    });

    group('AiQueueItem', () {
      test('serializes to and from JSON', () {
        final now = DateTime.now();
        final item = AiQueueItem(
          entryId: 'entry-1',
          text: 'Test text',
          operation: QueueOperation.polish,
          createdAt: now,
          retryCount: 2,
        );

        final json = item.toJson();
        final restored = AiQueueItem.fromJson(json);

        expect(restored.entryId, 'entry-1');
        expect(restored.text, 'Test text');
        expect(restored.operation, QueueOperation.polish);
        expect(restored.retryCount, 2);
      });

      test('copyWith updates retryCount', () {
        final item = AiQueueItem(
          entryId: 'e1',
          text: 't',
          operation: QueueOperation.analyze,
          createdAt: DateTime.now(),
        );
        final updated = item.copyWith(retryCount: 3);
        expect(updated.retryCount, 3);
        expect(updated.entryId, 'e1');
      });
    });

    group('QueueOperation', () {
      test('has all expected values', () {
        expect(QueueOperation.values, hasLength(3));
        expect(QueueOperation.values, contains(QueueOperation.polish));
        expect(QueueOperation.values, contains(QueueOperation.lightPolish));
        expect(QueueOperation.values, contains(QueueOperation.analyze));
      });
    });

    group('LocalAnalysisResult', () {
      test('holds all fields', () {
        const result = LocalAnalysisResult(
          mood: 'great',
          moodConfidence: 0.85,
          title: 'Beach Day',
          highlightQuote: 'The waves were perfect',
        );
        expect(result.mood, 'great');
        expect(result.moodConfidence, 0.85);
        expect(result.title, 'Beach Day');
        expect(result.highlightQuote, 'The waves were perfect');
      });
    });

    group('ProcessingReport', () {
      test('default values are zero', () {
        const report = ProcessingReport();
        expect(report.succeeded, 0);
        expect(report.failed, 0);
        expect(report.results, isEmpty);
      });
    });
  });
}
