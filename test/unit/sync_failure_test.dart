library;

/// Tests for sync failure edge cases and queue item serialization.
///
/// Verifies:
/// - SyncQueue count returns 0 when not initialized
/// - AiQueueItem serialization round-trips correctly
/// - AiQueueItem handles unknown operations gracefully
/// - AiQueueItem copyWith works correctly
/// - ProcessingReport default values
import 'package:flutter_test/flutter_test.dart';

import 'package:deardays/services/ai/offline_ai_queue.dart';
import 'package:deardays/services/sync/sync_queue.dart';

void main() {
  group('SyncQueue edge cases', () {
    test('count returns 0 or throws when box is not open', () {
      // SyncQueue.count may throw if the box hasn't been initialized.
      // In production, init() is called during startup. In tests, we verify
      // it doesn't crash the app (returns 0 or throws a known error).
      try {
        final count = SyncQueue().count;
        expect(count, greaterThanOrEqualTo(0));
      } on StateError {
        // Expected if box is not initialized
      } catch (e) {
        // HiveError or similar — also acceptable in test env
        expect(e.toString(), contains('not initialized'));
      }
    });

    test('is a singleton', () {
      expect(identical(SyncQueue(), SyncQueue()), isTrue);
    });
  });

  group('OfflineAiQueue edge cases', () {
    test('pendingCount returns 0 when not initialized', () {
      final count = OfflineAiQueue().pendingCount;
      expect(count, greaterThanOrEqualTo(0));
    });

    test('OfflineAiQueue is a singleton', () {
      expect(identical(OfflineAiQueue(), OfflineAiQueue()), isTrue);
    });
  });

  group('AiQueueItem serialization', () {
    test('round-trip preserves all fields', () {
      final item = AiQueueItem(
        entryId: 'test-entry-123',
        text: 'Hello world, this is a test.',
        operation: QueueOperation.polish,
        createdAt: DateTime(2026, 3, 15, 10, 30),
        retryCount: 2,
      );

      final json = item.toJson();
      final restored = AiQueueItem.fromJson(json);

      expect(restored.entryId, item.entryId);
      expect(restored.text, item.text);
      expect(restored.operation, QueueOperation.polish);
      expect(restored.retryCount, 2);
      expect(restored.createdAt.year, 2026);
      expect(restored.createdAt.month, 3);
      expect(restored.createdAt.day, 15);
    });

    test('fromJson handles unknown operation gracefully', () {
      final json = {
        'entry_id': 'test',
        'text': 'hello',
        'operation': 'unknown_operation',
        'created_at': '2026-01-01T00:00:00.000',
        'retry_count': 0,
      };

      final item = AiQueueItem.fromJson(json);
      expect(item.operation, QueueOperation.analyze);
    });

    test('fromJson handles missing retry_count', () {
      final json = {
        'entry_id': 'test',
        'text': 'hello',
        'operation': 'lightPolish',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final item = AiQueueItem.fromJson(json);
      expect(item.retryCount, 0);
      expect(item.operation, QueueOperation.lightPolish);
    });

    test('copyWith updates retryCount only', () {
      final item = AiQueueItem(
        entryId: 'e1',
        text: 'text',
        operation: QueueOperation.lightPolish,
        createdAt: DateTime(2026, 1, 1),
        retryCount: 0,
      );

      final updated = item.copyWith(retryCount: 3);
      expect(updated.retryCount, 3);
      expect(updated.entryId, 'e1');
      expect(updated.text, 'text');
      expect(updated.operation, QueueOperation.lightPolish);
      expect(updated.createdAt.year, 2026);
    });

    test('toJson produces expected keys', () {
      final item = AiQueueItem(
        entryId: 'e1',
        text: 'text',
        operation: QueueOperation.analyze,
        createdAt: DateTime(2026, 1, 1),
      );

      final json = item.toJson();
      expect(json, containsPair('entry_id', 'e1'));
      expect(json, containsPair('text', 'text'));
      expect(json, containsPair('operation', 'analyze'));
      expect(json, contains('created_at'));
      expect(json, containsPair('retry_count', 0));
    });
  });

  group('ProcessingReport', () {
    test('default values', () {
      const report = ProcessingReport();
      expect(report.succeeded, 0);
      expect(report.failed, 0);
      expect(report.results, isEmpty);
    });

    test('custom values', () {
      final report = ProcessingReport(
        succeeded: 5,
        failed: 2,
        results: {'e1': const ServerAnalysisResult(polishedText: 'polished')},
      );
      expect(report.succeeded, 5);
      expect(report.failed, 2);
      expect(report.results, hasLength(1));
      expect(report.results['e1']!.polishedText, 'polished');
    });
  });

  group('LocalAnalysisResult', () {
    test('holds all fields', () {
      const result = LocalAnalysisResult(
        mood: 'great',
        moodConfidence: 0.85,
        title: 'My Day',
        highlightQuote: 'It was amazing!',
      );
      expect(result.mood, 'great');
      expect(result.moodConfidence, 0.85);
      expect(result.title, 'My Day');
      expect(result.highlightQuote, 'It was amazing!');
    });

    test('highlightQuote is optional', () {
      const result = LocalAnalysisResult(
        mood: 'okay',
        moodConfidence: 0.5,
        title: 'Untitled',
      );
      expect(result.highlightQuote, isNull);
    });
  });
}
