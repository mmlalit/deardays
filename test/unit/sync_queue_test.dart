import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/sync/sync_operation.dart';

void main() {
  group('SyncQueue', () {
    late SyncQueue queue;

    setUpAll(() async {
      Hive.init('${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_sync_test');
    });

    setUp(() async {
      queue = SyncQueue();
      await queue.initForTesting(Directory.systemTemp.path);
      await queue.clear();
    });

    test('is a singleton', () {
      final a = SyncQueue();
      final b = SyncQueue();
      expect(identical(a, b), isTrue);
    });

    test('starts empty', () {
      expect(queue.count, 0);
      expect(queue.getAll(), isEmpty);
    });

    test('enqueue adds operations', () async {
      await queue.enqueue(SyncOperation(
        id: 'entry-1',
        type: SyncOperationType.create,
        tableName: 'journal_entries',
        payload: {'id': 'entry-1', 'user_id': 'user-1', 'content': 'test'},
        createdAt: DateTime.now(),
        idempotencyKey: 'idem-enqueue-1',
      ));

      expect(queue.count, 1);
    });

    test('getAll returns operations in FIFO order', () async {
      final now = DateTime.now();
      await queue.enqueue(SyncOperation(
        id: 'entry-1',
        type: SyncOperationType.create,
        tableName: 'journal_entries',
        payload: {'id': 'entry-1', 'user_id': 'user-1'},
        createdAt: now,
        idempotencyKey: 'idem-fifo-1',
      ));
      await queue.enqueue(SyncOperation(
        id: 'entry-2',
        type: SyncOperationType.update,
        tableName: 'journal_entries',
        payload: {'id': 'entry-2', 'user_id': 'user-1'},
        createdAt: now.add(const Duration(seconds: 1)),
        idempotencyKey: 'idem-fifo-2',
      ));

      final all = queue.getAll();
      expect(all.length, 2);
      expect(all.first.value.id, 'entry-1');
      expect(all.last.value.id, 'entry-2');
    });

    test('dequeue removes operation by key', () async {
      await queue.enqueue(SyncOperation(
        id: 'entry-1',
        type: SyncOperationType.create,
        tableName: 'journal_entries',
        payload: {'id': 'entry-1', 'user_id': 'user-1'},
        createdAt: DateTime.now(),
        idempotencyKey: 'idem-dequeue-1',
      ));

      final all = queue.getAll();
      expect(all.length, 1);

      await queue.dequeue(all.first.key);
      expect(queue.count, 0);
    });

    test('update replaces operation data', () async {
      await queue.enqueue(SyncOperation(
        id: 'entry-1',
        type: SyncOperationType.create,
        tableName: 'journal_entries',
        payload: {'id': 'entry-1', 'user_id': 'user-1'},
        createdAt: DateTime.now(),
        idempotencyKey: 'idem-update-1',
      ));

      final all = queue.getAll();
      final key = all.first.key;
      final op = all.first.value;

      final updated = op.copyWith(retryCount: 2, lastError: 'Network error');
      await queue.update(key, updated);

      final refreshed = queue.getAll();
      expect(refreshed.first.value.retryCount, 2);
      expect(refreshed.first.value.lastError, 'Network error');
    });

    test('clear removes all operations', () async {
      for (int i = 0; i < 5; i++) {
        await queue.enqueue(SyncOperation(
          id: 'entry-$i',
          type: SyncOperationType.create,
          tableName: 'journal_entries',
          payload: {'id': 'entry-$i', 'user_id': 'user-1'},
          createdAt: DateTime.now().add(Duration(seconds: i)),
          idempotencyKey: 'idem-clear-$i',
        ));
      }

      expect(queue.count, 5);
      await queue.clear();
      expect(queue.count, 0);
    });
  });

  group('SyncOperation', () {
    test('serializes to and from JSON', () {
      final now = DateTime.now();
      final op = SyncOperation(
        id: 'entry-1',
        type: SyncOperationType.update,
        tableName: 'journal_entries',
        payload: {'id': 'entry-1', 'user_id': 'user-1', 'content': 'test'},
        createdAt: now,
        retryCount: 1,
        lastError: 'timeout',
        idempotencyKey: 'idem-serial-1',
      );

      final json = op.toJson();
      final restored = SyncOperation.fromJson(json);

      expect(restored.id, 'entry-1');
      expect(restored.type, SyncOperationType.update);
      expect(restored.tableName, 'journal_entries');
      expect(restored.retryCount, 1);
      expect(restored.lastError, 'timeout');
      expect(restored.payload['content'], 'test');
    });

    test('copyWith updates retryCount and lastError', () {
      final op = SyncOperation(
        id: 'e1',
        type: SyncOperationType.delete,
        tableName: 'journal_entries',
        payload: {'id': 'e1', 'user_id': 'u1'},
        createdAt: DateTime.now(),
        idempotencyKey: 'idem-copywith-1',
      );

      final updated = op.copyWith(retryCount: 3, lastError: 'fail');
      expect(updated.retryCount, 3);
      expect(updated.lastError, 'fail');
      expect(updated.id, 'e1');
      expect(updated.type, SyncOperationType.delete);
    });

    test('has all expected operation types', () {
      expect(SyncOperationType.values, hasLength(3));
      expect(SyncOperationType.values, contains(SyncOperationType.create));
      expect(SyncOperationType.values, contains(SyncOperationType.update));
      expect(SyncOperationType.values, contains(SyncOperationType.delete));
    });
  });
}
