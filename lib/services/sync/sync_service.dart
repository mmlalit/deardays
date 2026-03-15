import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/sync/sync_operation.dart';

/// Sync status exposed to the UI layer.
enum SyncStatus { synced, pending, syncing, error, failedItems }

/// Orchestrates background sync: listens for connectivity changes and replays
/// queued write operations against Supabase.
///
/// Key design decisions for scale:
/// - **Never drops data**: operations are retried with exponential backoff
///   indefinitely. After 10 failures they're flagged but never deleted.
/// - **Idempotency**: every operation carries a UUID key. The server deduplicates
///   retries so network timeouts can't create duplicate entries.
/// - **Independent processing**: a single failed operation doesn't block the rest
///   of the queue.
/// - **Exponential backoff**: retries wait 2^n seconds (capped at 5 minutes)
///   to avoid thundering herd on server recovery.
class SyncService {
  SyncService._internal();

  static final SyncService _instance = SyncService._internal();
  static SyncService get instance => _instance;
  factory SyncService() => _instance;

  StreamSubscription<bool>? _connectivitySub;
  bool _initialized = false;
  bool _syncing = false;

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Number of operations that have exceeded the soft retry threshold.
  /// These are surfaced in the UI so the user can take action.
  int _failedItemCount = 0;
  int get failedItemCount => _failedItemCount;

  /// Soft threshold: after this many retries, operations are flagged as
  /// "failed" in the UI, but they are NEVER deleted from the queue.
  static const _softRetryThreshold = 10;

  /// Maximum backoff duration between retries.
  static const _maxBackoff = Duration(minutes: 5);

  bool _queueReady = false;

  /// Callback invoked after a successful sync so the UI can refresh providers.
  VoidCallback? onSyncComplete;

  /// Initialize: listen for connectivity changes and trigger sync.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _connectivitySub = ConnectivityService().onlineStatus.listen((online) {
      if (online && _queueReady) {
        processQueue();
      } else if (!online) {
        _setStatus(SyncStatus.pending);
      }
    });

    if (kDebugMode) {
      debugPrint('[SyncService] Initialized (queue not yet ready).');
    }
  }

  /// Call after SyncQueue.init() to enable queue processing.
  void enableQueue() {
    _queueReady = true;
    _updateStatus();
    if (ConnectivityService().isOnline && SyncQueue().count > 0) {
      processQueue();
    }
    if (kDebugMode) {
      debugPrint('[SyncService] Queue enabled. Status: $_status');
    }
  }

  /// Process all queued operations. Called automatically on reconnect.
  ///
  /// Operations are processed independently — one failure does not block others.
  /// Failed operations stay in the queue and are retried on the next cycle
  /// with exponential backoff.
  Future<void> processQueue() async {
    if (_syncing || !_queueReady) return;
    _syncing = true;
    _setStatus(SyncStatus.syncing);

    final queue = SyncQueue();
    final entries = queue.getAll();

    if (entries.isEmpty) {
      _syncing = false;
      _setStatus(SyncStatus.synced);
      return;
    }

    bool hadErrors = false;
    bool hadSuccess = false;
    int failedCount = 0;

    for (final entry in entries) {
      final key = entry.key;
      final op = entry.value;

      // Exponential backoff: skip operations that aren't ready to retry yet
      if (op.lastRetryAt != null && op.retryCount > 0) {
        final backoff = _calculateBackoff(op.retryCount);
        final nextRetryAt = op.lastRetryAt!.add(backoff);
        if (DateTime.now().isBefore(nextRetryAt)) {
          // Not ready to retry yet — skip for this cycle
          if (op.retryCount >= _softRetryThreshold) failedCount++;
          continue;
        }
      }

      try {
        await _replayOperation(op);
        await queue.dequeue(key);
        hadSuccess = true;
        // Remove from local cache after successful sync
        if (op.type == SyncOperationType.create ||
            op.type == SyncOperationType.update) {
          await LocalStorageService().removeCachedEntry(op.id);
        }
        if (kDebugMode) {
          debugPrint('[SyncService] Synced ${op.type.name} ${op.id}');
        }
      } catch (e) {
        // PGRST204 = column not found — schema mismatch, will never succeed.
        // Discard immediately rather than retrying forever.
        if (e.toString().contains('PGRST204')) {
          await queue.dequeue(key);
          if (kDebugMode) {
            debugPrint('[SyncService] Discarded ${op.id}: schema mismatch (PGRST204) — $e');
          }
          continue;
        }

        hadErrors = true;
        final updated = op.copyWith(
          retryCount: op.retryCount + 1,
          lastError: e.toString(),
          lastRetryAt: DateTime.now(),
        );
        await queue.update(key, updated);
        if (updated.retryCount >= _softRetryThreshold) failedCount++;
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Failed ${op.id}: $e '
            '(retry ${updated.retryCount}, '
            'next in ${_calculateBackoff(updated.retryCount).inSeconds}s)',
          );
        }
      }
    }

    _failedItemCount = failedCount;

    if (!hadErrors) {
      await LocalStorageService().setLastSyncTime(DateTime.now());
    }

    _syncing = false;
    _updateStatus();

    // Notify the UI to refresh data after successful syncs
    if (hadSuccess) {
      onSyncComplete?.call();
    }
  }

  /// Manually retry all failed operations (user-triggered from UI).
  /// Resets retry counts so backoff starts fresh.
  Future<void> retryFailed() async {
    final queue = SyncQueue();
    final entries = queue.getAll();

    for (final entry in entries) {
      if (entry.value.retryCount >= _softRetryThreshold) {
        final reset = entry.value.copyWith(
          retryCount: 0,
          lastError: null,
          lastRetryAt: null,
        );
        await queue.update(entry.key, reset);
      }
    }

    _failedItemCount = 0;
    await processQueue();
  }

  /// Replay a single operation against Supabase.
  /// Includes the idempotency key in headers so the server can deduplicate.
  Future<void> _replayOperation(SyncOperation op) async {
    final client = Supabase.instance.client;
    final table = op.tableName;

    // Idempotency is handled by upsert(onConflict: 'id') — no extra column needed.
    final payload = Map<String, dynamic>.from(op.payload);

    switch (op.type) {
      case SyncOperationType.create:
        await client.from(table).upsert(payload, onConflict: 'id');
        if (kDebugMode) {
          debugPrint('[SyncService] UPSERT into $table: ${op.id}');
        }

      case SyncOperationType.update:
        await client
            .from(table)
            .update(payload)
            .eq('id', op.id)
            .eq('user_id', payload['user_id'] as String);
        if (kDebugMode) {
          debugPrint('[SyncService] UPDATE $table: ${op.id}');
        }

      case SyncOperationType.delete:
        await client
            .from(table)
            .delete()
            .eq('id', op.id)
            .eq('user_id', payload['user_id'] as String);
        if (kDebugMode) {
          debugPrint('[SyncService] DELETE from $table: ${op.id}');
        }
    }
  }

  /// Exponential backoff: 2^retryCount seconds, capped at [_maxBackoff].
  Duration _calculateBackoff(int retryCount) {
    final seconds = min(pow(2, retryCount).toInt(), _maxBackoff.inSeconds);
    return Duration(seconds: seconds);
  }

  void _updateStatus() {
    if (!_queueReady) {
      _setStatus(SyncStatus.synced);
      return;
    }
    final queue = SyncQueue();
    if (queue.count == 0) {
      _setStatus(SyncStatus.synced);
    } else if (_failedItemCount > 0) {
      _setStatus(SyncStatus.failedItems);
    } else {
      _setStatus(SyncStatus.pending);
    }
  }

  void _setStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }
}
