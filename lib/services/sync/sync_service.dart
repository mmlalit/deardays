import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/sync/sync_operation.dart';

/// Sync status exposed to the UI layer.
enum SyncStatus { synced, pending, syncing, error }

/// Orchestrates background sync: listens for connectivity changes and replays
/// queued write operations against Supabase.
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

  static const _maxRetries = 3;

  bool _queueReady = false;

  /// Initialize: listen for connectivity changes and trigger sync.
  /// Note: SyncQueue must be initialized separately (requires Hive cipher).
  /// Until the queue is ready, the service operates in pass-through mode.
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

    for (final entry in entries) {
      final key = entry.key;
      final op = entry.value;

      if (op.retryCount >= _maxRetries) {
        if (kDebugMode) {
          debugPrint('[SyncService] Skipping failed op ${op.id} (max retries)');
        }
        hadErrors = true;
        continue;
      }

      try {
        await _replayOperation(op);
        await queue.dequeue(key);
        if (kDebugMode) {
          debugPrint('[SyncService] Synced ${op.type.name} ${op.id}');
        }
      } catch (e) {
        hadErrors = true;
        final updated = op.copyWith(
          retryCount: op.retryCount + 1,
          lastError: e.toString(),
        );
        await queue.update(key, updated);
        if (kDebugMode) {
          debugPrint('[SyncService] Failed ${op.id}: $e (retry ${updated.retryCount})');
        }
      }
    }

    if (!hadErrors) {
      await LocalStorageService().setLastSyncTime(DateTime.now());
    }

    _syncing = false;
    _updateStatus();
  }

  /// Replay a single operation against Supabase.
  ///
  /// In the current implementation this is a stub that logs the operation.
  /// Wire up to JournalRepository.createEntry/updateEntry/deleteEntry
  /// once the offline-aware repository wrapper is ready.
  Future<void> _replayOperation(SyncOperation op) async {
    // TODO: Wire to JournalRepository when OfflineJournalRepository is implemented
    // For now, simulate the replay with a short delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (kDebugMode) {
      debugPrint(
        '[SyncService] Replaying ${op.type.name} on ${op.tableName}: ${op.id}',
      );
    }
  }

  void _updateStatus() {
    if (!_queueReady) {
      _setStatus(SyncStatus.synced);
      return;
    }
    final queue = SyncQueue();
    if (queue.count == 0) {
      _setStatus(SyncStatus.synced);
    } else {
      final entries = queue.getAll();
      final allFailed = entries.every((e) => e.value.retryCount >= _maxRetries);
      _setStatus(allFailed ? SyncStatus.error : SyncStatus.pending);
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
