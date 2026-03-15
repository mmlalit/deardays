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
    // Evict oldest if at capacity
    if (_box!.length >= maxQueueSize) {
      final oldestKey = (_box!.keys.cast<String>().toList()..sort()).first;
      await _box!.delete(oldestKey);
      if (kDebugMode) {
        debugPrint('[SyncQueue] Queue full ($maxQueueSize). Evicted $oldestKey');
      }
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

  void _ensureOpen() {
    if (_box == null || !_box!.isOpen) {
      throw StateError('SyncQueue not initialized. Call init() first.');
    }
  }
}
