import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'sync_operation.dart';

/// FIFO queue of pending sync operations, persisted in an encrypted Hive box.
class SyncQueue {
  SyncQueue._internal();

  static final SyncQueue _instance = SyncQueue._internal();
  static SyncQueue get instance => _instance;
  factory SyncQueue() => _instance;

  static const String _boxName = 'sync_queue';

  /// Maximum queue size — prevents unbounded Hive box growth. Oldest
  /// successfully-retried items are compacted before this limit bites, but if
  /// the device stays offline for a very long time, we cap to prevent disk bloat.
  static const int maxQueueSize = 10000;
  Box<String>? _box;

  // H-03 FIX: Track evictions so callers can detect data-loss conditions.
  int _evictionCount = 0;
  int get evictionCount => _evictionCount;

  /// Open the Hive box. Call after `Hive.initFlutter()`.
  Future<void> init(HiveAesCipher cipher) async {
    _box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    if (kDebugMode) {
      debugPrint('[SyncQueue] Initialized with ${_box!.length} pending ops.');
    }
  }

  /// Initialize without encryption — for tests only.
  @visibleForTesting
  Future<void> initForTesting(String hiveDir) async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Enqueue a new sync operation (FIFO — key is timestamp + id).
  ///
  /// If the queue has reached [maxQueueSize], the oldest operation is evicted
  /// to make room. This prevents unbounded disk growth on devices that stay
  /// offline for extended periods.
  Future<void> enqueue(SyncOperation op) async {
    _ensureOpen();
    // H-03 FIX: Evict oldest if at capacity — track and warn about data loss.
    if (_box!.length >= maxQueueSize) {
      final sortedKeys = _box!.keys.cast<String>().toList()..sort();
      final oldestKey = sortedKeys.first;
      // Try to decode evicted op for the warning message
      String evictedDesc = oldestKey;
      try {
        final raw = _box!.get(oldestKey);
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          evictedDesc = '${decoded['type']} on ${decoded['tableName']}';
        }
      } catch (_) {}
      await _box!.delete(oldestKey);
      _evictionCount++;
      debugPrint('[SyncQueue] WARNING: Queue full ($maxQueueSize) — evicting oldest operation: $evictedDesc (total evictions: $_evictionCount)');
    }
    final key = '${op.createdAt.millisecondsSinceEpoch}_${op.id}';
    await _box!.put(key, jsonEncode(op.toJson()));
    if (kDebugMode) {
      debugPrint('[SyncQueue] Enqueued ${op.type.name} for ${op.tableName}');
    }
  }

  /// Remove a completed operation by its key.
  Future<void> dequeue(String key) async {
    _ensureOpen();
    await _box!.delete(key);
  }

  /// All pending operations in FIFO order.
  List<MapEntry<String, SyncOperation>> getAll() {
    _ensureOpen();
    final entries = <MapEntry<String, SyncOperation>>[];
    for (final key in _box!.keys.cast<String>().toList()..sort()) {
      try {
        final json = jsonDecode(_box!.get(key)!) as Map<String, dynamic>;
        entries.add(MapEntry(key, SyncOperation.fromJson(json)));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SyncQueue] Skipping corrupt entry $key: $e');
        }
      }
    }
    return entries;
  }

  /// Number of pending operations.
  int get count {
    _ensureOpen();
    return _box!.length;
  }

  /// Clear all pending operations.
  Future<void> clear() async {
    _ensureOpen();
    await _box!.clear();
  }

  /// Update an existing operation (e.g. to increment retryCount).
  Future<void> update(String key, SyncOperation op) async {
    _ensureOpen();
    await _box!.put(key, jsonEncode(op.toJson()));
  }

  /// Returns true if there is a pending sync operation for the given [entityId].
  /// Used by UI to show sync status indicators on entry cards.
  bool isPending(String entityId) {
    if (_box == null || !_box!.isOpen) return false;
    for (final key in _box!.keys.cast<String>()) {
      if (key.endsWith('_$entityId')) return true;
    }
    return false;
  }

  /// Set of all entity IDs currently pending sync.
  Set<String> get pendingIds {
    if (_box == null || !_box!.isOpen) return {};
    final ids = <String>{};
    for (final key in _box!.keys.cast<String>()) {
      final parts = key.split('_');
      if (parts.length >= 2) ids.add(parts.sublist(1).join('_'));
    }
    return ids;
  }

  void _ensureOpen() {
    if (_box == null || !_box!.isOpen) {
      throw StateError('SyncQueue not initialized. Call init() first.');
    }
  }
}
