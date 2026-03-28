import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/sync/sync_operation.dart';
import 'package:deardays/services/sync/sync_service.dart';

/// Status update emitted when a write is queued or replayed.
class OfflineWriteStatus {
  final int pendingCount;
  final DateTime lastQueuedAt;

  const OfflineWriteStatus({
    required this.pendingCount,
    required this.lastQueuedAt,
  });
}

/// Result of replaying queued operations.
class OfflineReplayResult {
  final int succeeded;
  final int failed;
  final List<SyncOperation> failedOps;

  const OfflineReplayResult({
    required this.succeeded,
    required this.failed,
    required this.failedOps,
  });
}

/// Intercepts write operations and either executes them immediately (online)
/// or queues them for later replay (offline).
///
/// This is a thin coordination layer — the actual queue persistence is handled
/// by [SyncQueue] and the actual replay is handled by [SyncService].
class OfflineWriteService {
  static final OfflineWriteService _instance = OfflineWriteService._();
  factory OfflineWriteService() => _instance;
  OfflineWriteService._();

  final _connectivity = ConnectivityService();
  final _queue = SyncQueue();
  final _statusController = StreamController<OfflineWriteStatus>.broadcast();

  Stream<OfflineWriteStatus> get statusStream => _statusController.stream;

  /// Executes a write operation. If offline, queues it for later.
  /// Returns true if the caller should proceed with the normal online write,
  /// false if the operation was queued for later.
  Future<bool> write({
    required String tableName,
    required SyncOperationType type,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    if (_connectivity.isOnline) {
      return true; // Let caller proceed with normal write
    }

    // Queue for later
    final opId = id ?? const Uuid().v4();
    final op = SyncOperation(
      id: opId,
      type: type,
      tableName: tableName,
      payload: payload,
      createdAt: DateTime.now(),
      retryCount: 0,
      idempotencyKey: const Uuid().v4(),
    );
    await _queue.enqueue(op);
    _statusController.add(OfflineWriteStatus(
      pendingCount: _queue.count,
      lastQueuedAt: DateTime.now(),
    ));

    if (kDebugMode) {
      debugPrint('[OfflineWriteService] Queued ${type.name} for $tableName (id: $opId)');
    }
    return false;
  }

  /// Replays all queued operations by delegating to [SyncService.processQueue].
  /// Called when connectivity is restored.
  Future<OfflineReplayResult> replayQueue() async {
    final countBefore = _queue.count;
    if (countBefore == 0) {
      return const OfflineReplayResult(succeeded: 0, failed: 0, failedOps: []);
    }

    if (kDebugMode) {
      debugPrint('[OfflineWriteService] Replaying $countBefore queued operations...');
    }

    // Delegate to SyncService which already handles retry, backoff, and idempotency
    await SyncService().processQueue();

    final countAfter = _queue.count;
    final succeeded = countBefore - countAfter;

    // Collect any remaining failed ops
    final failedOps = _queue.getAll().map((e) => e.value).toList();

    final result = OfflineReplayResult(
      succeeded: succeeded,
      failed: countAfter,
      failedOps: failedOps,
    );

    _statusController.add(OfflineWriteStatus(
      pendingCount: countAfter,
      lastQueuedAt: DateTime.now(),
    ));

    if (kDebugMode) {
      debugPrint('[OfflineWriteService] Replay complete: ${result.succeeded} succeeded, ${result.failed} failed');
    }

    return result;
  }

  /// Number of pending operations in the queue.
  int get pendingCount => _queue.count;

  void dispose() {
    _statusController.close();
  }
}
